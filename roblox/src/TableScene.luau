-- Table-local presentation. Every action is still validated by the server.
local Tarot=require(game.ReplicatedStorage.VochkoPrototype.Tarot)
local RaceTarot=require(game.ReplicatedStorage.VochkoPrototype.RaceTarot)
local ownTarotLabel,opponentTarotLabel
local function tarotBox(parent,x,y,w,h)
local box=Instance.new("TextLabel");box.Name="TarotEffect";box.Position=UDim2.fromOffset(x,y);box.Size=UDim2.fromOffset(w,h);box.BackgroundColor3=Color3.fromRGB(8,24,17);box.BackgroundTransparency=1;box.TextColor3=Color3.fromRGB(246,227,176);box.TextSize=22;box.Font=Enum.Font.GothamMedium;box.RichText=true;box.TextWrapped=true;box.TextYAlignment=Enum.TextYAlignment.Center;box.TextXAlignment=Enum.TextXAlignment.Left;box.TextStrokeTransparency=.65;box.ZIndex=40;box.Visible=false;box.Parent=parent
local pad=Instance.new("UIPadding");pad.PaddingLeft=UDim.new(0,5);pad.PaddingRight=UDim.new(0,5);pad.Parent=box
local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,6);corner.Parent=box
return box
end
local TweenService = game:GetService("TweenService")
local Assets = require(script.Parent.Assets)
local CardImpact = require(script.Parent.CardImpact)
local HeadLook=require(script.Parent.HeadLook)
local headLook
local Loadout=require(script.Parent.Loadout)
local Scene = {CameraTuning=false,CameraLocked=true,ImpactActive=false}
local impactJob
local enemyLanes,enemyNodes={},{ }
local enemyDeckLabel,enemySupplyLabels,playerTarget
Scene.DuelMode=false;Scene.CanvasHeight=900
local cameraPreferences={}
local cameraLimits={distance={-5,12},height={6,24},pitch={18,70},fov={40,100}}
function Scene.IsMobileView(viewport)
local input=game:GetService("UserInputService")
return input.TouchEnabled or viewport.Y>viewport.X or (viewport.X<=1000 and viewport.Y<=600)
end
local function cameraMode(viewport)return (if Scene.DuelMode then "duel-"else "")..(if Scene.IsMobileView(viewport)then "phone-"else "desktop-")..(if viewport.X<viewport.Y then "portrait" else "landscape")end
function Scene.GetCameraSettings(viewport)
if Scene.IsMobileView(viewport)then return {distance=.5,height=24,pitch=70,fov=77}end
local mode=cameraMode(viewport)
if not cameraPreferences[mode]then
 cameraPreferences[mode]=if Scene.IsMobileView(viewport)then {distance=8,height=18,pitch=42,fov=80}elseif Scene.DuelMode then {distance=-1.65,height=12.54,pitch=50.31,fov=71.92}else {distance=-2.38,height=10.15,pitch=44.14,fov=74.90}
end
return table.clone(cameraPreferences[mode])
end
function Scene.SetCameraSetting(viewport,key,value)
if Scene.CameraLocked or Scene.IsMobileView(viewport)then return false end
local bounds=cameraLimits[key]
if not bounds or type(value)~="number" or value~=value or math.abs(value)==math.huge then return false end
Scene.GetCameraSettings(viewport)
cameraPreferences[cameraMode(viewport)][key]=math.clamp(value,bounds[1],bounds[2]);return true
end
function Scene.ResetCameraSettings(viewport)
cameraPreferences[cameraMode(viewport)]=nil;Scene.CameraLocked=false
end
local C = { gold=Color3.fromRGB(202,164,88), paper=Color3.fromRGB(239,213,158),
ink=Color3.fromRGB(22,21,16), green=Color3.fromRGB(22,51,36), red=Color3.fromRGB(120,37,34),
muted=Color3.fromRGB(198,193,160), active=Color3.fromRGB(255,211,86) }
local model, surface, board, head, home, cameraTween
local inputConnection
local handlers = {}
local lanes, nodes, buttons = {}, {}, {}
local targetLabel, damageLabel, deckLabel, helpLabel, roundLabel, receipt, session, selected, latest, dispatch
local hidden = {}
local lightingRestore, tone = {}, nil
local tableParts, placingOnTable = {}, false
local tableMesh, tableMeshHome
local promptEnabledBefore
local characterConnections={}
local selfHumanoid,selfDisplay
local jokerCards={}
local layoutHomes={}
local raceOpenFrame,raceOpenSlotGui,raceOpenPart
-- Presentation-only tilt around the near rail. Lobby geometry stays level.
local tableTilt=CFrame.new(19,4.77,-3.275)*CFrame.Angles(math.rad(12),0,0)*CFrame.new(-19,-4.77,3.275)
local function make(class, props, parent)
local obj=Instance.new(class); for k,v in props do obj[k]=v end; obj.Parent=parent; return obj
end
local function part(name,size,pos,color,material)
local p=make("Part",{Name=name,Size=size,Position=pos,Color=color,Material=material or Enum.Material.SmoothPlastic,
Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false},model)
if placingOnTable then table.insert(tableParts,p) end
return p
end
local function outline(obj,color,width)
return make("UIStroke",{Color=color or C.gold,Thickness=width or 2,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},obj)
end
local function label(parent,name,value,x,y,w,h,size,color)
return make("TextLabel",{Name=name,Text=value,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
BackgroundTransparency=1,TextColor3=color or C.paper,Font=Enum.Font.GothamMedium,TextSize=size or 34,
TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Center},parent)
end
local function plaque(parent,name,value,x,y,w,h,color)
local p=make("Frame",{Name=name,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=color or C.green,BorderSizePixel=0},parent)
make("UICorner",{CornerRadius=UDim.new(0,9)},p);outline(p)
return p,label(p,"Text",value,5,3,w-10,h-6,32)
end
local function raisedPlaque(playerGui,name,x,z,width,height,caption)
local y=4.82+height*.5*math.cos(math.rad(55))
local plate=part(name,Vector3.new(width,height,.11),Vector3.new(x,y,z),C.gold,Enum.Material.Metal)
plate.CFrame=CFrame.new(x,y,z)*CFrame.Angles(math.rad(-55),0,0)
table.insert(tableParts,plate)
local canvasWidth=math.floor(180*width/height)
local gui=make("SurfaceGui",{Name=name.."Face",Adornee=plate,Face=Enum.NormalId.Back,CanvasSize=Vector2.new(canvasWidth,180),LightInfluence=0,AlwaysOnTop=false},plate)
local frame=make("Frame",{Size=UDim2.new(1,-16,1,-16),Position=UDim2.fromOffset(8,8),BackgroundColor3=C.paper,BorderSizePixel=0},gui);outline(frame,Color3.fromRGB(134,98,44),4)
if caption then label(frame,"Caption",caption,0,6,canvasWidth-16,34,28,C.ink) end
local value=label(frame,"Value","—",0,if caption then 40 else 0,canvasWidth-16,if caption then 118 else 164,110,C.ink)
value.Font=Enum.Font.GothamBold
return value
end
local function action(parent,name,value,x,y,w,h,color,callback)
local b=make("TextButton",{Name=name,Text=value,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
BackgroundColor3=color,BorderSizePixel=0,TextColor3=C.paper,Font=Enum.Font.GothamBold,TextSize=34,AutoButtonColor=true},parent)
make("UICorner",{CornerRadius=UDim.new(0,8)},b);outline(b)
handlers[b]=function()if b:GetAttribute("Enabled") and dispatch then callback() end end
return b
end
local function enable(b,value)
b:SetAttribute("Enabled",value);b.Active=value;b.AutoButtonColor=value;b.TextTransparency=if value then 0 else .55
for _,child in b:GetDescendants() do if child:IsA("TextLabel") then child.TextTransparency=if value then 0 else .55 end end
end
local function hideRoomDetail(obj)
if obj:IsA("BasePart") then hidden[obj]=obj.LocalTransparencyModifier;obj.LocalTransparencyModifier=1
elseif obj:IsA("LayerCollector") then hidden[obj]=obj.Enabled;obj.Enabled=false end
end
function Scene.Destroy()
if headLook then headLook:Destroy();headLook=nil end
for _,connection in characterConnections do connection:Disconnect()end;characterConnections={}
if selfHumanoid and selfHumanoid.Parent then selfHumanoid.DisplayDistanceType=selfDisplay end;selfHumanoid=nil;selfDisplay=nil
if promptEnabledBefore~=nil then game:GetService("ProximityPromptService").Enabled=promptEnabledBefore;promptEnabledBefore=nil end
if impactJob then impactJob:Cancel();impactJob=nil end;Scene.ImpactActive=false
 Scene.CameraTuning=false;Scene.DuelMode=false;Scene.CanvasHeight=900;Scene.RaceMode=false
