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
local HUDControls=require(remote:WaitForChild("HUDControls"))
local SoundKit=require(remote:WaitForChild("SoundKit")) -- RaceUI left out: race tables are drawn by TableScene
local hudControls
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
 b.Activated:Connect(function()if b:GetAttribute("Enabled")then SoundKit.Play("ui")callback()end end);return b
end
local function enabled(b,value)
 b:SetAttribute("Enabled",value);b.Active=value;b.AutoButtonColor=value;b.TextTransparency=if value then 0 else .55;b.BackgroundTransparency=if value then 0 else .45
end
local sequence,current,selectedItem,battleUI,screenKey=0,nil,nil,nil,nil
local ACTION_CUES={grab="take",discard="discard",stand="stand",draw="take",stop="stand",play="stand"}
local function send(kind,extra)
 sequence+=1;local data=extra or {};data.kind=kind;data.requestId=sequence
 if current and current.battle then data.sessionId=current.battle.id end
 if data.sessionId and ACTION_CUES[kind] then SoundKit.Play(ACTION_CUES[kind]) end
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
 if screen=="lobby"or screen=='pvpwait'or screen=='pvpwardrobe'then
  TableScene.Destroy();camera.FieldOfView=70
  camera.CameraType=Enum.CameraType.Custom
  local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid");if humanoid then camera.CameraSubject=humanoid end
  if controls then if screen=='lobby'then controls:Enable()else controls:Disable()end end
 elseif screen=="battle" then
  TableScene.Camera(root.AbsoluteSize,true)
  if controls then controls:Disable() end
 else
  TableScene.Destroy()
  camera.CameraType=Enum.CameraType.Scriptable;camera.CFrame=if screen=='pvpwait'then CFrame.lookAt(Vector3.new(0,12,5),Vector3.new(0,4,-7))elseif screen=="wardrobe"then CFrame.lookAt(Vector3.new(-23,7,4),Vector3.new(-23,6,15))else CFrame.lookAt(Vector3.new(19,12,3),Vector3.new(19,4,-7))
  if controls then controls:Disable() end
 end
end
local function clearApp()
 if hudControls then hudControls:Destroy();hudControls=nil end
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
local function seatedWaiting(data)
 local dock=make('Frame',{Name='WaitingPanel',AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-8),Size=UDim2.new(1,-24,0,100),BackgroundColor3=C.ink,BackgroundTransparency=.08},app)
 make('UISizeConstraint',{MaxSize=Vector2.new(520,100)},dock);stroke(dock)
 text(dock,'Status',data.notice.body,16,UDim2.fromOffset(10,4),UDim2.new(1,-20,0,36),C.paper)
 button(dock,'Build','Выбрать сборку',UDim2.new(0,8,0,48),UDim2.new(.67,-12,0,44),function()send('openBuild')end)
 button(dock,'Stand','Встать',UDim2.new(.67,0,0,48),UDim2.new(.33,-8,0,44),function()send('return')end,C.red)
end
local function intro(data)
 local s=data.battle;local body=scrollBody(72);header(body,if s.mode=="race"then "ВОЧКО · ТРЕНИРОВКА В РЕАЛЬНОМ ВРЕМЕНИ"elseif s.mode=="duel"then "ДУЭЛЬ · ТРЕНИРОВКА С ИИ"else "ТЕМНИЦА · ПЕРВЫЙ БОЙ")
 make("ImageLabel",{Name="Opponent",Image=Assets.Portraits,ImageRectSize=Vector2.new(200,200),ImageRectOffset=Vector2.new(0,0),BackgroundTransparency=1,
  AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,60),Size=UDim2.fromOffset(250,250)},body)
 text(body,"EnemyTitle",s.enemyName,31,UDim2.fromOffset(18,316),UDim2.new(1,-36,0,40))
 text(body,"EnemyStats",string.format("Здоровье: %d  ·  Атака: %d\nЦель: %d  ·  Мест на зоне: %d\nРозыгрышей на бой: %d",s.enemyMaxHp,s.enemyAttack,s.target,s.slots,s.roundsTotal),20,UDim2.fromOffset(18,365),UDim2.new(1,-36,0,105),C.muted)
 text(body,"Hint",if s.mode=="race"then "Общая колода в центре. За 20 секунд набери три зоны: открытую карту можно взять или сбросить. Сбросы дают броню, таро вскрываются при взятии. Побеждает тот, у кого больше HP после раунда."elseif s.mode=="duel"then "У каждой стороны своя колода. ИИ набирает карты на твоих глазах: видны суммы, остановки и переборы. Цель растёт каждый раунд: 21, 22, 23… Удары одновременные; после десяти раундов сравнивается здоровье."else "Добирай карты к цели. Точное попадание усиливает удар. Перебор можно исправить срезом до розыгрыша.",17,UDim2.fromOffset(18,480),UDim2.new(1,-36,0,90))
 actionDock(function()send("begin")end,"ВОЙТИ В БОЙ")
