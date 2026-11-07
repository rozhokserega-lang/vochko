-- All prototype geometry is grouped; existing Baseplate and SpawnLocation are preserved.
return function()
 local function ensureSeats(root)
  for _,entry in {{key="campaign",x=19},{key="training",x=-19},{key="pvp",x=0}}do
   local station=root:FindFirstChild("Table_"..entry.key)
   if station then
    for _,chair in root:GetChildren()do
     local cushion=chair:IsA("Model")and chair.Name=="Chair"and chair:FindFirstChild("Seat")
     if cushion and math.abs(cushion.Position.X-entry.x)<.1 and math.abs(cushion.Position.Z+1)<.1 then
      chair:PivotTo(CFrame.new(0,0,2.3)*chair:GetPivot());chair:SetAttribute("BattleChair",entry.key)
     end
    end
    if not station:FindFirstChild("PlayerSeat")then
    local seat=Instance.new("Seat");seat.Name="PlayerSeat";seat.Size=Vector3.new(2.5,.2,2.2);seat.CFrame=CFrame.new(entry.x,3.1,1.3)
    seat.Anchored=true;seat.Transparency=1;seat.CanCollide=false;seat.CanTouch=false;seat.Parent=station
    end
    local seat=station.PlayerSeat
    for _,chair in root:GetChildren()do
     local cushion=chair:IsA('Model')and chair.Name=='Chair'and chair:FindFirstChild('Cushion')
     if cushion and math.abs(cushion.Position.X-entry.x)<.1 and math.abs(cushion.Position.Z-1.3)<.1 then
      local position=cushion.Position+Vector3.new(0,cushion.Size.Y/2-seat.Size.Y/2+.01,0)
      seat.CFrame=CFrame.lookAt(position,Vector3.new(entry.x,position.Y,-7))
      local binding=seat:FindFirstChild('ChairModel')or Instance.new('ObjectValue');binding.Name='ChairModel';binding.Value=chair;binding.Parent=seat
     end
    end
   end
  end
 end
 local function ensureTableVisual(root)
  local storage=game:GetService("ServerStorage"):FindFirstChild("VochkoPrototype")
  local template=storage and storage:FindFirstChild("TavernTable")
  if not template then return end
  for _,definition in {{key="campaign",x=19,depth=9.47247314453125},{key="training",x=-19,depth=12.2},{key="pvp",x=0,depth=12.2}}do
   local station=root:FindFirstChild("Table_"..definition.key)
   if station then
    if not station:FindFirstChild("TavernTable")then
     local visual=template:Clone();visual.Name="TavernTable"
     local mesh=visual:FindFirstChildWhichIsA("MeshPart",true)
     if mesh then
      mesh.Size=Vector3.new(definition.depth,mesh.Size.Y,18.2)
      mesh.CFrame=CFrame.new(definition.x,1.2+mesh.Size.Y/2,-7)*CFrame.Angles(0,math.pi/2,0)
      mesh.Anchored=true;mesh.CanCollide=false;mesh.CanTouch=false;visual.Parent=station
     else visual:Destroy()end
    end
    for _,p in station:GetChildren()do
     if p:IsA("BasePart")and p.Name~="CardDeck"and p.Name~="DeckPaper"and p.Name~="LaneEdge"then p.Transparency=1 end
    end
    -- PvP is the only shared-table race: deck lives in the center next to an
    -- empty slot for the currently open card.
    if definition.key=="pvp"then
     local deck=station:FindFirstChild("CardDeck")
     if deck and math.abs(deck.Position.X)>0.05 then deck.CFrame=CFrame.new(0,4.77,-7) end
     local paper=station:FindFirstChild("DeckPaper")
     if paper and deck then paper.Position=deck.Position-Vector3.new(0,.02,0) end
     if not station:FindFirstChild("OpenCardSlot")then
      local slot=Instance.new("Part");slot.Name="OpenCardSlot";slot.Anchored=true;slot.CanCollide=false;slot.CanTouch=false
      slot.Size=Vector3.new(1.2,.05,1.7);slot.Color=Color3.fromRGB(205,186,140);slot.Material=Enum.Material.SmoothPlastic
      slot.CFrame=CFrame.new(1.7,4.62,-7);slot.Parent=station
     end
    end
   end
  end
 end
 local function ensureLamp(root)
 for _, station in {{x=-19,name="DuelTableLamp"},{x=0,name="CentralTableLamp"},{x=19,name="CampaignTableLamp"}} do
 if not root:FindFirstChild(station.name) then
 local lamp=Instance.new("Model");lamp.Name=station.name;lamp.Parent=root
 local function lampPart(name,size,pos,color,material)
  local p=Instance.new("Part");p.Name=name;p.Size=size;p.Position=pos+Vector3.new(station.x,0,0);p.Anchored=true;p.CanCollide=false;p.Color=color;p.Material=material;p.Parent=lamp;return p
 end
 lampPart("Suspension",Vector3.new(.12,4.7,.12),Vector3.new(0,15,-7),Color3.fromRGB(116,88,44),Enum.Material.Metal)
 lampPart("Shade",Vector3.new(5.2,.45,3.4),Vector3.new(0,12.5,-7),Color3.fromRGB(19,64,43),Enum.Material.Metal)
 lampPart("BrassRim",Vector3.new(5.35,.12,3.55),Vector3.new(0,12.23,-7),Color3.fromRGB(174,134,65),Enum.Material.Metal)
 local diffuser=lampPart("WarmDiffuser",Vector3.new(4.8,.12,3.05),Vector3.new(0,12.13,-7),Color3.fromRGB(255,218,151),Enum.Material.Neon)
 local down=Instance.new("SpotLight");down.Name="TableLight";down.Face=Enum.NormalId.Bottom;down.Angle=100;down.Range=22;down.Brightness=3;down.Color=Color3.fromRGB(255,218,167);down.Shadows=false;down.Parent=diffuser
 local glow=Instance.new("PointLight");glow.Name="LampGlow";glow.Range=12;glow.Brightness=.5;glow.Color=down.Color;glow.Shadows=false;glow.Parent=diffuser
 end
 end
 end
 local function arrangeTables(root)
  -- Migrate already-built places as well as fresh Rojo builds, once.
  local training=root:FindFirstChild("Table_training")
  if not training then training=root:FindFirstChild("Table_pvp");if training then training.Name="Table_training"end end
  if not training then return end
  local endless=root:FindFirstChild("Table_endless");if endless then endless:Destroy()end
  if not root:FindFirstChild("Table_pvp")then
   local copy=training:Clone();copy.Name="Table_pvp"
   for _,p in copy:GetDescendants()do if p:IsA("BasePart")then p.CFrame=CFrame.new(19,0,0)*p.CFrame end end
   copy.Parent=root
  end
  for _,entry in {{key="training",title="ТРЕНИРОВОЧНЫЙ",sub="Бой с ИИ"},{key="pvp",title="PVP",sub="Игрок против игрока"}}do
   local station=root:FindFirstChild("Table_"..entry.key)
   for _,v in station:GetDescendants()do
    if v:IsA("ProximityPrompt")and v.Name=="VochkoPrompt"then v.ObjectText=entry.title;v.Parent:SetAttribute("VochkoMode",entry.key)end
    if v:IsA("BillboardGui")and v.Name=="StationSign"then for _,label in v:GetChildren()do if label:IsA("TextLabel")then label.Text=if label.Position.Y.Scale==0 then entry.title else entry.sub end end end
   end
  end
 end
 local function pvpChairs(root)
  local station=root:FindFirstChild('Table_pvp');if not station then return end
  for _,v in station:GetDescendants()do if v:IsA('ProximityPrompt')and v.Name=='VochkoPrompt'then v.Enabled=false end end
  for i,z in {1.3,-15.3}do
   local name='PvPSeat'..i;local seat=station:FindFirstChild(name)
   if not seat then
    seat=Instance.new('Seat');seat.Name=name;seat.Anchored=true;seat.CanCollide=false;seat.CanTouch=false;seat.Transparency=1;seat.Size=Vector3.new(2.5,.2,2.2)
    seat.CFrame=CFrame.new(0,3.1,z)*CFrame.Angles(0,if i==2 then math.pi else 0,0);seat:SetAttribute('PvPSide',i);seat.Parent=station
    local chair
    for _,m in root:GetChildren()do local c=m:IsA('Model')and m.Name=='Chair'and m:FindFirstChild('Seat');if c and math.abs(c.Position.X)<.1 and ((i==1 and c.Position.Z>0)or(i==2 and c.Position.Z< -10))then chair=m;break end end
    if chair and i==2 then chair:PivotTo(CFrame.new(0,0,-2.3)*chair:GetPivot())end
    local h=Instance.new('Highlight');h.Name='AvailableSeat';h.Adornee=chair or seat;h.FillColor=Color3.fromRGB(216,183,93);h.FillTransparency=.75;h.OutlineColor=Color3.fromRGB(255,221,128);h.DepthMode=Enum.HighlightDepthMode.Occluded;h.Parent=seat
    local p=Instance.new('ProximityPrompt');p.Name='PvPSeatPrompt';p.ActionText='Сесть';p.ObjectText='PvP · свободный стул';p.MaxActivationDistance=10;p.RequiresLineOfSight=false;p.Parent=seat
   end
  end
  -- Bind the real server seats to the visible cushions, including migrated places.
  for _,seat in {station.PvPSeat1,station.PvPSeat2}do
   local nearest,distance
   for _,m in root:GetChildren()do
    local cushion=m:IsA('Model')and m.Name=='Chair'and m:FindFirstChild('Cushion')
    if cushion then local d=(Vector2.new(cushion.Position.X,cushion.Position.Z)-Vector2.new(seat.Position.X,seat.Position.Z)).Magnitude
     if not distance or d<distance then nearest=m;distance=d end
    end
   end
   if nearest and distance<1 then
    local cushion=nearest.Cushion
    local position=cushion.Position+Vector3.new(0,cushion.Size.Y/2-seat.Size.Y/2+.01,0)
    seat.CFrame=CFrame.lookAt(position,Vector3.new(0,position.Y,-7))
    local binding=seat:FindFirstChild('ChairModel')or Instance.new('ObjectValue');binding.Name='ChairModel';binding.Value=nearest;binding.Parent=seat
    seat.AvailableSeat.Adornee=nearest
   end
  end
 end
 local existing = workspace:FindFirstChild("VochkoPrototype")
 if existing then assert(existing:GetAttribute("Owner") == "vochko.prototype.v1", "Name occupied by another model");arrangeTables(existing);ensureLamp(existing);ensureTableVisual(existing);ensureSeats(existing);pvpChairs(existing);return existing end
 local root = Instance.new("Model"); root.Name = "VochkoPrototype"; root:SetAttribute("Owner", "vochko.prototype.v1"); root.Parent = workspace
 local colors = { stone = Color3.fromRGB(36,42,36), wood = Color3.fromRGB(61,39,24), brass = Color3.fromRGB(159,124,61), felt = Color3.fromRGB(18,61,41) }
 local n = 0
 local function part(name, size, pos, color, material, parent)
  local p = Instance.new("Part"); p.Name = name; p.Size = size; p.Position = pos; p.Anchored = true
  p.Material = material or Enum.Material.Wood; p.Color = color; p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
  p.Parent = parent or root; n += 1; if n % 100 == 0 then task.wait() end; return p
 end
 local function sign(anchor, text, subtitle)
  local gui = Instance.new("BillboardGui"); gui.Name = "StationSign"; gui.Size = UDim2.fromOffset(240,70); gui.StudsOffset = Vector3.new(0,3.1,0); gui.MaxDistance = 60; gui.AlwaysOnTop = false; gui.Parent = anchor
  local title = Instance.new("TextLabel"); title.Size = UDim2.fromScale(1,.57); title.BackgroundTransparency = 1; title.Text = text; title.Font = Enum.Font.Garamond; title.TextSize = 28; title.TextColor3 = Color3.fromRGB(234,205,144); title.TextStrokeTransparency = .25; title.Parent = gui
  local sub = Instance.new("TextLabel"); sub.Position = UDim2.fromScale(0,.58); sub.Size = UDim2.fromScale(1,.4); sub.BackgroundTransparency = 1; sub.Text = subtitle; sub.Font = Enum.Font.Gotham; sub.TextSize = 13; sub.TextColor3 = Color3.fromRGB(192,199,171); sub.TextStrokeTransparency = .4; sub.Parent = gui
 end
 local function prompt(anchor, mode, title)
  anchor:SetAttribute("VochkoMode", mode)
  local p = Instance.new("ProximityPrompt"); p.Name = "VochkoPrompt"; p.ActionText = "Открыть"; p.ObjectText = title
  p.MaxActivationDistance = 12; p.HoldDuration = 0; p.RequiresLineOfSight = false; p.Parent = anchor
 end
 part("Foundation",Vector3.new(66,.8,48),Vector3.new(0,.4,0),colors.stone,Enum.Material.Slate)
 for x=-31,31,2 do part("FloorPlank",Vector3.new(1.94,.12,46),Vector3.new(x,.86,0),Color3.fromRGB(51+math.abs(x)%7,38,25),Enum.Material.WoodPlanks) end
 part("NorthWall",Vector3.new(66,17,1.4),Vector3.new(0,9,-24),colors.stone,Enum.Material.Cobblestone)
 for _, x in {-33,33} do
  part("SideWall",Vector3.new(1.4,17,48),Vector3.new(x,9,0),colors.stone,Enum.Material.Cobblestone)
  for z=-21,21,7 do part("Pillar",Vector3.new(1.9,18,1.9),Vector3.new(x,9.5,z),Color3.fromRGB(58,57,44),Enum.Material.Slate) end
 end
 for _, x in {-23,23} do part("EntranceWall",Vector3.new(20,17,1.4),Vector3.new(x,9,24),colors.stone,Enum.Material.Cobblestone) end
 for x=-30,30,10 do part("Beam",Vector3.new(1.2,1.3,48),Vector3.new(x,17.7,0),colors.wood,Enum.Material.Wood) end
 part("CentralRug",Vector3.new(56,.08,25),Vector3.new(0,1,0),Color3.fromRGB(20,43,30),Enum.Material.Fabric)
 for _,z in {-12.5,12.5} do part("RugBorder",Vector3.new(56,.04,.13),Vector3.new(0,1.06,z),colors.brass,Enum.Material.Metal) end
 local function chair(x,z,flip)
  local m=Instance.new("Model");m.Name="Chair";m.Parent=root
  part("Seat",Vector3.new(3,.45,2.8),Vector3.new(x,2.7,z),colors.wood,nil,m)
  part("Cushion",Vector3.new(2.7,.16,2.5),Vector3.new(x,3,z),Color3.fromRGB(54,72,45),Enum.Material.Fabric,m)
  for _,dx in {-1.1,1.1} do for _,dz in {-1,1} do part("Leg",Vector3.new(.35,1.9,.35),Vector3.new(x+dx,1.8,z+dz),colors.wood,nil,m) end end
  part("Back",Vector3.new(3,3,.45),Vector3.new(x,4.5,z+flip*1.25),colors.wood,nil,m)
  part("BackInset",Vector3.new(2.5,2.4,.12),Vector3.new(x,4.5,z+flip*1.0),Color3.fromRGB(45,60,39),Enum.Material.Fabric,m)
 end
 local modes={{x=-19,key="pvp",title="ДУЭЛЬ",sub="Игрок против игрока",felt=Color3.fromRGB(72,29,26)},
  {x=0,key="endless",title="БЕСКОНЕЧНОСТЬ",sub="Проверь свою сборку",felt=Color3.fromRGB(19,44,53)},
  {x=19,key="campaign",title="КАМПАНИЯ",sub="Темница · первый бой",felt=colors.felt}}
 for _, mode in modes do
  local m=Instance.new("Model");m.Name="Table_"..mode.key;m.Parent=root
  local top=part("Tabletop",Vector3.new(12,.65,7.7),Vector3.new(mode.x,4.1,-7),colors.wood,nil,m)
  part("Felt",Vector3.new(11.4,.1,7.1),Vector3.new(mode.x,4.48,-7),mode.felt,Enum.Material.Fabric,m)
  for _,dx in {-5.6,5.6} do part("BrassEdge",Vector3.new(.1,.08,7.1),Vector3.new(mode.x+dx,4.56,-7),colors.brass,Enum.Material.Metal,m) end
  for _,dz in {-3.4,3.4} do part("BrassEdge",Vector3.new(11.4,.08,.1),Vector3.new(mode.x,4.56,-7+dz),colors.brass,Enum.Material.Metal,m) end
  for _,dx in {-4.8,4.8} do for _,dz in {-2.5,2.5} do part("Leg",Vector3.new(.75,3,.75),Vector3.new(mode.x+dx,2.25,-7+dz),colors.wood,nil,m) end end
  for lane=-1,1 do
   part("CardSpace",Vector3.new(2.2,.025,3.3),Vector3.new(mode.x+lane*3.2,4.56,-7),Color3.fromRGB(48,73,45),Enum.Material.Fabric,m)
   for _,dx in {-1.05,1.05} do part("LaneEdge",Vector3.new(.035,.025,3.25),Vector3.new(mode.x+lane*3.2+dx,4.59,-7),colors.brass,Enum.Material.Metal,m) end
  end
  local deck=part("CardDeck",Vector3.new(1.1,.4,1.6),Vector3.new(mode.x+4.3,4.77,-9.2),Color3.fromRGB(99,49,31),Enum.Material.Fabric,m)
  part("DeckPaper",Vector3.new(1.07,.28,1.57),deck.Position-Vector3.new(0,.02,0),Color3.fromRGB(205,186,140),Enum.Material.SmoothPlastic,m)
  sign(top,mode.title,mode.sub);prompt(top,mode.key,mode.title);chair(mode.x,-1.0,1);chair(mode.x,-13,-1)
 end
 ensureLamp(root)
 local cabinet=Instance.new("Model");cabinet.Name="CollectionWardrobe";cabinet.Parent=root
 part("CabinetBack",Vector3.new(10,10,.6),Vector3.new(-23,6.1,16),colors.wood,nil,cabinet)
 for _,x in {-28,-18} do part("CabinetSide",Vector3.new(.6,10,3.2),Vector3.new(x,6.1,15),colors.wood,nil,cabinet) end
 local shelf
 for _,y in {1.3,4.3,7.3,10.8} do shelf=part("Shelf",Vector3.new(10,.4,3.5),Vector3.new(-23,y,15),colors.wood,nil,cabinet)
  part("ShelfEdge",Vector3.new(10,.15,.15),Vector3.new(-23,y+.12,13.2),colors.brass,Enum.Material.Metal,cabinet) end
 local assets=require(game.ReplicatedStorage.VochkoPrototype.Assets)
 local tarot=require(game.ReplicatedStorage.VochkoPrototype.Tarot)
 for i,d in tarot.List do
  local row=math.floor((i-1)/4);local col=(i-1)%4
  local card=part("CollectionCard_"..d.id,Vector3.new(1.2,1.8,.1),Vector3.new(-26.6+col*2.4,2.4+row*3,14),Color3.fromRGB(205,183,131),Enum.Material.SmoothPlastic,cabinet)
  local gui=Instance.new("SurfaceGui");gui.Face=Enum.NormalId.Front;gui.CanvasSize=Vector2.new(256,384);gui.Parent=card
  local art=Instance.new("ImageLabel");art.Size=UDim2.fromScale(1,1);art.BackgroundTransparency=1;art.Image=assets.Tarot[d.id];art.Parent=gui
 end
 sign(shelf,"ПОДГОТОВКА","Подготовка · таро · таланты");prompt(shelf,"wardrobe","Подготовка к партии")
 part("WardrobeCrown",Vector3.new(11,.8,4),Vector3.new(-23,11.6,15),colors.wood,nil,cabinet)
 for _,x in {-31,31} do for _,z in {-17,3,18} do
  part("Sconce",Vector3.new(.6,2,.6),Vector3.new(x,8,z),colors.brass,Enum.Material.Metal)
  local flame=part("WarmFlame",Vector3.new(.5,.8,.5),Vector3.new(x,9.3,z),Color3.fromRGB(255,177,66),Enum.Material.Neon);flame.Shape=Enum.PartType.Ball;flame.CanCollide=false
  local light=Instance.new("PointLight");light.Color=Color3.fromRGB(255,186,99);light.Range=24;light.Brightness=1.8;light.Shadows=false;light.Parent=flame
 end end
 local plaque=part("WelcomePlaque",Vector3.new(15,3,.4),Vector3.new(0,10,-23),colors.wood)
 local gui=Instance.new("SurfaceGui");gui.Face=Enum.NormalId.Back;gui.CanvasSize=Vector2.new(900,180);gui.Parent=plaque
 local title=Instance.new("TextLabel");title.Size=UDim2.fromScale(1,1);title.BackgroundTransparency=1;title.Font=Enum.Font.Garamond;title.Text="ВОЧКО  ·  КОМНАТА ПОЕДИНКОВ";title.TextSize=58;title.TextColor3=Color3.fromRGB(229,198,133);title.Parent=gui
 root:SetAttribute("SpawnPosition",Vector3.new(0,4.5,17));root:SetAttribute("Version",1)
 arrangeTables(root)
 ensureTableVisual(root)
 ensureSeats(root)
 pvpChairs(root)
 return root
end
