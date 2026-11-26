"""From runtime root: python3 scripts/android/check_results.py PERSONA [MIN_SCREENS].

Exit 0 for complete, structurally consistent evidence; otherwise exit 1. Never
print report content, paths, parser diagnostics or image warnings. Run after the
agent exits, on its fresh per-run results tree. This is not a factual review of
an agent's findings. An issues array may legitimately be empty.
MIN_SCREENS defaults to 1; the runner supplies charged UI actions + initial view.
"""
import json
import os
from pathlib import Path
import re
import stat
import sys
import warnings


PNG_NAME = re.compile(r"(0[1-9]|[1-9][0-9])\.png")
VIDEO_NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9_-]{0,63}\.mp4")
SEVERITIES = {"blocker", "major", "minor", "cosmetic"}


def regular(path, byte_limit):
    info = path.lstat()
    return (stat.S_ISREG(info.st_mode) and info.st_nlink == 1
            and 0 < info.st_size <= byte_limit)


def text(value):
    return isinstance(value, str) and bool(value.strip()) and "\0" not in value


def unique_keys(pairs):
    record = dict(pairs)
    if len(record) != len(pairs):
        raise ValueError("duplicate field")
    return record


def valid_png(path):
    # Pillow is also required by the producer, screen.py. Check the bounded
    # dimensions, chunk checksums and decoded pixels, not just a magic prefix.
    from PIL import Image

    if not regular(path, 16 * 1024 * 1024):
        return False
    # Pillow accepts a missing/truncated final IEND chunk. screen.py always
    # emits a complete PNG ending in this empty chunk and its CRC.
    with path.open("rb") as source:
        source.seek(-12, os.SEEK_END)
        if source.read() != b"\0\0\0\0IEND\xaeB`\x82":
            return False
    with Image.open(path, formats=["PNG"]) as image:
        if image.width * image.height > 12_000_000 or getattr(image, "is_animated", False):
            return False
        image.verify()
    with Image.open(path, formats=["PNG"]) as image:
        image.load()
    return True


def valid(persona, minimum_screens=1):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,63}", persona):
        return False
    root = Path("results")
    out = root / persona
    if not all(stat.S_ISDIR(path.lstat().st_mode) for path in (root, out)):
        return False
    if any(entry != out for entry in root.iterdir()):
        return False

    report = out / "report.md"
    manifest = out / "findings.json"
    if not all(regular(path, 1024 * 1024) for path in (report, manifest)):
        return False
    if not text(report.read_text(encoding="utf-8-sig")):
        return False
    data = json.loads(manifest.read_text(encoding="utf-8-sig"), object_pairs_hook=unique_keys)
    if not isinstance(data, dict) or type(data.get("score")) not in (int, float) or not 0 <= data["score"] <= 10:
        return False
    if not isinstance(data.get("issues"), list):
        return False

    available = set()
    for path in out.iterdir():
        if path in (report, manifest):
            continue
        if path.name == "video":
            if not stat.S_ISDIR(path.lstat().st_mode):
                return False
            # Optional Android screenrecord segments (upstream: 180s, 4Mbps).
            for segment in path.iterdir():
                if not VIDEO_NAME.fullmatch(segment.name) or not regular(segment, 256 * 1024 * 1024):
                    return False
            continue
        match = PNG_NAME.fullmatch(path.name)
        if not match or not valid_png(path):
            return False
        available.add(match[1])
    if len(available) < minimum_screens or available != {f"{i:02}" for i in range(1, len(available) + 1)}:
        return False
    for issue in data["issues"]:
        if (not isinstance(issue, dict) or not text(issue.get("title")) or not text(issue.get("screen"))
                or issue.get("severity") not in SEVERITIES):
            return False
        steps, refs = issue.get("steps"), issue.get("screens")
        if not isinstance(steps, list) or not steps or not all(map(text, steps)):
            return False
        if not isinstance(refs, list) or not refs or not all(isinstance(s, str) and s in available for s in refs):
            return False
    return True


if __name__ == "__main__":
    try:
        # Silence dependencies too, including native decoder diagnostics.
        with open(os.devnull, "wb") as sink:
            os.dup2(sink.fileno(), 1)
            os.dup2(sink.fileno(), 2)
        with warnings.catch_warnings():
            warnings.simplefilter("error")
            minimum = sys.argv[2] if len(sys.argv) == 3 else "1"
            ok = (len(sys.argv) in (2, 3) and re.fullmatch(r"[1-9][0-9]?", minimum)
                  and valid(sys.argv[1], int(minimum)))
    except Exception:
        # Includes unreadable files, malformed input and decoder errors. Do
        # not stringify exceptions: they can include attacker-supplied data.
        ok = False
    sys.exit(0 if ok else 1)
