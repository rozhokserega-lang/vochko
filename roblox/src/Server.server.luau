local Players = game:GetService("Players")
local Http = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage"):WaitForChild("VochkoPrototype")
local storage = game:GetService("ServerStorage"):WaitForChild("VochkoPrototype")
local Config = require(storage.Config)
local Battle = require(storage.Battle)
local Duel = require(storage.Duel)
local SharedDuel = require(storage.SharedDuel)
local RaceBot = require(storage.RaceBot)
local Tarot=require(RS.Tarot)
local Loadout=require(RS.Loadout)
local Seating=require(storage.Seating)
local NetworkDuel=require(storage.NetworkDuel)
local network
local campaignSessions,duelSessions={},{}
local function rules(state)return if state and state.mode=="duel"then Duel else Battle end
local room = require(storage.RoomBuilder)()
local Input, Snapshot = RS:WaitForChild("Input"), RS:WaitForChild("Snapshot")
local sessions, profiles, screens, requests, buckets = {}, {}, {}, {}, {}
local talents = { sharp = true, healer = true, daring = true }
task.spawn(Config.Load)
local function profile(player)
 if not profiles[player] then profiles[player] = { class="sharp",jokers={"crimson","blot"},duelTarot={"rose","guardian","sun"},raceTarot=Loadout.DefaultRaceTarot(Random.new():NextInteger(1,1000000000)),raceSeed=Random.new():NextInteger(1,1000000000),talent = "sharp", deck = "classic", coins = 0, wins = 0, duelWins=0,tarot={},owned={},ach={},played=0,sleeveUses=0 } end
 return profiles[player]
end
local function allowed(player)
 local now = os.clock(); local bucket = buckets[player]
 if not bucket then bucket = { tokens = Config.Defaults.RequestBurst, at = now }; buckets[player] = bucket end
 bucket.tokens = math.min(Config.Defaults.RequestBurst, bucket.tokens + (now - bucket.at) * Config.Defaults.RequestsPerSecond); bucket.at = now
 if bucket.tokens < 1 then return false end; bucket.tokens -= 1; return true
end
local function nearby(player, position, range)
 local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 return root and (root.Position - position).Magnitude <= range
end
local function raceView(state)
 local view=SharedDuel.View(state,1,workspace:GetServerTimeNow())
 view.network=false;view.seatIndex=1;view.enemyName="Тренировочный ИИ"
 view.enemyAttack=0;view.ready=true
 view.duel.opponentKind="bot";view.duel.enemyReady=true
 if state.phase=="round"then view.phase="combat"elseif state.phase=="resolving"then view.phase="resolving"elseif state.phase=="idle"then view.phase="intro"end
 return view