enemyLanes={};enemyNodes={};enemyDeckLabel=nil;enemySupplyLabels={};playerTarget=nil
if raceOpenSlotGui then raceOpenSlotGui:Destroy();raceOpenSlotGui=nil end
raceOpenFrame=nil;raceOpenPart=nil
if tableMesh and tableMesh.Parent and tableMeshHome then tableMesh.CFrame=tableMeshHome end
tableMesh=nil;tableMeshHome=nil;tableParts={};layoutHomes={};jokerCards={};placingOnTable=false
if inputConnection then inputConnection:Disconnect();inputConnection=nil end
if cameraTween then cameraTween:Cancel();cameraTween=nil end
for obj,value in hidden do if obj.Parent then if obj:IsA("BasePart") then obj.LocalTransparencyModifier=value else obj.Enabled=value end end end
hidden={}
for light,value in lightingRestore do if light.Parent then light.Brightness=value end end;lightingRestore={}
if tone then tone:Destroy();tone=nil end
if surface then surface:Destroy() end;surface=nil
if model then model:Destroy() end;model=nil;head=nil
lanes={};nodes={};buttons={};handlers={};receipt=0;session=nil;latest=nil;selected=nil;dispatch=nil
end
local function opponent()
-- Block silhouette, brimmed hat, red scarf and cards held above the far rail.
part("Coat",Vector3.new(3.4,2.8,1.5),Vector3.new(19,6.25,-12.8),Color3.fromRGB(23,26,29))
part("Waistcoat",Vector3.new(1.65,2.3,.14),Vector3.new(19,6.2,-12),Color3.fromRGB(86,35,31))
head=part("Head",Vector3.new(1.85,1.8,1.7),Vector3.new(19,8.4,-12.6),Color3.fromRGB(225,177,112));home=head.CFrame
make("SpecialMesh",{MeshType=Enum.MeshType.Head},head)
-- Faces are geometry so they do not depend on a private decal.
for i=1,4 do
 local lock=part("HairLock",Vector3.new(.38,.62,.16),Vector3.new(18.3+i*.29,8.96,-11.7),Color3.fromRGB(22,19,18));lock.Orientation=Vector3.new(0,0,20-i*7)
end
part("Hair",Vector3.new(1.98,.55,1.78),Vector3.new(19,9.13,-12.6),Color3.fromRGB(23,20,18))
local brim=part("HatBrim",Vector3.new(.18,3.2,2.6),Vector3.new(19,9.45,-12.6),Color3.fromRGB(21,23,26));brim.Shape=Enum.PartType.Cylinder;brim.Orientation=Vector3.new(0,0,90)
local crown=part("HatCrown",Vector3.new(1.05,2.1,1.9),Vector3.new(19,10,-12.6),Color3.fromRGB(25,26,29));crown.Shape=Enum.PartType.Cylinder;crown.Orientation=Vector3.new(0,0,90)
local ribbon=part("HatRibbon",Vector3.new(.24,2.14,1.94),Vector3.new(19,9.65,-12.6),C.red);ribbon.Shape=Enum.PartType.Cylinder;ribbon.Orientation=Vector3.new(0,0,90)
part("Scarf",Vector3.new(2.1,.5,1.88),Vector3.new(19,7.43,-12.6),C.red)
local tail=part("ScarfTail",Vector3.new(.6,1.45,.18),Vector3.new(19.6,6.55,-11.9),C.red);tail.Orientation=Vector3.new(0,0,-15)
for _,side in {-1,1} do
 local sleeve=part("Sleeve",Vector3.new(.95,1.15,2),Vector3.new(19+side*1.6,5.5,-11.6),Color3.fromRGB(25,28,31));sleeve.Orientation=Vector3.new(-12,side*15,0)
 part("Hand",Vector3.new(.82,.5,.8),Vector3.new(19+side*1.45,5.15,-10.7),Color3.fromRGB(225,177,112))
 part("Eye",Vector3.new(.13,.23,.05),Vector3.new(19+side*.36,8.5,-11.72),C.ink)
 local brow=part("Brow",Vector3.new(.38,.07,.05),Vector3.new(19+side*.36,8.77,-11.72),C.ink);brow.Orientation=Vector3.new(0,0,side*12)
