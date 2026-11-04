local Players = game:GetService("Players")
local Http = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage"):WaitForChild("VochkoPrototype")
local storage = game:GetService("ServerStorage"):WaitForChild("VochkoPrototype")
local Config = require(storage.Config)
local Battle = require(storage.Battle)
local Duel = require(storage.Duel)
local Tarot=require(RS.Tarot)
local campaignSessions,duelSessions={},{}
local function rules(state)return if state and state.mode=="duel"then Duel else Battle end
local room = require(storage.RoomBuilder)()
local Input, Snapshot = RS:WaitForChild("Input"), RS:WaitForChild("Snapshot")
local sessions, profiles, screens, requests, buckets = {}, {}, {}, {}, {}
local talents = { sharp = true, healer = true, daring = true }
task.spawn(Config.Load)
local function profile(player)
 if not profiles[player] then profiles[player] = { talent = "sharp", deck = "classic", coins = 0, wins = 0, duelWins=0,tarot={},owned={},ach={},played=0,sleeveUses=0 } end
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
local function push(player, message, notice)
 if player.Parent ~= Players then return end
 local state = sessions[player]
 Snapshot:FireClient(player, { screen = screens[player] or "lobby", profile = table.clone(profile(player)),
  battle = if state then rules(state).View(state) else nil, preparation=if state and state.mode=="duel"then {ready=state.botPrepared==true,count=state.botLoadout and #state.botLoadout or 0}else nil, message = message, notice = notice })
end
local function open(player, mode)
 if not nearby(player, Vector3.new(0,4,0), 65) then push(player,"Подойди к комнате поединков"); return end
 if mode == "campaign" or mode=="pvp" then
  local cache=if mode=="pvp"then duelSessions else campaignSessions
  local state=cache[player]
  if not state or state.phase=="won"or state.phase=="lost"or state.phase=="draw"then
   local engine=if mode=="pvp"then Duel else Battle
   state=engine.New(Config.ForBattle(),Random.new():NextInteger(1,1000000000),profile(player).talent,Http:GenerateGUID(false),profile(player).tarot)
   state.phase="intro";cache[player]=state
   if mode=="pvp"then
    local preparing=state
    task.delay(2,function()
     if player.Parent==Players and duelSessions[player]==preparing then
      preparing.botLoadout=Duel.ChooseTarot((preparing.seed+7919)%1000000000);preparing.botPrepared=true
      if sessions[player]==preparing and screens[player]=="duelsetup"then push(player)end
     end
    end)
   end
  end
  sessions[player]=state
  screens[player] = if state.phase == "intro" then (if mode=="pvp"then "duelsetup"else "intro")else "battle"
  push(player)
 elseif mode == "wardrobe" then screens[player] = "wardrobe"; push(player)
 elseif mode == "endless" then
  screens[player] = "notice"; push(player,nil,{ title = if mode == "pvp" then "Дуэль" else "Бесконечный поход",
   body = if mode == "pvp" then "Этот стол предназначен для боя с другим игроком. Подбор и отдельный баланс PvP появятся после проверки основного боя."
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
 if kind == "open" then
  if data.mode == "campaign" or data.mode == "wardrobe" or data.mode == "pvp" or data.mode == "endless" then open(player,data.mode) end
  return
 elseif kind == "return" then screens[player] = "lobby"; push(player); return
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
 elseif kind == "talent" then
  local active = sessions[player]
  if active and active.phase ~= "won" and active.phase ~= "lost" and active.phase~="draw"then push(player,"Заверши текущий бой перед сменой таланта"); return end
  if type(data.talent) == "string" and talents[data.talent] then profile(player).talent = data.talent; push(player,"Талант выбран") end
  return
 end
 local state = sessions[player]
 if not state or data.sessionId ~= state.id then push(player,"Сессия боя изменилась"); return end
 if kind == "begin" then
  if state.phase == "intro" then if state.mode=="duel"then
   if not state.botPrepared then push(player,"Соперник ещё выбирает таро");return end
   local prepared=state
   state=Duel.New(prepared.config,prepared.seed,profile(player).talent,prepared.id,profile(player).tarot,prepared.botLoadout)
   state.botLoadout=prepared.botLoadout;state.botPrepared=true
   sessions[player]=state;duelSessions[player]=state;Duel.Begin(state)
  else state.phase="combat";state.revision+=1 end;screens[player]="battle"end
  push(player); return
 end
 if screens[player] ~= "battle" then return end
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
  local root = character:WaitForChild("HumanoidRootPart",10)
  if root then character:PivotTo(CFrame.new(room:GetAttribute("SpawnPosition"))) end
 end
 player.CharacterAdded:Connect(spawned)
 if player.Character then task.spawn(spawned,player.Character) end
end
Players.PlayerAdded:Connect(added)
for _, player in Players:GetPlayers() do task.spawn(added,player) end
Players.PlayerRemoving:Connect(function(player)
 sessions[player]=nil;campaignSessions[player]=nil;duelSessions[player]=nil;profiles[player]=nil;screens[player]=nil;requests[player]=nil;buckets[player]=nil
end)
-- Read-only inspection in Studio; never exposed to clients or published servers.
if game:GetService("RunService"):IsStudio() then
 local debug = Instance.new("BindableFunction");debug.Name="StudioReadOnly";debug.Parent=storage
 debug.OnInvoke=function(player)
  local state=sessions[player]
  return {screen=screens[player],profile=table.clone(profile(player)),battle=if state then rules(state).View(state)else nil,
   requestId=requests[player],hiddenCards=if state then (if state.mode=="duel"then #state.player.deck else #state.deck)else 0}
 end
end

-- Advance one visible AI action at a time, independently of player input.
task.spawn(function()
 while true do
  task.wait(.65)
  for player,state in duelSessions do
   if player.Parent==Players and state.phase=="combat"and not state.botReady then
    Duel.StepBot(state)
    if sessions[player]==state and screens[player]=="battle"then push(player)end
   end
  end
 end
end)
