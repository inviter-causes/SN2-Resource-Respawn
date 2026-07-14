# Changelog

## 2.0.0

- Mined deposits now respawn **live** — no Save, no reload, no swimming away
- Deposits, loose pickups and water slugs all come back where they stood
- Respawned deposits are real nodes: mine them, get the resource, mine them again
- Resources you harvested before installing the mod get refilled too
- Fixed: the game could crash when swimming between areas
- Fixed: a spot could stop respawning after a round or two
- Performance: ~100x lighter per scan — no more stutter every 5 seconds
- Troilite is still unsupported (static object, no gathered state to read)
- Known: respawned nodes aren't written into your save (the mod refills the spot on load
  anyway); the mod only acts within ~150m of you; co-op spawning isn't verified yet

## 1.0.0

- Initial release
- Resources respawn on a configurable timer, set in-game via Mod Settings
- Small loose pickups & water slugs respawn live; mined deposits return after a Save + reload
- Per-resource on/off toggles
- English, with localization support
