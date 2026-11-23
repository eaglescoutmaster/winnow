"""Unit tests for scripts/winnow.py. Standard library only: python -m unittest discover -s tests
Every command goes to a fake shell, so these tests cannot change the machine and run on any OS."""
import glob
import io
import json
import os
import re
import sys
import tempfile
import unittest
from contextlib import redirect_stdout

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
import winnow  # noqa: E402


class FakeShell:
    """Answers commands from a list of (regex, exit code, output). Records every call."""

    def __init__(self, rules=None, tools=("dpkg-query", "systemctl", "gsettings", "snap", "flatpak", "rpm")):
        self.rules = list(rules or [])
        self.tools = set(tools)
        self.calls = []

    def run(self, argv, sudo=False, env=None, timeout=900):
        line = " ".join(argv)
        self.calls.append((line, sudo))
        for pattern, code, output in self.rules:
            if re.search(pattern, line):
                return code, output
        return 1, ""

    def which(self, name):
        return name if name in self.tools else None

    def ran(self, pattern):
        return [c for c in self.calls if re.search(pattern, c[0])]


def jload(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def jdump(obj, path):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f)


def catalog(platform="linux", items=None):
    return {"schemaVersion": 1, "platform": platform, "categories": ["apps", "telemetry"], "tags": ["office", "media"],
            "protected": {"packages": ["ubuntu-desktop*", "sudo"], "units": ["NetworkManager.service"],
                          "labels": ["com.apple.softwareupdated"], "paths": ["/Applications/Safari.app"], "domains": []},
            "items": items if items is not None else [item()]}


def item(**kw):
    base = {"id": "fx-pkg", "name": "Fixture package", "category": "apps", "tier": "safe", "tags": [],
            "op": "package-remove", "target": {"manager": "apt", "name": "fx-game"}, "returnsAfterUpgrade": "no",
            "notes": "", "sources": ["https://example.com/doc"]}
    base.update(kw)
    return base


LINUX = {"hostname": "testhost", "user": "u", "isRoot": False, "os": "linux", "distro": "ubuntu", "like": ["debian"],
         "version": "24.04", "managed": False, "python": "3"}
MAC = dict(LINUX, os="macos", distro="macos", like=[], version="15.1")


class CatalogValidation(unittest.TestCase):
    def test_valid_catalog_has_no_errors(self):
        self.assertEqual(winnow.validate_catalog(catalog()), [])

    def test_rejects_bad_items(self):
        cases = {
            "id must be kebab-case": item(id="Bad_Id"),
            "invalid tier": item(tier="extreme"),
            "needs at least one source": item(sources=[]),
            "not an https URL": item(sources=["http://example.com"]),
            "unknown op": item(op="rm-rf"),
            "target.manager invalid": item(target={"manager": "pacman", "name": "x"}),
            "invalid tag": item(tags=["printers"]),
            "is not valid on linux": item(op="app-trash", target={"path": "/Applications/X.app"}),
            "must be under /etc/": item(op="keyvalue-set", value="0", target={"file": "/usr/lib/x", "key": "k"}),
            "value missing": item(op="gsettings-set", target={"schema": "s", "key": "k"}),
        }
        for expected, bad in cases.items():
            errors = winnow.validate_catalog(catalog(items=[bad]))
            self.assertTrue(any(expected in e for e in errors), "%s not in %s" % (expected, errors))

    def test_rejects_duplicate_ids(self):
        self.assertTrue(any("duplicate" in e for e in winnow.validate_catalog(catalog(items=[item(), item()]))))

    def test_protected_target_must_be_never_default(self):
        bad = item(target={"manager": "apt", "name": "ubuntu-desktop-minimal"})
        self.assertTrue(any("protected" in e for e in winnow.validate_catalog(catalog(items=[bad]))))
        ok = item(target={"manager": "apt", "name": "ubuntu-desktop-minimal"}, tier="never-default")
        self.assertEqual(winnow.validate_catalog(catalog(items=[ok])), [])

    def test_macos_rules(self):
        bad_path = item(op="app-trash", target={"path": "/System/Applications/Mail.app"})
        self.assertTrue(any("target.path" in e for e in winnow.validate_catalog(catalog("macos", [bad_path]))))
        bad_restart = item(op="defaults-write", value=False, valueType="bool",
                           target={"domain": "com.x", "key": "k", "restart": ["loginwindow"]})
        self.assertTrue(any("restart target" in e for e in winnow.validate_catalog(catalog("macos", [bad_restart]))))


