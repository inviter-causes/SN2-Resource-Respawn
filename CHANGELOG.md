# Changelog

## 2.0.1

- Fixed the stutter that returned every few seconds during play
- Respawning several deposits at once no longer freezes the game for up to a second
- Scans now run less often when the respawn timer is long. At the default 300s the mod
  scans every 20s instead of every 5s
- Fixed a startup error that cut the settings line off in the log
- The internal position cache no longer grows for the whole session
- New `Profile` flag in `config.lua` logs where each scan spends its time, for chasing
  performance reports
- Known: one scan still costs a few tens of ms, so a brief hitch can remain once per scan
  interval. A longer respawn timer means it happens less often

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
