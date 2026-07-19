#!/usr/bin/env python3
"""Run the ResourceRespawn mock tests.

main.lua reaches SN2ModSettings through paths relative to the working directory, so a
throwaway tree is built in a temp dir and the tests run from there. Neither the repo nor
the game install is touched.

    python tests/run.py
"""
import os
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
HARNESS = HERE / "harness.lua"

# What the in-game menu would have written. Present so the settings-read test has a real
# file to open.
#
# A short respawn time on purpose: the mod scales its scan interval to this value, and 15s
# puts it at one scan per wake, so the behavioural tests below drive one scan per tick.
# Section 5 rewrites this file to exercise the scaling itself.
SAVED = """return {
    Enabled = true,
    RespawnSeconds = 15,
    Titanium = true,
    Copper = true,
}
"""


def lua_path(p: Path) -> str:
    return str(p).replace("\\", "/")


def main() -> int:
    if not SCRIPTS.is_dir():
        sys.exit(f"not found: {SCRIPTS}")

    with tempfile.TemporaryDirectory(prefix="rr-tests-") as tmp:
        ms = Path(tmp) / "ue4ss" / "Mods" / "SN2ModSettings"
        (ms / "registrations").mkdir(parents=True)
        (ms / "saved").mkdir(parents=True)
        (ms / "enabled.txt").write_text("")
        (ms / "saved" / "ResourceRespawn.lua").write_text(SAVED)

        cwd = os.getcwd()
        os.chdir(tmp)
        try:
            lua = lupa.LuaRuntime(unpack_returned_tuples=True)
            run = lua.eval(
                "function(path, scripts)"
                "  local f = assert(loadfile(path))"
                "  return f(scripts)"
                "end"
            )
            failures = run(lua_path(HARNESS), lua_path(SCRIPTS))
        finally:
            os.chdir(cwd)

    failures = int(failures or 0)
    print()
    print("RESULT:", "OK" if failures == 0 else f"{failures} FAILED")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
