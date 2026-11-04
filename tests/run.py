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

# lupa auto-selects the newest Lua it bundles (lua55), but on this machine that DLL is
# blocked by an Application Control policy. Fall back to an allowed build; lua54 matches
# the Lua 5.4 that UE4SS runs, so behaviour is the closest to the game.
def _lua_runtime_factory():
    for name in ("lua54", "lua53", "luajit21", "lua52", "lua51"):
        try:
            mod = __import__("lupa", fromlist=[name]).__dict__.get(name)
            if mod is None:
                continue
            mod.LuaRuntime(unpack_returned_tuples=True)  # prove the DLL actually loads
            return lambda m=mod: m.LuaRuntime(unpack_returned_tuples=True)
        except Exception:
            continue
    try:
        lupa.LuaRuntime(unpack_returned_tuples=True)
        return lambda: lupa.LuaRuntime(unpack_returned_tuples=True)
    except Exception as e:
        sys.exit(f"no usable Lua runtime in lupa: {e}")

_new_runtime = _lua_runtime_factory()

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
SCRIPTS = REPO / "ResourceRespawn" / "Scripts"
HARNESS = HERE / "harness.lua"
CATALOG_HARNESS = HERE / "catalog_harness.lua"

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


def check_mod_manager_view() -> int:
    """What UE4SS Mod Manager's "Configure mod" window would list for config.lua.

    Since SN2ModSettings left Nexus, that window is the easy way to configure the mod. It
    only edits top-level scalar lines of the returned table (depth 1), takes its
    description from the comment line directly above, and skips nested tables. This
    mirrors those rules (AtilioA/UE4SS-mod-manager, src/common/config.py) closely enough to
    catch a toggle sliding into a nested table or losing its description.
    """
    import re
    assign = re.compile(r"^\s*([A-Za-z_]\w*)\s*=\s*(true|false|[+-]?\d+(?:\.\d+)?)\s*,?\s*(--.*)?$")
    depth, prev_comment, seen = 0, None, {}
    for line in (SCRIPTS / "config.lua").read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if depth == 1:
            if stripped.startswith("--"):
                prev_comment = stripped[2:].strip()
            else:
                m = assign.match(line)
                if m:
                    seen[m.group(1)] = prev_comment
                prev_comment = None
        code = line.split("--", 1)[0]
        depth = max(depth + code.count("{") - code.count("}"), 0)

    expected = {"Enabled", "RespawnSeconds", "RefillOnLoad", "Titanium", "Copper", "Quartz",
                "Salt", "WaterSlug", "Lead", "Silver", "Sulfur", "Gold", "Lithium",
                "Atacamite", "Celestine", "ConduitCrystal", "CreatureEnamel", "AxumCulture",
                "Troilite"}
    failures = 0

    def check(name, ok, detail=""):
        nonlocal failures
        print(f"  {'PASS' if ok else 'FAIL'}  {name}" + ("" if ok else f"   ({detail})"))
        if not ok:
            failures += 1

    check("Mod Manager lists every player setting", expected <= set(seen),
          sorted(expected - set(seen)))
    check("Mod Manager lists no developer flags", set(seen) <= expected,
          sorted(set(seen) - expected))
    check("every listed setting has a description",
          all(seen.get(k) for k in expected), [k for k in expected if not seen.get(k)])
    return failures


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
            def run_harness(harness: Path) -> int:
                # A fresh runtime per harness so their global mocks never bleed together.
                lua = _new_runtime()
                run = lua.eval(
                    "function(path, scripts)"
                    "  local f = assert(loadfile(path))"
                    "  return f(scripts)"
                    "end"
                )
                return int(run(lua_path(harness), lua_path(SCRIPTS)) or 0)

            print("### main.lua ###")
            failures = run_harness(HARNESS)
            print()
            print("### catalog.lua ###")
            failures += run_harness(CATALOG_HARNESS)
            print()
            print("### config.lua as UE4SS Mod Manager sees it ###")
            failures += check_mod_manager_view()
        finally:
            os.chdir(cwd)

    failures = int(failures or 0)
    print()
    print("RESULT:", "OK" if failures == 0 else f"{failures} FAILED")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
