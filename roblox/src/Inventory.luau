local L=require(script.Parent.Loadout)
local T=require(script.Parent.Tarot)
local RT=require(script.Parent.RaceTarot)
local A=require(script.Parent.Assets)
local Inventory={}
local tab='tarot';local focus={kind='tarot',id='rose'};local positions={}
local C={ink=Color3.fromRGB(9,24,20),panel=Color3.fromRGB(18,42,33),raised=Color3.fromRGB(29,57,44),gold=Color3.fromRGB(220,183,105),paper=Color3.fromRGB(248,232,194),muted=Color3.fromRGB(175,192,173),edge=Color3.fromRGB(73,99,77)}
local function make(class,props,parent)local o=Instance.new(class);for k,v in props do o[k]=v end;o.Parent=parent;return o end
local function border(o,color,width)make('UICorner',{CornerRadius=UDim.new(0,9)},o);make('UIStroke',{Color=color or C.edge,Thickness=width or 1,Transparency=.15},o)end
local function text(p,n,s,x,y,w,h,size,color)return make('TextLabel',{Name=n,Text=s,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,TextColor3=color or C.paper,Font=Enum.Font.GothamMedium,TextSize=size or 16,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left},p)end
local function button(p,n,s,x,y,w,h,fn,color)
 local o=make('TextButton',{Name=n,Text=s,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=color or C.raised,TextColor3=C.paper,Font=Enum.Font.GothamBold,TextSize=16,BorderSizePixel=0,AutoButtonColor=true},p);border(o);o.Activated:Connect(fn);return o
end
local function list(kind,race)
 if kind=='class'then return L.Classes elseif kind=='joker'then return L.Jokers end
 if race then
  local out={}
  for _,d in RT.List do table.insert(out,{id=d.id,name=d.name,symbol=d.symbol,desc=d.desc,good=d.good})end
  return out
 end
 local out={};for _,id in L.TarotIds do local d=T.Def(id);table.insert(out,{id=id,name=d.name,symbol=d.symbol,desc=T.Caption(id,true)})end;return out
end
local function def(kind,id,race)for _,d in list(kind,race)do if d.id==id then return d end end end
local function selected(p,kind,id,race)
 if kind=='class'then return p.class==id end
 local values=if kind=='joker'then p.jokers elseif race then (p.raceTarot or {}) else p.duelTarot
 return table.find(values,id)~=nil
end
local function art(parent,kind,d,mini,race)
 local holder=make('Frame',{Name='Art',Position=UDim2.fromOffset(6,6),Size=UDim2.new(1,-12,1,-12),BackgroundColor3=Color3.fromRGB(225,205,156),BorderSizePixel=0,ClipsDescendants=true},parent);border(holder,C.gold)
 if kind=='tarot'and race then
  make('UIGradient',{Color=ColorSequence.new(if d.good then Color3.fromRGB(44,89,62)else Color3.fromRGB(92,43,39),C.ink),Rotation=55},holder)
  local symbol=text(holder,'Symbol',d.symbol,0,0,0,0,24,if d.good then C.gold else Color3.fromRGB(239,180,164));symbol.Size=UDim2.fromScale(1,1);symbol.TextScaled=true;symbol.TextXAlignment=Enum.TextXAlignment.Center
  make('UITextSizeConstraint',{MaxTextSize=if mini then 34 else 70,MinTextSize=14},symbol)
  -- Race atlas cell over the readable fallback (symbol/type stay visible while art loads).
  A.CreateTarotArt(holder,d.id)
  if not mini then local label=text(holder,'Type',if d.good then 'ХОРОШЕЕ'else 'ПЛОХОЕ',4,4,0,18,11,if d.good then C.gold else Color3.fromRGB(239,180,164));label.Size=UDim2.new(1,-8,0,18);label.TextXAlignment=Enum.TextXAlignment.Center end
 elseif kind=='tarot'then local image=A.CreateTarotArt(holder,d.id);image.ScaleType=Enum.ScaleType.Fit
 else
  make('UIGradient',{Color=ColorSequence.new(Color3.fromRGB(249,230,180),Color3.fromRGB(157,126,72)),Rotation=45},holder)
  local symbol=text(holder,'Symbol',d.symbol,0,0,0,0,24,if d.id=='crimson'or d.id=='healer'then Color3.fromRGB(157,44,42)else C.ink);symbol.Size=UDim2.fromScale(1,1);symbol.TextScaled=true;symbol.TextXAlignment=Enum.TextXAlignment.Center
  make('UITextSizeConstraint',{MaxTextSize=if mini then 34 else 86,MinTextSize=16},symbol)
  if not mini then local label=text(holder,'Type',if kind=='class'then 'КЛАСС'else 'ДЖОКЕР',4,4,0,18,11,C.ink);label.Size=UDim2.new(1,-8,0,18);label.TextXAlignment=Enum.TextXAlignment.Center end
  A.CreateLoadoutArt(holder,kind,d.id)
 end
