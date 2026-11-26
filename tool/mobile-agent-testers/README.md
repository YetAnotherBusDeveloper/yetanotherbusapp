# Android AI tests for YABus

## First run

1. **Confirm you hold the decryption key first** (below). Review the workflow and test code, then merge them and **only the public PEM** onto the repository's protected default branch. GitHub won't list a new manual workflow until it is there. Nothing here pushes, publishes or dispatches a run.
2. In **Settings → Secrets and variables → Actions**, keep the existing repository **secrets** `LLM_BASE_URL` (HTTPS Anthropic-compatible CPA base, not the OpenAI chat or full `/v1/messages` URL), `LLM_API_KEY` (CPA bearer token), and `LLM_MODEL` (exact CPA model ID, not a Claude model-family alias). The endpoint must be reachable from a GitHub-hosted Ubuntu runner with a publicly trusted TLS certificate. No other secret is required. Do not enter secrets in dispatch inputs or enable runner debug tracing. Set a spending/rate limit on the CPA credential.
3. Open **Actions → Mobile agent testers (YABus Android) → Run workflow**. Leave **Use workflow from** on the **default branch**. The separate **App branch, tag or full SHA** field defaults to the dispatch commit. For a historical build, enter a branch/tag resolving to, or full SHA of, a commit already in that branch's history. Unmerged feature/PR code is deliberately not supported. Start with **`anna`**, **`yabus`**, **15** actions, recording **off**. Click **Run workflow** once. This authorizes billable requests including the short capability check. Cancel in Actions if necessary; cancelled jobs may have no report.
4. Watch **plan** then **Android / anna**. Build, emulator boot, install/launch, model, and evidence failures are not successful test results. An exhausted budget or cancelled run is not a clean bill of health. On a complete run, open the encrypted artifact as described below. **Review the numbered screenshots against the claims.**

## Report key and local recovery

`results_public.pem` is a **new YABus RSA public key, not the upstream example**. Its private half was written to an owner-only directory under the generating Windows user's `%USERPROFILE%\.mobile-agent-testers\YABus-…\private.pem`, **outside** the repository. If this is not your machine or you cannot access that key, **rotate before running**, rather than collecting unreadable artifacts. Back up the private half to an encrypted vault/offline medium. Do not copy it into a checkout, GitHub secret, CI log, issue, or chat. Rotation does not recover old reports: retain old private keys until the corresponding reports expire.

To check the pair, run the following locally with Bash and OpenSSL (from the repository root). The two hashes must match:

```bash
openssl pkey -in "$PRIVATE_KEY" -pubout -outform DER | openssl dgst -sha256
openssl pkey -pubin -in tool/mobile-agent-testers/results_public.pem -outform DER | openssl dgst -sha256
```

To generate your own on **Windows**, run `powershell -ExecutionPolicy Bypass -File tool/mobile-agent-testers/new-key.ps1` locally with OpenSSL on PATH. It creates a new ACL-protected directory, prints the private **path**, and replaces only the public PEM in the repo. On **Linux/macOS** (local terminal):

```bash
umask 077
mkdir -p "$HOME/.mobile-agent-testers"
keydir=$(mktemp -d "$HOME/.mobile-agent-testers/YABus.XXXXXXXX")
openssl genpkey -algorithm RSA -aes-256-cbc -pkeyopt rsa_keygen_bits:3072 -out "$keydir/private.pem"
openssl pkey -in "$keydir/private.pem" -pubout -out tool/mobile-agent-testers/results_public.pem
```

Preserve the PEM passphrase separately if used. Review and commit **only `tool/mobile-agent-testers/results_public.pem`** for a key rotation. Never run upstream `setup.sh`, which sets different secrets and pushes changes.

**Download/decrypt** (Linux/macOS/WSL; Bash, OpenSSL, Python 3.12+ recommended). On the run summary click `results-anna` under **Artifacts**, unzip it **outside the repository**, or use GitHub CLI from the checkout:

```bash
run=123456789   # numeric Actions run ID from the run URL
umask 077
out=$(mktemp -d "$HOME/yabus-report.XXXXXXXX")
gh run download "$run" -n results-anna -D "$out/encrypted"
# Set PRIVATE_KEY to your local private PEM path. No network/model call to decrypt.
bash tool/mobile-agent-testers/decrypt.sh "$PRIVATE_KEY" "$out/encrypted/anna.key.bin" "$out/decrypted"
ls "$out/decrypted/results/anna"
```

Repeat with the corresponding persona name for a multi-persona run. The `.key.bin` is the RSA-OAEP-wrapped random secret; `.tgz.enc` is the salted AES-256-CBC/PBKDF2 encrypted tarball. This is the format of upstream `encrypt_results.sh`, not a password-protected ZIP. It provides confidentiality, **not a signed or authenticated report**: only decrypt artifacts from your own trusted run. Expect `report.md`, `findings.json`, numbered PNGs and optional MP4 segments; failures may have partial/empty results. Do not publish decrypted data. Downloads expire after seven days. **No `ARTIFACT_PASSPHRASE`**: upstream uses it only to shuttle the APK between jobs. Here the APK never leaves the runner, not even as an artifact.

## What runs (and what doesn't)

