#!/usr/bin/env python3
"""Compare per-scan allocation between the committed revision and the working tree.

    python tests/bench.py

Runs tests/bench.lua twice: once against HEAD's main.lua, once against the working copy.
Both runs use the same mock world and the same fake SN2ModSettings tree, so the difference
is the scan itself.
"""
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

try:
    import lupa
except ImportError:
    sys.exit("lupa is not installed.  Run: python -m pip install lupa")

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
SCRIPTS = REPO / "ResourceRespawn" / "Scripts"
BENCH = HERE / "bench.lua"

NODES = 800
TICKS = 50

SAVED = "return { Enabled = true, RespawnSeconds = 300, Titanium = true }\n"


def lua_path(p: Path) -> str:
    return str(p).replace("\\", "/")


def run_bench(scripts_dir: Path, cwd: Path) -> float:
    prev = os.getcwd()
    os.chdir(cwd)
    try:
        lua = lupa.LuaRuntime(unpack_returned_tuples=True)
        fn = lua.eval(
            "function(path, scripts, nodes, ticks)"
            "  return assert(loadfile(path))(scripts, nodes, ticks)"
            "end"
        )
        return float(fn(lua_path(BENCH), lua_path(scripts_dir), NODES, TICKS))
    finally:
        os.chdir(prev)


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="rr-bench-") as tmp:
        tmp = Path(tmp)
        ms = tmp / "ue4ss" / "Mods" / "SN2ModSettings"
        (ms / "registrations").mkdir(parents=True)
        (ms / "saved").mkdir(parents=True)
        (ms / "enabled.txt").write_text("")
        (ms / "saved" / "ResourceRespawn.lua").write_text(SAVED)

        # A copy of Scripts with HEAD's main.lua dropped in, so config.lua and friends
        # resolve exactly as they do for the working tree.
        old_scripts = tmp / "head_Scripts"
        shutil.copytree(SCRIPTS, old_scripts)
        head = subprocess.run(
            ["git", "-C", str(REPO), "show", "HEAD:ResourceRespawn/Scripts/main.lua"],
            capture_output=True, text=True, check=True,
        ).stdout
        (old_scripts / "main.lua").write_text(head, newline="\n")

        before = run_bench(old_scripts, tmp)
        after = run_bench(SCRIPTS, tmp)

    print(f"  {NODES} nodes, {TICKS} scans")
    print(f"  HEAD (v2.0.0) : {before:9.1f} KB of garbage per scan")
    print(f"  working tree  : {after:9.1f} KB of garbage per scan")
    if after > 0:
        print(f"  reduction     : {(1 - after / before) * 100:9.1f} %   ({before / after:.1f}x less)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
