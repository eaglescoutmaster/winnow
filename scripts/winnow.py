#!/usr/bin/env python3
"""Winnow for Linux and macOS. Data-driven: reads catalog/linux.json or catalog/macos.json and
contains no removal lists of its own. Python 3.8+, standard library only.

  winnow.py state [--json]                          read-only report
  winnow.py auto [--profile P] [--exclude a,b] [--only id,id] [--no-snapshot]   one shot: plan and apply
  winnow.py plan [--profile P] [--exclude a,b] [--only id,id]   dry run, writes logs/plan-<id>.json
  winnow.py apply --plan FILE [--no-snapshot]       changes the system; only what the plan listed
  winnow.py revert LOG [--apply] [--no-snapshot]    undo a run (dry run unless --apply)

Run it as your normal user, never with sudo: user-level settings must be changed for you, not
for root. Commands that need root are run through sudo one at a time.

Exit codes: 0 ok | 1 unexpected error | 2 precondition failed, nothing changed
            3 finished with failures | 4 invalid input or catalog
"""
import argparse
import datetime
import fnmatch
import hashlib
import json
import os
import re
import secrets
import shutil
import socket
import subprocess
import sys
import tempfile

EXIT_OK, EXIT_ERROR, EXIT_PRECONDITION, EXIT_PARTIAL, EXIT_INVALID = 0, 1, 2, 3, 4
TIERS = ["safe", "moderate", "aggressive", "never-default"]
PROFILES = {"safe": ["safe"], "moderate": ["safe", "moderate"], "aggressive": ["safe", "moderate", "aggressive"]}
RECUR = ["yes", "no", "sometimes", "unknown"]
ID_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
RESTARTABLE = ["cfprefsd", "Dock", "Finder", "SystemUIServer", "ControlCenter", "NotificationCenter"]

# op -> platform, required target fields. The only dispatch table; targets live in the catalog.
OPS = {
    "package-remove": {"os": "linux", "target": ["manager", "name"]},
    "systemd-disable": {"os": "linux", "target": ["unit", "scope"]},
    "gsettings-set": {"os": "linux", "target": ["schema", "key"], "value": True},
    "keyvalue-set": {"os": "linux", "target": ["file", "key"], "value": True},
    "defaults-write": {"os": "macos", "target": ["domain", "key"], "value": True},
    "app-trash": {"os": "macos", "target": ["path"]},
    "launchctl-disable": {"os": "macos", "target": ["label", "domain"]},
}
MANAGERS = ["apt", "dnf", "snap", "flatpak"]
SYSTEMD_STATES = ["enabled", "enabled-runtime", "linked", "linked-runtime", "alias", "masked", "masked-runtime",
                  "static", "indirect", "disabled", "generated", "transient"]
DEFAULTS_TYPES = ["bool", "int", "float", "string"]


class Stop(Exception):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code
        self.message = message


# ------------------------------------------------------------------ shell

class Shell:
    """Runs commands with a fixed argv (never through a shell). Tests substitute a fake."""

    def run(self, argv, sudo=False, env=None, timeout=900):
        if sudo and hasattr(os, "geteuid") and os.geteuid() != 0:
            argv = ["sudo", "-n"] + list(argv)
        e = dict(os.environ)
        e["LC_ALL"] = "C"
        if env:
            e.update(env)
        try:
            p = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=e, timeout=timeout)
            return p.returncode, p.stdout.decode("utf-8", "replace")
        except FileNotFoundError:
            return 127, "command not found: %s" % argv[0]
        except subprocess.TimeoutExpired:
            return 124, "timed out: %s" % " ".join(argv)

    def which(self, name):
        return shutil.which(name)


# ------------------------------------------------------------------ machine

def parse_os_release(text):
    out = {}
    for line in text.splitlines():
        m = re.match(r'^([A-Z_]+)=(.*)$', line.strip())
        if m:
            out[m.group(1)] = m.group(2).strip().strip('"').strip("'")
    return out


def version_tuple(s):
    return tuple(int(x) for x in re.findall(r"\d+", str(s))[:3])


def machine_info(sh):
    info = {"hostname": socket.gethostname(), "user": os.environ.get("USER") or os.environ.get("USERNAME") or "",
            "isRoot": bool(hasattr(os, "geteuid") and os.geteuid() == 0), "python": sys.version.split()[0]}
    if sys.platform == "darwin":
        code, out = sh.run(["sw_vers", "-productVersion"])
        info.update({"os": "macos", "version": out.strip() if code == 0 else "", "distro": "macos", "like": []})
        code, out = sh.run(["profiles", "status", "-type", "enrollment"])
        info["managed"] = bool(code == 0 and re.search(r"MDM enrollment:\s*Yes", out))
    elif sys.platform.startswith("linux"):
        rel = {}
        try:
            with open("/etc/os-release", encoding="utf-8") as f:
                rel = parse_os_release(f.read())
        except OSError:
            pass
        info.update({"os": "linux", "distro": rel.get("ID", ""), "like": rel.get("ID_LIKE", "").split(),
                     "version": rel.get("VERSION_ID", ""), "managed": False})
    else:
        info.update({"os": sys.platform, "distro": "", "like": [], "version": "", "managed": False})
    return info


# ------------------------------------------------------------------ catalog

def is_protected(item, protected):
    t = item.get("target", {})
    checks = (("packages", t.get("name") if item.get("op") == "package-remove" else None),
              ("units", t.get("unit")), ("paths", t.get("path") or t.get("file")),
              ("labels", t.get("label")), ("domains", t.get("domain") if item.get("op") == "defaults-write" else None))
    for key, value in checks:
        if value:
            for pat in (protected or {}).get(key, []):
                if fnmatch.fnmatchcase(value, pat):
                    return True
    return False


