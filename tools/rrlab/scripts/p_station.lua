local L = LAB
local st = FindAllOf("SN2BaseScannerStation") or {}
L.out("stations:", #st)
local p = L.ploc()
for _, s in ipairs(st) do
    local loc = L.aloc(s)
    L.out(string.format("station %s at (%.0f,%.0f,%.0f) d=%.0fm", L.name(s), loc.X, loc.Y, loc.Z, p and L.dist(p, loc) / 100 or -1))
    L.out("  ActiveFilter:", L.try(function() return L.name(s.ActiveFilter) end))
    for _, prop in ipairs({ "AvailableFilters", "AllFilters", "ResourceBuffer", "ActivePoints", "PointTransforms" }) do
        L.out("  ", prop, L.try(function() return s[prop]:GetArrayNum() end))
    end
    L.out("  LastPointCount", L.try(function() return s.LastPointCount end), "ScannerRadius", L.try(function() return s.ScannerRadius end))
end
local fs = FindAllOf("SN2BaseScannerStationFilterDataAsset") or {}
L.out("filters loaded:", #fs)
for _, f in ipairs(fs) do
    local n = L.try(function() return f.WorldPopResourcesToFind:GetArrayNum() end)
    local tag = L.try(function() return f.ScannerStationSignalTag.TagName:ToString() end)
    local first = L.try(function() return f.WorldPopResourcesToFind[1]:ToString() end)
               or L.try(function() return tostring(f.WorldPopResourcesToFind[1]) end)
    L.out(string.format("  filter %-42s toFind=%s tag=%s first=%s", L.name(f), tostring(n), tostring(tag), tostring(first)))
end
