local L = LAB
local p = L.ploc()
L.out("player", p and string.format("%.0f %.0f %.0f", p.X, p.Y, p.Z))
local all = FindAllOf("UWEWorldPopResourceBaseActor") or {}
local best = {}
for i, a in ipairs(all) do
    local ok, loc = pcall(L.aloc, a)
    if not ok then
        if i <= 3 then L.out("aloc err", L.cls(a), tostring(loc)) end
    else
        best[#best + 1] = { d = L.dist(p, loc), c = L.cls(a), loc = loc, a = a }
    end
end
table.sort(best, function(x, y) return x.d < y.d end)
L.out("located", #best, "of", #all)
for i = 1, math.min(12, #best) do
    local b = best[i]
    L.out(string.format("  %-44s d=%.0fm at (%.0f,%.0f,%.0f) id=%s", b.c, b.d / 100, b.loc.X, b.loc.Y, b.loc.Z,
        L.try(function() return L.guidStr(b.a.ResourceId) end) or "?"))
end
