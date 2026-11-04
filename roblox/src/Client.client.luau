local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer
local remote = game:GetService("ReplicatedStorage"):WaitForChild("VochkoPrototype")
local Assets = require(remote:WaitForChild("Assets"))
local TableScene = require(remote:WaitForChild("TableScene"))
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
  camera.CameraType=Enum.CameraType.Scriptable;camera.CFrame=CFrame.lookAt(Vector3.new(19,12,3),Vector3.new(19,4,-7))
  if controls then controls:Disable() end
 end
end
local function clearApp()
 for _,child in app:GetChildren() do if not child:IsA("UISizeConstraint") then child:Destroy() end end
 battleUI=nil
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
 local s=data.battle;local body=scrollBody(72);header(body,"ТЕМНИЦА · ПЕРВЫЙ БОЙ")
 make("ImageLabel",{Name="Opponent",Image=Assets.Portraits,ImageRectSize=Vector2.new(200,200),ImageRectOffset=Vector2.new(0,0),BackgroundTransparency=1,
  AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,60),Size=UDim2.fromOffset(250,250)},body)
 text(body,"EnemyTitle",s.enemyName,31,UDim2.fromOffset(18,316),UDim2.new(1,-36,0,40))
 text(body,"EnemyStats",string.format("Здоровье: %d  ·  Атака: %d\nЦель: %d  ·  Мест на зоне: %d\nРозыгрышей на бой: %d",s.enemyMaxHp,s.enemyAttack,s.target,s.slots,s.roundsTotal),20,UDim2.fromOffset(18,365),UDim2.new(1,-36,0,105),C.muted)
 text(body,"Hint","Добирай карты к цели. Точное попадание усиливает удар. Перебор можно исправить срезом до розыгрыша.",17,UDim2.fromOffset(18,480),UDim2.new(1,-36,0,90))
 actionDock(function()send("begin")end,"ВОЙТИ В БОЙ")
end
local function wardrobe(data)
 local body=scrollBody(72);header(body,"ШКАФ КОЛЛЕКЦИИ")
 text(body,"DeckTitle","Классическая колода · 52 карты",23,UDim2.fromOffset(16,62),UDim2.new(1,-32,0,38))
 for i=1,3 do atlas(body,"CardPreview"..i,{rankIndex=9+i,suitIndex=1},UDim2.new(.5,(i-2)*72-30,0,112),UDim2.fromOffset(62,87)) end
 text(body,"OriginalArt","Карты и портреты — наша графика из ВОЧКО.",15,UDim2.fromOffset(16,212),UDim2.new(1,-32,0,35),C.muted)
 text(body,"TalentTitle","Стартовый талант",24,UDim2.fromOffset(16,258),UDim2.new(1,-32,0,34))
 local definitions={{id="healer",name="Лекарь",desc="Красные зоны лечат на 50% больше."},
  {id="sharp",name="Картёжник",desc="Точные зоны наносят на 15% больше урона."},
  {id="daring",name="Авантюрист",desc="Ровно один перебор: общий урон +30%."}}
 local active=data.battle and data.battle.phase~="won" and data.battle.phase~="lost"
 for i,def in definitions do
  local b=button(body,"Talent_"..def.id,(if data.profile.talent==def.id then "✓ " else "")..def.name.."\n"..def.desc,UDim2.fromOffset(16,300+(i-1)*72),UDim2.new(1,-32,0,62),function()send("talent",{talent=def.id})end)
  b.TextSize=17;if data.profile.talent==def.id then b.BackgroundColor3=Color3.fromRGB(68,70,35)end;enabled(b,not active)
 end
 text(body,"WardrobeStatus",if active then "Сборка текущего боя уже зафиксирована. Сменить талант можно после его завершения." else "Выбор применяется к следующему бою. В этой технической сборке профиль хранится до выхода с сервера.",15,UDim2.fromOffset(16,521),UDim2.new(1,-32,0,68),C.muted)
 text(body,"FutureCollection","Джокеры и таро\nСледующий этап: выбор стартовых предметов и сохранённые сборки.",19,UDim2.fromOffset(16,600),UDim2.new(1,-32,0,85))
 actionDock(function()send("open",{mode="campaign"})end,if active then "ПРОДОЛЖИТЬ БОЙ" else "К СТОЛУ КАМПАНИИ")
