local L = LAB
local s = L.sub(); if not s then L.out("no sub"); return end
for _, p in ipairs({ "ResourcesToRespawn", "RespawnTimers", "PendingRespawnActors", "ResourceInstanceGatherStates" }) do
    local n = 0
    local ok, e = pcall(function() s[p]:ForEach(function() n = n + 1 end) end)
    L.out(p, "count=", n, ok and "" or ("err " .. tostring(e)))
end
pcall(function()
    s.ResourceInstanceGatherStates:ForEach(function(k, v) L.out("  gs", L.guidStr(k:get()), v:get()) end)
end)