end
function Inventory.Build(app,data,duelSetup,send,race)
 race=race==true
 A.PreloadAll();local p=data.profile;local frozen=data.loadoutLocked==true
 if race and focus.kind=='tarot'and not RT.Def(focus.id)then focus={kind='tarot',id=RT.List[1].id}end
 if not race and focus.kind=='tarot'and not T.Def(focus.id)then focus={kind='tarot',id='rose'}end
 local raceTarot=if race then (p.raceTarot or {})else p.duelTarot
 local root=make('Frame',{Name='TacticalMenu',Size=UDim2.fromScale(1,1),BackgroundColor3=C.ink,BorderSizePixel=0},app)
 make('UIGradient',{Color=ColorSequence.new(C.panel,C.ink),Rotation=90},root)
 local draw
 local function choose(kind,id)
  focus={kind=kind,id=id}
  if not frozen then send(if kind=='class'then 'buildClass'elseif kind=='joker'then 'buildJoker'else 'buildTarot',{item=id})end
  draw()
 end
 draw=function()
  if not root.Parent then return end
  for _,o in root:GetChildren()do if not o:IsA('UIGradient')then o:Destroy()end end
  local w,h=math.floor(app.AbsoluteSize.X),math.floor(app.AbsoluteSize.Y);if w<100 or h<100 then return end
  local portrait=w<600 and h>w;local short=h<400;local footer=if portrait then 146 else 96
  local mainY=if short then 58 else 104;local mainH=math.max(112,h-mainY-footer-18)
  local infoW=if portrait then w-24 else math.clamp(math.floor(w*.26),204,290)
  local browserW=if portrait then w-24 else w-infoW-36
  local contentH=if portrait then math.max(mainH,340)else mainH
  local browserH=if portrait then math.floor(contentH*.58)else mainH
  local mainParent=root
  if portrait then mainParent=make('ScrollingFrame',{Name='MobileContent',Position=UDim2.fromOffset(0,mainY),Size=UDim2.fromOffset(w,mainH),CanvasSize=UDim2.fromOffset(0,contentH),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollingDirection=Enum.ScrollingDirection.Y},root)end
  text(root,'Title','♠  ВОЧКО',14,if short then 8 else 2,if short then 110 else w-140,32,if short then 19 else 25,C.gold).Font=Enum.Font.GothamBold
  button(root,'Return',if data.seated then 'К столу'else 'В комнату',w-122,2,108,44,function()send(if data.seated then 'closeBuild'else 'return')end)
  local tabX=if short then 138 else 14;local tabW=(w-(if short then 264 else 28))/3
  for i,e in {{'class','Класс  1/1'},{'joker','Джокеры  '..#p.jokers..'/2'},{'tarot','Таро  '..#raceTarot..(if race then '/4'else '/3')}}do
   local b=button(root,'Tab_'..e[1],e[2],tabX+(i-1)*tabW,if short then 2 else 52,tabW-8,44,function()tab=e[1];focus={kind=tab,id=list(tab,race)[1].id};draw()end,if tab==e[1]then C.raised else C.ink)
   if tab==e[1]then b.UIStroke.Color=C.gold;b.UIStroke.Thickness=2;b.TextColor3=C.gold end
  end
  local browser=make('ScrollingFrame',{Name='CardBrowser',Position=UDim2.fromOffset(12,if portrait then 0 else mainY),Size=UDim2.fromOffset(browserW,browserH),BackgroundColor3=C.panel,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=C.gold,ScrollingDirection=Enum.ScrollingDirection.X,CanvasSize=UDim2.new()},mainParent);border(browser)
  local cardH=browserH-16;local cardW=math.clamp(math.floor(cardH*.68),94,170);local cards=list(tab,race)
  for i,d in cards do
   local chosen=selected(p,tab,d.id,race)
   local card=button(browser,'Card_'..d.id,'',8+(i-1)*(cardW+12),6,cardW,cardH,function()choose(tab,d.id)end,if chosen then Color3.fromRGB(73,66,37)else C.raised)
   card.UIStroke.Color=if chosen then C.gold else C.edge;card.UIStroke.Thickness=if chosen then 2 else 1;art(card,tab,d,false,race)
   if race and tab=='tarot'then local mark=text(card,'Kind',if d.good then 'ХОРОШЕЕ'else 'ПЛОХОЕ',5,3,cardW-10,20,11,if d.good then Color3.fromRGB(144,219,161)else Color3.fromRGB(239,180,164));mark.TextXAlignment=Enum.TextXAlignment.Center;mark.ZIndex=4 end
   local name=text(card,'CardName',d.name,5,cardH-40,cardW-10,36,if short then 15 else 16);name.TextXAlignment=Enum.TextXAlignment.Center;name.BackgroundColor3=C.ink;name.BackgroundTransparency=.1;name.ZIndex=3
   if chosen then local tick=text(card,'Selected','✓',cardW-29,2,26,26,23,C.gold);tick.ZIndex=5;tick.TextXAlignment=Enum.TextXAlignment.Center;tick.BackgroundColor3=C.ink;tick.BackgroundTransparency=.1;border(tick,C.gold)end
  end
  browser.CanvasSize=UDim2.fromOffset(16+#cards*(cardW+12),0)
  browser.CanvasPosition=Vector2.new(math.clamp(positions[tab]or 0,0,math.max(0,browser.CanvasSize.X.Offset-browserW)),0)
  local tabKey=tab;browser:GetPropertyChangedSignal('CanvasPosition'):Connect(function()positions[tabKey]=browser.CanvasPosition.X end)
  local d=def(focus.kind,focus.id,race)or cards[1]
  local infoY=if portrait then browserH+10 else mainY;local infoH=if portrait then contentH-browserH-10 else mainH
  local info=make('Frame',{Name='Details',Position=UDim2.fromOffset(if portrait then 12 else w-infoW-12,infoY),Size=UDim2.fromOffset(infoW,infoH),BackgroundColor3=C.panel,BorderSizePixel=0},mainParent);border(info)
  local heading=text(info,'Heading',d.name,12,6,infoW-24,28,if short then 18 else 23,C.gold);heading.Font=Enum.Font.GothamBold
  if race and d.good~=nil then heading.TextColor3=if d.good then Color3.fromRGB(144,219,161)else Color3.fromRGB(239,180,164);heading.Text=d.name..(if d.good then ' · хорошее'else ' · плохое') end
  local desc=make('ScrollingFrame',{Name='DescriptionScroll',Position=UDim2.fromOffset(12,40),Size=UDim2.new(1,-24,1,-76),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=2,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y},info)
  local label=text(desc,'Description',d.desc,0,0,infoW-30,0,if short then 16 else 17);label.AutomaticSize=Enum.AutomaticSize.Y;label.TextYAlignment=Enum.TextYAlignment.Top
  local chosen=selected(p,focus.kind,d.id,race)
  text(info,'Hint',if frozen then 'Сборка зафиксирована'elseif chosen then '✓ В твоём наборе'else 'Нажми карту, чтобы выбрать',12,infoH-31,infoW-24,26,13,if chosen then C.gold else C.muted)
  local dock=make('Frame',{Name='Dock',AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,12,1,-8),Size=UDim2.fromOffset(w-24,footer),BackgroundColor3=C.panel,BorderSizePixel=0},root);border(dock)
  local valid,why
  if race then valid,why=L.ValidateRace(p.class,p.jokers,raceTarot)else valid,why=L.Validate(p.class,p.jokers,p.duelTarot)end
  local ready=valid and (not duelSetup or data.preparation and data.preparation.ready)
  local status=if frozen then 'Сборка зафиксирована'elseif not valid then why elseif duelSetup and not ready then 'Соперник собирает набор…'else 'ТВОЙ НАБОР · 1 класс / 2 джокера / '..(if race then '2 хороших + 2 плохих таро'else '3 таро')
  text(dock,'Status',status,10,3,w-46,22,14,C.muted)
  local goW=if portrait then w-44 else math.clamp(math.floor(w*.22),142,210)
  local miniH=if portrait then 60 else 58;local miniW=if portrait then math.max(44,math.floor((w-92)/6))else math.clamp(math.floor((w-goW-92)/6),44,50)
  local items={{kind='class',id=p.class},{kind='joker',id=p.jokers[1]},{kind='joker',id=p.jokers[2]}}
  for i=1,(if race then 4 else 3)do table.insert(items,{kind='tarot',id=raceTarot[i]})end
  local strip=make('ScrollingFrame',{Name='SelectedCards',Position=UDim2.fromOffset(10,28),Size=UDim2.fromOffset(if portrait then w-44 else w-goW-54,miniH),CanvasSize=UDim2.fromOffset(#items*(miniW+8)+10,0),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=2,ScrollingDirection=Enum.ScrollingDirection.X},dock)
  for i,item in items do
   local x=(i-1)*(miniW+8)+(if i>1 then 5 else 0)+(if i>3 then 5 else 0)
   local slot=button(strip,'Slot_'..i,'+',x,0,miniW,miniH,function()tab=item.kind;focus={kind=item.kind,id=item.id or list(item.kind,race)[1].id};draw()end,C.ink)
   if item.id then local entry=def(item.kind,item.id,race);if entry then slot.Text='';art(slot,item.kind,entry,true,race)end end
  end
  local go=button(dock,'Primary',if frozen then 'ПРОДОЛЖИТЬ'elseif data.seated then 'ГОТОВО'elseif duelSetup then 'НАЧАТЬ ДУЭЛЬ'else 'К ТРЕНИРОВКЕ',if portrait then 10 else w-24-goW-10,if portrait then 94 else 35,goW,44,function()
   if not frozen and not ready then return end
   if data.seated then send('closeBuild')elseif duelSetup then send('begin')else send('open',{mode='training'})end
  end,C.gold)
  go.TextColor3=C.ink;go.TextSize=if short then 15 else 17;go.AutoButtonColor=ready==true;go.TextTransparency=if frozen or ready then 0 else .5
 end
 draw();local resize=app:GetPropertyChangedSignal('AbsoluteSize'):Connect(draw)
 root.Destroying:Once(function()resize:Disconnect()end)
end
return Inventory