end
local function result(data)
 local s=data.battle;local body=scrollBody(72);header(body,"ВОЧКО · ИТОГ БОЯ")
 text(body,"ResultTitle",if s.phase=="won" then "Противник повержен" else "Побег прервался",32,UDim2.fromOffset(20,98),UDim2.new(1,-40,0,80))
 local desc=if s.phase=="won" then "За победу: +4 монеты\nПобед в этой сессии: "..data.profile.wins else "Не хватило "..(if s.hp<=0 then "здоровья." else "розыгрышей.").."\nПопробуй другую стратегию или талант."
 text(body,"ResultStats",desc.."\nМонеты этой сессии: "..data.profile.coins,21,UDim2.fromOffset(20,190),UDim2.new(1,-40,0,120),C.muted)
 text(body,"JournalTitle","Журнал боя",24,UDim2.fromOffset(20,330),UDim2.new(1,-40,0,35))
 text(body,"Journal",table.concat(s.journal,"\n"),16,UDim2.fromOffset(20,372),UDim2.new(1,-40,0,150),C.muted)
 actionDock(function()send("open",{mode="campaign"})end,"НОВАЯ ПОПЫТКА")
end
local function buildBattle()
 local body,scroll=scrollBody(94);header(body,"ТЕМНИЦА · КРЫСОЛОВ")
 local scene=make("Frame",{Name="EnemyScene",Position=UDim2.fromOffset(8,53),Size=UDim2.new(1,-16,0,106),BackgroundColor3=C.green,BorderSizePixel=0},body);stroke(scene)
 make("ImageLabel",{Name="Portrait",Image=Assets.Portraits,ImageRectOffset=Vector2.new(0,0),ImageRectSize=Vector2.new(200,200),BackgroundTransparency=1,Size=UDim2.fromOffset(104,104)},scene)
 text(scene,"EnemyName","КРЫСОЛОВ",24,UDim2.fromOffset(112,5),UDim2.new(1,-120,0,31))
 local enemyHP=text(scene,"EnemyHP","",18,UDim2.fromOffset(112,37),UDim2.new(1,-120,0,26))
 local bar=make("Frame",{Name="HealthTrack",Position=UDim2.fromOffset(112,67),Size=UDim2.new(1,-122,0,11),BackgroundColor3=Color3.fromRGB(33,22,15),BorderSizePixel=0},scene)
 local fill=make("Frame",{Name="Fill",Size=UDim2.fromScale(1,1),BackgroundColor3=C.red,BorderSizePixel=0},bar)
 local intent=text(scene,"Intent","",15,UDim2.fromOffset(112,81),UDim2.new(1,-120,0,22),C.muted)
 local status=make("Frame",{Name="PlayerStatus",Position=UDim2.fromOffset(8,167),Size=UDim2.new(1,-16,0,43),BackgroundTransparency=1},body)
 local playerHP=text(status,"PlayerHP","",23,UDim2.new(),UDim2.new(.48,0,1,0),Color3.fromRGB(188,220,159))
 local rounds=text(status,"Rounds","",23,UDim2.fromScale(.48,0),UDim2.fromScale(.52,1));rounds.TextXAlignment=Enum.TextXAlignment.Right
 local target=text(body,"Target","",22,UDim2.fromOffset(10,212),UDim2.new(.48,-10,0,35))
 local deck=text(body,"Deck","",16,UDim2.new(.48,0,0,212),UDim2.new(.52,-10,0,35),C.muted);deck.TextXAlignment=Enum.TextXAlignment.Right
 local cons={}
 for i,item in {"minus2","minus4"}do
  cons[item]=button(body,item,"",UDim2.new((i-1)*.5,8,0,252),UDim2.new(.5,-12,0,41),function()selectedItem=if selectedItem==item then nil else item;message(if selectedItem then "Нажми на зону с картами" else "Выбор отменён");if current then battleUI.update(current.battle)end end)
 end
 local laneRoot=make("Frame",{Name="Zones",Position=UDim2.fromOffset(8,302),Size=UDim2.new(1,-16,0,240),BackgroundTransparency=1},body)
 local lanes={}
 for i=1,3 do
  local lane=make("Frame",{Name="Zone"..i,Position=UDim2.new((i-1)/3,2,0,0),Size=UDim2.new(1/3,-4,1,0),BackgroundColor3=C.green,BorderSizePixel=0,ClipsDescendants=true},laneRoot);stroke(lane)
  local title=text(lane,"Title","ЗОНА "..i,16,UDim2.fromOffset(4,5),UDim2.new(1,-8,0,24));title.TextXAlignment=Enum.TextXAlignment.Center
  local state=text(lane,"State","",12,UDim2.fromOffset(4,31),UDim2.new(1,-8,0,20),C.muted)
  local cards=make("Frame",{Name="Cards",Position=UDim2.fromOffset(0,53),Size=UDim2.new(1,0,1,-104),BackgroundTransparency=1},lane)
  local sum=text(lane,"Sum","—",29,UDim2.new(.1,0,1,-45),UDim2.new(.8,0,0,36),Color3.fromRGB(35,29,15));sum.BackgroundColor3=C.brass;sum.BackgroundTransparency=0;sum.TextXAlignment=Enum.TextXAlignment.Center
  local click=make("TextButton",{Name="UseItem",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="",ZIndex=9},lane)
  click.Activated:Connect(function()if selectedItem then send("consume",{item=selectedItem,zone=i})end end)
  lanes[i]={root=lane,status=state,cards=cards,sum=sum,nodes={}}
 end
 local damage=text(body,"Damage","",30,UDim2.fromOffset(8,552),UDim2.new(1,-16,0,44));damage.TextXAlignment=Enum.TextXAlignment.Center;damage.BackgroundTransparency=0;damage.BackgroundColor3=C.green;stroke(damage)
 local dock=make("Frame",{Name="Dock",AnchorPoint=Vector2.new(0,1),Position=UDim2.fromScale(0,1),Size=UDim2.new(1,0,0,90),BackgroundColor3=C.ink,BorderSizePixel=0},app);stroke(dock)
 local draw=button(dock,"Draw","ВЗЯТЬ\nКАРТУ",UDim2.new(0,7,0,7),UDim2.new(1/3,-9,0,53),function()send("draw")end,Color3.fromRGB(147,113,55))
 local stop=button(dock,"Stop","СТОП\nНА ЗОНЕ",UDim2.new(1/3,3,0,7),UDim2.new(1/3,-7,0,53),function()send("stop")end)
 local play=button(dock,"Play","СЫГРАТЬ\nХОД",UDim2.new(2/3,2,0,7),UDim2.new(1/3,-9,0,53),function()send("play")end,C.red)
 local hint=text(dock,"Hint","Space — добор · F — стоп · Enter — удар",12,UDim2.fromOffset(8,64),UDim2.new(1,-16,0,21),C.muted);hint.TextXAlignment=Enum.TextXAlignment.Center
 local lastReceipt=0
 TableScene.Create()
 app.BackgroundTransparency=1
 body.PageTitle.Visible=false
 body.Return.ZIndex=5
 scene.Position=UDim2.fromOffset(8,6);scene.Size=UDim2.new(1,-118,0,68)
 scene.Portrait.Visible=false
 scene.EnemyName.Position=UDim2.fromOffset(10,0);scene.EnemyName.Size=UDim2.new(.5,-10,0,28)
 enemyHP.Position=UDim2.new(.5,0,0,0);enemyHP.Size=UDim2.new(.5,-10,0,28);enemyHP.TextXAlignment=Enum.TextXAlignment.Right
 bar.Position=UDim2.fromOffset(10,31);bar.Size=UDim2.new(1,-20,0,9)
 intent.Position=UDim2.fromOffset(10,43);intent.Size=UDim2.new(1,-20,0,23)
 status.Position=UDim2.fromOffset(8,78)
 status.BackgroundTransparency=.12;status.BackgroundColor3=C.ink
 target.Position=UDim2.fromOffset(10,118);deck.Position=UDim2.new(.48,0,0,118)
 scroll.ScrollingEnabled=false;scroll.AutomaticCanvasSize=Enum.AutomaticSize.None
 damage.Visible=false
 for _,lane in lanes do lane.cards.Visible=false;lane.status.TextSize=14;lane.sum.TextSize=24;lane.root.BackgroundTransparency=.12 end
 local function update(s)
  local size=app.AbsoluteSize;local laneH=66
  laneRoot.Position=UDim2.new(0,8,0,size.Y-166);laneRoot.Size=UDim2.new(1,-16,0,laneH)
  for _,lane in lanes do lane.root.Title.Size=UDim2.new(1,-8,0,20);lane.status.Position=UDim2.fromOffset(4,22);lane.status.Size=UDim2.new(.52,-4,0,36);lane.sum.Position=UDim2.new(.54,0,0,24);lane.sum.Size=UDim2.new(.43,0,0,34)end
  for i,item in {"minus2","minus4"}do cons[item].Position=UDim2.new((i-1)*.5,8,0,size.Y-217);cons[item].Size=UDim2.new(.5,-12,0,44)end
  body.Size=UDim2.new(1,0,0,math.max(1,size.Y-94))
  TableScene.Update(s)
  enemyHP.Text=string.format("%d / %d",s.enemyHp,s.enemyMaxHp);fill.Size=UDim2.fromScale(s.enemyHp/s.enemyMaxHp,1)
  intent.Text="Далее: атака "..s.enemyAttack;playerHP.Text="♥ "..s.hp.." / "..s.maxHp
  rounds.Text="ХОДОВ: "..s.roundsLeft.." / "..s.roundsTotal;target.Text="ЦЕЛЬ  "..s.target;deck.Text="КОЛОДА  "..s.deckCount.." / 52"
  damage.Text="УРОН  "..s.forecast.damage
  hint.Text="УРОН  "..s.forecast.damage.."   ·   ВЫБЕРИ СРЕЗ, ЗАТЕМ ЗОНУ";hint.TextSize=15
  local combat=s.phase=="combat"
  enabled(draw,combat and s.active~=nil);enabled(stop,combat and s.active~=nil and #s.zones[s.active].cards>0);enabled(play,combat and s.forecast.cards>0)
  for item,b in cons do
   b.Text=(if item=="minus2" then "Срез −2" else "Срез −4").." · "..(s.supplies[item]or 0)
   enabled(b,combat and(s.supplies[item]or 0)>0);b.BackgroundColor3=if selectedItem==item then Color3.fromRGB(79,78,35)else C.green
  end
  if selectedItem and(s.supplies[selectedItem]or 0)<=0 then selectedItem=nil end
  for i,z in s.zones do
   local l=lanes[i];local r=s.forecast.zones[i]
   l.status.Text=(if r.bust then "ПЕРЕБОР" elseif r.exact then "ТОЧНО" elseif z.stood then "СТОП" elseif s.active==i then "НАБОР" else "ЖДЁТ").." · "..#z.cards.."/"..s.slots
   l.sum.Text=if #z.cards>0 then tostring(r.sum)else "—";l.root.BackgroundColor3=if s.active==i then Color3.fromRGB(34,67,40)else C.green
   local width=math.max(40,math.min(l.root.AbsoluteSize.X*.78,(laneH-102)*.67*Assets.CardWidth/Assets.CardHeight))
   local height=width*Assets.CardHeight/Assets.CardWidth;local step=math.max(7,math.min(20,(laneH-106-height)/math.max(1,s.slots-1)))
   local keep={};for ci,card in z.cards do
    local node=l.nodes[card.id];if not node then node=atlas(l.cards,"Card_"..card.id,card,UDim2.new(),UDim2.new());l.nodes[card.id]=node end
    keep[card.id]=true;node.AnchorPoint=Vector2.new(.5,0);node.Position=UDim2.new(.5,0,0,(ci-1)*step);node.Size=UDim2.fromOffset(width,height);node.ZIndex=ci
   end
   for id,node in l.nodes do if not keep[id]then node:Destroy();l.nodes[id]=nil end end
  end
  if s.receipt and s.receipt.round>lastReceipt then
   lastReceipt=s.receipt.round;local value=text(scene,"Hit","−"..s.receipt.damage,29,UDim2.fromOffset(15,25),UDim2.fromOffset(95,40),Color3.fromRGB(255,209,134));value.TextXAlignment=Enum.TextXAlignment.Center;value.ZIndex=12
   TweenService:Create(value,TweenInfo.new(.65),{Position=UDim2.fromOffset(15,0),TextTransparency=1}):Play();task.delay(.7,function()value:Destroy()end)
  end
 end
 return {update=update}
end
local function lobbyUI()
 local title=text(lobby,"Title","ВОЧКО\nКомната поединков",25,UDim2.fromOffset(16,8),UDim2.fromOffset(280,64));title.TextStrokeTransparency=.4
 local shortcuts=make("Frame",{Name="Shortcuts",AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-14),Size=UDim2.new(1,-20,0,100),BackgroundTransparency=1},lobby)
 make("UISizeConstraint",{MaxSize=Vector2.new(600,100)},shortcuts)
 local names={{"campaign","Кампания"},{"wardrobe","Коллекция"},{"pvp","PvP"},{"endless","Бесконечный"}}
 for i,pair in names do button(shortcuts,pair[1],pair[2],UDim2.new((i-1)%2*.5,3,0,math.floor((i-1)/2)*49),UDim2.new(.5,-6,0,44),function()send("open",{mode=pair[1]})end)end