class Selection(unittest.TestCase):
    def setUp(self):
        self.cat = catalog(items=[item(id="a", tier="safe"), item(id="b", tier="moderate", tags=["office"]),
                                  item(id="c", tier="aggressive"), item(id="d", tier="never-default")])

    def ids(self, **kw):
        return [i["id"] for i in winnow.select_items(self.cat, **kw)]

    def test_profiles_are_cumulative_and_never_reach_never_default(self):
        self.assertEqual(self.ids(profile="safe"), ["a"])
        self.assertEqual(self.ids(profile="moderate"), ["a", "b"])
        self.assertEqual(self.ids(profile="aggressive"), ["a", "b", "c"])

    def test_only_and_exclude(self):
        self.assertEqual(self.ids(only=["d"]), ["d"])
        self.assertEqual(self.ids(profile="aggressive", exclude=["office"]), ["a", "c"])
        with self.assertRaises(winnow.Stop) as cm:
            self.ids(only=["nope"])
        self.assertEqual(cm.exception.code, winnow.EXIT_INVALID)

    def test_applicability(self):
        fedora_only = item(applies={"distros": ["fedora"]})
        self.assertFalse(winnow.applicable(fedora_only, LINUX))
        self.assertFalse(winnow.applicable(item(applies={"distros": ["debian"]}), LINUX))  # ID_LIKE is not enough
        self.assertTrue(winnow.applicable(item(applies={"distros": ["ubuntu", "debian"]}), LINUX))
        self.assertFalse(winnow.applicable(item(applies={"minVersion": "25.04"}), LINUX))
        self.assertFalse(winnow.applicable(item(applies={"maxVersion": "22.04"}), LINUX))
        self.assertTrue(winnow.applicable(item(applies={"minVersion": "22.04", "maxVersion": "24.04"}), LINUX))


class PureHelpers(unittest.TestCase):
    def test_keyvalue_round_trip(self):
        text = "# comment\nenabled=1\nother=x\n"
        idx, raw = winnow.kv_find(text, "enabled")
        self.assertEqual((idx, raw), (1, "1"))
        changed = winnow.kv_set(text, "enabled", "0")
        self.assertEqual(changed, "# comment\nenabled=0\nother=x\n")
        back = winnow.kv_restore(changed, "enabled", {"exists": True, "line": "enabled=1"})
        self.assertEqual(back, text)

    def test_keyvalue_added_line_is_removed_on_revert(self):
        text = "a=1\n"
        changed = winnow.kv_set(text, "ENABLED", "0")
        self.assertEqual(changed, "a=1\nENABLED=0\n")
        self.assertEqual(winnow.kv_restore(changed, "ENABLED", {"exists": False, "line": None}), text)

    def test_keyvalue_ignores_commented_lines(self):
        self.assertEqual(winnow.kv_find("#enabled=1\n", "enabled"), (None, None))

    def test_apt_simulation_parser(self):
        sim = "Reading package lists...\nRemv fx-game [1.0]\nRemv ubuntu-desktop:amd64 [1.5]\nRemv libfoo [2]\n"
        self.assertEqual(winnow.parse_apt_simulation(sim), ["fx-game", "ubuntu-desktop", "libfoo"])

    def test_print_disabled_parser(self):
        text = '\tdisabled services = {\n\t\t"com.a" => true\n\t\t"com.b" => false\n\t\t"com.c" => disabled\n\t\t"com.d" => enabled\n\t}'
        self.assertEqual(winnow.parse_print_disabled(text), {"com.a": True, "com.b": False, "com.c": True, "com.d": False})

    def test_os_release_and_versions(self):
        rel = winnow.parse_os_release('ID=ubuntu\nID_LIKE="debian"\nVERSION_ID="24.04"\n')
        self.assertEqual((rel["ID"], rel["ID_LIKE"], rel["VERSION_ID"]), ("ubuntu", "debian", "24.04"))
        self.assertLess(winnow.version_tuple("14.6.1"), winnow.version_tuple("15.0"))

    def test_plan_hash_is_order_independent(self):
        self.assertEqual(winnow.plan_hash("S", "h", ["b", "a"]), winnow.plan_hash("S", "h", ["a", "b"]))
        self.assertNotEqual(winnow.plan_hash("S", "h", ["a"]), winnow.plan_hash("S", "h", ["a", "b"]))


