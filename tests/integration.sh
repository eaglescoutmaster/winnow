#!/usr/bin/env bash
# Real plan -> apply -> revert on a DISPOSABLE machine (a CI runner or a VM). It creates its own
# throwaway targets and a fixture catalog; it never uses the shipped catalog. Refuses to run
# unless WINNOW_INTEGRATION=1.
set -euo pipefail
[ "${WINNOW_INTEGRATION:-}" = "1" ] || { echo "set WINNOW_INTEGRATION=1 on a disposable machine"; exit 1; }

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
cat="$work/catalog.json"
w() { python3 "$root/scripts/winnow.py" --catalog "$cat" --log-dir "$work/logs" "$@"; }
field() { grep "^$1=" | head -n1 | cut -d= -f2-; }
fail() { echo "FAIL: $*"; exit 1; }
src='"returnsAfterUpgrade":"no","notes":"","sources":["https://example.com/fixture"]'

if [ "$(uname)" = "Darwin" ]; then
  domain="com.winnow.integration"
  defaults write "$domain" Existing -bool true
  defaults delete "$domain" Fresh 2>/dev/null || true
  cat > "$cat" <<EOF
{"schemaVersion":1,"platform":"macos","categories":["telemetry"],"tags":[],"protected":{},
 "items":[
  {"id":"fx-existing","name":"Existing bool","category":"telemetry","tier":"safe","tags":[],"op":"defaults-write",
   "target":{"domain":"$domain","key":"Existing"},"valueType":"bool","value":false,$src},
  {"id":"fx-fresh","name":"Unset int","category":"telemetry","tier":"safe","tags":[],"op":"defaults-write",
   "target":{"domain":"$domain","key":"Fresh"},"valueType":"int","value":2,$src}
 ]}
EOF
  check_applied() {
    [ "$(defaults read "$domain" Existing)" = "0" ] || fail "Existing not written"
    [ "$(defaults read "$domain" Fresh)" = "2" ] || fail "Fresh not written"
  }
  check_reverted() {
    [ "$(defaults read "$domain" Existing)" = "1" ] || fail "Existing not restored"
    defaults read "$domain" Fresh >/dev/null 2>&1 && fail "Fresh not deleted"
    return 0
  }
  cleanup() { defaults delete "$domain" >/dev/null 2>&1 || true; }
  expect=2
else
  pkg="${WINNOW_TEST_PACKAGE:-sl}"
  sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" >/dev/null
  kv=/etc/default/winnow-integration
  printf '# fixture\nenabled=1\n' | sudo tee "$kv" >/dev/null
  unit=winnow-integration.service
  printf '[Unit]\nDescription=winnow fixture\n[Service]\nExecStart=/bin/sleep 3600\n[Install]\nWantedBy=multi-user.target\n' |
    sudo tee "/etc/systemd/system/$unit" >/dev/null
  sudo systemctl daemon-reload
  sudo systemctl enable --now "$unit"
  cat > "$cat" <<EOF
{"schemaVersion":1,"platform":"linux","categories":["apps","telemetry","services"],"tags":[],"protected":{"packages":["sudo"]},
 "items":[
  {"id":"fx-package","name":"Package","category":"apps","tier":"safe","tags":[],"op":"package-remove",
   "target":{"manager":"apt","name":"$pkg"},$src},
  {"id":"fx-keyvalue","name":"Config line","category":"telemetry","tier":"safe","tags":[],"op":"keyvalue-set",
   "target":{"file":"$kv","key":"enabled"},"value":"0",$src},
  {"id":"fx-unit","name":"Unit","category":"services","tier":"safe","tags":[],"op":"systemd-disable",
   "target":{"unit":"$unit","scope":"system"},$src}
 ]}
EOF
  check_applied() {
    dpkg-query -W -f='${db:Status-Status}' "$pkg" 2>/dev/null | grep -q '^installed' && fail "package still installed"
    grep -q '^enabled=0$' "$kv" || fail "config line not set"
    [ "$(systemctl is-enabled "$unit" || true)" = "disabled" ] || fail "unit not disabled"
    systemctl is-active --quiet "$unit" && fail "unit still active"
    return 0
  }
  check_reverted() {
    dpkg-query -W -f='${db:Status-Status}' "$pkg" | grep -q '^installed' || fail "package not reinstalled"
    grep -q '^enabled=1$' "$kv" || fail "config line not restored"
    [ "$(systemctl is-enabled "$unit")" = "enabled" ] || fail "unit not re-enabled"
    systemctl is-active --quiet "$unit" || fail "unit not restarted"
  }
  cleanup() {
    sudo systemctl disable --now "$unit" >/dev/null 2>&1 || true
    sudo rm -f "/etc/systemd/system/$unit" "$kv"
    sudo systemctl daemon-reload
  }
  expect=3
fi
trap cleanup EXIT

echo "== state";  w state | tail -n 4
echo "== plan";   out="$(w plan)"; echo "$out"
plan="$(echo "$out" | field PLAN_FILE)"
echo "$out" | grep -q "to-change=$expect" || fail "expected $expect changes in the plan"

echo "== apply without --no-snapshot must stop or snapshot"
set +e; out="$(w apply --plan "$plan")"; code=$?; set -e
echo "$out" | tail -n 6
if [ "$code" = "2" ]; then
  echo "$out" | grep -q '^PRECONDITION' || fail "exit 2 without PRECONDITION"
  echo "== apply --no-snapshot"; out="$(w apply --plan "$plan" --no-snapshot)"; echo "$out"
elif [ "$code" != "0" ]; then fail "apply exit $code"; fi
log="$(echo "$out" | field LOG_FILE)"
echo "$out" | grep -q '^OUTCOME=completed$' || fail "apply did not complete"
check_applied

echo "== second plan is idempotent"
w plan | grep -q "to-change=0" || fail "second plan still wants changes"

echo "== revert (dry run changes nothing)"
w revert "$log" | grep -q "No changes were made" || fail "revert dry run"
check_applied
echo "== revert --apply"
out="$(w revert "$log" --apply --no-snapshot)"; echo "$out"
echo "$out" | grep -q '^OUTCOME=completed$' || fail "revert did not complete"
check_reverted
echo "INTEGRATION OK"
