local L = LAB
local pats = { "Titanium", "Copper", "Quartz", "Silver", "Salt", "Lead", "Gold", "Sulfur", "Lithium", "Celestine", "Atacamite", "Fulgurite", "NeedlerShark", "DeepRoot", "AxumRebar" }
local n = 0
for _, da in ipairs(FindAllOf("UWEWorldPopResourceDA") or {}) do
    local nm = L.name(da)
    for _, pt in ipairs(pats) do
        if nm:find(pt) and not nm:find("Clamthulu") then
            da.TimeToRespawnSeconds = LAB.RESP_SEC or 30
            n = n + 1
            break
        end
    end
end
L.out("set TimeToRespawnSeconds =", LAB.RESP_SEC or 30, "on", n, "DAs")