* Manual Android only. One job per requested persona, **one at a time**; select up to three distinct Android IDs from `runtime/personas.json` (no `all`). A concurrency group prevents overlapping workflows. No iOS/Wear OS, releases, signing secrets, deployment, production account, issue creation or unattended triggers. A turn limit and step/job timeouts bound the run; UI actions aren't equivalent to a token or dollar limit. The focused `search` brief is for a second run, not an additional agent on the first.
* Plan resolves and validates the source SHA before CPA calls. The harness/briefs/key always come from the dispatch revision, not the app input. Each persona builds the actual phone target with the same Flutter 3.41.6 / Java 17 as YABus CI (`flutter pub get`, `flutter build apk --debug --target-platform android-x64`). Flutter/pub and Gradle caches are used; no AVD snapshots or report cache. Sign-in client IDs, keystores, distribution settings, and backend admin credentials aren't needed. An ephemeral debug manifest deactivates Firebase Analytics even though the app requests collection on startup; a debug-only inert Firebase project config prevents production FCM token registration. Debug ads use the app's existing test unit. These changes do not affect the repository's Android manifests or release variants.
* The stock Google APIs x86_64 AVD uses KVM. Device, Android API, font scale and theme come from the upstream persona, **locale and simulated location are zh-TW / Taipei**. The installed package is read with `aapt2 dump packagename app.apk` (currently `tw.avianjay.taiwanbus.flutter`), not taken from a workflow default. The runner installs without `-g`, resolves the package's actual launcher and checks `am start -W`. Fresh local state only; test database/search coverage depends on the selected region, permission and live feeds. Push delivery, account sync, data submissions, installing updates, ads and production mutations are out of scope.
* **CPA, not a Codex CLI replacement.** The upstream control loop is headless `claude -p`, with Android actions via ADB, half-size PNGs read by Claude's image-capable Read tool, accessibility hints and on-disk reports. A fresh unprivileged Linux user has a root-owned harness, a writable result directory, no inherited GitHub credentials and limited host egress (DNS, local ADB/emulator and addresses resolved for CPA). The guest can still fetch transit data. Protected default branch and reviewed commits are part of the trust boundary; GitHub users able to change trusted workflow code can change how repository secrets are used.
* The preflight makes **two small Messages requests** (one synthetic image, one tool-result continuation). It checks the selected model's visual/tool response and streamed message protocol; it never sends app screenshots or prints provider response bodies. Non-compatible `/v1/messages`, HTTP auth/model errors, 429s, malformed streams, incorrect visual/tool responses, or missing tool-result support should stop the run rather than changing providers. During the tester session actual screenshots and UI text **are sent to CPA**. Endpoint logs, data retention, quotas and model routing beyond CPA are under the owner's control. Anthropic model slots including background/small models use `LLM_MODEL`; direct Anthropic auth is not an alternate path. A probe pass cannot guarantee good findings or support for every flag/header used by Claude Code. Check CPA diagnostics privately if the probe passes but the agent fails. DNS/IP changes during a session can require a fresh dispatch. Don't retry repeated 429s automatically.

## Maintenance and verification

Derived from [pierridotite/mobile-agent-testers at aa69f3f](https://github.com/pierridotite/mobile-agent-testers/tree/aa69f3f390079a3236c089643d032bc2c393c036), MIT, © 2026 Pierre Raffalli (see `LICENSE.upstream`). Start upstream comparisons at `.github/workflows/agent-testers.yml`, `scripts/{android/,a11y.py,llm_env.sh,agent_status.py,matrix.py,encrypt_results.sh,collect.sh}`, `personas.json` and `AGENT_BRIEF.md`. Local adaptations are intentional: reviewed YABus source, Android-only matrix, no pre-grants, constrained counted actions, CPA-only credentials, checked agent/evidence status, and encrypt-before-upload. Do not copy the upstream demo, recipient, automatic setup, or optional model-based local summarizer. Actions, Claude Code and the imported upstream revision are pinned; review CLI flags and model environment variables when updating.

See [the runtime contract](RUNTIME.md) for the exact inputs, tool permissions, exit status and evidence format. [The main YABus brief](runtime/briefs/yabus.md) and [focused search brief](runtime/briefs/search.md) are the selectable missions.

Offline checks (Linux; Python with Pillow and PyYAML, Git, Bash and OpenSSL):

```bash
actionlint .github/workflows/mobile-agent-testers.yml
python3 -B -m unittest discover -s tool/mobile-agent-testers/tests -v
find tool/mobile-agent-testers -name '*.sh' -exec bash -n {} \;
```

Local validation: an x86_64-capable debug APK was built with Flutter 3.41.6. `aapt2` verified `tw.avianjay.taiwanbus.flutter.MainActivity`, min SDK 24, the inert Firebase project and analytics deactivation in the packaged APK. Actionlint 1.7.12, shell syntax checks and 44 offline integration tests passed. These include mock device/CLI and CPA protocol errors, evidence validation, and report decryption with correct versus incorrect keys. None uses the owner's CPA credentials.

The existing route-keypad tests completed (11 passed). Broader local Flutter test invocations, including stop search and favorites, exceeded their command timeouts; the app test suite is **not** claimed green. The integration does not change app source or replace existing CI.

The first authorized hosted run still needs to confirm CPA's real vision/tool support, hosted runner disk and KVM/device setup, successful launch on the desired ref and local recovery of its encrypted evidence. A manual dispatch will not run a workflow file that only exists in a local working tree.
