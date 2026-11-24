#!/usr/bin/env python3
"""Winnow GUI for Linux and macOS: a local web page in front of scripts/winnow.py.

  python3 scripts/winnow_gui.py [--no-browser] [--port N]

It listens on 127.0.0.1 only, needs the one-time token printed in its URL for every request,
and does nothing the command line cannot: it runs winnow.py state / plan / apply / revert.
Run it as your normal user from a terminal. If a change needs sudo, run `sudo -v` in that
terminal first. Standard library only.
"""
import argparse
import glob
import json
import os
import re
import secrets
import subprocess
import sys
import threading
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENGINE = os.path.join(ROOT, "scripts", "winnow.py")
PAGE = os.path.join(ROOT, "gui", "index.html")
FILE_RE = re.compile(r"^(plan|run)-[0-9A-Za-z-]+\.json$")
OPTIONS = [{"key": "noSnapshot", "label": "Continue without a filesystem snapshot",
            "help": "Only if no snapshot tool is set up (Timeshift, Snapper, Time Machine). The run log is then the only way back."}]


class App:
    def __init__(self, catalog, log_dir, token):
        self.catalog, self.log_dir, self.token = catalog, log_dir, token
        self.lock = threading.Lock()  # one engine run at a time

    def engine(self, *args):
        argv = [sys.executable, ENGINE, "--log-dir", self.log_dir]
        if self.catalog:
            argv += ["--catalog", self.catalog]
        with self.lock:
            p = subprocess.run(argv + list(args), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL)
        return p.returncode, p.stdout.decode("utf-8", "replace")

    def log_file(self, name, prefix):
        """Only files this tool wrote, inside the log directory."""
        base = os.path.basename(str(name or ""))
        if not FILE_RE.match(base) or not base.startswith(prefix + "-"):
            raise ValueError("not a %s file" % prefix)
        path = os.path.join(self.log_dir, base)
        if not os.path.isfile(path):
            raise ValueError("%s file not found" % prefix)
        return path

    def state(self):
        code, out = self.engine("state", "--json")
        start = out.find("{")
        if code != 0 or start < 0:
            raise RuntimeError(out.strip() or "state failed")
        doc = json.loads(out[start:out.rindex("}") + 1])
        m = doc["machine"]
        path = self.catalog or os.path.join(ROOT, "catalog", "%s.json" % m["os"])
        with open(path, encoding="utf-8") as f:
            cat = json.load(f)
        by_id = {i["id"]: i for i in cat["items"]}
        order = {c: n for n, c in enumerate(cat.get("categories", []))}
        items = []
        for s in doc["items"]:
            c = by_id.get(s["id"], {})
            items.append(dict(s, tags=c.get("tags", []), notes=c.get("notes", ""), sources=c.get("sources", []),
                              returns=c.get("returnsAfterUpgrade", "unknown")))
        items.sort(key=lambda i: order.get(i["category"], 99))
        warnings = []
        if cat.get("platform") != m["os"]:
            warnings.append("This catalog is for %s but this machine is %s. Plans will be refused." % (cat.get("platform"), m["os"]))
        if m.get("managed"):
            warnings.append("This Mac is enrolled in device management (MDM). Winnow will not change it.")
        if m.get("isRoot"):
            warnings.append("Running as root. Start the GUI as your normal user instead.")
        if not cat.get("testedOn"):
            warnings.append("This catalog has not been applied on real machines yet. Read each plan before applying.")
        return {"platform": m["os"], "machine": dict(m, summary="%s · %s %s" % (m["hostname"], m.get("distro") or m["os"], m.get("version", ""))),
                "warnings": warnings, "tags": cat.get("tags", []), "options": OPTIONS, "items": items}

    def plan(self, body):
        only = [str(x) for x in body.get("only") or []]
        if not only or not all(re.match(r"^[a-z0-9-]+$", x) for x in only):
            raise ValueError("only must be a list of item ids")
        code, out = self.engine("plan", "--only", ",".join(only))
        m = re.search(r"^PLAN_FILE=(.+)$", out, re.M)
        plan = None
        if code == 0 and m:
            with open(m.group(1).strip(), encoding="utf-8") as f:
                plan = json.load(f)
        return {"exitCode": code, "output": out, "plan": plan, "planFile": os.path.basename(m.group(1).strip()) if m else None}

    def read_log(self, out):
        m = re.search(r"^LOG_FILE=(.+)$", out, re.M)
        if not m or not os.path.isfile(m.group(1).strip()):
            return None
        with open(m.group(1).strip(), encoding="utf-8") as f:
            return json.load(f)

    def apply(self, body):
        args = ["apply", "--plan", self.log_file(body.get("planFile"), "plan")]
        if (body.get("options") or {}).get("noSnapshot") is True:
            args.append("--no-snapshot")
        code, out = self.engine(*args)
        return {"exitCode": code, "output": out, "log": self.read_log(out)}

    def revert(self, body):
        args = ["revert", self.log_file(body.get("logFile"), "run")]
        if body.get("apply") is True:
            args.append("--apply")
            if (body.get("options") or {}).get("noSnapshot") is True:
                args.append("--no-snapshot")
        code, out = self.engine(*args)
        return {"exitCode": code, "output": out, "log": self.read_log(out) if body.get("apply") is True else None}

    def runs(self):
        out = []
        for path in sorted(glob.glob(os.path.join(self.log_dir, "run-*.json")), reverse=True)[:50]:
            try:
                with open(path, encoding="utf-8") as f:
                    d = json.load(f)
            except (OSError, ValueError):
                continue
            done = [c for c in d.get("changes", []) if c.get("status") in ("changed", "reverted")]
            out.append({"file": os.path.basename(path), "runId": d.get("runId"), "kind": d.get("kind"),
                        "startedAt": d.get("startedAt"), "outcome": d.get("outcome"), "changed": len(done)})
        return out