class Detection(unittest.TestCase):
    prot = catalog()["protected"]

    def status(self, sh, it, machine=LINUX):
        return winnow.item_status(sh, it, machine, self.prot)

    def test_apt_installed_and_clean_removal(self):
        sh = FakeShell([(r"dpkg-query", 0, "installed 1.0"), (r"apt-mark showmanual", 0, "fx-game\n"),
                        (r"apt-get -s remove", 0, "Remv fx-game [1.0]\n")])
        s = self.status(sh, item())
        self.assertEqual(s["status"], "present")
        self.assertEqual(s["state"]["current"], {"version": "1.0", "manual": True})

    def test_apt_not_installed(self):
        self.assertEqual(self.status(FakeShell([(r"dpkg-query", 1, "no packages found")]), item())["status"], "not-present")

    def test_apt_refuses_when_removal_drags_other_packages(self):
        sh = FakeShell([(r"dpkg-query", 0, "installed 1.0"), (r"apt-mark", 0, ""),
                        (r"apt-get -s remove", 0, "Remv fx-game [1.0]\nRemv ubuntu-desktop [1]\n")])
        s = self.status(sh, item())
        self.assertEqual(s["status"], "blocked")
        self.assertIn("protected", s["detail"])
        sh.rules[2] = (r"apt-get -s remove", 0, "Remv fx-game [1.0]\nRemv fx-data [1]\n")
        self.assertEqual(self.status(sh, item())["status"], "blocked")
        allowed = item(target={"manager": "apt", "name": "fx-game", "alsoRemoves": ["fx-data"]})
        self.assertEqual(self.status(sh, allowed)["status"], "present")

    def test_systemd_states(self):
        it = item(op="systemd-disable", target={"unit": "x.service", "scope": "system"})
        sh = FakeShell([(r"is-enabled", 0, "enabled\n"), (r"is-active", 0, "active\n")])
        self.assertEqual(self.status(sh, it)["status"], "present")
        sh = FakeShell([(r"is-enabled", 1, "disabled\n"), (r"is-active", 3, "inactive\n")])
        self.assertEqual(self.status(sh, it)["status"], "applied")
        sh = FakeShell([(r"is-enabled", 1, "Failed to get unit file state for x.service: No such file or directory\n")])
        self.assertEqual(self.status(sh, it)["status"], "not-present")
        sh = FakeShell([(r"is-enabled", 0, "static\n"), (r"is-active", 3, "inactive\n")])
        self.assertEqual(self.status(sh, it)["status"], "blocked")

    def test_user_units_use_user_flag_and_no_sudo(self):
        it = item(op="systemd-disable", target={"unit": "x.service", "scope": "user"})
        sh = FakeShell([(r"is-enabled", 0, "enabled\n"), (r"is-active", 0, "active\n"), (r"disable --now", 0, "")])
        s = self.status(sh, it)
        winnow.systemd_remove(sh, it, s["state"])
        call = sh.ran(r"disable --now")[0]
        self.assertIn("--user", call[0])
        self.assertFalse(call[1])

    def test_gsettings(self):
        it = item(op="gsettings-set", value="false", target={"schema": "org.x", "key": "k"})
        self.assertEqual(self.status(FakeShell([(r"gsettings get", 0, "true\n")]), it)["status"], "present")
        self.assertEqual(self.status(FakeShell([(r"gsettings get", 0, "false\n")]), it)["status"], "applied")
        self.assertEqual(self.status(FakeShell([(r"gsettings get", 1, "No such schema \"org.x\"\n")]), it)["status"], "not-present")
        self.assertEqual(self.status(FakeShell(tools=()), it)["status"], "not-present")

    def test_not_applicable_runs_no_commands(self):
        sh = FakeShell()
        self.assertEqual(self.status(sh, item(applies={"distros": ["fedora"]}))["status"], "not-applicable")
        self.assertEqual(sh.calls, [])

    def test_defaults_detection(self):
        it = item(op="defaults-write", value=False, valueType="bool", target={"domain": "com.x", "key": "k"})
        sh = FakeShell([(r"defaults read-type", 0, "Type is boolean\n"), (r"defaults read ", 0, "1\n")])
        s = self.status(sh, it, MAC)
        self.assertEqual(s["status"], "present")
        self.assertEqual(s["state"]["current"], {"exists": True, "type": "bool", "value": "1"})
        sh = FakeShell([(r"defaults read-type", 0, "Type is boolean\n"), (r"defaults read ", 0, "0\n")])
        self.assertEqual(self.status(sh, it, MAC)["status"], "applied")
        self.assertEqual(self.status(FakeShell(), it, MAC)["status"], "present")  # unset key: would be written

    def test_defaults_revert_restores_or_deletes(self):
        it = item(op="defaults-write", value=False, valueType="bool", target={"domain": "com.x", "key": "k"})
        sh = FakeShell([(r"defaults", 0, "")])
        self.assertTrue(winnow.defaults_revert(sh, it, {"exists": False})["ok"])
        self.assertTrue(sh.ran(r"defaults delete com\.x k"))
        self.assertTrue(winnow.defaults_revert(sh, it, {"exists": True, "type": "bool", "value": "1"})["ok"])
        self.assertTrue(sh.ran(r"defaults write com\.x k -bool true"))
        r = winnow.defaults_revert(sh, it, {"exists": True, "type": "dictionary", "value": "{}"})
        self.assertTrue(r["manual"])


