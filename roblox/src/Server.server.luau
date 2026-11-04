local Players = game:GetService("Players")
local Http = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage"):WaitForChild("VochkoPrototype")
local storage = game:GetService("ServerStorage"):WaitForChild("VochkoPrototype")
local Config = require(storage.Config)
local Battle = require(storage.Battle)
local room = require(storage.RoomBuilder)()
local Input, Snapshot = RS:WaitForChild("Input"), RS:WaitForChild("Snapshot")
local sessions, profiles, screens, requests, buckets = {}, {}, {}, {}, {}
local talents = { sharp = true, healer = true, daring = true }
task.spawn(Config.Load)
local function profile(player)
 if not profiles[player] then profiles[player] = { talent = "sharp", deck = "classic", coins = 0, wins = 0 } end
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
  battle = if state then Battle.View(state) else nil, message = message, notice = notice })
end
local function open(player, mode)
 if not nearby(player, Vector3.new(0,4,0), 65) then push(player,"Подойди к комнате поединков"); return end
 if mode == "campaign" then
  local state = sessions[player]
  if not state or state.phase == "won" or state.phase == "lost" then
   state = Battle.New(Config.ForBattle(), Random.new():NextInteger(1, 1000000000), profile(player).talent, Http:GenerateGUID(false))
   state.phase = "intro"; sessions[player] = state
  end
  screens[player] = if state.phase == "intro" then "intro" else "battle"
  push(player)
 elseif mode == "wardrobe" then screens[player] = "wardrobe"; push(player)
 elseif mode == "pvp" or mode == "endless" then
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
 elseif kind == "talent" then
  local active = sessions[player]
  if active and active.phase ~= "won" and active.phase ~= "lost" then push(player,"Заверши текущий бой перед сменой таланта"); return end
  if type(data.talent) == "string" and talents[data.talent] then profile(player).talent = data.talent; push(player,"Талант выбран") end
  return
 end
 local state = sessions[player]
 if not state or data.sessionId ~= state.id then push(player,"Сессия боя изменилась"); return end
 if kind == "begin" then
  if state.phase == "intro" then state.phase = "combat"; state.revision += 1; screens[player] = "battle" end
  push(player); return
 end
 if screens[player] ~= "battle" then return end
 local ok, message = false, "Недоступное действие"
 if kind == "draw" then ok,message = Battle.Draw(state)
 elseif kind == "stop" then ok,message = Battle.Stop(state)
 elseif kind == "consume" then ok,message = Battle.Consume(state,data.item,data.zone)
 elseif kind == "play" then ok,message = Battle.Play(state) end
 if ok and kind == "play" and state.phase == "won" and not state.rewardGranted then
  state.rewardGranted = true; local p = profile(player); p.coins += state.config.WinCoins; p.wins += 1
 end
 push(player, if ok then nil else message)
 if ok and kind == "play" and state.phase == "resolving" then
  task.delay(state.config.ResolveSeconds,function()
   if sessions[player] == state and player.Parent == Players then Battle.Next(state); push(player) end
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
 sessions[player]=nil;profiles[player]=nil;screens[player]=nil;requests[player]=nil;buckets[player]=nil
end)
-- Read-only inspection in Studio; never exposed to clients or published servers.
if game:GetService("RunService"):IsStudio() then
 local debug = Instance.new("BindableFunction");debug.Name="StudioReadOnly";debug.Parent=storage
 debug.OnInvoke=function(player)
  local state=sessions[player]
  return {screen=screens[player],profile=table.clone(profile(player)),battle=if state then Battle.View(state)else nil,
   requestId=requests[player],hiddenCards=if state then #state.deck else 0}
 end
end
