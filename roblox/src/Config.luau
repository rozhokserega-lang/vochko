-- Tunable defaults for the private prototype; live ConfigService can override them.
local Config = {}
Config.Defaults = table.freeze({ Target = 21, Slots = 4, Zones = 3, Rounds = 4,
 PlayerHP = 100, EnemyHP = 2400, EnemyAttack = 7, BustPenalty = 2,
 RequestBurst = 30, RequestsPerSecond = 15, ResolveSeconds = 0.65, WinCoins = 4, DuelRoseHeal=8,DuelGuardianShield=6,DuelHP=100, DuelRounds=8, DuelHealScale=20, DuelResolveMs=3400 })
local limits = { Target = { 15, 40 }, Slots = { 3, 7 }, Rounds = { 1, 12 },
 DuelRoseHeal={0,20},DuelGuardianShield={0,15},DuelHP={30,200},DuelRounds={3,16},DuelHealScale={0,50},DuelResolveMs={1000,8000},
 PlayerHP = { 10, 1000 }, EnemyHP = { 100, 100000 }, EnemyAttack = { 0, 100 } }
local snapshot
function Config.Load()
 if game.GameId == 0 then return end
 local ok, value = pcall(function() return game:GetService("ConfigService"):GetConfigAsync() end)
 if not ok then return end
 snapshot = value
 snapshot.UpdateAvailable:Connect(function() pcall(function() snapshot:Refresh() end) end)
end
function Config.ForBattle()
 local result = table.clone(Config.Defaults)
 if snapshot then
  for key, bounds in limits do
   local ok, value = pcall(function() return snapshot:GetValue("vochko_" .. key) end)
   if ok and type(value) == "number" and value == value and value % 1 == 0 then
    result[key] = math.clamp(value, bounds[1], bounds[2])
   end
  end
 end
 return result
end
return Config
