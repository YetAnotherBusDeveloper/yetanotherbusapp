"""Capture results/<persona>/<NN>.png at half size; list real-pixel tap targets.

Adapted from pierridotite/mobile-agent-testers (aa69f3f), MIT, © 2026 Pierre
Raffalli. Output is for the private tester transcript, NOT the Actions log.
"""
import io
import os
from pathlib import Path
import re
import secrets
import subprocess
import sys
import xml.etree.ElementTree as ET

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import a11y  # noqa: E402


def adb(*args):
    return subprocess.run(["adb", *args], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                          timeout=60, check=True).stdout


def describe(w, h):
    # A failed dump must not re-use a previous screen's hierarchy. Don't leave
    # visible field values in shared storage or a persistent density cache.
    tmp = f"/data/local/tmp/ui-{secrets.token_hex(8)}.xml"
    try:
        adb("shell", "uiautomator", "dump", tmp)
        xml = adb("exec-out", "cat", tmp)
        root = ET.fromstring(xml[xml.index(b"<"):])
    finally:
        adb("shell", "rm", "-f", tmp)
    for node in root.iter("node"):
        if node.get("password") == "true":
            node.set("text", "[password field]")
            node.set("content-desc", "")
        label = (node.get("text") or "").strip() or (node.get("content-desc") or "").strip()
        edit = node.get("class", "").endswith("EditText")
        bounds = re.findall(r"-?\d+", node.get("bounds", ""))
        if (label or edit) and len(bounds) == 4:
            x1, y1, x2, y2 = map(int, bounds)
            kind = "field" if edit else "button" if node.get("clickable") == "true" else "text"
            print(f"- {kind} {label[:70]!r} centre=({(x1+x2)//2},{(y1+y2)//2})")
    dpi = re.findall(rb"\d+", adb("shell", "wm", "density"))
    if dpi and int(dpi[-1]) > 0:
        check = a11y.android(root, int(dpi[-1]), w, h)
        if check:
            print(check)


def capture(args):
    if len(args) != 2 or not re.fullmatch(r"results/[A-Za-z0-9][A-Za-z0-9_-]{0,63}", args[0]):
        sys.exit("Usage: screen.py results/<persona> <NN>")
    out, nn = Path(args[0]), args[1]
    if (not re.fullmatch(r"[0-9]{2}", nn) or nn == "00" or out.parent.is_symlink() or out.is_symlink()
            or out.name != os.environ.get("PERSONA", out.name)):
        sys.exit("Invalid screenshot destination.")
    out.mkdir(mode=0o700, parents=True, exist_ok=True)
    png = adb("exec-out", "screencap", "-p")
    # Some foldables print a warning before the PNG signature.
    with Image.open(io.BytesIO(png[png.index(b"\x89PNG\r\n\x1a\n"):]), formats=["PNG"]) as img:
        w, h = img.size
        small = img.convert("RGB").resize((w // 2, h // 2))
    path = out / f"{nn}.png"
    with path.open("xb") as dest:  # never overwrite evidence or follow a file symlink
        try:
            small.save(dest, format="PNG")
        except OSError:
            dest.close()
            path.unlink(missing_ok=True)
            raise
    print(f"screenshot: {path.as_posix()} (screen {w}x{h}; image is half size: multiply positions read on it by 2)")
    try:
        describe(w, h)
    except (ValueError, ET.ParseError, OSError, subprocess.SubprocessError, RecursionError):
        print("UI hierarchy or accessibility check unavailable; inspect the screenshot.")
    try:
        # Never forward raw logcat: crash messages can contain app data. This
        # emulator-wide signal alone does not establish that the app crashed.
        crash = adb("logcat", "-d", "-b", "crash", "-t", "30")
        if any(line.strip() and not line.startswith(b"-----") for line in crash.splitlines()):
            print("Emulator crash log has new entries; verify which app and what happened on screen.")
            adb("logcat", "-b", "crash", "-c")
    except (OSError, subprocess.SubprocessError):
        print("Emulator crash check unavailable.")


if __name__ == "__main__":
    try:
        capture(sys.argv[1:])
    except FileExistsError:
        sys.exit("Screenshot number already used; use the next number.")
    except (OSError, ValueError, Image.DecompressionBombError, subprocess.SubprocessError):
        sys.exit("Could not capture Android screenshot.")