def validate_catalog(cat):
    """Structural validation. Returns a list of error strings."""
    e = []
    if cat.get("schemaVersion") != 1:
        e.append("schemaVersion must be 1")
    plat = cat.get("platform")
    if plat not in ("linux", "macos"):
        e.append("platform must be linux or macos")
    items = cat.get("items") or []
    if not items:
        e.append("items must be a non-empty array")
    cats = cat.get("categories") or []
    tags = cat.get("tags") or []
    seen = set()
    for it in items:
        iid = str(it.get("id", ""))
        p = "item '%s':" % iid
        if not ID_RE.match(iid):
            e.append(p + " id must be kebab-case")
        if iid in seen:
            e.append(p + " duplicate id")
        seen.add(iid)
        if not it.get("name"):
            e.append(p + " name missing")
        if it.get("category") not in cats:
            e.append(p + " invalid category")
        if it.get("tier") not in TIERS:
            e.append(p + " invalid tier")
        for tag in it.get("tags", []):
            if tag not in tags:
                e.append(p + " invalid tag '%s'" % tag)
        if it.get("returnsAfterUpgrade") not in RECUR:
            e.append(p + " invalid returnsAfterUpgrade")
        src = it.get("sources") or []
        if not src:
            e.append(p + " needs at least one source")
        for s in src:
            if not str(s).startswith("https://"):
                e.append(p + " source is not an https URL: %s" % s)
        op = OPS.get(it.get("op"))
        if not op:
            e.append(p + " unknown op")
            continue
        if op["os"] != plat:
            e.append(p + " op '%s' is not valid on %s" % (it.get("op"), plat))
        t = it.get("target") or {}
        for f in op["target"]:
            if not t.get(f):
                e.append(p + " target.%s missing" % f)
        if op.get("value") and "value" not in it:
            e.append(p + " value missing")
        o = it.get("op")
        if o == "package-remove" and t.get("manager") not in MANAGERS:
            e.append(p + " target.manager invalid")
        if o == "systemd-disable" and t.get("scope") not in ("system", "user"):
            e.append(p + " target.scope must be system or user")
        if o == "keyvalue-set" and not str(t.get("file", "")).startswith("/etc/"):
            e.append(p + " target.file must be under /etc/")
        if o == "defaults-write":
            if it.get("valueType") not in DEFAULTS_TYPES:
                e.append(p + " valueType invalid")
            for r in t.get("restart", []):
                if r not in RESTARTABLE:
                    e.append(p + " restart target '%s' not allowed" % r)
        if o == "app-trash" and not re.match(r"^/Applications/[^/]+\.app$", str(t.get("path", ""))):
            e.append(p + " target.path must be /Applications/<name>.app")
        if o == "launchctl-disable" and t.get("domain") not in ("user", "system"):
            e.append(p + " target.domain must be user or system")
        if it.get("tier") != "never-default" and is_protected(it, cat.get("protected")):
            e.append(p + " targets a protected identifier and must be tier never-default")
    return e


def load_catalog(path):
    if not os.path.exists(path):
        raise Stop(EXIT_INVALID, "INVALID: catalog not found: %s" % path)
    with open(path, "rb") as f:
        raw = f.read()
    try:
        cat = json.loads(raw.decode("utf-8"))
    except ValueError as ex:
        raise Stop(EXIT_INVALID, "INVALID: catalog is not valid JSON: %s" % ex)
    errors = validate_catalog(cat)
    if errors:
        raise Stop(EXIT_INVALID, "INVALID: catalog invalid:\n  " + "\n  ".join(errors))
    cat["sha256"] = hashlib.sha256(raw).hexdigest().upper()
    return cat


def select_items(cat, profile="safe", only=None, exclude=None):
    """Profile tiers are cumulative. never-default items are only ever selected by explicit only."""
    items = cat["items"]
    if only:
        known = {i["id"] for i in items}
        unknown = [x for x in only if x not in known]
        if unknown:
            raise Stop(EXIT_INVALID, "INVALID: unknown item id(s): " + ", ".join(unknown))
        return [i for i in items if i["id"] in only]
    if profile not in PROFILES:
        raise Stop(EXIT_INVALID, "INVALID: unknown profile: %s" % profile)
    sel = [i for i in items if i["tier"] in PROFILES[profile]]
    if exclude:
        sel = [i for i in sel if not set(i.get("tags", [])) & set(exclude)]
    return sel


def applicable(item, machine):
    a = item.get("applies") or {}
    d = a.get("distros")
    if d and machine["os"] == "linux" and machine.get("distro", "") not in d:
        return False  # exact ID from /etc/os-release; derivatives are not assumed to match
    v = version_tuple(machine.get("version", ""))
    if a.get("minVersion") and v and v < version_tuple(a["minVersion"]):
        return False
    if a.get("maxVersion") and v and v > version_tuple(a["maxVersion"]):
        return False
    return True


def plan_hash(catalog_sha, hostname, ids):
    text = "%s|%s|%s" % (catalog_sha, hostname, ",".join(sorted(ids)))
    return hashlib.sha256(text.encode("utf-8")).hexdigest().upper()


# ------------------------------------------------------------------ state objects

def st(known=True, present=True, applied=False, current=None, detail="", blocked=False):
    return {"known": known, "present": present, "applied": applied, "current": current, "detail": detail, "blocked": blocked}


# ------------------------------------------------------------------ linux: packages

def parse_apt_simulation(text):
    """Names apt-get -s would remove ('Remv name [version]' lines)."""
    names = []
    for line in text.splitlines():
        m = re.match(r"^Remv (\S+)", line)
        if m:
            names.append(m.group(1).split(":")[0])
    return names


def package_state(sh, item, protected):
    t = item["target"]
    mgr, name = t["manager"], t["name"]
    if mgr == "apt":
        if not sh.which("dpkg-query"):
            return st(present=False, detail="apt/dpkg not available")
        code, out = sh.run(["dpkg-query", "-W", "-f=${db:Status-Status} ${Version}", name])
        if code != 0 or not out.startswith("installed"):
            return st(present=False, detail="not installed")
        version = out.split(" ", 1)[1].strip() if " " in out else ""
        code, manual = sh.run(["apt-mark", "showmanual", name])
        cur = {"version": version, "manual": bool(code == 0 and name in manual.split())}
        code, sim = sh.run(["apt-get", "-s", "remove", name])
        if code != 0:
            return st(known=False, detail="apt simulation failed: %s" % sim.strip()[-200:])
        extra = [n for n in parse_apt_simulation(sim) if n != name and n not in t.get("alsoRemoves", [])]
        return _package_guard(name, version, cur, extra, protected)
    if mgr == "dnf":
        if not sh.which("rpm"):
            return st(present=False, detail="dnf/rpm not available")
        code, out = sh.run(["rpm", "-q", "--qf", "%{VERSION}-%{RELEASE}", name])
        if code != 0:
            return st(present=False, detail="not installed")
        code, test = sh.run(["rpm", "-e", "--test", name])
        if code != 0:
            return st(blocked=True, current={"version": out.strip()},
                      detail="refused: other installed packages depend on it: %s" % " ".join(test.split())[:200])
        return st(current={"version": out.strip()}, detail="installed %s" % out.strip())
    if mgr == "snap":
        if not sh.which("snap"):
            return st(present=False, detail="snapd not available")
        code, out = sh.run(["snap", "list", name])
        if code != 0:
            return st(present=False, detail="not installed")
        cols = out.strip().splitlines()[-1].split()
        cur = {"version": cols[1] if len(cols) > 1 else "", "tracking": cols[3] if len(cols) > 3 else "",
               "classic": "classic" in (cols[5] if len(cols) > 5 else "")}
        return st(current=cur, detail="installed %s" % cur["version"])
    if mgr == "flatpak":
        if not sh.which("flatpak"):
            return st(present=False, detail="flatpak not available")
        code, out = sh.run(["flatpak", "list", "--app", "--columns=application,origin,installation"])
        for line in out.splitlines() if code == 0 else []:
            cols = line.split()
            if cols and cols[0] == name:
                cur = {"origin": cols[1] if len(cols) > 1 else "", "installation": cols[2] if len(cols) > 2 else "system"}
                return st(current=cur, detail="installed from %s (%s)" % (cur["origin"], cur["installation"]))
        return st(present=False, detail="not installed")
    return st(known=False, detail="unknown package manager")


