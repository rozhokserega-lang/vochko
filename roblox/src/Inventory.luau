local Loadout=require(script.Parent.Loadout)
local Tarot=require(script.Parent.Tarot)
local Assets=require(script.Parent.Assets)
local Inventory={}
local tipState
local rowPositions={}
local C={wood=Color3.fromRGB(57,35,22),dark=Color3.fromRGB(18,12,9),gold=Color3.fromRGB(207,168,91),paper=Color3.fromRGB(241,225,187),muted=Color3.fromRGB(192,174,137)}
local function make(class,props,parent)local p=Instance.new(class);for k,v in props do p[k]=v end;p.Parent=parent;return p end
local function text(parent,value,pos,size,fontSize,color)
 return make("TextLabel",{Text=value,Position=pos,Size=size,TextSize=fontSize or 17,TextColor3=color or C.paper,Font=Enum.Font.Garamond,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1},parent)
end
local function border(p,color,width)make("UIStroke",{Color=color or C.gold,Thickness=width or 1,Transparency=.15},p);make("UICorner",{CornerRadius=UDim.new(0,7)},p)end
function Inventory.Build(app,data,duelSetup,send)
 Assets.WarmTarot()
 local savedPositions=table.clone(rowPositions)
 local p=data.profile;local frozen=data.loadoutLocked==true
 local function showTip(title,description,rect)
  local old=app:FindFirstChild("ItemTip");if old then old:Destroy()end
  local width=math.min(300,app.AbsoluteSize.X-20);local height=146
  local maxY=math.max(8,app.AbsoluteSize.Y-100-height-8)
  local x=math.clamp(rect.X,10,math.max(10,app.AbsoluteSize.X-width-10))
  local y=rect.Y+rect.Z+8;if y>maxY then y=rect.Y-height-8 end;y=math.clamp(y,8,maxY)
  local frame=make("Frame",{Name="ItemTip",Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(width,height),BackgroundColor3=C.dark,BorderSizePixel=0,ZIndex=60,Active=true},app);border(frame,C.gold,2)
  local heading=text(frame,title,UDim2.fromOffset(12,8),UDim2.new(1,-64,0,30),21,C.gold);heading.ZIndex=61
  local desc=text(frame,description,UDim2.fromOffset(12,46),UDim2.new(1,-24,0,88),17);desc.ZIndex=61;desc.TextYAlignment=Enum.TextYAlignment.Top
  local close=make("TextButton",{Name="Close",Text="×",Position=UDim2.new(1,-48,0,2),Size=UDim2.fromOffset(44,44),TextSize=25,Font=Enum.Font.Garamond,BackgroundTransparency=1,TextColor3=C.gold,ZIndex=62},frame)
  close.Activated:Connect(function()tipState=nil;frame:Destroy()end)
 end
 local body=make("ScrollingFrame",{Name="Body",Size=UDim2.new(1,0,1,-100),CanvasSize=UDim2.fromOffset(0,760),ScrollBarThickness=3,BackgroundColor3=C.dark,BorderSizePixel=0},app)
 text(body,"ШКАФ",UDim2.fromOffset(16,8),UDim2.new(1,-132,0,42),32,C.gold)
 local back=make("TextButton",{Name="Return",Text=if data.seated then 'К столу'else "В комнату",Position=UDim2.new(1,-116,0,10),Size=UDim2.fromOffset(100,44),TextSize=16,Font=Enum.Font.Garamond,TextColor3=C.paper,BackgroundColor3=C.wood,BorderSizePixel=0},body);border(back);back.Activated:Connect(function()send(if data.seated then 'closeBuild'else "return")end)
 text(body,if frozen then "Сборка зафиксирована до конца дуэли"else "Подготовка к дуэли · одинаковые возможности для обеих сторон",UDim2.fromOffset(16,56),UDim2.new(1,-32,0,38),16,C.muted)
 local function shelf(title,count,y,height)
  local frame=make("Frame",{Name=if title=="КЛАСС"then "ClassShelf"elseif title=="ДЖОКЕРЫ"then "JokerShelf"else "TarotShelf",Position=UDim2.fromOffset(12,y),Size=UDim2.new(1,-24,0,height),BackgroundColor3=C.wood,BorderSizePixel=0},body);border(frame,C.wood,3)
  text(frame,title,UDim2.fromOffset(10,2),UDim2.new(.65,0,0,28),20,C.gold)
  local counter=text(frame,count,UDim2.new(.65,0,0,2),UDim2.new(.35,-10,0,28),16,C.muted);counter.TextXAlignment=Enum.TextXAlignment.Right
  return make("ScrollingFrame",{Name="Items",Position=UDim2.fromOffset(8,34),Size=UDim2.new(1,-16,1,-42),CanvasSize=UDim2.new(),ScrollBarThickness=3,ScrollingDirection=Enum.ScrollingDirection.X,BackgroundColor3=C.dark,BorderSizePixel=0},frame)
 end
 local function card(row,index,id,title,symbol,description,chosen,kind,image)
  local width=if image then 106 else 116
  local b=make("TextButton",{Name=kind.."_"..id,Text="",Position=UDim2.fromOffset((index-1)*(width+10)+4,4),Size=UDim2.new(0,width,1,-12),BackgroundColor3=if chosen then Color3.fromRGB(74,52,25)else Color3.fromRGB(37,25,16),BorderSizePixel=0,AutoButtonColor=true,Active=true},row);border(b,if chosen then Color3.fromRGB(249,211,125)else Color3.fromRGB(116,89,49),if chosen then 2 else 1)
  if image then
   local holder=make("Frame",{Name="Art",Size=UDim2.fromOffset(54,81),Position=UDim2.new(.5,-27,0,7),BackgroundTransparency=1},b)
   Assets.CreateTarotArt(holder,id)
   text(b,title,UDim2.fromOffset(4,89),UDim2.new(1,-8,0,30),16)
  else
   local icon=text(b,symbol,UDim2.fromOffset(5,2),UDim2.new(1,-10,0,38),30,C.gold);icon.TextXAlignment=Enum.TextXAlignment.Center
   local label=text(b,title,UDim2.fromOffset(5,40),UDim2.new(1,-10,0,40),17);label.TextXAlignment=Enum.TextXAlignment.Center
  end
  if chosen then local tick=text(b,"✓",UDim2.fromOffset(5,2),UDim2.fromOffset(20,22),18,C.gold);tick.ZIndex=3 end
  b.Activated:Connect(function()
   local rect=Vector3.new(b.AbsolutePosition.X-app.AbsolutePosition.X,b.AbsolutePosition.Y-app.AbsolutePosition.Y,b.AbsoluteSize.Y)
   tipState={title=title,description=description,rect=rect};showTip(title,description,rect)
   if not frozen then send(kind,{item=id})end
  end)
  row.CanvasSize=UDim2.fromOffset(index*(width+10)+4,0)
 end
 local classes=shelf("КЛАСС","1 / 1",104,132)
 for i,d in Loadout.Classes do card(classes,i,d.id,d.name,d.symbol,d.desc,p.class==d.id,"buildClass")end
 local jokers=shelf("ДЖОКЕРЫ",#p.jokers.." / 2",248,146)
 for i,d in Loadout.Jokers do card(jokers,i,d.id,d.name,d.symbol,d.desc,table.find(p.jokers,d.id)~=nil,"buildJoker")end
 local tarot=shelf("ТАРО В КОЛОДЕ",#p.duelTarot.." / 3",406,178)
 for i,id in Loadout.TarotIds do local d=Tarot.Def(id);card(tarot,i,id,d.name,d.symbol,Tarot.Caption(id,true),table.find(p.duelTarot,id)~=nil,"buildTarot",Assets.Tarot[id])end
 for _,row in {classes,jokers,tarot}do
  if savedPositions[row.Parent.Name]then row.CanvasPosition=savedPositions[row.Parent.Name]end
  local key=row.Parent.Name;row:GetPropertyChangedSignal("CanvasPosition"):Connect(function()rowPositions[key]=row.CanvasPosition end)
 end
 text(body,"Нажми на предмет — описание появится рядом. Выбранные предметы отмечены галочкой.",UDim2.fromOffset(16,598),UDim2.new(1,-32,0,76),18)
 text(body,"Колода: 52 + 3 таро. Таро одноразовые за матч. Броня действует на один обмен ударами. Нить и рукав пока отключены в PvP.",UDim2.fromOffset(16,684),UDim2.new(1,-32,0,66),16,C.muted)
 local dock=make("Frame",{Name="Dock",AnchorPoint=Vector2.new(0,1),Position=UDim2.fromScale(0,1),Size=UDim2.new(1,0,0,100),BackgroundColor3=C.dark,BorderSizePixel=0},app)
 local valid,why=Loadout.Validate(p.class,p.jokers,p.duelTarot)
 local ready=valid and (not duelSetup or data.preparation and data.preparation.ready)
 text(dock,if not valid then why elseif duelSetup and not ready then "Соперник собирает набор…"else "1 класс · 2 джокера · 3 таро",UDim2.fromOffset(16,0),UDim2.new(1,-32,0,28),16,C.muted)
 local go=make("TextButton",{Name="Primary",Text=if frozen then "ПРОДОЛЖИТЬ ДУЭЛЬ"elseif duelSetup then "ГОТОВ · НАЧАТЬ ДУЭЛЬ"else "К ТРЕНИРОВОЧНОМУ СТОЛУ",Position=UDim2.fromOffset(16,34),Size=UDim2.new(1,-32,0,52),BackgroundColor3=C.gold,TextColor3=C.dark,Font=Enum.Font.Garamond,TextSize=22,BorderSizePixel=0,AutoButtonColor=ready==true,TextTransparency=if ready then 0 else .5},dock);border(go)
 if data.seated then go.Text='ГОТОВО · К СТОЛУ'end
 go.Activated:Connect(function()if frozen or ready then if data.seated then send('closeBuild')elseif duelSetup then send("begin")else send("open",{mode="training"})end end end)
 if tipState then showTip(tipState.title,tipState.description,tipState.rect)end
end
return Inventory
