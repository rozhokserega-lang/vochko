local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer
local remote = game:GetService("ReplicatedStorage"):WaitForChild("VochkoPrototype")
local Tarot=require(remote:WaitForChild("Tarot"))
local Assets = require(remote:WaitForChild("Assets"))
local TableScene = require(remote:WaitForChild("TableScene"))
local CameraControls = require(remote:WaitForChild("CameraControls"))
local Inventory=require(remote:WaitForChild("Inventory"))
local Loadout=require(remote:WaitForChild("Loadout"))
local cameraControls
local Input, Snapshot = remote:WaitForChild("Input"), remote:WaitForChild("Snapshot")
local C = { ink=Color3.fromRGB(9,25,16), green=Color3.fromRGB(22,57,37), brass=Color3.fromRGB(183,147,78),
 paper=Color3.fromRGB(233,214,167), muted=Color3.fromRGB(172,189,156), red=Color3.fromRGB(128,46,36) }
local function make(class,props,parent)
 local item=Instance.new(class);for key,value in props do item[key]=value end;item.Parent=parent;return item
end
local gui=make("ScreenGui",{Name="VochkoPrototypeUI",ResetOnSpawn=false,DisplayOrder=20,ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets,ClipToDeviceSafeArea=true},player:WaitForChild("PlayerGui"))
local root=make("Frame",{Name="Root",Size=UDim2.fromScale(1,1),BackgroundTransparency=1},gui)
local app=make("Frame",{Name="App",AnchorPoint=Vector2.new(.5,0),Position=UDim2.fromScale(.5,0),Size=UDim2.fromScale(1,1),BackgroundColor3=C.ink,Visible=false},root)
make("UISizeConstraint",{MaxSize=Vector2.new(640,1600)},app)
local lobby=make("Frame",{Name="Lobby",Size=UDim2.fromScale(1,1),BackgroundTransparency=1},root)
local function stroke(item,color,thickness) make("UIStroke",{Color=color or C.brass,Thickness=thickness or 1,Transparency=.2},item) end
local function text(parent,name,content,size,pos,dim,color)
 return make("TextLabel",{Name=name,Text=content,TextSize=size or 16,Font=Enum.Font.Garamond,TextColor3=color or C.paper,
  BackgroundTransparency=1,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,Position=pos or UDim2.new(),Size=dim or UDim2.fromScale(1,1)},parent)
end
local function button(parent,name,content,pos,size,callback,color)
 local b=make("TextButton",{Name=name,Text=content,TextSize=17,Font=Enum.Font.Garamond,TextColor3=C.paper,
  Position=pos,Size=size,BackgroundColor3=color or C.green,BorderSizePixel=0,AutoButtonColor=true},parent)
 stroke(b);b:SetAttribute("Enabled",true)
 b.Activated:Connect(function()if b:GetAttribute("Enabled") then callback() end end);return b
end
local function enabled(b,value)
 b:SetAttribute("Enabled",value);b.Active=value;b.AutoButtonColor=value;b.TextTransparency=if value then 0 else .55;b.BackgroundTransparency=if value then 0 else .45
end
local sequence,current,selectedItem,battleUI,screenKey=0,nil,nil,nil,nil
local function send(kind,extra)
 sequence+=1;local data=extra or {};data.kind=kind;data.requestId=sequence
 if current and current.battle then data.sessionId=current.battle.id end
 Input:FireServer(data)
end
local function atlas(parent,name,card,pos,size)
 return make("ImageLabel",{Name=name,Image=Assets.Cards,ImageRectOffset=Vector2.new((card.rankIndex-1)*Assets.CardWidth,(card.suitIndex-1)*Assets.CardHeight),
  ImageRectSize=Vector2.new(Assets.CardWidth,Assets.CardHeight),BackgroundTransparency=1,Position=pos,Size=size,ScaleType=Enum.ScaleType.Stretch},parent)