def _package_guard(name, version, cur, extra, protected):
    hit = [n for n in extra if any(fnmatch.fnmatchcase(n, p) for p in (protected or {}).get("packages", []))]
    if hit:
        return st(blocked=True, current=cur, detail="refused: removal would also remove protected package(s): %s" % ", ".join(hit))
    if extra:
        return st(blocked=True, current=cur, detail="refused: removal would also remove: %s" % ", ".join(extra[:8]))
    return st(current=cur, detail="installed %s" % version)


def package_remove(sh, item, state):
    t = item["target"]
    mgr, name = t["manager"], t["name"]
    if mgr == "apt":
        argv, env = ["apt-get", "-y", "remove", name], {"DEBIAN_FRONTEND": "noninteractive"}
    elif mgr == "dnf":
        argv, env = ["dnf", "-y", "remove", "--noautoremove", name], None
    elif mgr == "snap":
        argv, env = ["snap", "remove", name], None
    else:
        user = (state["current"] or {}).get("installation") == "user"
        argv, env = ["flatpak", "uninstall", "-y", "--noninteractive", "--user" if user else "--system", name], None
        code, out = sh.run(argv, sudo=not user)
        return _done(code, out, "removed with flatpak")
    if mgr == "apt":
        code, out = sh.run(["env", "DEBIAN_FRONTEND=noninteractive"] + argv, sudo=True)
    else:
        code, out = sh.run(argv, sudo=True, env=env)
    return _done(code, out, "removed with %s (configuration files kept)" % mgr if mgr == "apt" else "removed with %s" % mgr)


def package_revert(sh, item, before):
    t = item["target"]
    mgr, name = t["manager"], t["name"]
    before = before or {}
    if mgr == "apt":
        code, out = sh.run(["env", "DEBIAN_FRONTEND=noninteractive", "apt-get", "-y", "install", name], sudo=True)
        if code == 0 and before.get("manual") is False:
            sh.run(["apt-mark", "auto", name], sudo=True)
    elif mgr == "dnf":
        code, out = sh.run(["dnf", "-y", "install", name], sudo=True)
    elif mgr == "snap":
        argv = ["snap", "install", name]
        if before.get("classic"):
            argv.append("--classic")
        if before.get("tracking") and before["tracking"] not in ("-", ""):
            argv.append("--channel=%s" % before["tracking"])
        code, out = sh.run(argv, sudo=True)
    else:
        user = before.get("installation") == "user"
        if not before.get("origin"):
            return {"ok": False, "manual": True, "detail": "reinstall %s with flatpak (origin unknown)" % name}
        code, out = sh.run(["flatpak", "install", "-y", "--noninteractive", "--user" if user else "--system", before["origin"], name], sudo=not user)
    if code != 0:
        return {"ok": False, "detail": "reinstall failed: %s" % out.strip()[-300:]}
    return {"ok": True, "detail": "reinstalled with %s (current repository version)" % mgr}


def _done(code, out, detail):
    if code != 0:
        raise RuntimeError("command failed (%d): %s" % (code, out.strip()[-400:]))
    return {"detail": detail}


# ------------------------------------------------------------------ linux: systemd

def _systemctl(item):
    return ["systemctl", "--user"] if item["target"]["scope"] == "user" else ["systemctl"]


def systemd_state(sh, item, protected):
    if not sh.which("systemctl"):
        return st(present=False, detail="systemd not available")
    unit = item["target"]["unit"]
    base = _systemctl(item)
    code, out = sh.run(base + ["is-enabled", unit])
    enabled = out.strip().splitlines()[-1].strip() if out.strip() else ""
    if enabled not in SYSTEMD_STATES:
        return st(present=False, detail="unit not found")
    code, act = sh.run(base + ["is-active", unit])
    active = act.strip() == "active"
    cur = {"enabled": enabled, "active": active}
    mask = bool(item["target"].get("mask"))
    if mask:
        applied = enabled in ("masked", "masked-runtime")
    else:
        applied = enabled in ("disabled", "masked", "masked-runtime") and not active
        if enabled in ("static", "indirect", "generated", "alias", "transient", "linked", "linked-runtime"):
            return st(blocked=True, current=cur, detail="refused: unit is %s and cannot be disabled" % enabled)
    return st(applied=applied, current=cur, detail="enabled=%s active=%s" % (enabled, active))


def systemd_remove(sh, item, state):
    base, unit = _systemctl(item), item["target"]["unit"]
    sudo = item["target"]["scope"] == "system"
    verb = "mask" if item["target"].get("mask") else "disable"
    code, out = sh.run(base + [verb, "--now", unit], sudo=sudo)
    return _done(code, out, "%sd and stopped" % ("mask" if verb == "mask" else "disable"))


def systemd_revert(sh, item, before):
    base, unit = _systemctl(item), item["target"]["unit"]
    sudo = item["target"]["scope"] == "system"
    before = before or {}
    notes = []
    if item["target"].get("mask") and before.get("enabled") not in ("masked", "masked-runtime"):
        code, out = sh.run(base + ["unmask", unit], sudo=sudo)
        if code != 0:
            return {"ok": False, "detail": "unmask failed: %s" % out.strip()[-200:]}
        notes.append("unmasked")
    if before.get("enabled") in ("enabled", "enabled-runtime"):
        code, out = sh.run(base + ["enable", unit], sudo=sudo)
        if code != 0:
            return {"ok": False, "detail": "enable failed: %s" % out.strip()[-200:]}
        notes.append("enabled")
    if before.get("active"):
        code, out = sh.run(base + ["start", unit], sudo=sudo)
        notes.append("started" if code == 0 else "will start on next boot or activation")
    return {"ok": True, "detail": ", ".join(notes) or "was not enabled before the run; left as is"}


