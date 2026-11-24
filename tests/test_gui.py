"""Tests for scripts/winnow_gui.py: a real server on a loopback port, a fixture catalog, and only
read-only engine calls (state, plan on a foreign platform is refused). Runs on any OS."""
import json
import os
import sys
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
import winnow_gui  # noqa: E402

PLATFORM = "macos" if sys.platform == "darwin" else "linux"
ITEM = ({"id": "fx-pref", "name": "Fixture preference", "category": "telemetry", "tier": "safe", "tags": ["media"],
         "op": "defaults-write", "target": {"domain": "com.winnow.guitest", "key": "K"}, "valueType": "bool", "value": False}
        if PLATFORM == "macos" else
        {"id": "fx-pref", "name": "Fixture preference", "category": "telemetry", "tier": "safe", "tags": ["media"],
         "op": "gsettings-set", "target": {"schema": "org.winnow.guitest", "key": "k"}, "value": "false"})
ITEM.update({"returnsAfterUpgrade": "sometimes", "notes": "fixture note", "sources": ["https://example.com/fixture"]})


class GuiServer(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cat = os.path.join(cls.tmp.name, "catalog.json")
        with open(cat, "w", encoding="utf-8") as f:
            json.dump({"schemaVersion": 1, "platform": PLATFORM, "categories": ["telemetry"], "tags": ["media"],
                       "protected": {}, "items": [ITEM]}, f)
        cls.logs = os.path.join(cls.tmp.name, "logs")
        cls.app = winnow_gui.App(cat, cls.logs, "test-token")
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), None)
        cls.port = cls.server.server_address[1]
        cls.server.RequestHandlerClass = winnow_gui.make_handler(cls.app, ["127.0.0.1:%d" % cls.port])
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.tmp.cleanup()

    def call(self, path, body=None, token="test-token", headers=None):
        h = {"X-Winnow-Token": token, "Content-Type": "application/json"}
        h.update(headers or {})
        data = None if body is None else json.dumps(body).encode()
        req = urllib.request.Request("http://127.0.0.1:%d%s" % (self.port, path), data=data, headers=h)
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.status, r.read().decode("utf-8")
        except urllib.error.HTTPError as e:
            with e:
                return e.code, e.read().decode("utf-8")

    def test_page_needs_the_token_in_the_url(self):
        self.assertEqual(self.call("/")[0], 403)
        self.assertEqual(self.call("/?t=wrong")[0], 403)
        code, text = self.call("/?t=test-token")
        self.assertEqual(code, 200)
        self.assertIn("<title>Winnow</title>", text)

    def test_api_rejects_missing_token_foreign_host_and_origin(self):
        self.assertEqual(self.call("/api/state", token="")[0], 403)
        self.assertEqual(self.call("/api/state", token="nope")[0], 403)
        self.assertEqual(self.call("/api/state", headers={"Host": "evil.test"})[0], 403)
        self.assertEqual(self.call("/api/state", headers={"Origin": "http://evil.test"})[0], 403)
        self.assertEqual(self.call("/api/plan", {"only": ["fx-pref"]}, token="")[0], 403)

    def test_state_merges_catalog_details(self):
        code, text = self.call("/api/state")
        self.assertEqual(code, 200, text)
        doc = json.loads(text)
        self.assertEqual(doc["tags"], ["media"])
        self.assertEqual([o["key"] for o in doc["options"]], ["noSnapshot"])
        it = doc["items"][0]
        self.assertEqual((it["id"], it["notes"], it["returns"], it["tags"]), ("fx-pref", "fixture note", "sometimes", ["media"]))
        self.assertIn("summary", doc["machine"])

    def test_plan_validates_ids(self):
        for bad in ({}, {"only": []}, {"only": ["a;rm -rf"]}, {"only": ["../x"]}):
            self.assertEqual(self.call("/api/plan", bad)[0], 400, bad)

    def test_plan_runs_the_engine_dry(self):
        code, text = self.call("/api/plan", {"only": ["fx-pref"]})
        self.assertEqual(code, 200, text)
        doc = json.loads(text)
        self.assertIn("MODE=DRYRUN", doc["output"])
        if doc["exitCode"] == 0:  # on the catalog's own platform
            self.assertRegex(doc["planFile"], r"^plan-[0-9a-z-]+\.json$")
            self.assertEqual([i["id"] for i in doc["plan"]["items"]], ["fx-pref"])
        else:                      # e.g. these tests running on Windows
            self.assertEqual(doc["exitCode"], 2)
        self.assertEqual([f for f in os.listdir(self.logs) if f.startswith("run-")] if os.path.isdir(self.logs) else [], [])

    def test_apply_and_revert_only_accept_their_own_files(self):
        for name in ("../../etc/passwd", "/etc/passwd", "plan-x.json/../../y", "run-abc.json", "plan-missing.json", "", None):
            self.assertEqual(self.call("/api/apply", {"planFile": name})[0], 400, name)
        for name in ("../catalog.json", "plan-abc.json", "run-missing.json"):
            self.assertEqual(self.call("/api/revert", {"logFile": name, "apply": True})[0], 400, name)

    def test_unknown_routes(self):
        self.assertEqual(self.call("/api/nope")[0], 404)
        self.assertEqual(self.call("/gui/index.html")[0], 404)
        self.assertEqual(self.call("/api/runs")[1], "[]")


if __name__ == "__main__":
    unittest.main()
