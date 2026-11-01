"""Validate distributable files and local documentation links; no Roblox execution."""

from __future__ import annotations

import re
import struct
import subprocess
import sys
import tomllib
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    errors: list[str] = []
    listed = subprocess.check_output(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
        cwd=ROOT,
    ).decode("utf-8").split("\0")
    paths = {ROOT / name for name in listed if name}
    packaged = {path.resolve() for path in paths}

    required = (
        "LICENSE", "NOTICE.md", "README.md", "README.fr.md",
        "saveinstance.luau", "moonwave.toml",
        "StreamingCapture.luau", "scripts/test_gps.py",
        "Economy Analyzer/Analyzer.luau", "Economy Analyzer/analyze.luau", "docs/ECONOMY.md",
        "docs/USAGE.md", "docs/TROUBLESHOOTING.md", "docs/ROADMAP.md",
        "assets/brand/logo.png", "assets/brand/banner.png",
        ".moonwave/static/logo.png", ".moonwave/static/favicon.png",
        "docs/intro.md", "docs/PRESETS.md", "Script Presets/presets.json",
        "Script Presets/README.md", "Script Presets/UltraCompleteSavePlace.luau",
    )
    for name in required:
        if not (ROOT / name).is_file():
            errors.append(f"Missing distribution file: {name}")

    source = (ROOT / "saveinstance.luau").read_text(encoding="utf-8")
    if re.search(r"--\s*Saved by|<!--\s*Saved by", source):
        errors.append("Exporter credit headers must not be inserted into saved content")

    # Validate actual PNG headers so accidental text/LFS placeholders cannot pass.
    for name in ("assets/brand/logo.png", "assets/brand/banner.png"):
        path = ROOT / name
        if path.is_file():
            data = path.read_bytes()[:24]
            if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n":
                errors.append(f"Invalid PNG asset: {name}")
            else:
                width, height = struct.unpack(">II", data[16:24])
                if width < 256 or height < 256:
                    errors.append(f"Brand image is unexpectedly small: {name}")

    # Check links to repository files, including HTML README image/link elements.
    for path in sorted(paths):
        if path.suffix.lower() != ".md" or not path.is_file():
            continue
        source = path.read_text(encoding="utf-8")
        source = re.sub(r"```.*?```", "", source, flags=re.DOTALL)
        links = re.findall(r"\[[^\]]*\]\(([^)\s]+)\)", source)
        links += re.findall(r'(?:src|href)="([^"]+)"', source)
        for link in links:
            parsed = urlsplit(link)
            if parsed.scheme or parsed.netloc or not parsed.path:
                continue
            if parsed.path.rstrip("/") == "/api/CompleteSavePlace":
                # This is a generated Moonwave route, not a source file.
                continue
            target = (path.parent / unquote(parsed.path)).resolve()
            if not target.is_relative_to(ROOT):
                errors.append(f"Link escapes repository in {path.relative_to(ROOT)}: {link}")
            elif not target.is_file() or target not in packaged:
                errors.append(f"Missing packaged link target in {path.relative_to(ROOT)}: {link}")

    try:
        config = tomllib.loads((ROOT / "moonwave.toml").read_text(encoding="utf-8"))
        for image in (config["home"]["bannerImage"], config["docusaurus"]["favicon"]):
            if not (ROOT / ".moonwave" / "static" / image).is_file():
                errors.append(f"Missing documentation image: {image}")
    except (OSError, KeyError, tomllib.TOMLDecodeError) as exc:
        errors.append(f"Invalid documentation configuration: {exc}")

    for path in paths:
        if path.suffix.lower() in {".rbxl", ".rbxlx", ".rbxm", ".rbxmx", ".log"}:
            errors.append(f"Local runtime output should not be distributed: {path.relative_to(ROOT)}")
        if path.name == ".env" or path.name.startswith(".env.") and path.name != ".env.example":
            errors.append(f"Environment file should not be distributed: {path.relative_to(ROOT)}")

    if errors:
        print("\n".join(f"ERROR: {message}" for message in errors))
        return 1
    print(f"Repository checks passed ({len(paths)} files; documentation links and PNG assets verified).")
    print("Roblox runtime compatibility and exported files are not covered by these checks.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