# ------------------------------------------------------------------ linux: gsettings

def gsettings_state(sh, item, protected):
    if not sh.which("gsettings"):
        return st(present=False, detail="gsettings not available")
    t = item["target"]
    code, out = sh.run(["gsettings", "get", t["schema"], t["key"]])
    if code != 0:
        if "No such schema" in out or "No such key" in out:
            return st(present=False, detail="schema or key not present")
        return st(known=False, detail="gsettings failed: %s" % out.strip()[-200:])
    cur = out.strip()
    return st(applied=_gs_norm(cur) == _gs_norm(item["value"]), current={"value": cur}, detail="current = %s" % cur)


def _gs_norm(v):
    s = str(v).strip()
    s = re.sub(r"^(uint32|int32|uint64|int64|double)\s+", "", s)
    return s.strip("'\"")


def gsettings_remove(sh, item, state):
    t = item["target"]
    code, out = sh.run(["gsettings", "set", t["schema"], t["key"], str(item["value"])])
    return _done(code, out, "set %s %s = %s" % (t["schema"], t["key"], item["value"]))


def gsettings_revert(sh, item, before):
    t = item["target"]
    if not before or "value" not in before:
        code, out = sh.run(["gsettings", "reset", t["schema"], t["key"]])
        return {"ok": code == 0, "detail": "reset to schema default" if code == 0 else out.strip()[-200:]}
    code, out = sh.run(["gsettings", "set", t["schema"], t["key"], before["value"]])
    return {"ok": code == 0, "detail": "restored %s" % before["value"] if code == 0 else out.strip()[-200:]}


# ------------------------------------------------------------------ linux: KEY=VALUE files

def kv_find(text, key, sep="="):
    """Returns (line_index, raw_value) of the last uncommented KEY<sep>VALUE line, or (None, None)."""
    found = (None, None)
    pat = re.compile(r"^\s*" + re.escape(key) + r"\s*" + re.escape(sep) + r"\s*(.*?)\s*$")
    for i, line in enumerate(text.splitlines()):
        m = pat.match(line)
        if m:
            found = (i, m.group(1))
    return found


def kv_set(text, key, value, sep="="):
    """Returns text with KEY set to value: rewrites the existing line or appends one."""
    lines = text.splitlines()
    idx, _ = kv_find(text, key, sep)
    new = "%s%s%s" % (key, sep, value)
    if idx is None:
        lines.append(new)
    else:
        lines[idx] = new
    return "\n".join(lines) + "\n"


def kv_restore(text, key, before, sep="="):
    """Undo kv_set: put the prior raw line back, or drop the line if the key was absent."""
    lines = text.splitlines()
    idx, _ = kv_find(text, key, sep)
    if idx is None:
        if before.get("exists"):
            lines.append(before["line"])
    elif before.get("exists"):
        lines[idx] = before["line"]
    else:
        del lines[idx]
    return "\n".join(lines) + "\n"


def keyvalue_state(sh, item, protected):
    t = item["target"]
    path, sep = t["file"], t.get("separator", "=")
    if not os.path.isfile(path):
        return st(present=False, detail="file not present")
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            text = f.read()
    except OSError as ex:
        return st(known=False, detail="cannot read %s: %s" % (path, ex))
    idx, raw = kv_find(text, t["key"], sep)
    cur = {"exists": idx is not None, "line": text.splitlines()[idx] if idx is not None else None}
    applied = idx is not None and raw.strip("'\"") == str(item["value"]).strip("'\"")
    return st(applied=applied, current=cur, detail="current = %s" % (raw if idx is not None else "(not set)"))