end
lobbyUI()
local function render(data,force)
 current=data;local screen=data.screen or "lobby";local s=data.battle
 local key=screen..(if s then ":"..s.id else "")
 if screen=="battle" and s and(s.phase=="won" or s.phase=="lost")then key..=":"..s.phase end
 if key~=screenKey or force then
  clearApp();app.BackgroundTransparency=0;app.UISizeConstraint.MaxSize=Vector2.new(if screen=="battle" then 1100 else 640,1600);screenKey=key;lobby.Visible=screen=="lobby";app.Visible=screen~="lobby";cameraFor(screen)
  if screen=="intro" and s then intro(data)
  elseif screen=="wardrobe"then wardrobe(data)
  elseif screen=="notice"then simpleNotice(data)
  elseif screen=="battle"and s then
   if s.phase=="won"or s.phase=="lost"then result(data)else battleUI=buildBattle()end
  end
 elseif screen=="wardrobe"then clearApp();wardrobe(data)end
 if battleUI and s then battleUI.update(s)end
 message(data.message)
end
Snapshot.OnClientEvent:Connect(function(data)
 if type(data)=="table"then render(data,false)end
end)
local resizeQueued=false
app:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
 if resizeQueued then return end;resizeQueued=true;task.defer(function()resizeQueued=false;if battleUI and current and current.battle then TableScene.Camera(root.AbsoluteSize,false);battleUI.update(current.battle)end end)
end)
UIS.InputBegan:Connect(function(input,processed)
 if processed or not current or current.screen~="battle"or not current.battle or current.battle.phase~="combat"then return end
 if input.KeyCode==Enum.KeyCode.Space then send("draw")elseif input.KeyCode==Enum.KeyCode.F then send("stop")elseif input.KeyCode==Enum.KeyCode.Return then send("play")end
end)
task.spawn(function()pcall(function()game:GetService("ContentProvider"):PreloadAsync({Assets.Cards,Assets.Portraits})end)end)
send("snapshot")