end
local toast=text(root,"Toast","",16,UDim2.new(.5,-150,.7,0),UDim2.fromOffset(300,48));toast.BackgroundColor3=C.green;toast.BackgroundTransparency=.05;toast.Visible=false;toast.ZIndex=30
local toastVersion=0
local function message(value)
 if not value or value=="" then return end;toastVersion+=1;local version=toastVersion;toast.Text=value;toast.Visible=true
 task.delay(2.2,function()if toastVersion==version then toast.Visible=false end end)
end
local controls
task.spawn(function()local module=player.PlayerScripts:WaitForChild("PlayerModule",10);if module then local ok,value=pcall(function()return require(module):GetControls()end);if ok then controls=value end end end)
local function cameraFor(screen)
 local camera=workspace.CurrentCamera;if not camera then return end
 if screen=="lobby" then
  TableScene.Destroy();camera.FieldOfView=70
  camera.CameraType=Enum.CameraType.Custom
  local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid");if humanoid then camera.CameraSubject=humanoid end
  if controls then controls:Enable() end
 elseif screen=="battle" then
  TableScene.Camera(root.AbsoluteSize,true)
  if controls then controls:Disable() end
 else
  TableScene.Destroy()
  camera.CameraType=Enum.CameraType.Scriptable;camera.CFrame=if screen=="wardrobe"then CFrame.lookAt(Vector3.new(-23,7,4),Vector3.new(-23,6,15))else CFrame.lookAt(Vector3.new(19,12,3),Vector3.new(19,4,-7))
  if controls then controls:Disable() end
 end
end
local function clearApp()
 if cameraControls then cameraControls:Destroy();cameraControls=nil end
 for _,child in app:GetChildren() do if not child:IsA("UISizeConstraint") then child:Destroy() end end
 battleUI=nil
 TableScene.Destroy()
end
local function scrollBody(bottom)
 local scroll=make("ScrollingFrame",{Name="Body",Size=UDim2.new(1,0,1,-bottom),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,
  ScrollingDirection=Enum.ScrollingDirection.Y,BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=C.brass},app)
 local body=make("Frame",{Name="Content",Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1},scroll)
 return body,scroll
end
local function header(parent,title)
 text(parent,"PageTitle",title,25,UDim2.fromOffset(12,6),UDim2.new(1,-118,0,42))
 button(parent,"Return","В комнату",UDim2.new(1,-102,0,6),UDim2.fromOffset(90,40),function()send("return")end)
end
local function actionDock(callback,label)
 local dock=make("Frame",{Name="Dock",AnchorPoint=Vector2.new(0,1),Position=UDim2.fromScale(0,1),Size=UDim2.new(1,0,0,72),BackgroundColor3=C.ink,BorderSizePixel=0},app)
 stroke(dock)
 button(dock,"Primary",label,UDim2.new(0,12,0,10),UDim2.new(1,-24,0,49),callback,C.red)
 return dock
end
local function simpleNotice(data)
 local body=scrollBody(72);header(body,"ВОЧКО")
 text(body,"NoticeTitle",data.notice and data.notice.title or "Комната поединков",30,UDim2.fromOffset(20,90),UDim2.new(1,-40,0,80))
 text(body,"NoticeBody",data.notice and data.notice.body or "",19,UDim2.fromOffset(20,180),UDim2.new(1,-40,0,190),C.muted)
 actionDock(function()send("return")end,"Вернуться в комнату")
end
local function intro(data)
 local s=data.battle;local body=scrollBody(72);header(body,if s.mode=="duel"then "ДУЭЛЬ · ТРЕНИРОВКА С ИИ"else "ТЕМНИЦА · ПЕРВЫЙ БОЙ")
 make("ImageLabel",{Name="Opponent",Image=Assets.Portraits,ImageRectSize=Vector2.new(200,200),ImageRectOffset=Vector2.new(0,0),BackgroundTransparency=1,
  AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,60),Size=UDim2.fromOffset(250,250)},body)
 text(body,"EnemyTitle",s.enemyName,31,UDim2.fromOffset(18,316),UDim2.new(1,-36,0,40))
 text(body,"EnemyStats",string.format("Здоровье: %d  ·  Атака: %d\nЦель: %d  ·  Мест на зоне: %d\nРозыгрышей на бой: %d",s.enemyMaxHp,s.enemyAttack,s.target,s.slots,s.roundsTotal),20,UDim2.fromOffset(18,365),UDim2.new(1,-36,0,105),C.muted)
 text(body,"Hint",if s.mode=="duel"then "У каждой стороны своя колода. ИИ набирает карты на твоих глазах: видны суммы, остановки и переборы. Цель растёт каждый раунд: 21, 22, 23… Удары одновременные; после восьми раундов сравнивается здоровье."else "Добирай карты к цели. Точное попадание усиливает удар. Перебор можно исправить срезом до розыгрыша.",17,UDim2.fromOffset(18,480),UDim2.new(1,-36,0,90))
 actionDock(function()send("begin")end,"ВОЙТИ В БОЙ")