end
local function push(player, message, notice)
 if player.Parent ~= Players then return end
 local state = sessions[player]
 local cachedDuel=duelSessions[player]
 local racing=cachedDuel and cachedDuel.mode=="race"
 local locked=cachedDuel and cachedDuel.phase~="intro"and cachedDuel.phase~="idle"and cachedDuel.phase~="won"and cachedDuel.phase~="lost"and cachedDuel.phase~="draw"
 local net=network and network:View(player)
 if net then
  net.profile=table.clone(profile(player));net.message=message;Snapshot:FireClient(player,net);return
 end
 local battle=nil
 if state then
  if state.mode=="race"and state.seats then battle=raceView(state)else battle=rules(state).View(state)end
 end
 local preparation=nil
 if state and state.mode=="duel"then preparation={ready=state.botPrepared==true,count=state.botLoadout and #state.botLoadout or 0}
 elseif racing then preparation={ready=true,count=#(profile(player).raceTarot or {})}end
 Snapshot:FireClient(player, { screen = screens[player] or "lobby", profile = table.clone(profile(player)),
  loadoutLocked=locked==true,
  battle = battle, preparation=preparation, message = message, notice = notice })
end
network=NetworkDuel.new({profile=profile,push=push,config=Config.ForDuelRace,id=function()return Http:GenerateGUID(false)end,now=function()return workspace:GetServerTimeNow()end,
 sit=function(p,i)local ok,why=Seating.Enter(p,'pvp',i);if ok then screens[p]='pvp'end;return ok,why end,
 leave=function(p)Seating.Leave(p);screens[p]='lobby'end,
 chairs={room.Table_pvp.PvPSeat1,room.Table_pvp.PvPSeat2}})
for i,seat in network.ctx.chairs do seat.PvPSeatPrompt.Triggered:Connect(function(player)
 if not allowed(player)or not nearby(player,seat.Position,12)then return end
 local ok,why=network:Join(player,i);if not ok then push(player,why)end
end)end
local function open(player, mode)
 if not nearby(player, Vector3.new(0,4,0), 65) then push(player,"Подойди к комнате поединков"); return end
 if mode == "campaign" or mode=="training" then
  local cache=if mode=="training"then duelSessions else campaignSessions
  local state=cache[player]
  local finished=state and (state.phase=="won"or state.phase=="lost"or state.phase=="draw"or state.phase=="finished")
  if not state or finished then
   if mode=="training"then
    local p=profile(player);local seed=Random.new():NextInteger(1,1000000000)
    local playerBuild={class=p.class,jokers=table.clone(p.jokers),tarot=table.clone(p.raceTarot or Loadout.DefaultRaceTarot(seed)),id="player"}
    local botBuild=RaceBot.Build((seed+7919)%1000000000)
    state=SharedDuel.New(Config.ForDuelRace(),seed,{playerBuild,botBuild},{id=Http:GenerateGUID(false)})
    state.mode="race";state.training=true;state.trainingSeed=seed;state.botBuild=botBuild;state.botNextAt=0
   else
    state=Battle.New(Config.ForBattle(),Random.new():NextInteger(1,1000000000),profile(player).talent,Http:GenerateGUID(false),profile(player).tarot)
    state.phase="intro"
   end
   cache[player]=state
  end
  sessions[player]=state
  if mode=="training"then screens[player]=if state.phase=="idle"or state.phase=="intro"then "duelsetup"else "battle"
  else screens[player]=if state.phase=="intro"then "intro"else "battle"end
  if screens[player]=="battle"then local ok,why=Seating.Enter(player,if state.mode=="race"then "duel"else state.mode);if not ok then screens[player]="lobby";push(player,why);return end else Seating.Leave(player)end
  push(player)
 elseif mode == "wardrobe" then Seating.Leave(player);screens[player] = "wardrobe"; push(player)
 elseif mode == "pvp" then
  Seating.Leave(player);screens[player]="notice"
  push(player,nil,{title="PvP · садись на стул",body="Подойди к любому подсвеченному стулу центрального стола и нажми «Сесть». Второй игрок садится напротив — дуэль начнётся автоматически. Сборку выбери заранее в шкафу."})
 elseif mode == "endless" then
  screens[player] = "notice"; push(player,nil,{ title = if mode == "training" then "Дуэль" else "Бесконечный поход",
   body = if mode == "training" then "Этот стол предназначен для боя с другим игроком. Подбор и отдельный баланс PvP появятся после проверки основного боя."
    else "Здесь начнётся поход с растущей сложностью и рекордами. В первой сборке доступен бой у стола кампании." })
 end
end
for _, prompt in room:GetDescendants() do
 if prompt:IsA("ProximityPrompt") and prompt.Name == "VochkoPrompt" then
  prompt.Triggered:Connect(function(player)
   if allowed(player) and nearby(player,prompt.Parent.Position,15) then open(player,prompt.Parent:GetAttribute("VochkoMode")) end
  end)
 end
end
Input.OnServerEvent:Connect(function(player, data)
 if type(data) ~= "table" or not allowed(player) then return end
 local kind = data.kind
 if type(kind) ~= "string" or #kind > 20 then return end
 if kind == "snapshot" then push(player); return end
 local rid = data.requestId
 if type(rid) ~= "number" or rid ~= rid or rid % 1 ~= 0 or rid < 1 or rid > 1000000000 then return end
 if rid <= (requests[player] or 0) then push(player); return end
 requests[player] = rid
 if network:Action(player,data)then return end
 if kind == "open" then
  if data.mode == "campaign" or data.mode == "wardrobe" or data.mode == "training" or data.mode == "pvp" or data.mode == "endless" then open(player,data.mode) end
  return
 elseif kind == "return" then Seating.Leave(player);screens[player] = "lobby"; push(player); return
 elseif kind=="tarot"or kind=="buyTarot"then
  local p=profile(player);local d=type(data.item)=="string"and Tarot.Def(data.item)
  if not d then return end
  if kind=="buyTarot"then
   if not Tarot.Unlocked(p,d)and d.price and p.coins>=d.price then p.coins-=d.price;p.owned[d.id]=true end
  elseif Tarot.Unlocked(p,d)then
   local index=table.find(p.tarot,d.id)
   if index then table.remove(p.tarot,index)elseif #p.tarot<4 then table.insert(p.tarot,d.id)else push(player,"Можно выбрать до четырёх разных таро");return end
  end
  push(player);return
 elseif kind=="buildClass"or kind=="buildJoker"or kind=="buildTarot"then
  local active=duelSessions[player]
  local editingRace=active and active.mode=="race"and active.phase=="idle"
  if active and not editingRace and active.phase~="intro"and active.phase~="won"and active.phase~="lost"and active.phase~="draw"then push(player,"Сборка уже зафиксирована до конца дуэли");return end
  local p=profile(player);local id=data.item
  if type(id)~="string"then return end
  if kind=="buildClass"then if Loadout.Class(id)then p.class=id end
  elseif kind=="buildJoker"then
   if not Loadout.Joker(id)then return end
   local list=p.jokers;local index=table.find(list,id)
   if index then table.remove(list,index)elseif #list<2 then table.insert(list,id)else push(player,"Сначала убери одного джокера");return end
  else
   if editingRace then
    local list=p.raceTarot or Loadout.DefaultRaceTarot(p.raceSeed or 1);p.raceTarot=list
    local def=Loadout.RaceTarotDef(id);if not def then return end
    local index=table.find(list,id)
    if index then table.remove(list,index)
    else
     local good,bad=0,0
     for _,other in list do local d=Loadout.RaceTarotDef(other);if d then if d.good then good+=1 else bad+=1 end end end
     if def.good and good>=Loadout.RaceTarotGood then push(player,"Можно выбрать только "..Loadout.RaceTarotGood.." хороших таро");return end
     if not def.good and bad>=Loadout.RaceTarotBad then push(player,"Можно выбрать только "..Loadout.RaceTarotBad.." плохих таро");return end
     if #list>=Loadout.RaceTarotGood+Loadout.RaceTarotBad then push(player,"Сначала убери одно таро");return end
     table.insert(list,id)
    end
   else
    local list=p.duelTarot;local limit=3;local valid=table.find(Loadout.TarotIds,id)
    if not valid then return end
    local index=table.find(list,id)
    if index then table.remove(list,index)elseif #list<limit then table.insert(list,id)else push(player,"Сначала убери один выбранный предмет");return end
   end
  end
  push(player);return
 elseif kind == "talent" then
  local active = sessions[player]
  if active and active.phase ~= "won" and active.phase ~= "lost" and active.phase~="draw"then push(player,"Заверши текущий бой перед сменой таланта"); return end
  if type(data.talent) == "string" and talents[data.talent] then profile(player).talent = data.talent; push(player,"Талант выбран") end
  return
 end
 local state = sessions[player]
 if not state or data.sessionId ~= state.id then push(player,"Сессия боя изменилась"); return end
 if kind == "begin" then
  if state.mode=="race"and state.phase=="idle"then
   local p=profile(player);local valid,why=Loadout.ValidateRace(p.class,p.jokers,p.raceTarot)
   if not valid then push(player,why);return end
   local seated,why=Seating.Enter(player,"duel");if not seated then push(player,why);return end
   local seed=state.trainingSeed or Random.new():NextInteger(1,1000000000)
   local playerBuild={class=p.class,jokers=table.clone(p.jokers),tarot=table.clone(p.raceTarot),id="player"}
   local botBuild=state.botBuild or RaceBot.Build((seed+7919)%1000000000)
   local fresh=SharedDuel.New(Config.ForDuelRace(),seed,{playerBuild,botBuild},{id=state.id})
   fresh.mode="race";fresh.training=true;fresh.trainingSeed=seed;fresh.botBuild=botBuild;fresh.botNextAt=0
   sessions[player]=fresh;duelSessions[player]=fresh;screens[player]="battle"
   SharedDuel.Begin(fresh,workspace:GetServerTimeNow())
   push(player);return
  end
  if state.phase == "intro" then if state.mode=="duel"then
   if not state.botPrepared then push(player,"Соперник ещё выбирает таро");return end
   local p=profile(player);local valid,why=Loadout.Validate(p.class,p.jokers,p.duelTarot)
   if not valid then push(player,why);return end
   local prepared=state
   local seated,why=Seating.Enter(player,"duel");if not seated then push(player,why);return end
   state=Duel.New(prepared.config,prepared.seed,p.class,prepared.id,p.duelTarot,prepared.botLoadout,p.jokers,Duel.ChooseBuild((prepared.seed+271)%1000000000))
   state.botLoadout=prepared.botLoadout;state.botPrepared=true
   sessions[player]=state;duelSessions[player]=state;Duel.Begin(state)
  else local seated,why=Seating.Enter(player,"campaign");if not seated then push(player,why);return end;state.phase="combat";state.revision+=1 end;screens[player]="battle"end
  push(player); return
 end
 if screens[player] ~= "battle" then return end
 if state.mode=="race"then
  local ok,message=false,"Недоступное действие"
  local now=workspace:GetServerTimeNow()
  if kind=="grab"or kind=="draw"then ok,message=SharedDuel.Grab(state,1,now)
  elseif kind=="discard"then ok,message=SharedDuel.Discard(state,1,now)
  elseif kind=="stand"or kind=="stop"then ok,message=SharedDuel.Stand(state,1,now)
  elseif kind=="play"then push(player,"В реальном времени карту берут кнопкой «Взять»");return
  end
  push(player,if ok then nil else message);return
 end
 local ok, message = false, "Недоступное действие"
 if kind == "draw" then ok,message = rules(state).Draw(state)
 elseif kind == "stop" then ok,message = rules(state).Stop(state)
 elseif kind == "consume" then ok,message = rules(state).Consume(state,data.item,data.zone)
 elseif kind == "play" then ok,message = rules(state).Play(state) end
 if ok and kind=="consume"and data.item=="hide"then
  local p=profile(player);p.sleeveUses+=1;if p.sleeveUses>=3 then p.ach.sleeve=true end
 end
 if ok and kind=="play"then
  local p=profile(player);p.played+=1;if p.played>=5 then p.ach.scout=true end
  local side=if state.mode=="duel"then state.player else state
  local exact=0;for _,z in side.zones do if Battle.Zone(z,side.config.Target).exact then exact+=1 end end
  if exact==3 then p.ach.exact3=true end
  local money=side.money or 0;p.coins+=money-(side.moneyPaid or 0);side.moneyPaid=money
  if state.phase=="won"and state.roundsLeft==0 then p.ach.last=true end
 end
 if ok and kind == "play" and state.phase == "won" and not state.rewardGranted then
  state.rewardGranted = true; local p=profile(player);if state.mode=="duel"then p.duelWins+=1 else p.coins+=state.config.WinCoins;p.wins+=1 end
 end
 push(player, if ok then nil else message)
 if ok and kind == "play" and state.phase == "resolving" then
  task.delay(state.config.ResolveSeconds,function()
   if player.Parent==Players and (campaignSessions[player]==state or duelSessions[player]==state)then rules(state).Next(state);if sessions[player]==state then push(player)end end
  end)
 end
end)
local function added(player)
 profile(player); screens[player] = "lobby"
 local function spawned(character)
  if network.members[player]then network:Leave(player);push(player)end
  local root = character:WaitForChild("HumanoidRootPart",10)
  if root then character:PivotTo(CFrame.new(room:GetAttribute("SpawnPosition"))) end
  local state=sessions[player]
  if state and screens[player]=="battle"then task.wait(.2);Seating.Enter(player,if state.mode=="race"then "duel"else state.mode)end
 end
 player.CharacterAdded:Connect(spawned)
 if player.Character then task.spawn(spawned,player.Character) end
end
Players.PlayerAdded:Connect(added)
for _, player in Players:GetPlayers() do task.spawn(added,player) end
Players.PlayerRemoving:Connect(function(player)
 network:Leave(player)
 Seating.Leave(player)
 sessions[player]=nil;campaignSessions[player]=nil;duelSessions[player]=nil;profiles[player]=nil;screens[player]=nil;requests[player]=nil;buckets[player]=nil
end)
-- Read-only inspection in Studio; never exposed to clients or published servers.
if game:GetService("RunService"):IsStudio() then
 local debug = Instance.new("BindableFunction");debug.Name="StudioReadOnly";debug.Parent=storage
 debug.OnInvoke=function(player)
  local net=network:View(player)
  if net then return net end
  local state=sessions[player]
  local battle=nil
  if state then if state.mode=="race"and state.seats then battle=raceView(state)else battle=rules(state).View(state)end end
  return {screen=screens[player],profile=table.clone(profile(player)),battle=battle,
   requestId=requests[player],hiddenCards=if state then (if state.mode=="duel"then #state.player.deck elseif state.mode=="race"then #state.deck else #state.deck)else 0}
 end
end

-- Real-time race training and the legacy turn-based duel share this clock.
task.spawn(function()
 local duelAccum=0
 while true do
  task.wait(.05)
  network:Tick()
  local now=workspace:GetServerTimeNow()
  duelAccum+=.05
  local oldStep=duelAccum>=.65
  if oldStep then duelAccum=0 end
  for player,state in duelSessions do
   if player.Parent==Players then
    if state.mode=="race"then
     local changed=false
     if state.phase=="round"then
      local before=state.revision
      SharedDuel.Tick(state,now)
      if state.phase=="round"then RaceBot.Step(state,now)end
      changed=state.revision~=before
     end
     if state.phase=="resolving"and now>=state.resolvedAt+(state.config.ResolveDelay or 2.4)then
      SharedDuel.NextRound(state,now);changed=true
     end
     if state.phase=="finished"and not state.finishedPushed then state.finishedPushed=true;changed=true end
     if sessions[player]==state and screens[player]=="battle"then
      if changed or now-(state.lastPush or 0)>=.1 then state.lastPush=now;push(player)end
     end
    elseif oldStep and state.phase=="combat"and not state.botReady then
     Duel.StepBot(state)
     if sessions[player]==state and screens[player]=="battle"then push(player)end
    end
   end
  end
 end
end)
