local L = LAB
local t = LAB.GO
local pawn = L.pc().Pawn
pawn:K2_SetActorLocation(t, false, {}, true)
L.out(string.format("go (%.0f,%.0f,%.0f)", t.X, t.Y, t.Z))