end
local function wardrobe(data,duelSetup)Inventory.Build(app,data,duelSetup,send)end
local function result(data)
 local s=data.battle;local body=scrollBody(72);header(body,"ВОЧКО · ИТОГ БОЯ")
 text(body,"ResultTitle",if s.phase=="won"then "Противник повержен"elseif s.phase=="draw"then "Ничья"elseif s.mode=="duel"then "Дуэль проиграна"else "Побег прервался",32,UDim2.fromOffset(20,98),UDim2.new(1,-40,0,80))
 local desc=if s.phase=="won" then "За победу: +4 монеты\nПобед в этой сессии: "..data.profile.wins else "Не хватило "..(if s.hp<=0 then "здоровья." else "розыгрышей.").."\nПопробуй другую стратегию или талант."
 if s.mode=="duel"then desc="Тренировочная дуэль с ИИ\nЗдоровье: "..s.hp.." : "..s.enemyHp.."\nПобед над ИИ: "..(data.profile.duelWins or 0)end
 text(body,"ResultStats",desc.."\nМонеты этой сессии: "..data.profile.coins,21,UDim2.fromOffset(20,190),UDim2.new(1,-40,0,120),C.muted)
 text(body,"JournalTitle","Журнал боя",24,UDim2.fromOffset(20,330),UDim2.new(1,-40,0,35))
 text(body,"Journal",table.concat(s.journal,"\n"),16,UDim2.fromOffset(20,372),UDim2.new(1,-40,0,150),C.muted)
 actionDock(function()send("open",{mode=if s.mode=="duel"then "pvp"else "campaign"})end,"НОВАЯ ПОПЫТКА")