end
local function wardrobe(data,duelSetup)
 local race=(duelSetup and data.battle and data.battle.mode=="race")or data.screen=="pvpwardrobe"
 Inventory.Build(app,data,duelSetup,send,race)
end
local function result(data)
 local s=data.battle;local body=scrollBody(72);header(body,"ВОЧКО · ИТОГ БОЯ")
 text(body,"ResultTitle",if s.phase=="won"then (if s.mode=="race"then "Забег выигран"else "Противник повержен")elseif s.phase=="draw"then "Ничья"elseif s.mode=="race"then "Забег проигран"elseif s.mode=="duel"then "Дуэль проиграна"else "Побег прервался",32,UDim2.fromOffset(20,98),UDim2.new(1,-40,0,80))
 local desc=if s.phase=="won" then "За победу: +4 монеты\nПобед в этой сессии: "..data.profile.wins else "Не хватило "..(if s.hp<=0 then "здоровья." else "розыгрышей.").."\nПопробуй другую стратегию или талант."
 if s.network then desc='Дуэль с '..s.enemyName..'\nЗдоровье: '..s.hp..' : '..s.enemyHp elseif s.mode=="race"then desc="Тренировочный забег с ИИ\nЗдоровье: "..s.hp.." : "..s.enemyHp.."\nПобед над ИИ: "..(data.profile.duelWins or 0) elseif s.mode=="duel"then desc="Тренировочная дуэль с ИИ\nЗдоровье: "..s.hp.." : "..s.enemyHp.."\nПобед над ИИ: "..(data.profile.duelWins or 0)end
 text(body,"ResultStats",desc.."\nМонеты этой сессии: "..data.profile.coins,21,UDim2.fromOffset(20,190),UDim2.new(1,-40,0,120),C.muted)
 text(body,"JournalTitle","Журнал боя",24,UDim2.fromOffset(20,330),UDim2.new(1,-40,0,35))
 text(body,"Journal",table.concat(s.journal,"\n"),16,UDim2.fromOffset(20,372),UDim2.new(1,-40,0,150),C.muted)
 actionDock(function()if s.network then send('return')else send("open",{mode=if s.mode=="race"then "training"elseif s.mode=="duel"then "training"else "campaign"})end end,if s.network then 'ВСТАТЬ ИЗ-ЗА СТОЛА'else "НОВАЯ ПОПЫТКА")
