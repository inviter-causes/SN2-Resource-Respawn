local L = LAB
local das = FindAllOf("UWEWorldPopResourceDA") or {}
L.out("DAs loaded:", #das)
for _, da in ipairs(das) do
    local t = L.try(function() return da.TimeToRespawnSeconds end)
    local g = L.try(function() return L.guidStr(da.ResourceGUID) end)
    local sp = L.try(function() return da.ActorToPlace end)
    local sps
    if sp then
        sps = L.try(function() return sp:ToString() end)
           or L.try(function() return sp.ObjectID.AssetPath.AssetName:ToString() end)
           or L.try(function() return tostring(sp) end)
    end
    L.out(string.format("DA %-46s respawn=%s guid=%s actor=%s", L.name(da), tostring(t), tostring(g), tostring(sps)))
end
