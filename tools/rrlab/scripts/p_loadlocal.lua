local L = LAB
local gm = FindFirstOf("UWELobbyGameMode")
L.out("lobby gm:", L.valid(gm), gm and L.cls(gm))
if not L.valid(gm) then return end
gm:LoadLocalGame(LAB.SLOT or "savegame_8", LAB.ALIAS or "", "")
L.out("LoadLocalGame called", LAB.SLOT or "savegame_8", LAB.ALIAS or "")
