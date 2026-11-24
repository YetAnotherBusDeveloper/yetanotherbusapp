## Android runtime contract

Stage the **contents** of `runtime/` into a fresh directory outside the checkout. Add the single, non-split APK as `app.apk`. From that directory, with `AGENT_BRIEF.md`, `briefs/`, `personas.json`, and `scripts/` at its root, invoke:

```sh
bash scripts/android/run_agent.sh
```

The workflow owns the build, emulator lifecycle, account isolation, networking, encryption and upload. The runtime does not fetch code, log in to a provider, build the app, or collect credentials interactively.

| Environment inputs | Meaning |
|---|---|
| `PERSONA`, `DEVICE` | ID of one Android entry in `personas.json` (also the output directory name); human-readable AVD description. Boot the matching profile/API before invoking the script. |
| `LOCALE`, `FONT_SCALE`, `THEME` | Android locale tag (e.g. `zh-TW`), positive decimal font scale, and `light` or `dark`. |
| `GEO` | Latitude,longitude, no spaces; e.g. `25.0478,121.5170`. |
| `BRIEF` | Relative path to the selected mission, e.g. `briefs/yabus.md` or `briefs/search.md`. |
| `MAX_ACTIONS`, `RECORD_VIDEO` | Integer **1–40** UI commands (workflow default 15); lowercase `true` or `false`. The separate Claude turn cap is `3 * MAX_ACTIONS + 12`, allowing observations and report writing. |
| `LLM_API_KEY`, `LLM_BASE_URL`, `LLM_MODEL` | Required **CPA** bearer credential, explicit HTTPS Anthropic-compatible gateway base URL, and explicit vision/tool-capable model ID. No provider default, subscription, CLI login or public API fallback. Supply as secrets, not command-line options. The caller must verify this is the intended CPA service and restrict egress accordingly. |

**Dependencies and trust boundary.** Use Linux, Bash, GNU coreutils, Python 3 with Pillow on the agent user's PATH, Android SDK platform-tools (`adb`) and build-tools (`aapt2` on PATH or in `$ANDROID_HOME/build-tools`), and Claude Code with the pinned workflow's restricted-mode flags (2.1.330). A single fresh, booted `google_apis` emulator must be accessible through the running adb server, with working console authentication for `adb emu geo fix` and `adb root`/`unroot` for locale changes. Stock Play images may not support this. Do not preinstall the APK, pass `APP_ID`, grant permissions, or restore a used AVD snapshot. The runtime reads the APK's manifest package, verifies a fresh install, resolves the launcher and waits for an actual activity start before testing.

Run as an unprivileged, disposable account. The staged scripts, brief, persona data and APK should be trusted, read-only files. Only `results/`, private temp space and the account's home need to be writable. The Claude process gets a separate empty home and a minimal environment, not Actions tokens, file-command paths, or user/project settings. Its Android tools capture the emulator, run accessibility checks, and permit only budgeted tap, swipe, Back, printable ASCII text entry and relaunch of the installed app. Claude permissions are not an OS sandbox: keep source, signing material, cloud credentials, other devices and unrelated services inaccessible.

Keep credential scrubbing enabled. On Linux the CLI uses an [isolated PID namespace for Bash subprocesses](https://code.claude.com/docs/en/env-vars#what-the-subprocess-environment-scrub-removes); the agent account must be able to use it on the selected runner.

**Exit and output.** Exit `0` means setup, Claude completion, optional recording and evidence validation succeeded; it does **not** mean the app had no defects. CLI failures retain their exit code. A turn limit, malformed response, missing report, invalid manifest or missing/referenced-invalid screen fails even if the process itself exited zero. The ordinary log contains only a fixed stage/status (for example, `rate_limit`), not raw model output, endpoint, model ID, screenshot data or adb output. Results remain private until your workflow encrypts them. On failure there may be partial evidence; do not publish it as a successful run.

A `device-setup/...` failure names the last attempted operation (for example, `adb-root`, `geo-fix`, `install-apk`, `verify-installed-apk` or `start-activity`). It happens before the model session. The separate “APK installed, digest verified and launcher activity started” milestone confirms installation and launch; “Starting Android UI tester” alone is **not** evidence that a UI action completed.

After a locale restart, setup waits for the new Android framework, settings services and unlocked emulator user. It installs and starts the app only once. If Android's `am start -W` reports `Status: timeout`, setup gives the launcher a bounded first-frame check: the actual app window must gain focus, be visible, and report `HAS_DRAWN`. A splash window or a running process is not enough. If these checks fail, the agent never starts.

- `results/<persona>/report.md` — nonempty narrative.
- `results/<persona>/findings.json` — numeric `score` (0–10) and `issues` array; each issue needs `title`, `severity`, `screen`, nonempty `steps`, and `screens` referencing existing numbered PNGs. An empty issues array is valid.
- `results/<persona>/01.png`, `02.png`, … — half-size evidence, initial screen then after each action. With recording enabled, `video/` holds private MP4 segments. Transcripts/stderr are temporary, not deliverables.

**Attribution.** The runtime adapts [Pierre Raffalli's mobile-agent-testers, commit `aa69f3f`](https://github.com/pierridotite/mobile-agent-testers/tree/aa69f3f390079a3236c089643d032bc2c393c036): `AGENT_BRIEF.md`, Android runner/capture/typing helpers, `a11y.py`, `llm_env.sh`, and `agent_status.py`. Copyright © 2026 Pierre Raffalli, MIT; see `LICENSE.upstream`. The Android-only setup, CPA isolation, action budget and evidence checks are local adaptations.
