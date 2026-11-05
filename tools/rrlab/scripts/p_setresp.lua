local L = LAB
local m, sec = LAB.RESP_MATCH or "Quartz", LAB.RESP_SEC or 30
for _, da in ipairs(FindAllOf("UWEWorldPopResourceDA") or {}) do
    local n = L.name(da)
    if n:find(m) then
        local old = da.TimeToRespawnSeconds
        da.TimeToRespawnSeconds = sec
        L.out("set", n, old, "->", da.TimeToRespawnSeconds)
    end
end