end
part("Smile",Vector3.new(.44,.075,.05),Vector3.new(19,8,-11.72),C.ink)
local lapel=part("Lapel",Vector3.new(.24,1.6,.12),Vector3.new(17.9,6.3,-11.94),C.gold,Enum.Material.Metal);lapel.Orientation=Vector3.new(0,0,-18)
for i=1,3 do
 local card=part("OpponentCard",Vector3.new(.75,1.1,.045),Vector3.new(19+(i-2)*.4,6.65,-11.15),C.red)
 card.Orientation=Vector3.new(-14,0,(i-2)*-12)
 local trim=make("SurfaceGui",{Face=Enum.NormalId.Front,CanvasSize=Vector2.new(120,170),LightInfluence=0},card)
 local face=make("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=C.red,BorderSizePixel=0},trim);outline(face,C.paper,2)
 label(face,"Suit","♠",0,25,112,110,60,C.paper)
end
end
local function props()
local foot=part("LanternFoot",Vector3.new(1,.13,1),Vector3.new(10.8,4.8,-7.5),C.ink,Enum.Material.Metal)
part("LanternGlass",Vector3.new(.65,1.05,.65),foot.Position+Vector3.new(0,.58,0),Color3.fromRGB(255,187,63),Enum.Material.Neon)
for _,x in {-.4,.4} do for _,z in {-.4,.4} do part("LanternFrame",Vector3.new(.08,1.2,.08),foot.Position+Vector3.new(x,.65,z),C.ink,Enum.Material.Metal) end end
part("LanternRoof",Vector3.new(1.05,.23,1.05),foot.Position+Vector3.new(0,1.3,0),C.ink,Enum.Material.Metal)
make("PointLight",{Color=Color3.fromRGB(255,192,100),Brightness=.6,Range=9,Shadows=false},foot)
for i=1,7 do
 local coin=part("Coin",Vector3.new(.06,.45,.45),Vector3.new(11.15+(i%2)*.48,4.8+math.floor((i-1)/2)*.07,-8.7),C.gold,Enum.Material.Metal)
 coin.Shape=Enum.PartType.Cylinder;coin.Orientation=Vector3.new(0,0,90)
end
end
function Scene.Create(playerGui,send,duel,presentation)
Scene.Destroy();dispatch=send;Scene.DuelMode=duel==true;Scene.RaceMode=presentation and presentation.mode=="race" or false;Scene.CanvasHeight=if duel then 1100 else 900
headLook=HeadLook.Create(Scene)
Scene.Network=presentation and presentation.network==true
Scene.WorldFrame=if Scene.Network then CFrame.new(0,0,-7)*CFrame.Angles(0,if presentation.seatIndex==2 then math.pi else 0,0)*CFrame.new(0,0,7)*CFrame.new(19,0,0)else CFrame.new()
model=make("Model",{Name="VochkoLocalBattleScene"},workspace)
local prompts=game:GetService("ProximityPromptService");promptEnabledBefore=prompts.Enabled;prompts.Enabled=false
local player=game:GetService("Players").LocalPlayer
local function hideCharacter(character)
 for _,p in character:GetDescendants()do if p:IsA("BasePart")then hideRoomDetail(p)end end
 local humanoid=character:FindFirstChildOfClass("Humanoid")
 if humanoid then selfHumanoid=humanoid;selfDisplay=humanoid.DisplayDistanceType;humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None end
 table.insert(characterConnections,character.DescendantAdded:Connect(function(p)if p:IsA("BasePart")then hideRoomDetail(p)end end))
end
if player.Character then hideCharacter(player.Character)end
table.insert(characterConnections,player.CharacterAdded:Connect(function(character)hideCharacter(character)end))
local room=workspace:FindFirstChild("VochkoPrototype")
if room then
 for _,obj in room:GetDescendants() do
  if obj:IsA("BillboardGui") or (obj:IsA("SurfaceGui") and obj.Parent.Name=="WelcomePlaque") or (obj:IsA("BasePart") and (obj.Name=="LaneEdge" or obj.Name=="WelcomePlaque" or ((obj.Name=="CardDeck" or obj.Name=="DeckPaper" or obj.Name=="OpenCardSlot") and not Scene.RaceMode))) then hideRoomDetail(obj) end
  if obj:IsA("Light") then lightingRestore[obj]=obj.Brightness;obj.Brightness*=.45 end
  if duel and obj:IsA("BasePart")and obj.Parent.Name==(if Scene.Network then 'CentralTableLamp'else 'DuelTableLamp')then hideRoomDetail(obj)end
  -- The fixed phone camera sits near the ceiling: beams must not hide the felt.
  if obj:IsA("BasePart")and obj.Name=="Beam"then hideRoomDetail(obj)end
 end
end
tone=make("ColorCorrectionEffect",{Name="VochkoBattleTone",Brightness=-.025,Contrast=.08,Saturation=-.14,TintColor=Color3.fromRGB(255,242,221)},game:GetService("Lighting"))
opponent()
if Scene.Network then for _,p in model:GetDescendants()do if p:IsA('BasePart')then p.Transparency=1 end end end
if duel then for _,p in model:GetDescendants()do if p:IsA("BasePart")then p.CFrame=CFrame.new(0,0,-1.6)*p.CFrame end end end
placingOnTable=true;props();placingOnTable=false
-- Blue night windows and hanging guild banners frame the opponent.
for _,x in {12,26} do
 part("WindowFrame",Vector3.new(3.4,6.6,.25),Vector3.new(x,9,-23.1),Color3.fromRGB(58,32,22),Enum.Material.Wood)
 part("NightGlass",Vector3.new(2.9,6,.12),Vector3.new(x,9,-22.9),Color3.fromRGB(32,53,119),Enum.Material.Neon)
 part("WindowMullion",Vector3.new(.13,6,.17),Vector3.new(x,9,-22.8),C.ink,Enum.Material.Wood)
 part("WindowCrossbar",Vector3.new(3,.13,.17),Vector3.new(x,9,-22.8),C.ink,Enum.Material.Wood)
end
for _,x in {16,22} do
 part("GuildBanner",Vector3.new(1.7,4.8,.12),Vector3.new(x,12,-22.9),Color3.fromRGB(90,26,30),Enum.Material.Fabric)
 part("BannerRod",Vector3.new(2,.1,.2),Vector3.new(x,14.4,-22.8),C.gold,Enum.Material.Metal)
end
-- A real SurfaceGui on the felt, not a screen overlay. PlayerGui parenting enables touch/mouse input.
local plane=part("TableInterface",Vector3.new(7.25,.01,16.6),Vector3.new(19,4.77,-6.9),C.green)
plane.CFrame=CFrame.new(19,4.77,-6.9)*CFrame.Angles(0,-math.pi/2,0)
plane.Transparency=1;plane.CanQuery=true;table.insert(tableParts,plane)
surface=make("SurfaceGui",{Name="VochkoTableUI",Adornee=plane,Face=Enum.NormalId.Top,CanvasSize=Vector2.new(1800,900),
SizingMode=Enum.SurfaceGuiSizingMode.FixedSize,AlwaysOnTop=false,LightInfluence=0,MaxDistance=100,ClipsDescendants=false,Active=true,ZOffset=.015},playerGui)
board=make("Frame",{Name="FeltLayout",Size=UDim2.fromScale(1,1),BackgroundTransparency=1},surface)
targetLabel=raisedPlaque(playerGui,"TargetPlaque",12.65,-9.35,2.9,1.05,"НУЖНО НАБРАТЬ")
for i,item in {"minus2","minus4"} do
 buttons[item]=action(board,item,"",150,345+(i-1)*135,225,108,C.green,function()
  selected=if selected==item then nil else item
  if latest then Scene.Update(latest) end
 end)
 local button=buttons[item]
 local icon=label(button,"Icon","✂",8,12,90,75,64,C.paper);icon.Font=Enum.Font.ArialBold
 label(button,"Name",if item=="minus2" then "Срез −2" else "Срез −4",95,40,115,50,27,C.paper)
 local counter=label(button,"Count","1",175,7,35,35,26,C.ink);counter.BackgroundColor3=C.gold;counter.BackgroundTransparency=0
 make("UICorner",{CornerRadius=UDim.new(1,0)},counter)
end
ownTarotLabel=label(board,"TarotEffects","",if duel then 35 else 45,if duel then 450 else 690,315,if duel then 135 else 90,20,C.paper)
ownTarotLabel.TextWrapped=true;ownTarotLabel.TextXAlignment=Enum.TextXAlignment.Left;ownTarotLabel.TextYAlignment=Enum.TextYAlignment.Top;ownTarotLabel.RichText=true
if duel then
 opponentTarotLabel=label(board,"EnemyTarotEffects","",1450,355,300,175,20,C.paper)
 opponentTarotLabel.TextWrapped=true;opponentTarotLabel.TextXAlignment=Enum.TextXAlignment.Left;opponentTarotLabel.TextYAlignment=Enum.TextYAlignment.Top;opponentTarotLabel.RichText=true
end
label(board,"Chapter","ТЕМНИЦА  ·  БОЙ I",775,28,585,50,30,C.muted)
label(board,"SuppliesTitle","РАСХОДНИКИ",135,260,240,50,29,C.muted)
local roundBox=make("Frame",{Name="RoundCounter",Position=UDim2.fromOffset(135,640),Size=UDim2.fromOffset(240,90),BackgroundColor3=C.ink,BorderSizePixel=0},board);outline(roundBox,C.gold,2);make("UICorner",{CornerRadius=UDim.new(0,8)},roundBox)
label(roundBox,"Title","ХОДЫ",8,3,224,30,30,C.gold).TextXAlignment=Enum.TextXAlignment.Center
roundLabel=label(roundBox,"Value","",8,35,224,50,46,C.paper);roundLabel.TextXAlignment=Enum.TextXAlignment.Center
for i=1,3 do
 local x=380+(i-1)*330
 local lane=make("Frame",{Name="Zone"..i,Position=UDim2.fromOffset(x,135),Size=UDim2.fromOffset(310,495),BackgroundColor3=C.green,BackgroundTransparency=1,BorderSizePixel=0},board)
 make("UICorner",{CornerRadius=UDim.new(0,16)},lane)
 local border=outline(lane,C.gold,2);border.Transparency=.55
 local sum=raisedPlaque(playerGui,"ScorePlaque"..i,19+((x+155)-900)/1800*16.6,-6.9+(179-450)/900*7.25,2.7,1.02,"СУММА")
 local tarot=tarotBox(lane,145,160,158,210)
 local status=label(lane,"Status","ЖДЁТ",18,84,274,55,24,C.muted)
 label(lane,"Name","Стол "..i,20,455,270,35,35)
 local click=make("TextButton",{Name="UseItem",Size=UDim2.fromScale(1,1),Text="",BackgroundTransparency=1,ZIndex=50,Visible=false},lane)
 handlers[click]=function()if selected and latest and latest.phase=="combat" then dispatch("consume",{item=selected,zone=i})end end
 lanes[i]={root=lane,sum=sum,status=status,tarot=tarot,border=border,click=click,scale=make("UIScale",{Scale=1},sum),prevSum=""}
end
-- Real layered stack with a raised burgundy top, bevel-like paper edges and a patterned back.
placingOnTable=true
local deckFrame=CFrame.new(25.34,4.79,-7.95)*CFrame.Angles(0,math.rad(-99),0)
for i=1,13 do
 local paper=part("DeckPaperLayer"..i,Vector3.new(2.24,.025,1.64),Vector3.new(),if i%2==0 then Color3.fromRGB(184,157,119)else Color3.fromRGB(226,207,174))
 paper.CFrame=deckFrame*CFrame.new(0,i*.035,0)
end
local topCard=part("DeckTop",Vector3.new(2.26,.055,1.66),Vector3.new(),C.red)
topCard.CFrame=deckFrame*CFrame.new(0,.5,0)
local backGui=make("SurfaceGui",{Face=Enum.NormalId.Top,CanvasSize=Vector2.new(300,420),LightInfluence=.15},topCard)
local back=make("Frame",{Position=UDim2.fromOffset(10,10),Size=UDim2.new(1,-20,1,-20),BackgroundColor3=C.red,BorderSizePixel=0},backGui)
make("UICorner",{CornerRadius=UDim.new(0,14)},back);outline(back,C.paper,5)
local inner=make("Frame",{Position=UDim2.fromOffset(12,12),Size=UDim2.new(1,-24,1,-24),BackgroundTransparency=1},back);outline(inner,C.gold,2)
label(back,"Spade","♠",20,105,240,180,145,C.paper)
for _,xy in {{15,12},{225,12},{15,340},{225,340}} do label(back,"Corner","✦",xy[1],xy[2],40,40,34,C.gold)end
placingOnTable=false
label(board,"DeckTitle","КОЛОДА",1490,465,210,35,28,C.muted)
deckLabel=label(board,"DeckCount","52 / 52",1490,505,210,50,36)
damageLabel=raisedPlaque(playerGui,"DamagePlaque",19,-4.95,5.4,.52);damageLabel.TextSize=100
helpLabel=label(board,"Help","Добирай к цели. Перебор можно исправить срезом.",420,733,960,40,26,C.muted)
buttons.draw=action(board,"Draw","ВЗЯТЬ КАРТУ",385,796,330,80,C.gold,function()dispatch("draw")end);buttons.draw.TextColor3=C.ink
buttons.stop=action(board,"Stop","СТОП НА СТОЛЕ",740,796,330,80,C.green,function()dispatch("stop")end)
buttons.hide=action(board,"SleeveHide","В рукав",115,if duel then 895 else 630,110,52,C.green,function()dispatch("consume",{item="hide"})end)
buttons.release=action(board,"SleeveRelease","Из рукава",235,if duel then 895 else 630,110,52,C.green,function()dispatch("consume",{item="release"})end)
buttons.hide.TextSize=20;buttons.hide.TextWrapped=true;buttons.release.TextSize=20;buttons.release.TextWrapped=true
-- Sleeve controls are paused for this version, including world hit testing.
buttons.hide.Visible=false;buttons.release.Visible=false
buttons.play=action(board,"Play","СЫГРАТЬ ХОД",1095,796,330,80,C.red,function()dispatch("play")end)
-- Route pointer input through the table plane. This also works for touch and
-- avoids ScreenGui/SurfaceGui hit-test differences in Studio and on devices.
inputConnection=game:GetService("UserInputService").InputBegan:Connect(function(input)
 if Scene.CameraTuning or Scene.HUDTuning or Scene.ImpactActive then return end
 local UIS=game:GetService('UserInputService')
 local pointer=if input.UserInputType==Enum.UserInputType.Touch then Vector2.new(input.Position.X,input.Position.Y)+game:GetService('GuiService'):GetGuiInset()else UIS:GetMouseLocation()
 for _,object in playerGui:GetGuiObjectsAtPosition(pointer.X,pointer.Y)do if object:IsA('GuiButton')and object:FindFirstAncestorOfClass('ScreenGui')then return end end
 if input.UserInputType==Enum.UserInputType.MouseButton2 then headLook:Begin(input);return end
 if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
 if game:GetService("UserInputService"):GetFocusedTextBox() then return end
 local camera=workspace.CurrentCamera;if not camera or not plane.Parent then return end
 -- InputObject.Position omits the top GUI inset; viewport rays do not.
 -- MouseLocation includes it. Touch needs the inset restored explicitly.
 local ray=camera:ViewportPointToRay(pointer.X,pointer.Y)
 local normal=plane.CFrame.UpVector
 local denominator=ray.Direction:Dot(normal)
 if math.abs(denominator)<.0001 then return end
 local distance=(plane.Position+normal*(plane.Size.Y/2)-ray.Origin):Dot(normal)/denominator
 if distance<=0 then return end
 local point=plane.CFrame:PointToObjectSpace(ray.Origin+ray.Direction*distance)
 local x=(.5-point.Z/plane.Size.Z)*1800
 local y=(.5+point.X/plane.Size.X)*Scene.CanvasHeight
 for object,callback in handlers do
  if object.Parent and object.Visible then
   local pos,size=object.AbsolutePosition,object.AbsoluteSize
   if x>=pos.X and x<=pos.X+size.X and y>=pos.Y and y<=pos.Y+size.Y then callback();return end
  end
 end
 if input.UserInputType==Enum.UserInputType.Touch then headLook:Begin(input)end
end)
if duel then
 plane.Size=Vector3.new(10.3,.01,16.6);plane.CFrame=CFrame.new(19,4.77,-7.1)*CFrame.Angles(0,-math.pi/2,0)
 surface.CanvasSize=Vector2.new(1800,1100)
 board.Chapter.Text="ДУЭЛЬ · ИИ ГОТОВ";board.Chapter.Position=UDim2.fromOffset(650,10)
 local function positionAt(x,y)return 19+(x-900)/1800*16.6,-7.1+(y-550)/1100*10.3 end
 for i,lane in lanes do
  local x=380+(i-1)*330
  lane.root.Position=UDim2.fromOffset(x,645);lane.root.Size=UDim2.fromOffset(310,240)
  local title=lane.root:FindFirstChild("Name");title.Position=UDim2.fromOffset(20,205);title.Size=UDim2.fromOffset(270,30);title.TextSize=26
  lane.tarot.Position=UDim2.fromOffset(140,36);lane.tarot.Size=UDim2.fromOffset(160,160)
  lane.status.Position=UDim2.fromOffset(12,0);lane.status.Size=UDim2.fromOffset(286,38);lane.status.TextSize=20
  lane.sum.Parent.Parent.Parent:Destroy()
  local sx,sz=positionAt(x+155,595)
  lane.sum=raisedPlaque(playerGui,"ScorePlaque"..i,sx,sz,2.6,.6)
  lane.scale=make("UIScale",{Scale=1},lane.sum)
  local root=make("Frame",{Name="EnemyZone"..i,Position=UDim2.fromOffset(x,65),Size=UDim2.fromOffset(310,240),BackgroundColor3=C.red,BackgroundTransparency=.9,BorderSizePixel=0},board)
  make("UICorner",{CornerRadius=UDim.new(0,14)},root)
  local border=outline(root,Color3.fromRGB(210,75,65),3)
  local ex,ez=positionAt(x+155,25)
  local sum=raisedPlaque(playerGui,"EnemyScorePlaque"..i,ex,ez,2.6,.6)
  local state=label(root,"Status","ГОТОВ",8,0,294,32,20,C.muted)
  label(root,"Name","Стол "..(i+3),12,205,286,30,26)
  local tarot=tarotBox(root,140,36,160,160)
  enemyLanes[i]={root=root,sum=sum,status=state,border=border,tarot=tarot,scale=make("UIScale",{Scale=1},sum),prevSum=""}
 end
 for _,n in {"DeckLayer4","DeckLayer3","DeckLayer2","DeckLayer1","Deck"}do local o=board:FindFirstChild(n);if o then o:Destroy()end end
 targetLabel.Parent.Parent.Parent:Destroy()
 local tx,tz=positionAt(900,435);targetLabel=raisedPlaque(playerGui,"TargetPlaque",tx,tz,2.8,.65,"ЦЕЛЬ")
 damageLabel.Parent.Parent.Parent:Destroy()
 local dx,dz=positionAt(900,930);damageLabel=raisedPlaque(playerGui,"DamagePlaque",dx,dz,5,.48);damageLabel.TextSize=100
 helpLabel.Position=UDim2.fromOffset(420,970);helpLabel.Size=UDim2.fromOffset(960,25);helpLabel.TextSize=18
 for _,b in {buttons.draw,buttons.stop,buttons.play}do b.Position=UDim2.new(b.Position.X.Scale,b.Position.X.Offset,0,1005);b.Size=UDim2.fromOffset(330,65)end
 buttons.play.Text="СЫГРАТЬ ХОД"
 for i,item in {"minus2","minus4"}do buttons[item].Position=UDim2.fromOffset(115,650+(i-1)*115);buttons[item].Size=UDim2.fromOffset(230,100)end
 board.SuppliesTitle.Position=UDim2.fromOffset(110,590);board.SuppliesTitle.Size=UDim2.fromOffset(235,45)
 roundBox.Position=UDim2.fromOffset(110,465);roundBox.Size=UDim2.fromOffset(235,105)
 roundLabel.Position=UDim2.fromOffset(8,42);roundLabel.Size=UDim2.fromOffset(219,56)
 label(board,"OwnJokersTitle","ТВОИ ДЖОКЕРЫ",85,870,280,24,22,C.gold)
 label(board,"EnemyJokersTitle","ДЖОКЕРЫ ИИ",1460,345,280,32,22,C.gold)
 for _,side in {"own","enemy"}do
  jokerCards[side]={}
  for i=1,2 do
   local x=(if side=="own"then 85 else 1460)+(i-1)*145
   local y=if side=="own"then 900 else 385
   local frame=action(board,side.."Joker"..i,"",x,y,135,95,C.ink,function()
    local card=jokerCards[side][i]
    if side=="own"and card and card.id=="xray"then dispatch("consume",{item="scan"})end
   end)
   local symbol=label(frame,"Symbol","✦",6,3,40,40,32,C.gold)
   local title=label(frame,"Title","Джокер",8,42,120,48,23,C.paper)
   local charges=label(frame,"Charges","",48,5,80,30,20,C.gold)
   local art=make('Frame',{Name='Artwork',Position=UDim2.fromOffset(5,5),Size=UDim2.fromOffset(48,85),BackgroundTransparency=1},frame)
   jokerCards[side][i]={frame=frame,title=title,symbol=symbol,charges=charges,art=art}
  end
 end
 local originals={}
 for _,o in tableParts do if o.Name=="DeckTop"or string.find(o.Name,"DeckPaperLayer",1,true)then table.insert(originals,o)end end
 for _,o in originals do
  local clone=o:Clone();clone.Name="Enemy"..o.Name;clone.CFrame=CFrame.new(-13.14,0,-1.7)*o.CFrame;clone.Parent=model;table.insert(tableParts,clone)
  o.CFrame=CFrame.new(0,0,2.35)*o.CFrame
 end
 board.DeckTitle.Position=UDim2.fromOffset(1490,830);deckLabel.Position=UDim2.fromOffset(1490,875)
 label(board,"EnemyDeckTitle","КОЛОДА ИИ",40,360,240,35,25,C.muted)
 enemyDeckLabel=label(board,"EnemyDeckCount","52 / 52",40,400,240,42,30)
 label(board,"EnemySupplyTitle","ПРЕДМЕТЫ ИИ",1475,125,255,35,24,C.muted)
 enemySupplyLabels={}
 for i,item in {"minus2","minus4"}do
  local _,value=plaque(board,"EnemySupply"..i,"",1480,175+(i-1)*85,240,65,C.green);value.TextSize=27;enemySupplyLabels[item]=value
 end
 playerTarget=part("PlayerImpactTarget",Vector3.new(.3,.3,.3),Vector3.new(19,5.5,-.2),C.paper);playerTarget.Transparency=1
end
local racePresentation=presentation and presentation.mode=="race"
if racePresentation then
 -- Shared race table: single horizontal deck in the centre with the open card right on top.
 local leftovers={}
 for _,p in tableParts do
  if p.Name=="DeckTop" or string.find(p.Name,"DeckPaperLayer",1,true) or string.find(p.Name,"EnemyDeck",1,true) or p.Name=="RaceOpenCard" then table.insert(leftovers,p) end
 end
 for _,p in leftovers do
  local index=table.find(tableParts,p);if index then table.remove(tableParts,index) end
  p:Destroy()
 end
 if board:FindFirstChild("EnemyDeckTitle") then board.EnemyDeckTitle.Visible=false end
 if board:FindFirstChild("EnemyDeckCount") then board.EnemyDeckCount.Visible=false end
 if board:FindFirstChild("OpenTitle") then board.OpenTitle.Visible=false end
 local function centerAt(x,y)return 19+(x-900)/1800*16.6,-7.1+(y-550)/1100*10.3 end
 local deckX,deckZ=centerAt(900,465)
 placingOnTable=true
 -- Horizontal deck: 2.38 along table width, 1.66 along depth
 local stack=CFrame.new(deckX,4.79,deckZ)*CFrame.Angles(0,math.rad(0),0)
 for i=1,13 do
  local sheet=part("SharedDeckLayer"..i,Vector3.new(2.36,.025,1.64),Vector3.new(),if i%2==0 then Color3.fromRGB(184,157,119)else Color3.fromRGB(226,207,174))
  sheet.CFrame=stack*CFrame.new(0,i*.035,0)
 end
 local lid=part("SharedDeckTop",Vector3.new(2.38,.055,1.66),Vector3.new(),C.red)
 lid.CFrame=stack*CFrame.new(0,.5,0)
 local openGui=make("SurfaceGui",{Name="RaceOpenFace",Adornee=lid,Face=Enum.NormalId.Top,CanvasSize=Vector2.new(340,235),LightInfluence=0.1,ZOffset=.03},lid)
 raceOpenFrame=make("Frame",{Name="Face",Size=UDim2.fromScale(1,1),BackgroundColor3=C.red,BorderSizePixel=0},openGui);outline(raceOpenFrame,C.gold,3)
 placingOnTable=false
 -- Left of deck: Deck count badge
 board.DeckTitle.Text="ОБЩАЯ КОЛОДА";board.DeckTitle.Position=UDim2.fromOffset(550,435);board.DeckTitle.Size=UDim2.fromOffset(190,26);board.DeckTitle.TextSize=22
 deckLabel.Position=UDim2.fromOffset(550,465);deckLabel.Size=UDim2.fromOffset(190,40);deckLabel.TextSize=32
 board.Chapter.Text=""
 buttons.play.Visible=false
 buttons["minus2"].Visible=false;buttons["minus4"].Visible=false
 -- Right of deck: Discard button
 buttons.discard=action(board,"RaceDiscard","СБРОС",1060,435,200,68,C.red,function()dispatch("discard")end)
 handlers[buttons.draw]=function()if buttons.draw:GetAttribute("Enabled")and dispatch then dispatch("grab")end end
 handlers[buttons.stop]=function()if buttons.stop:GetAttribute("Enabled")and dispatch then dispatch("stand")end end
end

-- The imported felt is uneven; ZOffset alone cannot prevent mesh occlusion.
-- Apply after both campaign and duel layouts have placed their interface.
plane.CFrame=plane.CFrame+Vector3.new(0,.14,0)
-- Apply the same transform to the mesh, plaques, felt and decorations.
-- Hit testing above uses the tilted plane normal rather than a horizontal Y.
local offset=if duel then CFrame.new(-38,0,0)else CFrame.new()
local tilt=if duel then CFrame.new(19,4.77,-1.95)*CFrame.Angles(math.rad(8),0,0)*CFrame.new(-19,-4.77,1.95)else tableTilt
for _,p in tableParts do if p.Parent then p.CFrame=tilt*p.CFrame end end
if duel then for _,p in model:GetDescendants()do if p:IsA("BasePart")then p.CFrame=offset*p.CFrame end end end
local station=room and room:FindFirstChild(if Scene.Network then 'Table_pvp'elseif duel then "Table_training"else "Table_campaign")
local visual=station and station:FindFirstChild("TavernTable")
tableMesh=visual and visual:FindFirstChildWhichIsA("MeshPart",true)
if tableMesh then tableMeshHome=tableMesh.CFrame;tableMesh.CFrame=offset*tilt*offset:Inverse()*(if Scene.Network then CFrame.new(-19,0,0)*tableMeshHome else tableMeshHome)end
if Scene.Network then
 for _,p in model:GetDescendants()do if p:IsA('BasePart')then p.CFrame=Scene.WorldFrame*p.CFrame end end
 if tableMesh then tableMesh.CFrame=Scene.WorldFrame*tableMesh.CFrame end
end
for _,p in tableParts do if p.Parent then layoutHomes[p]=p.CFrame end end
if tableMesh then layoutHomes[tableMesh]=tableMesh.CFrame end
end
function Scene.Camera(viewport,animate)
local camera=workspace.CurrentCamera;if not camera then return end
local settings=Scene.GetCameraSettings(viewport)
-- Move the entire felt assembly together, preserving card/label hit coordinates.
local delta=Vector3.new(0,0,if Scene.IsMobileView(viewport)then .55 else 0)
local shift=CFrame.new((Scene.WorldFrame or CFrame.new()):VectorToWorldSpace(delta))
if not Scene.ImpactActive then for p,base in layoutHomes do if p.Parent then p.CFrame=shift*base end end end
local frame=(Scene.WorldFrame or CFrame.new())*CFrame.new(if Scene.DuelMode then -19 else 19,settings.height,settings.distance)*CFrame.Angles(math.rad(-settings.pitch),0,0)
Scene.CameraBase=frame
camera.CameraType=Enum.CameraType.Scriptable
-- 80 degrees is the portrait framing baseline. Preserve its readable table
-- scale in landscape instead of exposing a very wide slice of the room.
local aspect=viewport.X/math.max(1,viewport.Y)
camera.FieldOfView=if Scene.IsMobileView(viewport)and aspect>1 then math.deg(2*math.atan(math.tan(math.rad(settings.fov/2))*.68/aspect))else settings.fov
if cameraTween then cameraTween:Cancel()end
if animate then cameraTween=TweenService:Create(camera,TweenInfo.new(.45,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{CFrame=frame});cameraTween:Play()
else camera.CFrame=frame end
end
local function cardFace(card)
local node=make("Frame",{Name="Card_"..card.id,Size=UDim2.fromOffset(144,200),BackgroundColor3=Color3.fromRGB(245,232,202),BorderSizePixel=0},board)
make("UICorner",{CornerRadius=UDim.new(0,9)},node);outline(node,Color3.fromRGB(167,139,86),2)
if card.tarot then
 if card.kind=="tarot"then
  local def=RaceTarot.Def(card.tarot);local good=def and def.good
  local base=if good then Color3.fromRGB(35,80,55)else Color3.fromRGB(82,38,35)
  node.BackgroundColor3=base;make("UIGradient",{Color=ColorSequence.new(base,Color3.fromRGB(15,25,20)),Rotation=55},node)
  label(node,"RaceSymbol",if def then def.symbol else "?",18,28,108,84,40,if good then C.paper else Color3.fromRGB(239,180,164))
  -- Race atlas skin over the fallback symbol. Holder is 5/6 of card width -> aspect always 0.6, matching the atlas cell exactly.
  local holder=make("Frame",{Name="RaceArt",AnchorPoint=Vector2.new(.5,0),Position=UDim2.fromScale(.5,0),Size=UDim2.fromScale(5/6,1),BackgroundTransparency=1,ClipsDescendants=true},node)
  Assets.CreateTarotArt(holder,card.tarot)
  local title=label(node,"RaceTitle",if def then def.name else "ТАРО",4,168,136,32,15,C.paper);title.BackgroundColor3=C.ink;title.BackgroundTransparency=.15
  return node
 end
 local fallback=label(node,"LoadingTitle",card.rank,5,12,80,105,18,C.ink);fallback.Size=UDim2.new(1,-10,1,-24);fallback.TextXAlignment=Enum.TextXAlignment.Center
 Assets.CreateTarotArt(node,card.tarot)
 if not Scene.DuelMode then local title=label(node,"TarotName",card.rank,3,159,138,38,19,C.paper);title.BackgroundColor3=C.ink;title.BackgroundTransparency=.1 end
 return node
end
-- Readable native face while the illustration is loading or unavailable to the experience.
local ink=if card.red then Color3.fromRGB(162,37,42)else C.ink
label(node,"Rank",card.rank..card.suit,9,3,126,35,33,ink).TextXAlignment=Enum.TextXAlignment.Left
label(node,"Suit",card.suit,10,62,124,90,70,ink)
local art=make("ImageLabel",{Name="Illustration",Image=Assets.Cards,ImageRectOffset=Vector2.new((card.rankIndex-1)*Assets.CardWidth,(card.suitIndex-1)*Assets.CardHeight),
ImageRectSize=Vector2.new(Assets.CardWidth,Assets.CardHeight),BackgroundTransparency=1,Size=UDim2.fromScale(1,1)},node)
-- Keep the image visible so Roblox starts loading it; the native face stays underneath.
return node
end
local function raceZoneText(z)
local lines={}
for _,card in z.cards do
 if card.kind=="tarot"then
  local def=RaceTarot.Def(card.tarot)
  table.insert(lines,(if def and def.good then "✦ "else "✧ ")..(if def then def.name else "Таро"))
 end
end
return table.concat(lines,"\n")
end
local function paintOpen(open)
if not raceOpenFrame then return end
raceOpenFrame:ClearAllChildren()
if not open then
 raceOpenFrame.BackgroundColor3=Color3.fromRGB(110,24,28)
 make("UIStroke",{Color=C.gold,Thickness=3},raceOpenFrame)
 label(raceOpenFrame,"DeckBackPattern","♠",0,35,328,110,72,C.paper)
 label(raceOpenFrame,"DeckBackTitle","КОЛОДА",0,150,328,40,26,C.paper)
 return
end
if open.kind=="tarot"then
 raceOpenFrame.BackgroundColor3=Color3.fromRGB(38,30,52)
 make("UIStroke",{Color=C.gold,Thickness=3},raceOpenFrame)
 if open.hidden or open.back then
  label(raceOpenFrame,"Symbol","?",0,25,328,90,64,C.gold)
  label(raceOpenFrame,"Title","ТАРО",0,120,328,34,26,C.paper)
  label(raceOpenFrame,"Hint","личность при взятии",0,160,328,32,18,C.muted)
 else
  local sym=if open.symbol then open.symbol else RaceTarot.Symbol(open.id)
  local name=if open.name then open.name else RaceTarot.Name(open.id)
  local good=if open.good~=nil then open.good else RaceTarot.IsGood(open.id)
  raceOpenFrame.BackgroundColor3=if good then Color3.fromRGB(35,80,55)else Color3.fromRGB(82,38,35)
  make("UIGradient",{Color=ColorSequence.new(raceOpenFrame.BackgroundColor3,Color3.fromRGB(15,25,20)),Rotation=55},raceOpenFrame)
  label(raceOpenFrame,"Symbol",sym,0,15,328,80,54,C.gold)
  -- Revealed tarot shows the race-atlas skin (aspect 0.6: height 223 -> width ~134) over the fallback text.
  local holder=make("Frame",{Name="OpenArt",AnchorPoint=Vector2.new(.5,0),Position=UDim2.fromScale(.5,0),Size=UDim2.fromOffset(134,223),BackgroundTransparency=1},raceOpenFrame)
  Assets.CreateTarotArt(holder,open.id)
  local chip=make("Frame",{Name="TitleChip",Position=UDim2.fromOffset(24,178),Size=UDim2.fromOffset(280,38),BackgroundColor3=C.ink,BackgroundTransparency=.15,BorderSizePixel=0},raceOpenFrame)
  label(chip,"RevealTitle",name.."  ·  "..(if good then "✦ ХОРОШЕЕ"else "✧ ПЛОХОЕ"),6,1,268,36,17,if good then C.good else Color3.fromRGB(239,180,164)).TextXAlignment=Enum.TextXAlignment.Center
 end
elseif open.hidden or open.back then
 raceOpenFrame.BackgroundColor3=Color3.fromRGB(110,24,28)
 make("UIStroke",{Color=C.gold,Thickness=3},raceOpenFrame)
 label(raceOpenFrame,"Back","♠",0,45,328,110,72,C.paper)
else
 raceOpenFrame.BackgroundColor3=Color3.fromRGB(246,240,225)
 make("UIStroke",{Color=Color3.fromRGB(80,50,30),Thickness=2},raceOpenFrame)
 local ink=if open.red then Color3.fromRGB(180,30,35)else Color3.fromRGB(25,25,30)
 local tag=(open.rank or "")..(open.suit or "")
 local tl=label(raceOpenFrame,"TL",tag,12,8,80,36,28,ink);tl.TextXAlignment=Enum.TextXAlignment.Left
 local br=label(raceOpenFrame,"BR",tag,328-92,223-44,80,36,28,ink);br.TextXAlignment=Enum.TextXAlignment.Right
 -- Native readable face under the illustration: blank atlas (private asset) still shows rank+suit.
 label(raceOpenFrame,"RankCenter",open.rank or "",0,14,328,44,32,ink)
 label(raceOpenFrame,"SuitCenter",open.suit or "",0,58,328,116,88,ink)
 if open.rankIndex and open.suitIndex then
  make("ImageLabel",{Name="Illu",Image=Assets.Cards,ImageRectOffset=Vector2.new((open.rankIndex-1)*Assets.CardWidth,(open.suitIndex-1)*Assets.CardHeight),ImageRectSize=Vector2.new(Assets.CardWidth,Assets.CardHeight),BackgroundTransparency=1,Size=UDim2.fromOffset(118,164),Position=UDim2.fromOffset((328-118)/2,(223-164)/2)},raceOpenFrame)
 end
end
end

local function zoneTarotText(z,r,duel,target)
local lines={}
if r.bust then table.insert(lines,'<font color="#ff8c77">Перебор: 0 урона</font>')
else
 if r.exact then table.insert(lines,"<b>Точно в цель</b>")end
 if r.colorBonus and r.colorBonus>0 then table.insert(lines,"♠ Урон +"..r.colorBonus.."%")end
 if r.heal and r.heal>0 then table.insert(lines,'<font color="#b9e5a2">♥ Лечение +'..r.heal..' HP</font>')end
 if r.critical then table.insert(lines,"Три туза: урон ×2")end
 if r.royal then table.insert(lines,"Три короля: без перебора")end
end
for _,c in z.cards do if c.tarot then
 local caption=Tarot.Caption(c.tarot,duel,target)
 local compact={moon="Входящий −30%",sun=if duel then "Урон +25%"else "Урон +40%",tower="Стол очищен",echo=if duel then "Урон +50%"else "Урон ×2",scales=if duel then "Точно: +25%"else "Точно: +50%",candle="Разведка 3",thread="Рукав +1",hourglass=if duel then "К цели на ±2"else "Всегда "..target,seal=if duel then "Входящий ÷2"else "Отмена атаки"}
 caption=compact[c.tarot]or caption
 if r.bust then caption="НЕ СРАБОТАЕТ"end
 local name=if c.tarot=="hourglass"then "Часы"else c.rank
 table.insert(lines,"<b>"..name.."</b>\n<font color=\""..(if r.bust then "#ff8c77"else "#fff0ba").."\">"..caption.."</font>")
end end
return table.concat(lines,"\n")
end
local function tarotFeedback(zones,results,duel,title)
local lines={}
for i,z in zones do for _,card in z.cards do if card.tarot then
 local r=results and results[i];local fails=r and r.bust
 local effect=if fails then "ПЕРЕБОР · не сработает"else Tarot.Caption(card.tarot,duel)
 local color=if fails then "#f08070"else "#eddda4"
 table.insert(lines,'<font color="'..color..'">'..i..' · '..card.rank..': '..effect..'</font>')
end end end
return if #lines>0 then title.."\n"..table.concat(lines,"\n")else ""
end
local function pulseSum(lane)
 if not lane or not lane.scale then return end
 lane.scale.Scale=1.16
 TweenService:Create(lane.scale,TweenInfo.new(.28,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Scale=1}):Play()
end

function Scene.Update(s)
if not model then return end;latest=s
local race=s.mode=="race"
local mobile=Scene.IsMobileView(workspace.CurrentCamera.ViewportSize)
roundLabel.Text=(if Scene.DuelMode then s.round else s.roundsLeft).." / "..s.roundsTotal
roundLabel.TextSize=if mobile then 56 else 46
roundLabel.Parent.Title.Text=if Scene.DuelMode then "РАУНД"else "ХОДЫ"
roundLabel.Parent.Title.TextSize=if mobile then 36 else 30
board.SuppliesTitle.TextSize=if mobile then 36 else 29;board.DeckTitle.TextSize=if mobile then 34 else 28
deckLabel.TextSize=if mobile then 44 else 36
for _,id in {"draw","stop","play"}do buttons[id].TextSize=if mobile then 40 else 34 end
if race then
 for _,b in buttons do b.Visible=false end
 for _,id in {"draw","stop"} do buttons[id].Visible=true end
 if buttons.discard then buttons.discard.Visible=true end
 board.SuppliesTitle.Visible=false;board.DeckTitle.Visible=true
 buttons.draw.TextSize=if mobile then 40 else 34;buttons.stop.TextSize=if mobile then 40 else 34
 buttons.draw.Text="ВЗЯТЬ";buttons.stop.Text="СТОП"
end
for _,id in {"minus2","minus4"}do
 local b=buttons[id];local name=b:FindFirstChild("Name")
 name.Position=UDim2.fromOffset(80,40);name.Size=UDim2.fromOffset(140,50);name.TextSize=if mobile then 32 else 27
 b.Count.TextSize=if mobile then 32 else 26
end
if session~=s.id then for _,node in nodes do node:Destroy()end;nodes={};receipt=0;session=s.id;selected=nil end
if selected and (s.supplies[selected] or 0)<=0 then selected=nil end
local keep={}
for i,z in s.zones do
 local r=s.forecast.zones[i];local lane=lanes[i];local active=s.active==i
 lane.tarot.Text=if race then raceZoneText(z)else zoneTarotText(z,r,Scene.DuelMode,s.target);lane.tarot.Visible=lane.tarot.Text~="";lane.tarot.TextSize=if mobile then 26 elseif #z.cards>=3 then 20 else 22
 local sumText=(if Scene.DuelMode then "Сумма "else "")..(if #z.cards>0 then tostring(r.sum)else "—")
 lane.sum.Text=sumText;lane.sum.TextSize=if Scene.DuelMode then (if mobile then 78 else 67)else (if mobile then 120 else 110)
 if lane.prevSum~=sumText then lane.prevSum=sumText;pulseSum(lane)end
 lane.status.TextSize=if mobile then (if Scene.DuelMode then 26 else 30)else (if Scene.DuelMode then 20 else 24)
 lane.root:FindFirstChild("Name").TextSize=if mobile then (if Scene.DuelMode then 34 else 40)else (if Scene.DuelMode then 27 else 35)
 lane.status.Text=(if r.bust then "ПЕРЕБОР" elseif r.exact then "ТОЧНО" elseif z.stood then "СТОП" elseif active then "НАБОР" else "ЖДЁТ").."   "..#z.cards.."/"..s.slots
 local fill=C.green
 local accent=if active or selected then C.active else C.gold
 local bonus=""
 if r.bust then fill=Color3.fromRGB(112,28,24);accent=Color3.fromRGB(238,92,69);bonus="ПЕРЕБОР · 0 урона"
 elseif r.exact then fill=Color3.fromRGB(89,74,28);accent=C.active;bonus="ТОЧНО В ЦЕЛЬ"
 elseif r.heal>0 then fill=Color3.fromRGB(99,35,45);accent=Color3.fromRGB(234,133,144);bonus="♥ +"..r.heal.." HP"
 elseif r.colorBonus and r.colorBonus>0 then fill=Color3.fromRGB(24,36,61);accent=Color3.fromRGB(134,179,231);bonus="♠ +"..r.colorBonus.."% урона"
 elseif #z.cards>=s.slots then fill=Color3.fromRGB(49,68,48);bonus="СТОЛ ЗАПОЛНЕН" end
 if Scene.DuelMode then lane.status.Text..=" · Урон "..r.damage end

 if lane.root.BackgroundColor3~=fill then TweenService:Create(lane.root,TweenInfo.new(.18),{BackgroundColor3=fill}):Play()end
 lane.root.BackgroundTransparency=if #z.cards==0 then 1 else math.max(.23,.9-#z.cards*.12)
 lane.border.Color=accent
 lane.border.Thickness=if active or selected then 4 else 2;lane.border.Transparency=if active or selected or r.bust then 0 else .55
 lane.click.Visible=selected~=nil and #z.cards>0 and s.phase=="combat"
 for ci,card in z.cards do
  keep[card.id]=true
  local node=nodes[card.id];local destination=if Scene.DuelMode then UDim2.fromOffset(410+(i-1)*330+(ci-1)*3,695+(ci-1)*8)else UDim2.fromOffset(410+(i-1)*330+(ci-1)*4,285+(ci-1)*24)
  if not node then
   node=cardFace(card);node.Size=if Scene.DuelMode then (if Scene.IsMobileView(workspace.CurrentCamera.ViewportSize)then UDim2.fromOffset(104,144)else UDim2.fromOffset(90,125))else UDim2.fromOffset(120,167);nodes[card.id]=node;node.Position=if race then UDim2.fromOffset(900,465)elseif Scene.DuelMode then UDim2.fromOffset(1510,710)else UDim2.fromOffset(1510,215)
   TweenService:Create(node,TweenInfo.new(.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=destination,Rotation=if ci%2==0 then 1 else -1}):Play()
  else node.Position=destination end
  node.ZIndex=ci+2;for _,v in node:GetDescendants()do if v:IsA("GuiObject")then v.ZIndex=node.ZIndex end end
 end
end
for id,node in nodes do if not keep[id]then node:Destroy();nodes[id]=nil end end
local combat=s.phase=="combat" and not Scene.ImpactActive and not s.ready
local activeCards=s.active and s.zones[s.active].cards
local lastCard=activeCards and activeCards[#activeCards]
enable(buttons.hide,combat and lastCard~=nil and not lastCard.tarot and s.sleeveUsed<1 and s.sleeveCount==0)
enable(buttons.release,combat and s.active~=nil and s.sleeveCount>0)
enable(buttons.draw,combat and s.active~=nil);enable(buttons.stop,combat and s.active~=nil and #s.zones[s.active].cards>0);enable(buttons.play,combat and (s.network or (s.forecast.cards>0 and (not Scene.DuelMode or s.duel.enemyReady))))
buttons.play.Text=if s.network then (if s.ready then 'ЖДЁМ ДРУГА'else 'Я ГОТОВ')else 'СЫГРАТЬ ХОД'
for item,b in buttons do if item=="minus2" or item=="minus4" then
 b.Count.Text=tostring(s.supplies[item]or 0);enable(b,combat and(s.supplies[item]or 0)>0)
 b.BackgroundColor3=if selected==item then Color3.fromRGB(110,91,38)else C.green
end end
if race then
 local me=s.race and s.race.seats and s.race.seats[s.race.you] or {}
 local open=s.race and s.race.open
 local contest=s.race and s.race.contest
 local contested=(contest and contest.active)or false
 local actedInContest=(contest and contest.yours)or false
 local armed=s.phase=="combat"and not Scene.ImpactActive
 local noStun=(me.stunIn or 0)<=0
 local zone=s.active and s.zones[s.active]
 enable(buttons.draw,armed and open~=nil and noStun and(me.grabReadyIn or 0)<=0 and not actedInContest)
 buttons.draw.Text=if(me.grabReadyIn or 0)>0 then("ВЗЯТЬ "..string.format("%.1f",me.grabReadyIn))elseif(me.stunIn or 0)>0 then("СТАН "..string.format("%.1f",me.stunIn))else "ВЗЯТЬ"
 if buttons.discard then
  enable(buttons.discard,armed and open~=nil and(me.discardsLeft or 0)>0 and noStun and(me.discardReadyIn or 0)<=0 and not actedInContest)
  buttons.discard.Text=if(me.discardReadyIn or 0)>0 then("СБРОС "..string.format("%.1f",me.discardReadyIn))else "СБРОС"
 end
 enable(buttons.stop,armed and zone~=nil and #zone.cards>0 and not contested)
 paintOpen(open)
end
ownTarotLabel.Visible=false
if Scene.DuelMode then
 for _,side in {"own","enemy"}do
  local list=if side=="own"then s.jokers else s.duel.enemyJokers
  for i,card in jokerCards[side]do
   local id=list and list[i];local def=id and Loadout.Joker(id);card.id=id
   if card.artId~=id then card.art:ClearAllChildren();if id then Assets.CreateLoadoutArt(card.art,'joker',id)end;card.artId=id end
   card.symbol.Visible=id==nil
   card.title.Text=if def then def.name else "Пусто";card.symbol.Text=if def then def.symbol else "—"
   card.title.TextSize=if mobile then 20 else 18;card.title.Position=UDim2.fromOffset(58,if id=='xray'then 28 else 5);card.title.Size=UDim2.fromOffset(72,if id=='xray'then 62 else 85)
   card.charges.TextSize=16;card.charges.Position=UDim2.fromOffset(58,3);card.charges.Size=UDim2.fromOffset(72,24)
   card.charges.Text=if id=="xray"then tostring(if side=="own"then s.scanCharges else s.duel.enemyScanCharges).." / 2"else ""
   enable(card.frame,side=="own"and id=="xray"and combat and (s.scanCharges or 0)>0 and s.active~=nil and (not s.peek or #s.peek==0))
   -- Passive opponent/own cards remain fully legible even without an action.
   if id~="xray"or side=="enemy"then card.frame.TextTransparency=0;card.frame.BackgroundTransparency=0 end
  end
 end
end
ownTarotLabel.Text=if race then "" else tarotFeedback(s.zones,s.forecast.zones,Scene.DuelMode,"ТВОИ ТАРО")
if Scene.DuelMode and s.duel then Scene.UpdateEnemy(s)end
targetLabel.Text=tostring(s.target);damageLabel.Text="УРОН  "..s.forecast.damage;deckLabel.Text=s.deckCount.." / "..s.deckTotal
helpLabel.Text=if race then "Space — взять   ·   F — сброс   ·   Enter — стоп"elseif selected then "Выбран Срез "..(if selected=="minus4"then "−4"else "−2").." · выбери стол"elseif not combat then "Удар…"else (if Scene.DuelMode then (if s.duel.enemyReady then "ИИ готов · можно сыграть ход"else "Соперник набирает карты…")else "Space — карта     ·     F — стоп     ·     Enter — удар")
if race then
 local me=s.race and s.race.seats and s.race.seats[s.race.you]
 helpLabel.Text=string.format("Цель %d · %.1f с · броня %d · сбросы %d/%d",s.target,s.timeLeft or 0,s.armor or 0,me and me.discardsLeft or 0,s.discardLimit or 2)
elseif s.network then
 helpLabel.Text=if s.phase=='countdown'then 'Начало через '..s.remaining elseif s.phase=='combat'then (if s.ready then 'Ты готов · ждём друга'elseif s.duel.enemyReady then 'Друг готов · твой ход'else 'Подтверди ход, когда будешь готов')..' · '..s.remaining..' сек.'else 'Розыгрыш хода…'
 board.EnemyJokersTitle.Text='ДЖОКЕРЫ ДРУГА';board.EnemySupplyTitle.Text='ПРЕДМЕТЫ ДРУГА';board.EnemyDeckTitle.Text='КОЛОДА ДРУГА'
end
if not race then helpLabel.Text..=" · Таро "..s.tarotUsed.." / "..s.tarotLimit end
if s.peek and #s.peek>0 then local names={}for _,c in s.peek do table.insert(names,c.rank..c.suit)end;helpLabel.Text..=" · Далее: "..table.concat(names," / ")end
end
function Scene.UpdateEnemy(s)
local race=s.mode=="race"
local mobile=Scene.IsMobileView(workspace.CurrentCamera.ViewportSize)
local results={}for i,z in s.duel.enemyZones do results[i]=z.result end
opponentTarotLabel.Visible=false
opponentTarotLabel.Text=if race then "" else tarotFeedback(s.duel.enemyZones,results,true,"ТАРО ИИ")
local keep={}
for i,z in s.duel.enemyZones do
 local lane=enemyLanes[i];local r=z.result
 lane.tarot.Text=if race then raceZoneText(z)else zoneTarotText(z,r,true,s.target);lane.tarot.Visible=lane.tarot.Text~="";lane.tarot.TextSize=if mobile then 26 elseif #z.cards>=3 then 20 else 22
 local enemySumText="Сумма "..(if #z.cards>0 and r then tostring(r.sum)else "—")
 lane.sum.Text=enemySumText;lane.sum.TextSize=if mobile then 78 else 67
 if lane.prevSum~=enemySumText then lane.prevSum=enemySumText;pulseSum(lane)end
 lane.status.TextSize=if mobile then 26 else 22;lane.root:FindFirstChild("Name").TextSize=if mobile then 34 else 27
 lane.status.Text=(if r and r.bust then "ПЕРЕБОР"elseif r and r.exact then "ТОЧНО"elseif z.stood then "СТОП"elseif #z.cards==0 then "ЖДЁТ"else "НАБОР").." "..#z.cards.."/"..s.slots
 lane.status.Text..=" · Урон "..(r and r.damage or 0)
 lane.root.BackgroundColor3=if r and r.bust then Color3.fromRGB(115,25,22)elseif r and r.exact then Color3.fromRGB(105,80,25)else C.red
 lane.root.BackgroundTransparency=if r then .55 else .9
 for ci,card in z.cards do
  keep[card.id]=true
  local node=enemyNodes[card.id]
  if not node then
   if card.hidden then
    node=make("Frame",{Name="EnemyBack",Size=UDim2.fromOffset(100,139),BackgroundColor3=C.red,BorderSizePixel=0},board);make("UICorner",{CornerRadius=UDim.new(0,7)},node);outline(node,C.paper,2);label(node,"Spade","♠",4,30,104,90,60,C.paper)
   else node=cardFace(card);node.Name="EnemyCard_"..card.id;node.Size=if Scene.IsMobileView(workspace.CurrentCamera.ViewportSize)then UDim2.fromOffset(104,144)else UDim2.fromOffset(90,125)end
   enemyNodes[card.id]=node
   node.Position=if race then UDim2.fromOffset(900,465)else UDim2.fromOffset(210,280)
   TweenService:Create(node,TweenInfo.new(.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=UDim2.fromOffset(410+(i-1)*330+(ci-1)*3,115+(ci-1)*8)}):Play()
  end
  node.ZIndex=ci+2
  for _,o in node:GetDescendants()do if o:IsA("GuiObject")then o.ZIndex=node.ZIndex end end
 end
end
for id,node in enemyNodes do if not keep[id]then node:Destroy();enemyNodes[id]=nil end end
enemyDeckLabel.Text=s.duel.enemyDeckCount.." / "..s.duel.enemyDeckTotal
enemyDeckLabel.TextSize=if mobile then 38 else 30
for item,value in enemySupplyLabels do
 if race then value.Parent.Visible=false else value.Parent.Visible=true;value.Text=(if item=="minus2"then "✂ −2"else "✂ −4").." ×"..s.duel.enemySupplies[item] end
end
end
function Scene.PlayAttack(s,onHit,onDone)
if not model or not head or not s.receipt or not s.receipt.hits then task.defer(onDone);return end
Scene.ImpactActive=true;Scene.Update(s)
local attackModel=model
local function finish()impactJob=nil;Scene.ImpactActive=false;onDone()end
local function incoming()
 if Scene.DuelMode and s.receipt.incoming then
  impactJob=CardImpact.Play({parent=model,plane=surface.Adornee,head=playerTarget,deck=model:FindFirstChild("EnemyDeckTop",true),nodes=enemyNodes,receipt=s.receipt.incoming,maxHp=s.maxHp,canvasHeight=Scene.CanvasHeight,
   hit=function(hp,maxHp,damage)onHit(hp,maxHp,damage,"player")end,done=finish})
 else finish()end
end
local function outgoing()
 if not Scene.ImpactActive or model~=attackModel then return end
 impactJob=CardImpact.Play({parent=model,plane=surface.Adornee,head=head,deck=model:FindFirstChild("DeckTop",true),nodes=nodes,receipt=s.receipt,maxHp=s.enemyMaxHp,canvasHeight=Scene.CanvasHeight,
  hit=onHit,done=incoming})
end
local healed=false
if s.receipt.ownBefore and s.receipt.ownHealed>s.receipt.ownBefore then onHit(s.receipt.ownHealed,s.maxHp,-(s.receipt.ownHealed-s.receipt.ownBefore),"player");healed=true end
if s.receipt.enemyHealBefore and s.receipt.enemyBefore>s.receipt.enemyHealBefore then onHit(s.receipt.enemyBefore,s.enemyMaxHp,-(s.receipt.enemyBefore-s.receipt.enemyHealBefore),"enemy");healed=true end
if healed then task.delay(.55,outgoing)else outgoing()end
end
return Scene
