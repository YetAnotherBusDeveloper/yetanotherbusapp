"""Offline regression tests. On Linux, with Bash and Python 3 + Pillow installed:

    python3 -B -m unittest discover -s tool/mobile-agent-testers/tests -p test_runtime.py -v
"""

from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

from PIL import Image


RUNTIME = Path(__file__).resolve().parents[1] / "runtime"
PERSONA = "anna"
# Different markers make it clear which boundary leaked. None are credentials.
KEY = "test-only-CPA-key-9841"
MODEL = "private-test-model-3497"
CLI_OUT = "private-test-result-2714"
CLI_ERR = "private-test-stderr-8392"
DEVICE_OUT = "private-test-device-6539"
REPORT = "private-test-report-7435"
SUCCESS = {"type": "result", "subtype": "success", "is_error": False, "result": CLI_OUT}


def document():
    return {"score": 7, "issues": [{"title": "Stop name clipped", "severity": "minor",
                                    "screen": "Search", "screens": ["01"],
                                    "steps": ["Open the search results."]}]}


def write_json(path, data):
    path.write_text(json.dumps(data), encoding="utf-8")


def write_evidence(directory):
    directory.mkdir(parents=True)
    (directory / "report.md").write_text(REPORT, encoding="utf-8")
    write_json(directory / "findings.json", document())
    Image.new("RGB", (12, 20), "navy").save(directory / "01.png")


class RuntimeTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix="android runtime ")
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        home = self.root / "home"
        home.mkdir()
        path = os.pathsep.join((str(Path(sys.executable).parent), os.defpath))
        self.env = {"HOME": str(home), "PATH": path, "LANG": "C.UTF-8"}

    def install_stub_bin(self):
        self.stub_bin = self.root / "bin"
        self.stub_bin.mkdir()
        self.env["PATH"] = str(self.stub_bin) + os.pathsep + self.env["PATH"]

    def executable(self, name, body):
        path = self.stub_bin / name
        path.write_text("#!/bin/sh\n" + body + "\n", encoding="utf-8")
        path.chmod(0o755)

    def invoke(self, *args, **env):
        p = subprocess.run(args, cwd=self.root, env={**self.env, **env}, capture_output=True,
                           text=True, encoding="utf-8", errors="replace", timeout=15)
        for marker in (KEY, MODEL, CLI_OUT, CLI_ERR, DEVICE_OUT, REPORT):
            self.assertNotIn(marker, p.stdout + p.stderr, "private value in public output")
        return p