end
local function buildBattle(s)
 app.BackgroundTransparency=1
 TableScene.Create(player:WaitForChild("PlayerGui"),send,s.mode=="duel"or s.mode=="race",s)
 local raceUI=nil
 local prevRace={}
 local top=make("Frame",{Name="BattleHUD",Size=UDim2.new(1,0,0,150),BackgroundTransparency=1},app)
 local title=text(top,"Title",if s.mode=="race"then "ВОЧКО / ЗАБЕГ"elseif s.network then 'ВОЧКО / PVP'elseif s.mode=="duel"then "ВОЧКО / ДУЭЛЬ С ИИ"else "ВОЧКО / ТЕМНИЦА",20,UDim2.fromOffset(16,7),UDim2.new(.55,0,0,30));title.TextStrokeTransparency=.5
 local surrenderArmed=false
 local returnButton
 returnButton=button(top,"Return","В комнату",UDim2.new(1,-116,0,7),UDim2.fromOffset(104,32),function()
  if s.network and not surrenderArmed then surrenderArmed=true;returnButton.Text='Сдаться?';return end
  send('return')
 end);returnButton.TextSize=15
 local function panel(name,x,w)
  local p=make("Frame",{Name=name,Position=UDim2.new(x,if x==0 then 16 else -16,0,50),AnchorPoint=Vector2.new(x,0),Size=UDim2.new(w,0,0,88),BackgroundColor3=C.ink,BackgroundTransparency=.12,BorderSizePixel=0},top)
  make("UICorner",{CornerRadius=UDim.new(0,9)},p);stroke(p)
  return p
 end
 local own=panel("Player",0,.24)
 local playerName=text(own,"Name",player.DisplayName,18,UDim2.fromOffset(10,4),UDim2.new(1,-20,0,24))
 local hp=text(own,"HP","",21,UDim2.fromOffset(10,31),UDim2.new(1,-20,0,24),Color3.fromRGB(177,216,146))
 local track=make("Frame",{Name="HPTrack",Position=UDim2.fromOffset(10,64),Size=UDim2.new(1,-20,0,8),BackgroundColor3=C.green,BorderSizePixel=0},own)
 local hpFill=make("Frame",{Name="Fill",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(102,177,93),BorderSizePixel=0},track)
 local enemy=panel("Enemy",1,.29)
 local name=text(enemy,"Name","КРЫСОЛОВ",20,UDim2.fromOffset(10,3),UDim2.new(1,-20,0,23))
 local enemyHP=text(enemy,"HP","",18,UDim2.fromOffset(10,28),UDim2.new(1,-20,0,23),Color3.fromRGB(234,162,138))
 local enemyTrack=make("Frame",{Name="HPTrack",Position=UDim2.fromOffset(10,51),Size=UDim2.new(1,-20,0,6),BackgroundColor3=C.green,BorderSizePixel=0},enemy)
 local enemyFill=make("Frame",{Name="Fill",Size=UDim2.fromScale(1,1),BackgroundColor3=C.red,BorderSizePixel=0},enemyTrack)
 local intent=text(enemy,"Intent","",15,UDim2.fromOffset(10,57),UDim2.new(1,-20,0,24),C.muted)
 local armorColor=Color3.fromRGB(103,196,218)
 local ownArmor=text(own,"Armor","◇ Броня 0",15,UDim2.fromOffset(10,82),UDim2.new(1,-20,0,20),armorColor)
 local ownArmorTrack=make("Frame",{Name="ArmorTrack",Position=UDim2.fromOffset(10,105),Size=UDim2.new(1,-20,0,5),BackgroundColor3=C.green,BorderSizePixel=0},own)
 local ownArmorFill=make("Frame",{Name="Fill",Size=UDim2.fromScale(0,1),BackgroundColor3=armorColor,BorderSizePixel=0},ownArmorTrack)
 local enemyArmor=text(enemy,"Armor","◇ Броня 0",15,UDim2.fromOffset(10,82),UDim2.new(1,-20,0,20),armorColor)
 local enemyArmorTrack=make("Frame",{Name="ArmorTrack",Position=UDim2.fromOffset(10,105),Size=UDim2.new(1,-20,0,5),BackgroundColor3=C.green,BorderSizePixel=0},enemy)
 local enemyArmorFill=make("Frame",{Name="Fill",Size=UDim2.fromScale(0,1),BackgroundColor3=armorColor,BorderSizePixel=0},enemyArmorTrack)
 local ownMax=text(own,"MaxHP","",12,UDim2.new(),UDim2.new(),C.muted)
 local enemyMax=text(enemy,"MaxHP","",12,UDim2.new(),UDim2.new(),C.muted)
 local function fillSize(value)
  value=math.clamp(value,0,1)
  return if TableScene.IsMobileView(root.AbsoluteSize)then UDim2.fromScale(1,value)else UDim2.fromScale(value,1)
 end
 cameraControls=CameraControls.Create(app,TableScene,function()return root.AbsoluteSize end)
 hudControls=HUDControls.Create(app,{own,enemy},TableScene,function()return app.AbsoluteSize end,function()if battleUI and current and current.battle then battleUI.update(current.battle)end end,returnButton)
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
  returnButton.Text=if surrenderArmed then 'Сдаться?'elseif s.network then (if mobile then 'Выход'else 'Сдаться')elseif mobile then "×"else "В комнату"
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
  intent.Text=if s.network then 'PvP · Раунд '..s.round..'/'..s.roundsTotal elseif s.mode=="duel"then "ИИ · Раунд "..s.round.."/"..s.roundsTotal else "Атака "..s.enemyAttack.." · Ходы "..s.roundsLeft.."/"..s.roundsTotal
  if mobile then intent.Text=if s.mode=="duel"then "Раунд "..s.round.."/"..s.roundsTotal else "Ходы "..s.roundsLeft.."/"..s.roundsTotal end
  intent.Visible=not mobile
  own.Size=UDim2.new(own.Size.X.Scale,own.Size.X.Offset,0,if mobile then 56 else 116)
  enemy.Size=UDim2.new(enemy.Size.X.Scale,enemy.Size.X.Offset,0,if mobile then 56 else 116)
  for _,pair in {{ownArmor,ownArmorTrack},{enemyArmor,enemyArmorTrack}}do
   pair[1].Position=UDim2.fromOffset(8,if mobile then 30 else 82);pair[1].TextSize=if mobile then 12 else 15
   pair[2].Position=UDim2.fromOffset(8,if mobile then 50 else 105);pair[2].Size=UDim2.new(1,-16,0,if mobile then 3 else 5)
  end
  local armor=s.armor or (s.forecast.tarot and s.forecast.tarot.shield)or 0
  local theirs=s.enemyArmor or 0;local cap=s.armorMax or 15
  ownArmor.Text="◇ Броня "..armor;enemyArmor.Text="◇ Броня "..theirs
  ownMax.Visible=mobile;enemyMax.Visible=mobile
  if mobile then
   local height=math.clamp(app.AbsoluteSize.Y*.45,140,260)
   local railY=math.max(48,app.AbsoluteSize.Y-height-4)
   height=math.max(110,math.min(height,app.AbsoluteSize.Y-railY-8))
   top.Size=UDim2.fromScale(1,1)
   own.AnchorPoint=Vector2.new(0,0);own.Position=UDim2.fromOffset(5,railY);own.Size=UDim2.fromOffset(48,height)
   enemy.AnchorPoint=Vector2.new(1,0);enemy.Position=UDim2.new(1,-5,0,railY);enemy.Size=UDim2.fromOffset(48,height)
   playerName.Visible=true;name.Visible=true;playerName.Text="ТЫ";name.Text="ВРАГ"
   for _,label in {playerName,name}do label.Position=UDim2.fromOffset(1,4);label.Size=UDim2.new(1,-2,0,16);label.TextSize=11;label.TextXAlignment=Enum.TextXAlignment.Center end
   hp.Text=tostring(s.hp);enemyHP.Text=tostring(s.enemyHp)
   for _,label in {hp,enemyHP}do label.Position=UDim2.fromOffset(1,22);label.Size=UDim2.new(1,-2,0,23);label.TextSize=18;label.TextXAlignment=Enum.TextXAlignment.Center end
   ownMax.Text="/ "..s.maxHp;enemyMax.Text="/ "..s.enemyMaxHp
   for _,label in {ownMax,enemyMax}do label.Position=UDim2.fromOffset(1,43);label.Size=UDim2.new(1,-2,0,16);label.TextXAlignment=Enum.TextXAlignment.Center end
   for _,bar in {track,enemyTrack}do bar.Visible=true;bar.Position=UDim2.fromOffset(8,64);bar.Size=UDim2.new(0,18,1,-92)end
   for _,bar in {ownArmorTrack,enemyArmorTrack}do bar.Position=UDim2.fromOffset(32,64);bar.Size=UDim2.new(0,7,1,-92)end
   for _,fill in {hpFill,enemyFill,ownArmorFill,enemyArmorFill}do fill.AnchorPoint=Vector2.new(0,1);fill.Position=UDim2.fromScale(0,1)end
   ownArmor.Text="◇ "..armor;enemyArmor.Text="◇ "..theirs
   for _,label in {ownArmor,enemyArmor}do label.Position=UDim2.new(0,1,1,-23);label.Size=UDim2.new(1,-2,0,20);label.TextSize=13;label.TextXAlignment=Enum.TextXAlignment.Center end
   intent.Parent=top;intent.AnchorPoint=Vector2.new(1,0);intent.Position=UDim2.new(1,-5,0,50);intent.Size=UDim2.fromOffset(48,28);intent.TextSize=12;intent.TextXAlignment=Enum.TextXAlignment.Center;intent.BackgroundColor3=C.ink;intent.BackgroundTransparency=.15
  else
   own.AnchorPoint=Vector2.new(0,0)
   for _,fill in {hpFill,enemyFill,ownArmorFill,enemyArmorFill}do fill.AnchorPoint=Vector2.new();fill.Position=UDim2.new()end
   for _,label in {playerName,name,hp,enemyHP,ownArmor,enemyArmor}do label.TextXAlignment=Enum.TextXAlignment.Left end
   hp.Size=UDim2.new(1,-20,0,24)
   track.Position=UDim2.fromOffset(10,64);track.Size=UDim2.new(1,-20,0,8)
   enemyTrack.Position=UDim2.fromOffset(10,51);enemyTrack.Size=UDim2.new(1,-20,0,6)
   intent.Parent=enemy;intent.AnchorPoint=Vector2.new();intent.BackgroundTransparency=1;intent.TextXAlignment=Enum.TextXAlignment.Left
  end
  hpFill.Size=fillSize(s.hp/s.maxHp);enemyFill.Size=fillSize(s.enemyHp/s.enemyMaxHp)
  TweenService:Create(ownArmorFill,TweenInfo.new(.2),{Size=fillSize(armor/cap)}):Play()
  TweenService:Create(enemyArmorFill,TweenInfo.new(.2),{Size=fillSize(theirs/cap)}):Play()
  if not mobile and s.mode=="duel"then
   local ownClass=Loadout.Class(s.class);local theirClass=Loadout.Class(s.duel.enemyClass)
   playerName.Text=player.DisplayName.." · "..(ownClass and ownClass.name or "")
   name.Text=(if s.network then s.enemyName else 'ИИ').." · "..(theirClass and theirClass.name or "")
  end
  hudControls:Apply()
  if raceUI then raceUI.Update(s) end
  if s.race then
   local race=s.race
   local open=race.open
   local openKey=if open then (if open.kind=="tarot"then (open.id or "tarot")else tostring(open.rank or "")..tostring(open.suit or ""))else ""
   if prevRace.openKey~=openKey then
    if openKey~=""then SoundKit.Play("reveal")end
    prevRace.openKey=openKey
   end
   local take=race.lastTake
   local takeKey=if take and take.card then tostring(take.round).."·"..tostring(take.seat).."·"..tostring(take.card.id or take.card.rank or "")else ""
   if takeKey~=""and prevRace.takeKey~=takeKey then
    prevRace.takeKey=takeKey
    local c=take.card
    if c.kind=="tarot"and take.seat==race.you then SoundKit.Play(if c.good then "good"else "bad")
    elseif take.seat~=race.you then SoundKit.Play("take") end
   end
   local armor=s.armor or 0
   if prevRace.armor and armor>prevRace.armor then SoundKit.Play("armor")end
   prevRace.armor=armor
   local me=race.seats and race.seats[race.you]or nil
   local stun=if me then me.stunIn or 0 else 0
   if prevRace.stun and stun>0 and prevRace.stun<=0 then SoundKit.Play("stun")end
   prevRace.stun=stun
  end
 end
 return {update=update,impact=function(value,maxHp,damage,side)
  local mobile=TableScene.IsMobileView(root.AbsoluteSize)
  if damage and damage>0 then SoundKit.Play(if side=="player"then "hurt"else "hit")elseif damage and damage<0 then SoundKit.Play("heal")end
  if damage and damage<0 then
   local panel=if side=="player"then own else enemy
   local pop=make("TextLabel",{Name="HealEffect",Text="♥ +"..(-damage),Font=Enum.Font.GothamBold,TextSize=if mobile then 19 else 25,TextColor3=Color3.fromRGB(151,255,163),TextStrokeTransparency=.3,BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,0,0),Size=UDim2.fromOffset(120,36),ZIndex=80},panel)
   if mobile then pop.AnchorPoint=Vector2.new(if side=="player"then 0 else 1,1);pop.Position=UDim2.new(if side=="player"then 1 else 0,0,0,0)end
   TweenService:Create(pop,TweenInfo.new(.85,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=pop.Position-UDim2.fromOffset(0,32),TextTransparency=1,TextStrokeTransparency=1}):Play()
   game:GetService("Debris"):AddItem(pop,.9)
  end
  local duration=if damage and damage<0 then .45 else .08
  if side=="player"then hp.Text=if mobile then tostring(value)else "♥ "..value.." / "..maxHp;TweenService:Create(hpFill,TweenInfo.new(duration),{Size=fillSize(value/maxHp)}):Play()
  else enemyHP.Text=if mobile then tostring(value)else value.." / "..maxHp;TweenService:Create(enemyFill,TweenInfo.new(duration),{Size=fillSize(value/maxHp)}):Play()end
 end}