def _write_root_file(sh, path, text):
    fd, tmp = tempfile.mkstemp(prefix="winnow-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
        code, out = sh.run(["cp", tmp, path], sudo=True)  # cp onto an existing file keeps its owner and mode
        if code != 0:
            raise RuntimeError("could not write %s: %s" % (path, out.strip()[-200:]))
    finally:
        os.unlink(tmp)


def keyvalue_remove(sh, item, state):
    t = item["target"]
    with open(t["file"], encoding="utf-8", errors="replace") as f:
        text = f.read()
    _write_root_file(sh, t["file"], kv_set(text, t["key"], item["value"], t.get("separator", "=")))
    return {"detail": "set %s in %s" % (t["key"], t["file"])}


def keyvalue_revert(sh, item, before):
    t = item["target"]
    if before is None:
        return {"ok": False, "detail": "no logged prior state"}
    with open(t["file"], encoding="utf-8", errors="replace") as f:
        text = f.read()
    _write_root_file(sh, t["file"], kv_restore(text, t["key"], before, t.get("separator", "=")))
    return {"ok": True, "detail": "restored previous line" if before.get("exists") else "removed the added line"}


# ------------------------------------------------------------------ macos: defaults

def _defaults(item):
    t = item["target"]
    return ["defaults"] + (["-currentHost"] if t.get("currentHost") else [])


def defaults_state(sh, item, protected):
    t = item["target"]
    base, sudo = _defaults(item), bool(t.get("sudo"))
    code, out = sh.run(base + ["read", t["domain"], t["key"]], sudo=False)
    if code != 0:
        return st(current={"exists": False}, detail="not set")
    value = out.strip()
    code, ty = sh.run(base + ["read-type", t["domain"], t["key"]])
    kind = ty.strip().replace("Type is ", "") if code == 0 else ""
    kind = {"boolean": "bool", "integer": "int", "float": "float", "string": "string"}.get(kind, kind)
    want = item["value"]
    if item["valueType"] == "bool":
        applied = kind == "bool" and value == ("1" if want else "0")
    elif item["valueType"] in ("int", "float"):
        try:
            applied = float(value) == float(want)
        except ValueError:
            applied = False
    else:
        applied = value == str(want)
    return st(applied=applied, current={"exists": True, "type": kind, "value": value}, detail="current = %s (%s)" % (value, kind))


def _defaults_write_args(kind, value):
    if kind == "bool":
        return ["-bool", "true" if value in (True, "1", 1, "true") else "false"]
    if kind == "int":
        return ["-int", str(int(float(value)))]
    if kind == "float":
        return ["-float", str(value)]
    return ["-string", str(value)]


def _restart(sh, item):
    for proc in item["target"].get("restart", []):
        if proc in RESTARTABLE:
            sh.run(["killall", proc])


def defaults_remove(sh, item, state):
    t = item["target"]
    code, out = sh.run(_defaults(item) + ["write", t["domain"], t["key"]] + _defaults_write_args(item["valueType"], item["value"]), sudo=bool(t.get("sudo")))
    r = _done(code, out, "wrote %s %s = %s" % (t["domain"], t["key"], item["value"]))
    _restart(sh, item)
    return r


def defaults_revert(sh, item, before):
    t = item["target"]
    sudo = bool(t.get("sudo"))
    if before and before.get("exists"):
        if before.get("type") not in DEFAULTS_TYPES:
            return {"ok": False, "manual": True, "detail": "previous value had type '%s'; restore it from the exported plist in the backup folder" % before.get("type")}
        code, out = sh.run(_defaults(item) + ["write", t["domain"], t["key"]] + _defaults_write_args(before["type"], before["value"]), sudo=sudo)
        detail = "restored %s" % before["value"]
    else:
        code, out = sh.run(_defaults(item) + ["delete", t["domain"], t["key"]], sudo=sudo)
        detail = "deleted the key (was not set before)"
    if code != 0:
        return {"ok": False, "detail": out.strip()[-200:]}
    _restart(sh, item)
    return {"ok": True, "detail": detail}


# ------------------------------------------------------------------ macos: apps

def app_state(sh, item, protected):
    path = item["target"]["path"]
    if not os.path.isdir(path):
        return st(present=False, detail="not installed")
    real = os.path.realpath(path)
    if os.path.islink(path) or not real.startswith("/Applications/") or real.startswith("/System/"):
        return st(blocked=True, detail="refused: app lives on the system volume or is a link")
    return st(current={"path": path}, detail="installed")


def app_remove(sh, item, state):
    path = item["target"]["path"]
    trash = os.path.join(os.path.expanduser("~"), ".Trash")
    dest = os.path.join(trash, os.path.basename(path))
    if os.path.exists(dest):
        dest = os.path.join(trash, "%s %s.app" % (os.path.basename(path)[:-4], datetime.datetime.now().strftime("%H%M%S")))
    code, out = sh.run(["mv", path, dest], sudo=True)
    r = _done(code, out, "moved to the Trash (%s); empty the Trash to reclaim space" % dest)
    state["current"]["trash"] = dest
    return r


def app_revert(sh, item, before):
    path = item["target"]["path"]
    if os.path.isdir(path):
        return {"ok": True, "detail": "already installed"}
    trash = (before or {}).get("trash")
    if trash and os.path.isdir(trash):
        code, out = sh.run(["mv", trash, path], sudo=True)
        if code == 0:
            return {"ok": True, "detail": "moved back from the Trash"}
    mas = item["target"].get("masId")
    link = "https://apps.apple.com/app/id%s" % mas if mas else "the App Store"
    return {"ok": False, "manual": True, "detail": "no longer in the Trash; reinstall from %s" % link}


# ------------------------------------------------------------------ macos: launchctl

def parse_print_disabled(text):
    """label -> True if disabled. Handles '=> true/false' and '=> disabled/enabled'."""
    out = {}
    for m in re.finditer(r'"([^"]+)"\s*=>\s*(\w+)', text):
        out[m.group(1)] = m.group(2) in ("true", "disabled")
    return out


def _lc_domain(item):
    return "gui/%d" % os.getuid() if item["target"]["domain"] == "user" else "system"


def launchctl_state(sh, item, protected):
    t = item["target"]
    dom = _lc_domain(item)
    code, out = sh.run(["launchctl", "print-disabled", dom], sudo=False)
    if code != 0:
        return st(known=False, detail="launchctl print-disabled failed")
    disabled = parse_print_disabled(out).get(t["label"], False)
    code, _ = sh.run(["launchctl", "print", "%s/%s" % (dom, t["label"])])
    if code != 0 and not disabled:
        return st(present=False, detail="service not loaded")
    if t.get("refuseOverSsh") and not disabled and (os.environ.get("SSH_CONNECTION") or os.environ.get("SSH_TTY")):
        return st(blocked=True, current={"disabled": disabled}, detail="refused: this session runs over SSH and the change would cut it off")
    return st(applied=disabled, current={"disabled": disabled}, detail="disabled" if disabled else "enabled")


def launchctl_remove(sh, item, state):
    t = item["target"]
    code, out = sh.run(["launchctl", "disable", "%s/%s" % (_lc_domain(item), t["label"])], sudo=t["domain"] == "system")
    return _done(code, out, "disabled; takes full effect after the next login or restart")


def launchctl_revert(sh, item, before):
    t = item["target"]
    if (before or {}).get("disabled"):
        return {"ok": True, "detail": "was disabled before the run; left disabled"}
    code, out = sh.run(["launchctl", "enable", "%s/%s" % (_lc_domain(item), t["label"])], sudo=t["domain"] == "system")
    return {"ok": code == 0, "detail": "enabled" if code == 0 else out.strip()[-200:]}


HANDLERS = {
    "package-remove": (package_state, package_remove, package_revert),
    "systemd-disable": (systemd_state, systemd_remove, systemd_revert),
    "gsettings-set": (gsettings_state, gsettings_remove, gsettings_revert),
    "keyvalue-set": (keyvalue_state, keyvalue_remove, keyvalue_revert),
    "defaults-write": (defaults_state, defaults_remove, defaults_revert),
    "app-trash": (app_state, app_remove, app_revert),
    "launchctl-disable": (launchctl_state, launchctl_remove, launchctl_revert),
}
NEEDS_ROOT = {
    "package-remove": lambda t: not (t["manager"] == "flatpak"),
    "systemd-disable": lambda t: t["scope"] == "system",
    "gsettings-set": lambda t: False,
    "keyvalue-set": lambda t: True,
    "defaults-write": lambda t: bool(t.get("sudo")),
    "app-trash": lambda t: True,
    "launchctl-disable": lambda t: t["domain"] == "system",
}


def item_status(sh, item, machine, protected):
    """status: present (would change) | applied | not-present | not-applicable | blocked | unknown"""
    state, detail = None, ""
    if not applicable(item, machine):
        status, detail = "not-applicable", "not for this distribution or OS version"
    else:
        try:
            state = HANDLERS[item["op"]][0](sh, item, protected)
            detail = state["detail"]
            if not state["known"]:
                status = "unknown"
            elif not state["present"]:
                status = "not-present"
            elif state["blocked"]:
                status = "blocked"
            elif state["applied"]:
                status = "applied"
            else:
                status = "present"
        except Exception as ex:  # detection must never abort a report
            status, detail = "unknown", str(ex)
    return {"id": item["id"], "name": item["name"], "category": item["category"], "tier": item["tier"],
            "op": item["op"], "status": status, "detail": detail, "state": state, "item": item}


ACTION = {"present": "CHANGE", "applied": "skip:done", "not-present": "skip:absent", "not-applicable": "skip:n/a",
          "blocked": "skip:blocked", "not-in-plan": "skip:unplanned", "unknown": "skip:unknown"}


# ------------------------------------------------------------------ backups

def take_snapshot(sh, machine, run_id, allow_none):
    """Filesystem snapshot before changes. Returns a dict, or raises Stop if none can be made and
    the user has not accepted running without one."""
    label = "winnow %s" % run_id
    attempts = []
    if machine["os"] == "linux":
        if sh.which("timeshift"):
            attempts.append(("timeshift", ["timeshift", "--create", "--comments", label, "--scripted"]))
        if sh.which("snapper"):
            attempts.append(("snapper", ["snapper", "create", "--description", label]))
    elif machine["os"] == "macos":
        attempts.append(("tmutil", ["tmutil", "localsnapshot"]))
        attempts.append(("tmutil", ["tmutil", "snapshot"]))
    errors = []
    for tool, argv in attempts:
        code, out = sh.run(argv, sudo=True, timeout=3600)
        if code == 0:
            return {"tool": tool, "created": True, "detail": " ".join(out.split())[-200:]}
        errors.append("%s: %s" % (tool, " ".join(out.split())[-200:]))
    if allow_none:
        return {"tool": None, "created": False, "detail": "no snapshot (--no-snapshot); " + "; ".join(errors)}
    raise Stop(EXIT_PRECONDITION, "PRECONDITION: no filesystem snapshot could be made (%s). Nothing was changed. "
               "Set up Timeshift/Snapper or Time Machine, or re-run with --no-snapshot if the user accepts relying on the run log alone."
               % ("; ".join(errors) or "no snapshot tool found"))


def backup_settings(sh, items, directory):
    """Copies every config file and exports every defaults domain the run will touch."""
    result = {"dir": directory, "files": []}
    todo = {}
    for it in items:
        t = it["target"]
        if it["op"] == "keyvalue-set":
            todo[("file", t["file"])] = it
        elif it["op"] == "defaults-write":
            todo[("domain", t["domain"], bool(t.get("currentHost")))] = it
    if not todo:
        return result
    os.makedirs(directory, exist_ok=True)
    for n, key in enumerate(sorted(todo, key=str), 1):
        if key[0] == "file":
            dest = os.path.join(directory, "%03d-%s" % (n, os.path.basename(key[1])))
            try:
                shutil.copy2(key[1], dest)
            except OSError as ex:
                raise Stop(EXIT_PRECONDITION, "PRECONDITION: backup failed for %s: %s. Nothing was changed." % (key[1], ex))
            result["files"].append({"source": key[1], "file": dest})
        else:
            base = ["defaults"] + (["-currentHost"] if key[2] else [])
            code, _ = sh.run(base + ["read", key[1]])
            if code != 0:
                result["files"].append({"source": key[1], "file": None, "existed": False})
                continue
            dest = os.path.join(directory, "%03d-%s.plist" % (n, re.sub(r"[^A-Za-z0-9._-]", "_", key[1])))
            code, out = sh.run(base + ["export", key[1], dest])
            if code != 0 or not os.path.exists(dest):
                raise Stop(EXIT_PRECONDITION, "PRECONDITION: defaults export failed for %s: %s. Nothing was changed." % (key[1], out.strip()[-200:]))
            result["files"].append({"source": key[1], "file": dest, "existed": True})
    return result


def ensure_sudo(sh, needed):
    if not needed or (hasattr(os, "geteuid") and os.geteuid() == 0):
        return
    code, _ = sh.run(["sudo", "-n", "true"])
    if code == 0:
        return
    if sys.stdin.isatty():
        if subprocess.call(["sudo", "-v"]) == 0:
            return
    raise Stop(EXIT_PRECONDITION, "PRECONDITION: this plan needs sudo and no cached sudo credentials are available. "
               "Ask the user to run this exact command themselves in a terminal (it will prompt for their password).")


# ------------------------------------------------------------------ commands

def out(line=""):
    sys.stdout.write(line + "\n")


def save_json(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, indent=2, default=str)


def new_run_id():
    return datetime.datetime.now().strftime("%Y%m%d-%H%M%S") + "-" + secrets.token_hex(2)


def split_list(v):
    return [x.strip() for x in (v or "").split(",") if x.strip()]


def print_table(entries):
    out("%-14s %-14s %-44s %s" % ("ACTION", "TIER", "ID", "DETAIL"))
    for e in entries:
        out("%-14s %-14s %-44s %s" % (ACTION.get(e["status"], "skip:unknown"), e["tier"], e["id"], e["detail"]))


def header(mode, machine):
    out("MODE=%s" % mode)
    out("MACHINE=%s %s %s %s user=%s" % (machine["hostname"], machine["os"], machine.get("distro", ""), machine.get("version", ""), machine["user"]))


def default_catalog(root, machine):
    return os.path.join(root, "catalog", "%s.json" % machine["os"])


def check_platform(cat, machine):
    if cat["platform"] != machine["os"]:
        raise Stop(EXIT_PRECONDITION, "PRECONDITION: this catalog is for %s but this machine is %s." % (cat["platform"], machine["os"]))


def cmd_state(args, sh, root):
    machine = machine_info(sh)
    cat = load_catalog(args.catalog or default_catalog(root, machine))
    statuses = [item_status(sh, i, machine, cat.get("protected")) for i in cat["items"]]
    counts = {}
    for s in statuses:
        counts[s["status"]] = counts.get(s["status"], 0) + 1
    by_tier = {t: len([s for s in statuses if s["tier"] == t and s["status"] == "present"]) for t in TIERS}
    if args.json:
        out(json.dumps({"machine": machine, "catalogSha256": cat["sha256"], "statusCounts": counts, "presentByTier": by_tier,
                        "items": [{k: s[k] for k in ("id", "name", "category", "tier", "status", "detail")} for s in statuses]}, indent=2))
        return EXIT_OK
    header("STATE", machine)
    if cat["platform"] != machine["os"]:
        out("WARNING: catalog platform is %s but this machine is %s." % (cat["platform"], machine["os"]))
    out("%-15s %-10s %-14s %-44s %s" % ("STATUS", "CATEGORY", "TIER", "ID", "DETAIL"))
    for s in sorted(statuses, key=lambda s: (s["status"] != "present", s["category"], s["id"])):
        out("%-15s %-10s %-14s %-44s %s" % (s["status"], s["category"], s["tier"], s["id"], s["detail"]))
    out("STATUS_COUNTS: " + " ".join("%s=%d" % kv for kv in sorted(counts.items())))
    out("PRESENT_BY_TIER: " + " ".join("%s=%d" % (t, by_tier[t]) for t in TIERS))
    return EXIT_OK


def build_entries(sh, cat, machine, profile, only, exclude):
    selected = select_items(cat, profile, only, exclude)
    return [item_status(sh, i, machine, cat.get("protected")) for i in selected]


def cmd_plan(args, sh, root):
    machine = machine_info(sh)
    cat = load_catalog(args.catalog or default_catalog(root, machine))
    only, exclude = split_list(args.only), split_list(args.exclude)
    bad = [x for x in exclude if x not in cat.get("tags", [])]
    if bad:
        raise Stop(EXIT_INVALID, "INVALID: unknown --exclude tag(s): %s. Allowed: %s" % (", ".join(bad), ", ".join(cat.get("tags", []))))
    header("DRYRUN", machine)
    check_platform(cat, machine)
    if machine.get("managed"):
        out("WARNING: this Mac is enrolled in device management (MDM). Its settings belong to an administrator.")
    out("SELECTION=profile:%s only:[%s] exclude:[%s]" % (args.profile, ",".join(only), ",".join(exclude)))
    entries = build_entries(sh, cat, machine, args.profile, only, exclude)
    change = [e for e in entries if e["status"] == "present"]
    print_table(entries)
    for e in change:
        if e["tier"] == "never-default":
            out("WARNING: '%s' is tier never-default and was selected explicitly with --only." % e["id"])
    h = plan_hash(cat["sha256"], machine["hostname"], [e["id"] for e in change])
    needs_root = any(NEEDS_ROOT[e["op"]](e["item"]["target"]) for e in change)
    out("SUMMARY: selected=%d to-change=%d needs-sudo=%s" % (len(entries), len(change), str(needs_root).lower()))
    out("PLAN_HASH=%s" % h)
    run_id = new_run_id()
    path = os.path.join(args.log_dir, "plan-%s.json" % run_id)
    save_json(path, {"schema": 1, "runId": run_id, "createdAt": datetime.datetime.now().isoformat(), "machine": machine,
                     "selection": {"profile": args.profile, "only": only, "exclude": exclude},
                     "catalog": os.path.abspath(args.catalog or default_catalog(root, machine)),
                     "catalogSha256": cat["sha256"], "planHash": h,
                     "items": [{"id": e["id"], "name": e["name"], "category": e["category"], "tier": e["tier"], "op": e["op"],
                                "status": e["status"], "action": ACTION.get(e["status"]), "detail": e["detail"], "target": e["item"]["target"]}
                               for e in entries]})
    out("PLAN_FILE=%s" % path)
    args.plan = path
    if getattr(args, "command", "") != "auto":
        out("No changes were made. To apply exactly this plan: winnow.py apply --plan <PLAN_FILE>")
    return EXIT_OK


def cmd_auto(args, sh, root):
    # Unattended: plan and apply in one go, no approval step in between.
    code = cmd_plan(args, sh, root)
    if code != EXIT_OK:
        return code
    return cmd_apply(args, sh, root)


class RunLog:
    def __init__(self, path, data):
        self.path, self.data = path, data
        self.save()

    def save(self):
        save_json(self.path, self.data)


def start_run(args, sh, machine, cat, kind, items, extra):
    run_id = new_run_id()
    log = RunLog(os.path.join(args.log_dir, "run-%s.json" % run_id),
                 dict({"schema": 1, "runId": run_id, "kind": kind, "startedAt": datetime.datetime.now().isoformat(), "finishedAt": None,
                       "outcome": "in-progress", "abortReason": None, "machine": machine, "catalogSha256": cat["sha256"],
                       "snapshot": None, "settingsBackup": None, "changes": []}, **extra))
    try:
        if machine.get("isRoot"):
            raise Stop(EXIT_PRECONDITION, "PRECONDITION: do not run winnow with sudo or as root. Run it as your normal user.")
        if machine.get("managed"):
            raise Stop(EXIT_PRECONDITION, "PRECONDITION: refusing to change a Mac enrolled in device management (MDM).")
        ensure_sudo(sh, any(NEEDS_ROOT[i["op"]](i["target"]) for i in items) or not args.no_snapshot)
        log.data["settingsBackup"] = backup_settings(sh, items, os.path.join(args.log_dir, "backup-%s" % run_id))
        log.data["snapshot"] = take_snapshot(sh, machine, run_id, args.no_snapshot)
        log.save()
    except Stop as s:
        log.data.update({"outcome": "aborted", "abortReason": s.message, "finishedAt": datetime.datetime.now().isoformat()})
        log.save()
        out("LOG_FILE=%s" % log.path)
        raise
    snap = log.data["snapshot"]
    out("SNAPSHOT=%s" % ("created with %s" % snap["tool"] if snap["created"] else "none (--no-snapshot)"))
    out("SETTINGS_BACKUP=%d file(s) -> %s" % (len(log.data["settingsBackup"]["files"]), log.data["settingsBackup"]["dir"]))
    return log


def finish_run(log, failures):
    log.data["outcome"] = "completed-with-failures" if failures else "completed"
    log.data["finishedAt"] = datetime.datetime.now().isoformat()
    log.save()
    out("RUN_ID=%s" % log.data["runId"])
    out("OUTCOME=%s" % log.data["outcome"])
    counts = {}
    for c in log.data["changes"]:
        counts[c["status"]] = counts.get(c["status"], 0) + 1
    for k in sorted(counts):
        out("COUNT %s = %d" % (k, counts[k]))
    for c in log.data["changes"]:
        if not c["status"].startswith("skipped-"):
            out("%-24s %-44s %s" % (c["status"], c["id"], c["detail"]))
    out("LOG_FILE=%s" % log.path)
    return EXIT_PARTIAL if failures else EXIT_OK


def cmd_apply(args, sh, root):
    if not os.path.exists(args.plan):
        raise Stop(EXIT_INVALID, "INVALID: plan file not found: %s" % args.plan)
    with open(args.plan, encoding="utf-8") as f:
        plan = json.load(f)
    machine = machine_info(sh)
    cat = load_catalog(args.catalog or plan.get("catalog") or default_catalog(root, machine))
    header("APPLY", machine)
    check_platform(cat, machine)
    approved = [i["id"] for i in plan.get("items", []) if i.get("status") == "present"]
    if plan_hash(plan.get("catalogSha256", ""), plan.get("machine", {}).get("hostname", ""), approved) != plan.get("planHash"):
        raise Stop(EXIT_INVALID, "INVALID: plan file does not match its own hash (edited or corrupt). Make a new plan.")
    if plan.get("catalogSha256") != cat["sha256"] or plan.get("machine", {}).get("hostname") != machine["hostname"]:
        raise Stop(EXIT_PRECONDITION, "PRECONDITION: PLAN_STALE - the catalog changed or the plan is from another machine. Make a new plan and get it approved.")
    sel = plan["selection"]
    out("PLAN=%s (selection taken from the plan file)" % args.plan)
    entries = build_entries(sh, cat, machine, sel["profile"], sel.get("only"), sel.get("exclude"))
    for e in entries:
        if e["status"] == "present" and e["id"] not in approved:
            e["status"], e["detail"] = "not-in-plan", e["detail"] + " [not in the approved plan; make a new plan to include it]"
    change = [e for e in entries if e["status"] == "present"]
    print_table(entries)
    out("SUMMARY: selected=%d to-change=%d" % (len(entries), len(change)))
    if not change:
        out("Nothing to change.")
        return EXIT_OK
    log = start_run(args, sh, machine, cat, "debloat", [e["item"] for e in change],
                    {"selection": sel, "planFile": os.path.abspath(args.plan), "planHash": plan["planHash"]})
    failures = 0
    for e in entries:
        item = e["item"]
        rec = {"id": e["id"], "name": e["name"], "op": e["op"], "status": "", "detail": e["detail"], "before": None, "verified": None,
               "item": {k: item[k] for k in ("id", "op", "target", "value", "valueType") if k in item},
               "at": datetime.datetime.now().isoformat()}
        if e["status"] != "present":
            rec["status"] = "skipped-" + e["status"]
        else:
            try:
                # Detect again: an earlier change in this run may have altered this item.
                now = item_status(sh, item, machine, cat.get("protected"))
                if now["status"] != "present":
                    rec["status"], rec["detail"] = "skipped-" + now["status"], now["detail"]
                    log.data["changes"].append(rec)
                    log.save()
                    continue
                e["state"] = now["state"]
                rec["before"] = e["state"]["current"]
                r = HANDLERS[e["op"]][1](sh, item, e["state"])
                rec["status"], rec["detail"] = "changed", r["detail"]
                rec["before"] = e["state"]["current"]
                after = item_status(sh, item, machine, cat.get("protected"))
                rec["verified"] = after["status"] in ("applied", "not-present")
            except Exception as ex:
                rec["status"], rec["detail"] = "failed", str(ex)
                failures += 1
        log.data["changes"].append(rec)
        log.save()
    return finish_run(log, failures)


def cmd_revert(args, sh, root):
    if not os.path.exists(args.log):
        raise Stop(EXIT_INVALID, "INVALID: run log not found: %s" % args.log)
    with open(args.log, encoding="utf-8") as f:
        src = json.load(f)
    if src.get("kind") != "debloat":
        raise Stop(EXIT_INVALID, "INVALID: revert needs a run log written by an apply run.")
    machine = machine_info(sh)
    cat = load_catalog(args.catalog or default_catalog(root, machine))
    header("APPLY" if args.apply else "DRYRUN", machine)
    todo = [c for c in src.get("changes", []) if c.get("status") in ("changed", "failed") and c.get("before") is not None]
    todo.reverse()
    out("REVERT_SOURCE=%s" % os.path.abspath(args.log))
    out("%-10s %-44s %s" % ("ACTION", "ID", "OP"))
    for c in todo:
        out("%-10s %-44s %s" % ("REVERT", c["id"], c["op"]))
    out("SUMMARY: %d change(s) to revert" % len(todo))
    if not args.apply:
        out("No changes were made. Add --apply to revert.")
        return EXIT_OK
    log = start_run(args, sh, machine, cat, "revert", [c["item"] for c in todo], {"sourceLog": os.path.abspath(args.log)})
    failures = 0
    for c in todo:
        rec = {"id": c["id"], "op": c["op"], "status": "", "detail": "", "at": datetime.datetime.now().isoformat()}
        try:
            r = HANDLERS[c["op"]][2](sh, c["item"], c["before"])
            rec["detail"] = r.get("detail", "")
            if r.get("ok"):
                rec["status"] = "reverted"
            elif r.get("manual"):
                rec["status"] = "manual-action-required"
            else:
                rec["status"] = "failed"
                failures += 1
        except Exception as ex:
            rec["status"], rec["detail"] = "failed", str(ex)
            failures += 1
        log.data["changes"].append(rec)
        log.save()
    return finish_run(log, failures)


def main(argv=None, sh=None):
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    p = argparse.ArgumentParser(prog="winnow.py", description="Winnow for Linux and macOS (dry run unless you use 'apply').")
    p.add_argument("--catalog", help="catalog file (default: catalog/<os>.json)")
    p.add_argument("--log-dir", default=os.path.join(root, "logs"))
    sub = p.add_subparsers(dest="command")
    s = sub.add_parser("state", help="read-only report")
    s.add_argument("--json", action="store_true")
    s = sub.add_parser("plan", help="dry run; writes a plan file")
    s.add_argument("--profile", choices=sorted(PROFILES), default="aggressive")
    s.add_argument("--exclude", default="")
    s.add_argument("--only", default="")
    s = sub.add_parser("auto", help="unattended: plan and apply in one go (default profile: aggressive)")
    s.add_argument("--profile", choices=sorted(PROFILES), default="aggressive")
    s.add_argument("--exclude", default="")
    s.add_argument("--only", default="")
    s.add_argument("--no-snapshot", action="store_true")
    s = sub.add_parser("apply", help="apply an approved plan")
    s.add_argument("--plan", required=True)
    s.add_argument("--no-snapshot", action="store_true")
    s = sub.add_parser("revert", help="undo a run from its log")
    s.add_argument("log")
    s.add_argument("--apply", action="store_true")
    s.add_argument("--no-snapshot", action="store_true")
    args = p.parse_args(argv)
    if not args.command:
        p.print_help()
        return EXIT_INVALID
    sh = sh or Shell()
    try:
        code = {"state": cmd_state, "plan": cmd_plan, "auto": cmd_auto, "apply": cmd_apply, "revert": cmd_revert}[args.command](args, sh, root)
    except Stop as s:
        out(s.message)
        code = s.code
    except Exception as ex:  # last resort
        out("ERROR: %s" % ex)
        code = EXIT_ERROR
    out("EXIT_CODE=%d" % code)
    return code


if __name__ == "__main__":
    sys.exit(main())