class StatusTests(RuntimeTest):
    def setUp(self):
        super().setUp()
        self.output = self.root / "response.json"
        self.errors = self.root / "stderr"
        self.status = self.root / "status"
        self.errors.write_text(CLI_ERR, encoding="utf-8")

    def classify(self, rc=0):
        return self.invoke(sys.executable, "-B", RUNTIME / "scripts/agent_status.py",
                           self.output, self.errors, str(rc), self.status)

    def expect(self, label, rc=0):
        self.status.unlink(missing_ok=True)
        p = self.classify(rc)
        self.assertEqual(p.returncode == 0, label == "finished", p.stderr)
        self.assertEqual(self.status.read_text(encoding="ascii").strip(), label)

    def test_setup_and_provider_hints_from_private_error_channels(self):
        cases = (
            ('cli_arguments', "error: unknown option '--restricted'"),
            ('cli_sandbox', 'unshare: unshare failed: Operation not permitted'),
            ('cli_setup', 'EACCES: permission denied, open config'),
            ('connection', 'getaddrinfo ENOTFOUND'),
            ('model_or_endpoint', 'API Error: 404'),
            ('invalid_request', 'invalid_request_error'),
            ('provider_error', 'API Error: 502 Bad Gateway'),
        )
        for label, message in cases:
            with self.subTest(label=label):
                private = f'{message}: {KEY} {MODEL} {CLI_ERR}'
                self.errors.write_text(private, encoding='utf-8')
                self.output.write_bytes(b'')
                self.expect(label, rc=2)
                self.errors.write_bytes(b'')
                write_json(self.output, {'type': 'result', 'is_error': True,
                                         'errors': [{'message': private}]})
                self.expect(label)  # an error result fails even with a zero exit

    def test_provider_error_envelope_never_substitutes_for_a_result(self):
        write_json(self.output, {'type': 'error', 'error': {'code': 'model_not_found',
                                                            'message': f'{KEY} {MODEL}'}})
        self.expect('model_or_endpoint', rc=1)
        self.expect('model_or_endpoint')

    def test_unrecognized_cli_failure_reports_only_output_shape(self):
        for label, stdout, stderr in (
                ('cli_no_output', b'', b''),
                ('cli_empty_output', b'\n', CLI_ERR.encode()),
                ('cli_non_json_output', KEY.encode(), CLI_ERR.encode()),
                ('cli_no_result', json.dumps([SUCCESS, {'type': MODEL}]).encode(), b''),
                ('cli_error_result', json.dumps({**SUCCESS, 'is_error': True}).encode(), b''),
                ('cli_oversized_output', json.dumps(SUCCESS).encode() + b' ' * (4 * 1024 * 1024), b'')):
            with self.subTest(label=label):
                self.output.write_bytes(stdout)
                self.errors.write_bytes(stderr)
                self.expect(label, rc=1)
                self.expect('invalid_response')

    def test_text_in_other_turns_or_completed_work_is_not_an_error_hint(self):
        write_json(self.output, [{'type': 'assistant', 'result': 'unknown option'},
                                 {**SUCCESS, 'result': 'Report: permission denied on location.'}])
        self.expect('finished')
        self.expect('cli_exit_with_success', rc=23)

    def test_only_a_complete_final_result_can_succeed(self):
        for data, label in ((SUCCESS, "finished"), ([{"type": "assistant"}, SUCCESS], "finished"),
                            ([SUCCESS, {"type": "assistant"}], "invalid_response"),
                            ({**SUCCESS, "stop_reason": "max_tokens"}, "invalid_response"),
                            ({**SUCCESS, "is_error": True}, "invalid_response"),
                            ({**SUCCESS, "subtype": "error_max_turns"}, "max_turns")):
            with self.subTest(data=data):
                write_json(self.output, data)
                self.expect(label)
        write_json(self.output, SUCCESS)
        self.expect("cli_exit_with_success", rc=23)

    def test_provider_errors_become_fixed_labels_not_private_text(self):
        for label, message, in_stderr in (("auth", "invalid API key", True),
                                          ("quota", "insufficient_quota", False),
                                          ("rate_limit", "API Error: 429", True),
                                          ("overloaded", "overloaded_error", False)):
            with self.subTest(label=label):
                self.errors.write_text(CLI_ERR + (message if in_stderr else ""), encoding="utf-8")
                write_json(self.output, {"type": "result", "is_error": True,
                                         "result": CLI_OUT + ("" if in_stderr else message)})
                self.expect(label, rc=1)

    def test_absent_or_malformed_output_fails_closed(self):
        self.expect("invalid_response")
        for response in (b"", CLI_OUT.encode(), b"\xff"):
            with self.subTest(response=response):
                self.output.write_bytes(response)
                self.expect("invalid_response")


