# Changelog

## 2.1.1

- Fixed co-op: a second player no longer sees a duplicate resource node that can't be
  mined. Only the host's copy of the mod respawns resources now, and every player sees
  that one node. A client's copy of the mod stays idle
- In co-op the host also respawns spots near the other players, not only near the host
- Fixed resources that never came back after you swam away. If the timer ran out while
  nobody was near the spot, the game could refuse the respawn and the mod forgot the spot
  for good. People noticed it most with the rare Axum Bacterial Culture. Now a spot
  respawns once you are back near it, and a refused respawn is retried instead of dropped
- Fixed a rare case where a freshly respawned node was missed by the mod and a second
  copy got stacked on top of it
- Fixed nodes you only swam past being treated as harvested. The game unloads parts of
  the world even while you are close, and the mod used to count that as mining, which
  could stack a duplicate node later. Now a spot counts as harvested only if the mod saw
  the node break, or you were right next to it
- Switching a resource off no longer makes the mod treat its standing nodes as
  harvested. Before, leaving it off long enough could stack a second node on each one
- Easier to configure now that Mod Settings has left Nexus. Every setting in `config.lua`,
  including each resource toggle, is on its own line with a description, so
  UE4SS Mod Manager's "Configure mod" button can edit all of it. Developer options moved
  into a separate `Dev` section
- Older `config.lua` files from 2.1.0 still work
- New `Enabled` master switch in `config.lua`

## 2.1.0

- Troilite now respawns. Its Mineralized Clinker turned out to be a real resource node
  under the hood, not a static object
- New: **Refill on load**. Spots emptied in an earlier session (or before installing the
  mod) come back about 15s after you get near them, instead of waiting the full timer on
  every login. On by default, toggle is right under the timer slider
- Respawned nodes keep their original size (they used to come back shrunken)
- Respawn slider is easier to tune: 5s to 10min (was 60min), default now 120s
- The slider description now explains why very low timers can cost a little performance
- Known: a respawned node rolls its own yield, so the piece count can differ from the
  original. That is the game's roll, not the mod's

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
