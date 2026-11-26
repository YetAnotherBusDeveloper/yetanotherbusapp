"""Replace up to 40 characters in the focused field: type.py "text".

Adapted from pierridotite/mobile-agent-testers (aa69f3f), MIT, © 2026 Pierre
Raffalli. Android's `input text` is not a Unicode IME. Unlike upstream, refuse
unsupported text *before* editing the field rather than silently dropping it.
"""
import shlex
import subprocess
import sys


def input_command(*args):
    # adb shell passes a command to the *device's* shell even without shell=True.
    subprocess.run(["adb", "shell", shlex.join(["input", *args])], check=True,
                   timeout=30, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main(args):
    if len(args) != 1 or len(args[0]) > 256 or any(not (' ' <= c <= '~') for c in args[0]) or '%s' in args[0]:
        sys.exit("Use a short printable ASCII query without literal %s, or use the on-screen keyboard.")
    input_command("keyevent", "KEYCODE_MOVE_END")
    input_command("keyevent", *(["67"] * 40))
    if args[0]:
        input_command("text", args[0].replace(" ", "%s"))
    print("typed: check it on the next screenshot")


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except (OSError, subprocess.SubprocessError):
        sys.exit("Android text input failed; check the field before retrying.")