class EvidenceTests(RuntimeTest):
    def setUp(self):
        super().setUp()
        self.out = self.root / "results" / PERSONA
        write_evidence(self.out)

    def check(self, valid, *args):
        p = self.invoke(sys.executable, "-B", RUNTIME / "scripts/android/check_results.py", PERSONA, *args)
        self.assertEqual(p.returncode, 0 if valid else 1, p.stdout + p.stderr)

    def test_complete_evidence_with_and_without_findings(self):
        self.check(True)
        write_json(self.out / "findings.json", {"score": 10, "issues": []})
        self.check(True)

    def test_invalid_manifest(self):
        path = self.out / "findings.json"
        for contents in ("", "{" + REPORT, "[]", '{"score":0,"score":1,"issues":[]}',
                         '{"score":true,"issues":[]}', '{"score":11,"issues":[]}',
                         '{"score":7}', '{"score":7,"issues":{}}'):
            with self.subTest(contents=contents):
                path.write_text(contents, encoding="utf-8")
                self.check(False)

    def test_every_issue_needs_observed_screens_and_repro_steps(self):
        for field, value in (("severity", "unknown"), ("title", " "), ("screen", ""),
                             ("steps", []), ("steps", [" "]), ("steps", "Open search"),
                             ("screens", []), ("screens", ["01", "02"]),
                             ("screens", ["01.png"]), ("screens", [1])):
            with self.subTest(field=field, value=value):
                data = document()
                data["issues"][0][field] = value
                write_json(self.out / "findings.json", data)
                self.check(False)

    def test_report_required_and_not_blank(self):
        report = self.out / "report.md"
        report.unlink()
        self.check(False)
        report.write_text(" \n", encoding="utf-8")
        self.check(False)

    def test_empty_issue_list_still_needs_a_real_numbered_png(self):
        write_json(self.out / "findings.json", {"score": 8, "issues": []})
        png = self.out / "01.png"
        complete_png = png.read_bytes()
        png.rename(self.out / "00.png")
        self.check(False)
        (self.out / "00.png").unlink()
        self.check(False)
        png.write_bytes(b"\x89PNG\r\n\x1a\n" + REPORT.encode())
        self.check(False)
        png.write_bytes(complete_png[:-4])  # decoded pixels alone do not prove a complete capture
        self.check(False)

    def test_minimum_screen_count_and_contiguous_numbering(self):
        self.check(False, "2")
        Image.new("RGB", (12, 20), "tan").save(self.out / "03.png")
        self.check(False, "2")
        (self.out / "03.png").rename(self.out / "02.png")
        self.check(True, "2")

    def test_unexpected_result_files_are_not_accepted_for_archiving(self):
        for extra in (self.out / "debug.log", self.out.parent / "other-persona"):
            with self.subTest(name=extra.name):
                extra.write_text(CLI_ERR, encoding="utf-8")
                self.check(False)
                extra.unlink()

    @unittest.skipUnless(os.name == "posix", "Linux link semantics")
    def test_evidence_cannot_be_borrowed_via_links(self):
        for name, hard in (("report.md", False), ("01.png", False), ("findings.json", True)):
            with self.subTest(name=name):
                path = self.out / name
                outside = self.root / name
                path.rename(outside)
                if hard:
                    os.link(outside, path)
                else:
                    path.symlink_to(outside)
                self.check(False)
                path.unlink()
                outside.rename(path)


@unittest.skipUnless(sys.platform.startswith("linux"), "Android action budget uses Linux file locking")
class ActionTests(RuntimeTest):
    def setUp(self):
        super().setUp()
        self.install_stub_bin()
        self.executable("adb", f"""printf '%s\\n' "$*" >> adb-calls
            echo {DEVICE_OUT} >&2
            exit "${{TEST_ADB_RC:-0}}"
        """)
        self.env.update(APP_ID="com.example.test", LAUNCH_COMPONENT="com.example.test/.MainActivity",
                        AGENT_STATE_DIR=str(self.root), MAX_ACTIONS="2")

    def action(self, *args, **env):
        return self.invoke(sys.executable, "-B", RUNTIME / "scripts/android/action.py", *args, **env)

    def adb_calls(self):
        path = self.root / "adb-calls"
        return path.read_text().splitlines() if path.exists() else []

    def test_parallel_gestures_share_one_budget(self):
        # Separate OS processes, one state directory. Check effects on the device,
        # not which call wins or how the runner stores its counter.
        with ThreadPoolExecutor(max_workers=8) as pool:
            calls = [pool.submit(self.action, "tap", str(x), "30") for x in range(8)]
            winners = [x for x, call in enumerate(calls) if call.result().returncode == 0]
        self.assertEqual(len(winners), 2)
        self.assertCountEqual(self.adb_calls(), [f"shell input tap {x} 30" for x in winners])

    def test_failed_gesture_cannot_be_retried_for_free(self):
        self.assertNotEqual(self.action("back", TEST_ADB_RC="18", MAX_ACTIONS="1").returncode, 0)
        self.assertNotEqual(self.action("back", MAX_ACTIONS="1").returncode, 0)
        self.assertEqual(len(self.adb_calls()), 1)

    def test_relaunch_is_scoped_to_the_installed_activity(self):
        component = self.env["LAUNCH_COMPONENT"]
        self.assertNotEqual(self.action("relaunch", "com.other.app/.Home").returncode, 0)
        self.assertNotEqual(self.action("relaunch", LAUNCH_COMPONENT="com.other.app/.Home").returncode, 0)
        self.assertEqual(self.adb_calls(), [])
        self.assertEqual(self.action("relaunch", MAX_ACTIONS="1").returncode, 0)
        self.assertNotEqual(self.action("back", MAX_ACTIONS="1").returncode, 0)
        self.assertEqual(self.adb_calls(), ["shell am force-stop com.example.test",
                                            f"shell am start -W -n {component}"])


