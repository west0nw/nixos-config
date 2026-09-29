"""Exercise menu parsing and VPN config writes without touching the desktop or network."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPTS = Path(sys.argv.pop(1)).resolve()

STUB = r'''#!PYTHON
import json, os, pathlib, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
root = pathlib.Path(os.environ["TEST_ROOT"])
with (root / "calls").open("a") as log:
    log.write(json.dumps([name, *args]) + "\n")
if name == "nmcli":
    if args[-1] == "general":
        print("enabled")
    elif "IN-USE,SIGNAL" in args:
        print("*:62")
    elif "ACTIVE,SIGNAL,SECURITY,SSID" in args:
        print(os.environ.get("TEST_NETWORKS", ""))
    elif args[:3] == ["dev", "wifi", "connect"]:
        sys.exit(0 if os.environ.get("TEST_SAVED", "1") == "1" or "password" in args else 1)
    else:
        raise RuntimeError(args)
elif name == "wofi":
    rows = sys.stdin.read().splitlines()
    with (root / "menus").open("a") as log:
        log.write(json.dumps(rows) + "\n")
    if "--password" in args:
        print("fixture-password")
    else:
        needle = os.environ.get("TEST_SELECT")
        if not needle:
            sys.exit(1)
        print(next(row for row in rows if needle in row))
elif name == "hyprctl":
    if args == ["clients", "-j"]:
        print(os.environ.get("TEST_HYPR_CLIENTS", "[]"))
    elif args[0] == "dispatch":
        print("ok")
    else:
        raise RuntimeError(args)
elif name == "slurp":
    if os.environ.get("TEST_SLURP_CANCEL") == "1":
        sys.exit(1)
    print(os.environ.get("TEST_GEOMETRY", "10,20 300x400"))
elif name == "grim":
    sys.stdout.buffer.write(b"PNG")
elif name == "wl-copy":
    sys.stdin.buffer.read()
elif name in ("sleep", "notify-send"):
    pass
elif name in ("pkill", "protonvpn-app"):
    pass
else:
    raise RuntimeError(name)
'''


class DesktopScripts(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name in (
            "nmcli", "wofi", "hyprctl", "slurp", "grim", "wl-copy", "sleep",
            "notify-send", "pkill", "protonvpn-app",
        ):
            p = self.bin / name
            p.write_text(STUB.replace("#!PYTHON", "#!" + sys.executable))
            p.chmod(0o700)
        self.env = dict(os.environ, TEST_ROOT=str(self.root),
                        XDG_CONFIG_HOME=str(self.root / "config"),
                        PATH=str(self.bin) + os.pathsep + os.environ["PATH"])

    def run_script(self, name, *args, **env):
        return subprocess.run([shutil.which("bash"), str(SCRIPTS / name), *args],
                              env=dict(self.env, **env), capture_output=True, text=True, timeout=10)

    def calls(self):
        return [json.loads(line) for line in (self.root / "calls").read_text().splitlines()]

    def test_punctuation_saved_credentials_and_duplicate_access_points(self):
        ssid = r"https://router\office <guest>"
        result = self.run_script("waybar-network-menu.sh",
            TEST_NETWORKS=f"no:98:WPA2:{ssid}\nyes:62:WPA2:{ssid}\nno:50:WPA2:Another network",
            TEST_SELECT=ssid)
        self.assertEqual(result.returncode, 0, result.stderr)
        menus = [json.loads(line) for line in (self.root / "menus").read_text().splitlines()]
        matching = [row for row in menus[0] if ssid in row]
        self.assertEqual(len(matching), 1)
        self.assertIn("62%", matching[0])  # Connected AP takes priority over a stronger duplicate.
        self.assertFalse(any(row.startswith("N1|") for row in menus[0]))
        calls = self.calls()
        self.assertIn(["nmcli", "dev", "wifi", "connect", ssid], calls)
        self.assertFalse(any("--password" in call for call in calls))
        self.assertTrue(any("allow_markup=false" in call for call in calls))

    def test_new_secured_network_prompts_only_after_saved_connection_fails(self):
        result = self.run_script("waybar-network-menu.sh", TEST_NETWORKS="no:75:WPA2:New network",
                                 TEST_SELECT="New network", TEST_SAVED="0")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(["nmcli", "dev", "wifi", "connect", "New network", "password", "fixture-password"], self.calls())

    def test_cancel_empty_scan_and_malformed_signal(self):
        for networks in ("", "no:bogus:WPA2:Bad signal", "no:08:WPA2:Low signal"):
            result = self.run_script("waybar-network-menu.sh", TEST_NETWORKS=networks)
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any(call[1:4] == ["dev", "wifi", "connect"] for call in self.calls()))

    def test_ssid_delimiters_and_whitespace_are_not_trimmed(self):
        for ssid in ("name:", ":name", " name ", r"name\\"):
            result = self.run_script("waybar-network-menu.sh",
                TEST_NETWORKS=f"no:75:WPA2:{ssid}", TEST_SELECT=ssid)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn(["nmcli", "dev", "wifi", "connect", ssid], self.calls())

    def test_status(self):
        result = self.run_script("waybar-network-menu.sh", "--status")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("62%", result.stdout)

    def test_region_screenshot_waits_for_selector_to_disappear(self):
        result = self.run_script("screenshot-region.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls()
        self.assertEqual(calls[:2], [["slurp", "-d"], ["sleep", "0.2"]])
        self.assertCountEqual(calls[2:4], [
            ["grim", "-g", "10,20 300x400", "-"],
            ["wl-copy", "--type", "image/png"],
        ])
        self.assertEqual(calls[4][0], "notify-send")

    def test_cancelled_region_screenshot_captures_nothing(self):
        result = self.run_script("screenshot-region.sh", TEST_SLURP_CANCEL="1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [["slurp", "-d"]])

    def test_vpn_malformed_config_is_preserved_and_app_is_not_restarted(self):
        config = self.root / "config/Proton/VPN/app-config.json"
        config.parent.mkdir(parents=True)
        config.write_text('{"invalid":')
        for name in ("proton-vpn-autostart.sh", "proton-vpn-toggle.sh"):
            result = self.run_script(name)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(config.read_text(), '{"invalid":')
            self.assertEqual(list(config.parent.iterdir()), [config])
        self.assertFalse(any(call[0] in ("pkill", "protonvpn-app") for call in self.calls()))

    def test_vpn_autostart_preserves_existing_preferences(self):
        config = self.root / "config/Proton/VPN/app-config.json"
        config.parent.mkdir(parents=True)
        config.write_text(json.dumps({"unrelated_setting": "keep"}))
        result = self.run_script("proton-vpn-autostart.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(config.read_text())
        self.assertEqual(data["unrelated_setting"], "keep")
        self.assertTrue(data["start_app_minimized"])
        self.assertEqual(data["connect_at_app_startup"], "FASTEST")
        self.assertIn(["protonvpn-app"], self.calls())

    def test_vpn_toggle_uses_lua_dispatch_for_existing_window(self):
        result = self.run_script("proton-vpn-toggle.sh",
            TEST_HYPR_CLIENTS='[{"class": "proton.vpn.app.gtk"}]')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [
            ["hyprctl", "clients", "-j"],
            ["hyprctl", "dispatch", 'hl.dsp.workspace.toggle_special("vpn")'],
        ])


if __name__ == "__main__":
    unittest.main()