end
local function lobbyUI()
 local title=text(lobby,"Title","ВОЧКО\nКомната поединков",25,UDim2.fromOffset(16,8),UDim2.fromOffset(280,64));title.TextStrokeTransparency=.4
end
lobbyUI()
local function render(data,force)
 current=data;local screen=data.screen or "lobby";local s=data.battle
 local key=screen..(if s then ":"..s.id else "")
 if screen=="battle" and s and(s.phase=="won" or s.phase=="lost" or s.phase=="draw")then key..=":"..s.phase end
 if key~=screenKey or force then
  clearApp();app.BackgroundTransparency=if screen=='pvpwait'then 1 else 0;app.UISizeConstraint.MaxSize=Vector2.new(if screen=="battle"or screen=='pvpwait'then 2400 elseif screen=='wardrobe'or screen=='duelsetup'or screen=='pvpwardrobe'then 1160 else 640,2400);screenKey=key;lobby.Visible=screen=="lobby";app.Visible=screen~="lobby";cameraFor(screen)
  if screen=="intro" and s then intro(data)
  elseif screen=="wardrobe"or screen=="duelsetup"or screen=='pvpwardrobe'then wardrobe(data,screen=="duelsetup")
  elseif screen=='pvpwait'then seatedWaiting(data)
  elseif screen=="notice"then simpleNotice(data)
  elseif screen=="battle"and s then
   if s.phase=="won"or s.phase=="lost"or s.phase=="draw"then
    if s.phase=="won"then SoundKit.Play("win")elseif s.phase=="draw"then SoundKit.Play("ui")else SoundKit.Play("lose")end
    result(data)
   else battleUI=buildBattle(s);TableScene.Camera(root.AbsoluteSize,false)end
  end
 elseif screen=="wardrobe"or screen=="duelsetup"or screen=='pvpwardrobe'then local old=app:FindFirstChild("Body");local pos=old and old.CanvasPosition;clearApp();wardrobe(data,screen=="duelsetup");if pos then app.Body.CanvasPosition=pos end end
 if screen=='pvpwait'and app:FindFirstChild('WaitingPanel')then app.WaitingPanel.Status.Text=data.notice.body end
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
 if TableScene.CameraTuning or TableScene.HUDTuning or TableScene.ImpactActive or processed or not current or current.screen~="battle"or not current.battle or current.battle.phase~="combat"then return end
 if current.battle.mode=="race"then
  if input.KeyCode==Enum.KeyCode.Space then send("grab")elseif input.KeyCode==Enum.KeyCode.F then send("discard")elseif input.KeyCode==Enum.KeyCode.Return then send("stand")end
 elseif input.KeyCode==Enum.KeyCode.Space then send("draw")elseif input.KeyCode==Enum.KeyCode.F then send("stop")elseif input.KeyCode==Enum.KeyCode.Return then send("play")end
end)
Assets.PreloadAll()
SoundKit.Init()
send("snapshot")