@unittest.skipUnless(sys.platform.startswith("linux"), "Android runtime wrapper runs on Linux")
class WrapperTests(RuntimeTest):
    """Run the real wrapper, preflight, provider launcher and validators.

    Replace only the device operations and the two external executables. Fake
    Claude reads its scenario from disk because it should get a clean env.
    """

    def setUp(self):
        super().setUp()
        shutil.copytree(RUNTIME / "scripts", self.root / "scripts")
        shutil.copytree(RUNTIME / "briefs", self.root / "briefs")
        for name in ("personas.json", "AGENT_BRIEF.md"):
            shutil.copyfile(RUNTIME / name, self.root / name)
        self.scratch = self.root / "tmp"
        self.scratch.mkdir()
        self.env["TMPDIR"] = str(self.scratch)
        (self.root / "app.apk").write_bytes(b"fixture apk")
        self.env.update(PERSONA=PERSONA, BRIEF="briefs/yabus.md", DEVICE="Test phone", GEO="25,121",
                        LOCALE="zh-TW", THEME="light", FONT_SCALE="1.3", RECORD_VIDEO="true",
                        MAX_ACTIONS="4", LLM_MODEL=MODEL, LLM_BASE_URL="https://test.invalid/v1",
                        LLM_API_KEY=KEY)
        fixture = self.root / "fixture"
        write_evidence(fixture / "evidence")
        self.result = fixture / "output.json"
        write_json(self.result, SUCCESS)
        (fixture / "exit").write_text("0\n", encoding="ascii")
        self.install_stub_bin()
        self.executable("adb", "echo unexpected-adb >> calls; exit 99")
        self.executable("claude", f"""set -eu
            echo claude >> calls
            if [ -f fixture/probe ]; then
                test -d "$HOME" && test ! -e "$HOME/account-marker" || exit 97
                printf '%s\\0' "$@" > fixture/argv
                env -0 > fixture/env
            fi
            if [ -f fixture/back ]; then
                python3 scripts/android/action.py back
                echo back-completed >> calls
            fi
            cp fixture/evidence/* "results/$PERSONA/"
            cat fixture/output.json
            echo {CLI_ERR} >&2
            exit "$(cat fixture/exit)"
        """)
        (self.root / "scripts/android/device.sh").write_text(f"""
            prepare_device() {{
                echo device >> calls
                echo {DEVICE_OUT}; echo {DEVICE_OUT} >&2
                stage=device-setup/install-apk
                export APP_ID=com.example.test LAUNCH_COMPONENT=com.example.test/.MainActivity
                return "${{TEST_DEVICE_RC:-0}}"
            }}
            start_recording() {{ echo start >> calls; }}
            stop_recording() {{ echo stop >> calls; echo {DEVICE_OUT} >&2; }}
        """, encoding="utf-8")

    def wrapper(self, **env):
        p = self.invoke("bash", "scripts/android/run_agent.sh", **env)
        self.assertEqual(list(self.scratch.iterdir()), [], "private session files left behind")
        return p

    def calls(self):
        path = self.root / "calls"
        return path.read_text().splitlines() if path.exists() else []

    def test_success_requires_agent_and_evidence(self):
        p = self.wrapper()
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn("claude", self.calls())
        self.assertIn('APK installed, digest verified and launcher activity started', p.stdout)
        self.assertIn("stop", self.calls())
        self.assertTrue((self.root / "results" / PERSONA / "01.png").is_file())

    def test_cli_receives_only_scoped_authority_and_pinned_provider(self):
        fixture = self.root / "fixture"
        (fixture / "probe").touch()
        (Path(self.env["HOME"]) / "account-marker").touch()
        ambient = {name: "must-not-inherit" for name in (
            "GITHUB_TOKEN", "GITHUB_ENV", "CLAUDE_CODE_OAUTH_TOKEN", "ANTHROPIC_API_KEY",
            "CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CONFIG_DIR", "UNRELATED_SECRET")}
        p = self.wrapper(**ambient)
        self.assertEqual(p.returncode, 0, p.stderr)
        argv = (fixture / "argv").read_bytes().decode().split("\0")[:-1]
        env = dict(item.split("=", 1) for item in
                   (fixture / "env").read_bytes().decode().split("\0") if item)

        self.assertNotEqual(env["HOME"], self.env["HOME"])
        self.assertFalse(Path(env["HOME"]).exists(), "per-run CLI home not removed")
        for name in (*ambient, "LLM_BASE_URL", "LLM_API_KEY", "LLM_MODEL"):
            self.assertFalse(env.get(name), name)
        self.assertEqual(env["ANTHROPIC_AUTH_TOKEN"], KEY)
        self.assertEqual(env["ANTHROPIC_BASE_URL"], "https://test.invalid")
        for slot in ("ANTHROPIC_MODEL", "ANTHROPIC_DEFAULT_MODEL", "ANTHROPIC_DEFAULT_HAIKU_MODEL",
                     "ANTHROPIC_DEFAULT_SONNET_MODEL", "ANTHROPIC_DEFAULT_OPUS_MODEL",
                     "ANTHROPIC_DEFAULT_FABLE_MODEL", "ANTHROPIC_SMALL_FAST_MODEL", "CLAUDE_CODE_SUBAGENT_MODEL"):
            self.assertEqual(env.get(slot), MODEL, slot)
        for secret in (KEY, MODEL, "test.invalid"):
            self.assertFalse(any(secret in arg for arg in argv), "provider setting in argv")

        def option(flag):
            self.assertEqual(argv.count(flag), 1, flag)
            return argv[argv.index(flag) + 1]

        self.assertEqual(option("--permission-mode"), "dontAsk")
        self.assertNotIn("--dangerously-skip-permissions", argv)
        self.assertEqual(set(option("--tools").split(",")), {"Bash", "Read", "Write"})
        self.assertEqual(option("--output-format"), "json")
        self.assertEqual(int(option("--max-turns")), 3 * int(self.env["MAX_ACTIONS"]) + 12)
        rules = set()
        for arg in argv[argv.index("--allowedTools") + 1:]:
            if arg.startswith("--"):
                break
            rules.add(arg)
        out = f"results/{PERSONA}"
        # Claude authorizes Write via Edit(path); Edit itself must not be an enabled tool.
        self.assertEqual(rules, {"Bash(python3 scripts/android/action.py *)",
                                 f"Bash(python3 scripts/android/screen.py {out} *)",
                                 "Read(/AGENT_BRIEF.md)", "Read(/briefs/yabus.md)", "Read(/personas.json)",
                                 f"Read(/{out}/*.png)", f"Read(/{out}/report.md)", f"Read(/{out}/findings.json)",
                                 f"Edit(/{out}/report.md)", f"Edit(/{out}/findings.json)"})

    def test_wrapper_reports_safe_provider_status(self):
        write_json(self.result, {"type": "result", "is_error": True, "result": f"{CLI_OUT} API Error: 429"})
        (self.root / "fixture/exit").write_text("19\n", encoding="ascii")
        p = self.wrapper()
        self.assertEqual(p.returncode, 19, p.stderr)
        self.assertIn("rate_limit", p.stdout + p.stderr)

    def test_wrapper_reports_cli_startup_failure_without_echoing_stderr(self):
        self.executable('claude', f"echo 'error: unknown option {KEY} {MODEL}' >&2; exit 2")
        p = self.wrapper()
        self.assertEqual(p.returncode, 2)
        self.assertEqual(p.stderr, 'Android agent failed (agent: cli_arguments, exit 2).\n')

    def test_wrapper_reports_unrecognized_non_json_failure_without_echoing_stdout(self):
        self.result.write_text(CLI_OUT, encoding='utf-8')
        (self.root / 'fixture/exit').write_text('9\n', encoding='ascii')
        p = self.wrapper()
        self.assertEqual(p.returncode, 9)
        self.assertEqual(p.stderr, 'Android agent failed (agent: cli_non_json_output, exit 9).\n')

    def test_malformed_status_is_neither_overwritten_nor_logged(self):
        self.executable('claude', f'''echo 'cli_setup: {KEY}' > "$AGENT_STATE_DIR/agent-status"
            echo 'unknown option' >&2; exit 7''')
        p = self.wrapper()
        self.assertEqual(p.returncode, 7)
        self.assertEqual(p.stderr, 'Android agent failed (agent, exit 7).\n')

    def test_cli_exit_wins_over_success_json_and_valid_files(self):
        (self.root / "fixture/exit").write_text("23\n", encoding="ascii")
        p = self.wrapper()
        self.assertEqual(p.returncode, 23, p.stderr)
        self.assertIn("claude", self.calls())
        self.assertIn("stop", self.calls(), "recording not stopped on failure")
        self.assertIn('agent: cli_exit_with_success', p.stderr)

    def test_success_json_cannot_replace_missing_evidence(self):
        (self.root / "fixture/evidence/01.png").unlink()
        self.assertNotEqual(self.wrapper().returncode, 0)
        self.assertIn("claude", self.calls())

    def test_charged_action_requires_another_screenshot(self):
        self.executable("adb", '[ "$*" = "shell input keyevent KEYCODE_BACK" ]')
        (self.root / "fixture/back").touch()
        p = self.wrapper()
        self.assertIn("back-completed", self.calls())
        self.assertNotEqual(p.returncode, 0)
        self.assertIn("evidence", p.stdout + p.stderr)

    def test_zero_exit_and_evidence_cannot_replace_result(self):
        self.result.write_text(CLI_OUT, encoding="utf-8")
        self.assertNotEqual(self.wrapper().returncode, 0)
        self.assertIn("claude", self.calls())

    def test_bad_setup_never_starts_agent(self):
        p = self.wrapper(TEST_DEVICE_RC="17")
        self.assertEqual(p.returncode, 17)
        self.assertIn('device-setup/install-apk', p.stderr)
        self.assertNotIn('APK installed', p.stdout)
        self.assertNotIn('Starting Android UI tester', p.stdout)
        self.assertEqual(self.calls(), ["device"])

    def test_invalid_configuration_never_reaches_device_or_agent(self):
        # A nominally usable Anthropic credential must not enable fallback.
        for name, value in (("LLM_API_KEY", ""), ("LLM_BASE_URL", ""), ("LLM_MODEL", ""),
                            ("LLM_MODEL", "sonnet"), ("LLM_BASE_URL", "https://api.anthropic.com"),
                            ("MAX_ACTIONS", "41"), ("PERSONA", "nobody"),
                            ("BRIEF", "../AGENT_BRIEF.md")):
            with self.subTest(name=name, value=value):
                p = self.wrapper(ANTHROPIC_API_KEY="fake-fallback", **{name: value})
                self.assertNotEqual(p.returncode, 0)
                self.assertEqual(self.calls(), [])
                stage = 'provider-config' if name.startswith('LLM_') else 'inputs'
                self.assertIn(f'preflight/{stage}', p.stderr)

    def test_stale_valid_evidence_is_not_reused(self):
        write_evidence(self.root / "results" / PERSONA)
        self.assertNotEqual(self.wrapper().returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_results_symlink_is_rejected_before_writing(self):
        elsewhere = self.root / "elsewhere"
        elsewhere.mkdir()
        (self.root / "results").symlink_to(elsewhere, target_is_directory=True)
        self.assertNotEqual(self.wrapper().returncode, 0)
        self.assertEqual(list(elsewhere.iterdir()), [])
        self.assertEqual(self.calls(), [])


if __name__ == "__main__":
    unittest.main()