def make_handler(app, allowed_hosts):
    class Handler(BaseHTTPRequestHandler):
        server_version = "winnow"

        def log_message(self, *a):  # quiet
            pass

        def send(self, code, body, ctype="application/json; charset=utf-8"):
            data = body if isinstance(body, bytes) else json.dumps(body).encode("utf-8")
            self.send_response(code)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Referrer-Policy", "no-referrer")
            self.end_headers()
            self.wfile.write(data)

        def guard(self, api):
            """Loopback page only: right Host (no DNS rebinding), no foreign Origin, and the token."""
            if self.headers.get("Host", "") not in allowed_hosts:
                return "bad host"
            origin = self.headers.get("Origin")
            if origin and origin not in ["http://" + h for h in allowed_hosts]:
                return "bad origin"
            if api and not secrets.compare_digest(self.headers.get("X-Winnow-Token", ""), app.token):
                return "bad token"
            return None

        def route(self, method):
            path = self.path.split("?", 1)[0]
            api = path.startswith("/api/")
            why = self.guard(api)
            if why:
                return self.send(403, {"error": why})
            try:
                if method == "GET" and path == "/":
                    if not secrets.compare_digest(self.path.partition("?t=")[2], app.token):
                        return self.send(403, b"Open the full URL printed in the terminal.", "text/plain; charset=utf-8")
                    with open(PAGE, "rb") as f:
                        return self.send(200, f.read(), "text/html; charset=utf-8")
                if method == "GET" and path == "/api/state":
                    return self.send(200, app.state())
                if method == "GET" and path == "/api/runs":
                    return self.send(200, app.runs())
                if method == "POST":
                    length = int(self.headers.get("Content-Length") or 0)
                    if length > 1_000_000:
                        return self.send(413, {"error": "too large"})
                    body = json.loads(self.rfile.read(length) or b"{}")
                    if path == "/api/plan":
                        return self.send(200, app.plan(body))
                    if path == "/api/apply":
                        return self.send(200, app.apply(body))
                    if path == "/api/revert":
                        return self.send(200, app.revert(body))
                    if path == "/api/quit":
                        self.send(200, {"ok": True})
                        threading.Thread(target=self.server.shutdown, daemon=True).start()
                        return None
                return self.send(404, {"error": "not found"})
            except ValueError as ex:
                return self.send(400, {"error": str(ex)})
            except Exception as ex:  # report, keep serving
                return self.send(500, {"error": str(ex)})

        def do_GET(self):
            self.route("GET")

        def do_POST(self):
            self.route("POST")

    return Handler


def main(argv=None):
    p = argparse.ArgumentParser(description="Winnow GUI (local web page) for Linux and macOS.")
    p.add_argument("--port", type=int, default=0, help="default: any free port")
    p.add_argument("--no-browser", action="store_true")
    p.add_argument("--catalog", help="catalog file (default: catalog/<os>.json)")
    p.add_argument("--log-dir", default=os.path.join(ROOT, "logs"))
    args = p.parse_args(argv)
    if hasattr(os, "geteuid") and os.geteuid() == 0:
        print("Do not run the GUI with sudo or as root. Run it as your normal user.")
        return 2
    app = App(args.catalog, args.log_dir, secrets.token_urlsafe(24))
    server = ThreadingHTTPServer(("127.0.0.1", args.port), None)
    port = server.server_address[1]
    server.RequestHandlerClass = make_handler(app, ["127.0.0.1:%d" % port, "localhost:%d" % port])
    url = "http://127.0.0.1:%d/?t=%s" % (port, app.token)
    print("WINNOW_GUI_URL=%s" % url, flush=True)
    print("Local only. Press Ctrl+C or use Quit in the page to stop.", flush=True)
    if not args.no_browser:
        threading.Timer(0.4, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    server.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
