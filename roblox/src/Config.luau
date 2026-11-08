-- Tunable defaults for the private prototype; live ConfigService can override them.
local Config = {}
Config.Defaults = table.freeze({ Target = 21, Slots = 4, Zones = 3, Rounds = 4,
 PlayerHP = 100, EnemyHP = 2400, EnemyAttack = 7, BustPenalty = 2, PvPRoundSeconds=60,
 RequestBurst = 30, RequestsPerSecond = 15, ResolveSeconds = 0.65, WinCoins = 4, DuelRoseHeal=8,DuelGuardianShield=6,DuelHP=100, DuelRounds=10, DuelHealScale=20, DuelResolveMs=3400,
 DuelRaceSeconds=20, DuelRaceHP=100, DuelRaceTarget=21, DuelRaceTargetStep=1, DuelRaceTargetCap=30,
 DuelRaceZones=3, DuelRaceSlots=4, DuelRaceDiscards=2, DuelRaceDiscardCooldownMs=800,
 DuelRaceGrabCooldownMs=600, DuelRaceGuardMs=400, DuelRaceArbMs=180, DuelRaceTarotTimeoutMs=1500,
 DuelRaceRevealMs=150, DuelRaceTarotGood=2, DuelRaceTarotBad=2, DuelRaceArmorPerDiscard=2,
 DuelRaceArmorCap=4, DuelRaceSuddenRound=8, DuelRaceSuddenPct=150, DuelRaceTiebreak=1,
 DuelRaceMaxRounds=24, DuelRaceHealScale=20, DuelRaceBotSkill=1 })
 local limits = { PvPRoundSeconds={20,180},Target = { 15, 40 }, Slots = { 3, 7 }, Rounds = { 1, 12 },
 DuelRoseHeal={0,20},DuelGuardianShield={0,15},DuelHP={30,200},DuelRounds={3,10},DuelHealScale={0,50},DuelResolveMs={1000,8000},
 DuelRaceSeconds={10,60},DuelRaceHP={30,200},DuelRaceTarget={15,40},DuelRaceTargetStep={0,3},DuelRaceTargetCap={15,40},
 DuelRaceZones={1,5},DuelRaceSlots={2,7},DuelRaceDiscards={0,5},DuelRaceDiscardCooldownMs={0,3000},
 DuelRaceGrabCooldownMs={0,3000},DuelRaceGuardMs={0,2000},DuelRaceArbMs={0,1000},DuelRaceTarotTimeoutMs={0,10000},
 DuelRaceRevealMs={0,2000},DuelRaceTarotGood={0,10},DuelRaceTarotBad={0,10},DuelRaceArmorPerDiscard={0,10},
 DuelRaceArmorCap={0,20},DuelRaceSuddenRound={1,50},DuelRaceSuddenPct={100,300},DuelRaceTiebreak={0,1},
 DuelRaceMaxRounds={5,100},DuelRaceHealScale={0,50},DuelRaceBotSkill={0,2},
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
function Config.ForDuelRace()
 local c=Config.ForBattle()
 return {
  RoundSeconds=c.DuelRaceSeconds, HP=c.DuelRaceHP, Target=c.DuelRaceTarget,
  TargetStep=c.DuelRaceTargetStep, TargetCap=c.DuelRaceTargetCap,
  Zones=c.DuelRaceZones, Slots=c.DuelRaceSlots, Discards=c.DuelRaceDiscards,
  DiscardCooldown=c.DuelRaceDiscardCooldownMs/1000, GrabCooldown=c.DuelRaceGrabCooldownMs/1000,
  Guard=c.DuelRaceGuardMs/1000, Arbitration=c.DuelRaceArbMs/1000,
  TarotTimeout=c.DuelRaceTarotTimeoutMs/1000, RevealDelay=c.DuelRaceRevealMs/1000,
  TarotGood=c.DuelRaceTarotGood, TarotBad=c.DuelRaceTarotBad,
  ArmorPerDiscard=c.DuelRaceArmorPerDiscard, ArmorCap=c.DuelRaceArmorCap,
  SuddenRound=c.DuelRaceSuddenRound, SuddenMult=c.DuelRaceSuddenPct/100,
  Tiebreak=c.DuelRaceTiebreak==1, MaxRounds=c.DuelRaceMaxRounds,
  HealScale=c.DuelRaceHealScale/100, BotSkill=c.DuelRaceBotSkill,
 }
end
return Config