class EndToEnd(unittest.TestCase):
    """plan -> apply -> revert through main(), with a fake shell and a fixture catalog."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.logs = os.path.join(self.tmp.name, "logs")
        self.cat_path = os.path.join(self.tmp.name, "catalog.json")
        self.items = [item(id="fx-gs", op="gsettings-set", value="false", target={"schema": "org.x", "key": "k"}),
                      item(id="fx-never", tier="never-default", op="gsettings-set", value="false", target={"schema": "org.y", "key": "k"}),
                      item(id="fx-unit", tier="moderate", op="systemd-disable", target={"unit": "x.service", "scope": "system"})]
        with open(self.cat_path, "w") as f:
            json.dump(catalog(items=self.items), f)
        self._machine = winnow.machine_info
        winnow.machine_info = lambda sh: dict(LINUX)
        self.addCleanup(lambda: setattr(winnow, "machine_info", self._machine))
        self.value = {"org.x": "true", "org.y": "true"}
        self.sh = FakeShell([(r"sudo -n true", 0, "")])
        outer = self

        def run(argv, sudo=False, env=None, timeout=900):
            line = " ".join(argv)
            outer.sh.calls.append((line, sudo))
            if argv[:2] == ["gsettings", "get"]:
                return 0, outer.value[argv[2]] + "\n"
            if argv[:2] == ["gsettings", "set"]:
                outer.value[argv[2]] = argv[4]
                return 0, ""
            if "is-enabled" in argv:
                return 1, "not-found\n"
            return (0, "") if line == "sudo -n true" else (1, "")
        self.sh.run = run

    def main(self, *argv):
        buf = io.StringIO()
        with redirect_stdout(buf):
            code = winnow.main(["--catalog", self.cat_path, "--log-dir", self.logs] + list(argv), sh=self.sh)
        return code, buf.getvalue()

    def plan_file(self, text):
        return re.search(r"^PLAN_FILE=(.+)$", text, re.M).group(1)

    def test_plan_changes_nothing_and_skips_never_default(self):
        code, text = self.main("plan", "--profile", "aggressive")
        self.assertEqual(code, 0)
        self.assertIn("MODE=DRYRUN", text)
        self.assertIn("No changes were made", text)
        plan = jload(self.plan_file(text))
        self.assertEqual([i["id"] for i in plan["items"]], ["fx-gs", "fx-unit"])
        self.assertEqual(self.value["org.x"], "true")
        self.assertEqual(glob.glob(os.path.join(self.logs, "run-*.json")), [])
        self.assertFalse(self.sh.ran(r"gsettings set|disable|remove"))

    def test_never_default_only_by_name(self):
        code, text = self.main("plan", "--only", "fx-never")
        self.assertEqual(code, 0)
        self.assertIn("WARNING: 'fx-never' is tier never-default", text)

    def test_apply_then_revert_round_trip(self):
        _, text = self.main("plan")
        code, text = self.main("apply", "--plan", self.plan_file(text), "--no-snapshot")
        self.assertEqual(code, 0, text)
        self.assertEqual(self.value["org.x"], "false")
        self.assertEqual(self.value["org.y"], "true")
        log = re.search(r"^LOG_FILE=(.+)$", text, re.M).group(1)
        doc = jload(log)
        self.assertEqual(doc["outcome"], "completed")
        change = [c for c in doc["changes"] if c["status"] == "changed"]
        self.assertEqual(len(change), 1)
        self.assertEqual(change[0]["before"], {"value": "true"})
        self.assertTrue(change[0]["verified"])

        code, text = self.main("apply", "--plan", self.plan_file(self.main("plan")[1]), "--no-snapshot")
        self.assertIn("Nothing to change", text)  # idempotent

        code, text = self.main("revert", log)
        self.assertEqual(self.value["org.x"], "false")  # revert is a dry run without --apply
        code, text = self.main("revert", log, "--apply", "--no-snapshot")
        self.assertEqual(code, 0, text)
        self.assertEqual(self.value["org.x"], "true")

    def test_apply_stops_without_snapshot(self):
        _, text = self.main("plan")
        code, text = self.main("apply", "--plan", self.plan_file(text))
        self.assertEqual(code, winnow.EXIT_PRECONDITION)
        self.assertIn("PRECONDITION", text)
        self.assertEqual(self.value["org.x"], "true")

    def test_plan_is_a_ceiling(self):
        _, text = self.main("plan", "--only", "fx-gs")
        path = self.plan_file(text)
        plan = jload(path)
        plan["selection"]["only"] = ["fx-gs", "fx-never"]  # widen the selection without re-planning
        jdump(plan, path)
        code, text = self.main("apply", "--plan", path, "--no-snapshot")
        self.assertEqual(self.value["org.y"], "true")
        self.assertIn("skip:unplanned", text)

    def test_tampered_or_stale_plan_is_refused(self):
        _, text = self.main("plan")
        path = self.plan_file(text)
        plan = jload(path)
        plan["items"].append({"id": "fx-never", "status": "present"})
        jdump(plan, path)
        self.assertEqual(self.main("apply", "--plan", path, "--no-snapshot")[0], winnow.EXIT_INVALID)

        _, text = self.main("plan")
        path = self.plan_file(text)
        with open(self.cat_path, "w") as f:
            json.dump(catalog(items=self.items[:2]), f)
        code, text = self.main("apply", "--plan", path, "--no-snapshot")
        self.assertEqual(code, winnow.EXIT_PRECONDITION)
        self.assertIn("PLAN_STALE", text)
        self.assertEqual(self.value["org.x"], "true")

    def test_refuses_root_and_managed(self):
        _, text = self.main("plan")
        path = self.plan_file(text)
        for extra in ({"isRoot": True}, {"managed": True}):
            winnow.machine_info = lambda sh, extra=extra: dict(LINUX, **extra)
            code, _ = self.main("apply", "--plan", path, "--no-snapshot")
            self.assertEqual(code, winnow.EXIT_PRECONDITION)
            self.assertEqual(self.value["org.x"], "true")

    def test_invalid_input(self):
        self.assertEqual(self.main("plan", "--only", "nope")[0], winnow.EXIT_INVALID)
        self.assertEqual(self.main("plan", "--exclude", "printers")[0], winnow.EXIT_INVALID)
        self.assertEqual(self.main("apply", "--plan", os.path.join(self.tmp.name, "none.json"))[0], winnow.EXIT_INVALID)
        self.assertEqual(self.main("revert", os.path.join(self.tmp.name, "none.json"))[0], winnow.EXIT_INVALID)

    def test_wrong_platform_catalog(self):
        with open(self.cat_path, "w") as f:
            json.dump(catalog("macos", [item(op="launchctl-disable", target={"label": "com.x", "domain": "user"})]), f)
        self.assertEqual(self.main("plan")[0], winnow.EXIT_PRECONDITION)


class RealCatalogs(unittest.TestCase):
    """The shipped catalogs: valid, sourced, and no profile reaches a protected identifier."""

    def test_shipped_catalogs(self):
        paths = [p for p in (os.path.join(ROOT, "catalog", n) for n in ("linux.json", "macos.json")) if os.path.exists(p)]
        self.assertTrue(paths, "no linux/macos catalog found")
        for path in paths:
            cat = winnow.load_catalog(path)
            self.assertEqual(cat["platform"], os.path.basename(path)[:-5])
            for it in winnow.select_items(cat, "aggressive"):
                self.assertFalse(winnow.is_protected(it, cat["protected"]), it["id"])
                self.assertNotEqual(it["tier"], "never-default")

    def test_engine_holds_no_identifiers(self):
        with open(os.path.join(ROOT, "scripts", "winnow.py"), encoding="utf-8") as f:
            src = f.read()
        for path in glob.glob(os.path.join(ROOT, "catalog", "*.json")):
            if os.path.basename(path) not in ("linux.json", "macos.json"):
                continue
            for it in jload(path)["items"]:
                t = it["target"]
                ident = t.get("name") or t.get("unit") or t.get("label") or t.get("path") or t.get("file") or t.get("key")
                # Plain dictionary words (a package called "snapshot") collide with ordinary code.
                if ident and len(ident) > 5 and re.search(r"[.\-/]", ident):
                    self.assertFalse('"%s"' % ident in src, "identifier hardcoded in engine: %s" % ident)


if __name__ == "__main__":
    unittest.main()
