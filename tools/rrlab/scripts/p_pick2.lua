-- like p_pick but filtered by class substring LAB.PICKCLS and within LAB.PICKR metres
local L = LAB
local pc = L.pc(); local pawn = pc.Pawn
local paddr = pawn:GetAddress()
local router
for _, c in ipairs(FindAllOf("UWEInventoryRouterComponent") or {}) do
    local o = L.try(function() return c:GetOwner() end)
    if o and L.try(function() return o:GetAddress() end) == paddr then router = c end
end
if not router then L.out("no router"); return end
local p = L.ploc()
local best, bd
for _, a in ipairs(FindAllOf("UWEWorldPopResourceBaseActor") or {}) do
    if L.cls(a):find(LAB.PICKCLS or "ResourceNode") then
        local ok, loc = pcall(L.aloc, a)
        if ok and not L.try(function() return a.bHasBeenGathered end) then
            local d = L.dist(p, loc)
            if d < (LAB.PICKR or 20) * 100 and (not bd or d < bd) then best, bd = a, d end
        end
    end
end
if not best then L.out("no target"); return end
local id = L.guidStr(best.ResourceId)
LAB.PICKED_ID = id
local reason = {}
local okc, can = pcall(function() return router:CanPickUpActor(best, {}, reason) end)
L.out("target", L.cls(best), id, string.format("d=%.1fm", bd / 100), "CanPickUp:", okc, tostring(can))
if LAB.PICK_FORCE or (okc and can) then
    local ok, err = pcall(function() router:PickupActor(best, {}) end)
    L.out("PickupActor ok=", ok, err and tostring(err) or "")
end
