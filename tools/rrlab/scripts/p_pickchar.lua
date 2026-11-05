local L = LAB
local ws = FindAllOf("WBP_CharacterSelectScreen_C") or {}
L.out("char screens:", #ws)
for _, w in ipairs(ws) do
    if L.valid(w) and not L.name(w):find("Default__") then
        L.out("calling DevSelectCharacterAndCloseScreen on", L.name(w))
        w:DevSelectCharacterAndCloseScreen()
    end
end