end
local function buildBattle(s)
 app.BackgroundTransparency=1
 TableScene.Create(player:WaitForChild("PlayerGui"),send,s.mode=="duel")
 local top=make("Frame",{Name="BattleHUD",Size=UDim2.new(1,0,0,150),BackgroundTransparency=1},app)
 local title=text(top,"Title",if s.mode=="duel"then "ВОЧКО / ДУЭЛЬ С ИИ"else "ВОЧКО / ТЕМНИЦА",20,UDim2.fromOffset(16,7),UDim2.new(.55,0,0,30));title.TextStrokeTransparency=.5
 local returnButton=button(top,"Return","В комнату",UDim2.new(1,-116,0,7),UDim2.fromOffset(104,32),function()send("return")end);returnButton.TextSize=15
 local function panel(name,x,w)
  local p=make("Frame",{Name=name,Position=UDim2.new(x,if x==0 then 16 else -16,0,50),AnchorPoint=Vector2.new(x,0),Size=UDim2.new(w,0,0,88),BackgroundColor3=C.ink,BackgroundTransparency=.12,BorderSizePixel=0},top)
  make("UICorner",{CornerRadius=UDim.new(0,9)},p);stroke(p)
  return p
 end
 local own=panel("Player",0,.24)
 local playerName=text(own,"Name",player.DisplayName,18,UDim2.fromOffset(10,4),UDim2.new(1,-20,0,24))
 local hp=text(own,"HP","",21,UDim2.fromOffset(10,31),UDim2.new(1,-20,0,24),Color3.fromRGB(177,216,146))
 local track=make("Frame",{Position=UDim2.fromOffset(10,64),Size=UDim2.new(1,-20,0,8),BackgroundColor3=C.green,BorderSizePixel=0},own)
 local hpFill=make("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(102,177,93),BorderSizePixel=0},track)
 local enemy=panel("Enemy",1,.29)
 local name=text(enemy,"Name","КРЫСОЛОВ",20,UDim2.fromOffset(10,3),UDim2.new(1,-20,0,23))
 local enemyHP=text(enemy,"HP","",18,UDim2.fromOffset(10,28),UDim2.new(1,-20,0,23),Color3.fromRGB(234,162,138))
 local enemyTrack=make("Frame",{Position=UDim2.fromOffset(10,51),Size=UDim2.new(1,-20,0,6),BackgroundColor3=C.green,BorderSizePixel=0},enemy)
 local enemyFill=make("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=C.red,BorderSizePixel=0},enemyTrack)
 local intent=text(enemy,"Intent","",15,UDim2.fromOffset(10,57),UDim2.new(1,-20,0,24),C.muted)
 local armorColor=Color3.fromRGB(103,196,218)
 local ownArmor=text(own,"Armor","◇ Броня 0",15,UDim2.fromOffset(10,82),UDim2.new(1,-20,0,20),armorColor)
 local ownArmorTrack=make("Frame",{Name="ArmorTrack",Position=UDim2.fromOffset(10,105),Size=UDim2.new(1,-20,0,5),BackgroundColor3=C.green,BorderSizePixel=0},own)
 local ownArmorFill=make("Frame",{Name="Fill",Size=UDim2.fromScale(0,1),BackgroundColor3=armorColor,BorderSizePixel=0},ownArmorTrack)
 local enemyArmor=text(enemy,"Armor","◇ Броня 0",15,UDim2.fromOffset(10,82),UDim2.new(1,-20,0,20),armorColor)
 local enemyArmorTrack=make("Frame",{Name="ArmorTrack",Position=UDim2.fromOffset(10,105),Size=UDim2.new(1,-20,0,5),BackgroundColor3=C.green,BorderSizePixel=0},enemy)
 local enemyArmorFill=make("Frame",{Name="Fill",Size=UDim2.fromScale(0,1),BackgroundColor3=armorColor,BorderSizePixel=0},enemyArmorTrack)
 cameraControls=CameraControls.Create(app,TableScene,function()return root.AbsoluteSize end)
 local function update(s)
  cameraControls:Refresh()
  TableScene.Update(s)
  local compact=app.AbsoluteSize.X<650
  local mobile=TableScene.IsMobileView(root.AbsoluteSize)
  title.Visible=not mobile
  top.Size=UDim2.new(1,0,0,if mobile then 64 else 150)
  own.Position=if mobile then UDim2.fromOffset(6,3)else UDim2.fromOffset(16,50)
  local landscape=root.AbsoluteSize.X>root.AbsoluteSize.Y
  own.Size=if mobile then UDim2.new(if landscape then .22 else .34,-8,0,36)else UDim2.new(if compact then .36 else .24,0,0,88)
  enemy.AnchorPoint=Vector2.new(1,0)
  enemy.Position=if mobile then UDim2.new(1,-56,0,3)else UDim2.new(1,-16,0,50)
  enemy.Size=if mobile then UDim2.new(if landscape then .25 else .66,if landscape then 0 else -62,0,36)else UDim2.new(if compact then .47 else .29,0,0,88)
  returnButton.Text=if mobile then "×"else "В комнату"
  returnButton.Position=UDim2.new(1,if mobile then -50 else -116,0,if mobile then 5 else 7)
  returnButton.Size=UDim2.fromOffset(if mobile then 44 else 104,if mobile then 44 else 32)
  track.Visible=not mobile;enemyTrack.Visible=not mobile
  playerName.Visible=not mobile;name.Visible=not mobile
  playerName.Position=UDim2.fromOffset(8,1);playerName.Size=UDim2.new(1,-16,0,if mobile then 18 else 24)
  playerName.TextTruncate=Enum.TextTruncate.AtEnd;playerName.TextWrapped=false
  hp.Position=UDim2.fromOffset(8,if mobile then 6 else 31);hp.TextSize=if mobile then 17 else 21
  name.Position=UDim2.fromOffset(8,1);name.Size=UDim2.new(1,-16,0,if mobile then 18 else 23);name.TextTruncate=Enum.TextTruncate.AtEnd;name.TextWrapped=false
  enemyHP.Position=UDim2.fromOffset(8,if mobile then 6 else 28);enemyHP.Size=UDim2.new(if mobile then .48 else 1,if mobile then -8 else -16,0,if mobile then 23 else 23);enemyHP.TextSize=if mobile then 16 else 18
  intent.Position=if mobile then UDim2.new(.48,0,0,6)else UDim2.fromOffset(8,57);intent.Size=UDim2.new(if mobile then .52 else 1,if mobile then -6 else -16,0,24);intent.TextSize=if mobile then 12 else 15
  playerName.TextSize=if compact then 14 else 18;name.TextSize=if compact then 16 else 20
  if mobile then playerName.TextSize=12;name.TextSize=13 end
  hp.Text="♥ "..s.hp.." / "..s.maxHp;hpFill.Size=UDim2.fromScale(s.hp/s.maxHp,1)
  name.Text=s.enemyName
  enemyHP.Text=s.enemyHp.." / "..s.enemyMaxHp;enemyFill.Size=UDim2.fromScale(s.enemyHp/s.enemyMaxHp,1)
  intent.Text=if s.mode=="duel"then "ИИ · Раунд "..s.round.."/"..s.roundsTotal else "Атака "..s.enemyAttack.." · Ходы "..s.roundsLeft.."/"..s.roundsTotal
  if mobile then intent.Text=if s.mode=="duel"then "Раунд "..s.round.."/"..s.roundsTotal else "Ходы "..s.roundsLeft.."/"..s.roundsTotal end
  own.Size=UDim2.new(own.Size.X.Scale,own.Size.X.Offset,0,if mobile then 56 else 116)
  enemy.Size=UDim2.new(enemy.Size.X.Scale,enemy.Size.X.Offset,0,if mobile then 56 else 116)
  for _,pair in {{ownArmor,ownArmorTrack},{enemyArmor,enemyArmorTrack}}do
   pair[1].Position=UDim2.fromOffset(8,if mobile then 30 else 82);pair[1].TextSize=if mobile then 12 else 15
   pair[2].Position=UDim2.fromOffset(8,if mobile then 50 else 105);pair[2].Size=UDim2.new(1,-16,0,if mobile then 3 else 5)
  end
  local armor=s.armor or (s.forecast.tarot and s.forecast.tarot.shield)or 0
  local theirs=s.enemyArmor or 0;local cap=s.armorMax or 15
  ownArmor.Text="◇ Броня "..armor;enemyArmor.Text="◇ Броня "..theirs
  TweenService:Create(ownArmorFill,TweenInfo.new(.2),{Size=UDim2.fromScale(math.clamp(armor/cap,0,1),1)}):Play()
  TweenService:Create(enemyArmorFill,TweenInfo.new(.2),{Size=UDim2.fromScale(math.clamp(theirs/cap,0,1),1)}):Play()
  if not mobile and s.mode=="duel"then
   local ownClass=Loadout.Class(s.class);local theirClass=Loadout.Class(s.duel.enemyClass)
   playerName.Text=player.DisplayName.." · "..(ownClass and ownClass.name or "")
   name.Text="ИИ · "..(theirClass and theirClass.name or "")
  end
 end
 return {update=update,impact=function(value,maxHp,damage,side)
  if side=="player"then hp.Text="♥ "..value.." / "..maxHp;TweenService:Create(hpFill,TweenInfo.new(.08),{Size=UDim2.fromScale(value/maxHp,1)}):Play()
  else enemyHP.Text=value.." / "..maxHp;TweenService:Create(enemyFill,TweenInfo.new(.08),{Size=UDim2.fromScale(value/maxHp,1)}):Play()end
 end}
end
local function lobbyUI()
 local title=text(lobby,"Title","ВОЧКО\nКомната поединков",25,UDim2.fromOffset(16,8),UDim2.fromOffset(280,64));title.TextStrokeTransparency=.4
 local shortcuts=make("Frame",{Name="Shortcuts",AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-14),Size=UDim2.new(1,-20,0,100),BackgroundTransparency=1},lobby)
 make("UISizeConstraint",{MaxSize=Vector2.new(600,100)},shortcuts)
 local names={{"campaign","Кампания"},{"wardrobe","Шкаф · подготовка"},{"pvp","PvP"},{"endless","Бесконечный"}}
 for i,pair in names do button(shortcuts,pair[1],pair[2],UDim2.new((i-1)%2*.5,3,0,math.floor((i-1)/2)*49),UDim2.new(.5,-6,0,44),function()send("open",{mode=pair[1]})end)end
end
lobbyUI()
local function render(data,force)
 current=data;local screen=data.screen or "lobby";local s=data.battle
 local key=screen..(if s then ":"..s.id else "")
 if screen=="battle" and s and(s.phase=="won" or s.phase=="lost" or s.phase=="draw")then key..=":"..s.phase end
 if key~=screenKey or force then
  clearApp();app.BackgroundTransparency=0;app.UISizeConstraint.MaxSize=Vector2.new(if screen=="battle" then 2400 else 640,2400);screenKey=key;lobby.Visible=screen=="lobby";app.Visible=screen~="lobby";cameraFor(screen)
  if screen=="intro" and s then intro(data)
  elseif screen=="wardrobe"or screen=="duelsetup"then wardrobe(data,screen=="duelsetup")
  elseif screen=="notice"then simpleNotice(data)
  elseif screen=="battle"and s then
   if s.phase=="won"or s.phase=="lost"or s.phase=="draw"then result(data)else battleUI=buildBattle(s);TableScene.Camera(root.AbsoluteSize,false)end
  end
 elseif screen=="wardrobe"or screen=="duelsetup"then local old=app:FindFirstChild("Body");local pos=old and old.CanvasPosition;clearApp();wardrobe(data,screen=="duelsetup");if pos then app.Body.CanvasPosition=pos end end
 if battleUI and s then battleUI.update(s)end
 message(data.message)
end
local attackPlayback,pendingSnapshot=false,nil
local animatedReceipts={}
Snapshot.OnClientEvent:Connect(function(data)
 if type(data)~="table"then return end
 local s=data.battle
 if attackPlayback then
  if data.screen=="battle" and current and s and current.battle and s.id==current.battle.id then pendingSnapshot=data;return end
  attackPlayback=false;pendingSnapshot=nil
  render(data,false);return
 end
 local receipt=s and s.receipt
 if data.screen=="battle" and battleUI and current and current.screen=="battle" and current.battle and s and s.id==current.battle.id
  and receipt and receipt.hits and receipt.round>(animatedReceipts[s.id]or 0)then
  animatedReceipts[s.id]=receipt.round;attackPlayback=true;pendingSnapshot=data
  TableScene.PlayAttack(s,function(hp,maxHp,damage,side)if battleUI then battleUI.impact(hp,maxHp,damage,side)end end,function()
   if not attackPlayback then return end
   attackPlayback=false;local nextData=pendingSnapshot;pendingSnapshot=nil
   if nextData then render(nextData,false)end
  end)
  return
 end
 render(data,false)
end)
local resizeQueued=false
app:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
 if resizeQueued then return end;resizeQueued=true;task.defer(function()resizeQueued=false;if battleUI and current and current.battle then TableScene.Camera(root.AbsoluteSize,false);if not TableScene.ImpactActive then battleUI.update(current.battle) end end end)
end)
UIS.InputBegan:Connect(function(input,processed)
 if TableScene.CameraTuning or TableScene.ImpactActive or processed or not current or current.screen~="battle"or not current.battle or current.battle.phase~="combat"then return end
 if input.KeyCode==Enum.KeyCode.Space then send("draw")elseif input.KeyCode==Enum.KeyCode.F then send("stop")elseif input.KeyCode==Enum.KeyCode.Return then send("play")end
end)
task.spawn(function()
 local images={Assets.Cards,Assets.Portraits};for _,id in Assets.Tarot do table.insert(images,id)end
 pcall(function()game:GetService("ContentProvider"):PreloadAsync(images)end)
end)
send("snapshot")
