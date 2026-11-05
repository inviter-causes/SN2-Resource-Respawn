-- teleport the pawn next to the nearest resource actor (optionally filtered by class substring LAB.TPCLS)
local L = LAB
local pc = L.pc(); local pawn = pc.Pawn
local p = L.ploc()
local best, bd
for _, a in ipairs(FindAllOf("UWEWorldPopResourceBaseActor") or {}) do
    if not LAB.TPCLS or L.cls(a):find(LAB.TPCLS) then
        local ok, loc = pcall(L.aloc, a)
        if ok and not L.try(function() return a.bHasBeenGathered end) then
            local d = L.dist(p, loc)
            if not bd or d < bd then best, bd = { a = a, loc = loc }, d end
        end
    end
end
if not best then L.out("nothing to teleport to"); return end
local t = { X = best.loc.X, Y = best.loc.Y + 150, Z = best.loc.Z + 100 }
local hit = {}
pawn:K2_SetActorLocation(t, false, hit, true)
LAB.TARGET_ID = L.guidStr(best.a.ResourceId)
L.out(string.format("teleported to (%.0f,%.0f,%.0f) next to %s id=%s (was %.0fm away)", t.X, t.Y, t.Z, L.cls(best.a), LAB.TARGET_ID, bd / 100))
