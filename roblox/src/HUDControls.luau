local UIS=game:GetService("UserInputService")
local HUD={}
local saved={}
local function make(class,props,parent)local o=Instance.new(class);for k,v in props do o[k]=v end;o.Parent=parent;return o end
function HUD.Create(app,panels,scene,viewport,relayout,returnButton)
 local self={editing=false,connections={},dead=false};local draft,active,lastMode
 local function mode()local v=viewport();return if scene.IsMobileView(v)then (if v.Y>v.X then "phone-portrait"else "phone-landscape")else "desktop"end
 local function connect(signal,fn)local c=signal:Connect(fn);table.insert(self.connections,c);return c end
 local toolbar=make("Frame",{Name="HUDSettings",Size=UDim2.fromOffset(300,44),BackgroundTransparency=1,ZIndex=70},app)
 local function button(name,label,x,width)
  local b=make("TextButton",{Name=name,Text=label,Position=UDim2.fromOffset(x,0),Size=UDim2.fromOffset(width,40),BackgroundColor3=Color3.fromRGB(28,57,43),TextColor3=Color3.fromRGB(240,217,167),Font=Enum.Font.Garamond,TextSize=16,BorderSizePixel=0,ZIndex=71},toolbar)
  make("UICorner",{CornerRadius=UDim.new(0,6)},b);return b
 end
 local toggle=button("Toggle","Настроить HP",0,112)
 local fix=button("Fix","Зафиксировать",120,116)
 local reset=button("Reset","Сброс",244,68)
 local handles,scales,trays={},{},{}
 local function changeScale(index,delta)
  if not self.editing then return end
  local entry=table.clone(draft[index]or {})
  entry.scale=math.clamp(math.floor(((entry.scale or 1)+delta)*100+.5)/100,.65,1.25)
  draft[index]=entry;active=nil;relayout()
 end
 for i,panel in panels do
  scales[i]=make("UIScale",{Name="HUDScale",Scale=1},panel)
  local tray=make("Frame",{Name="ResizeHP"..i,Size=UDim2.fromOffset(176,44),BackgroundColor3=Color3.fromRGB(16,34,26),BorderSizePixel=0,ZIndex=72,Visible=false},app)
  local minus=make("TextButton",{Name="Minus",Text="−",Size=UDim2.fromOffset(44,44),BackgroundColor3=Color3.fromRGB(35,66,47),TextColor3=Color3.fromRGB(240,217,167),TextSize=27,Font=Enum.Font.Garamond,ZIndex=73,BorderSizePixel=0},tray)
  local value=make("TextLabel",{Name="Value",Text="100%",Position=UDim2.fromOffset(44,0),Size=UDim2.fromOffset(88,44),BackgroundTransparency=1,TextColor3=Color3.fromRGB(240,217,167),TextSize=15,Font=Enum.Font.Garamond,ZIndex=73},tray)
  local plus=minus:Clone();plus.Name="Plus";plus.Text="+";plus.Position=UDim2.fromOffset(132,0);plus.Parent=tray
  trays[i]={root=tray,value=value,minus=minus,plus=plus}
  connect(minus.Activated,function()changeScale(i,-.1)end);connect(plus.Activated,function()changeScale(i,.1)end)
  local handle=make("TextButton",{Name="DragHP",Size=UDim2.fromScale(1,1),Text="↕",Font=Enum.Font.Garamond,TextSize=30,TextColor3=Color3.fromRGB(255,218,123),TextStrokeTransparency=.3,BackgroundColor3=Color3.fromRGB(90,73,28),BackgroundTransparency=.65,ZIndex=65,Visible=false,Active=true},panel);handles[i]=handle
  connect(handle.InputBegan,function(input)
   if not self.editing then return end
   if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
    active={index=i,input=input,start=Vector2.new(input.Position.X,input.Position.Y),origin=panel.AbsolutePosition-app.AbsolutePosition}
   end
  end)
 end
 local function finish(commit)
  if commit then
   -- The drag draft is already normalized. Re-reading AbsolutePosition in a
   -- click/layout event can see the previous GUI frame and save a stale point.
   saved[mode()]=table.clone(draft or {})
  end
  self.editing=false;scene.HUDTuning=false;draft=nil;active=nil;relayout()
 end
 connect(toggle.Activated,function()
  if scene.CameraTuning then return end
  if self.editing then finish(false)else self.editing=true;scene.HUDTuning=true;draft=table.clone(saved[mode()]or {});relayout()end
 end)
 connect(fix.Activated,function()finish(true)end)
 connect(reset.Activated,function()draft={};active=nil;relayout()end)
 connect(UIS.InputChanged,function(input)
  if not active or not self.editing then return end
  if input.UserInputType~=Enum.UserInputType.MouseMovement and input~=active.input then return end
  local v=viewport();local panel=panels[active.index]
  local delta=Vector2.new(input.Position.X,input.Position.Y)-active.start
  local x=math.clamp(active.origin.X+delta.X,4,math.max(4,v.X-panel.AbsoluteSize.X-4))
  local y=math.clamp(active.origin.Y+delta.Y,48,math.max(48,v.Y-panel.AbsoluteSize.Y-4))
  panel.AnchorPoint=Vector2.new();panel.Position=UDim2.fromOffset(x,y)
  local entry=table.clone(draft[active.index]or {});entry.x=x/math.max(1,v.X);entry.y=y/math.max(1,v.Y);draft[active.index]=entry
 end)
 connect(UIS.InputEnded,function(input)if active and (input==active.input or input.UserInputType==Enum.UserInputType.MouseButton1)then active=nil end end)
 function self:Apply()
  if scene.IsMobileView(viewport())then
   self.editing=false;scene.HUDTuning=false;draft=nil;active=nil
   toolbar.Visible=false;returnButton.Visible=true
   for _,h in handles do h.Visible=false end
   for _,s in scales do s.Scale=1 end
   for _,t in trays do t.root.Visible=false end
   return
  end
  toolbar.Visible=true
  local key=mode();if lastMode and key~=lastMode then self.editing=false;scene.HUDTuning=false;active=nil;draft=nil end;lastMode=key
  local mobile=scene.IsMobileView(viewport());toolbar.Position=if mobile then UDim2.fromOffset(6,4)else UDim2.new(1,-342,0,7)
  toolbar.Size=UDim2.fromOffset(if self.editing then 318 else 112,44)
  if not mobile and self.editing then toolbar.Position=UDim2.fromOffset(12,7)end
  toggle.Text=if self.editing then "Отмена"else "Настроить HP";fix.Visible=self.editing;reset.Visible=self.editing
  returnButton.Visible=not self.editing
  for _,h in handles do h.Visible=self.editing end
  local v=viewport();local positions=if self.editing then draft else saved[key]
  if v.X<=0 or v.Y<=0 then task.defer(function()if not self.dead then relayout()end end);return end
  for i,p in panels do
   local pos=positions and positions[i]
   local scale=if pos then pos.scale or 1 else 1
   scales[i].Scale=scale
   local parentSize=p.Parent.AbsoluteSize
   local size=Vector2.new(p.Size.X.Scale*parentSize.X+p.Size.X.Offset,p.Size.Y.Scale*parentSize.Y+p.Size.Y.Offset)*scale
   if pos and pos.x and pos.y then
    p.AnchorPoint=Vector2.new();p.Position=UDim2.fromOffset(math.clamp(pos.x*v.X,4,math.max(4,v.X-size.X-4)),math.clamp(pos.y*v.Y,48,math.max(48,v.Y-size.Y-4)))
   end
   local tray=trays[i];tray.root.Visible=self.editing;tray.value.Text=(if i==1 then "Ты "else "Враг ")..math.floor(scale*100+.5).."%"
   local base=Vector2.new(p.Position.X.Scale*parentSize.X+p.Position.X.Offset,p.Position.Y.Scale*parentSize.Y+p.Position.Y.Offset)-Vector2.new(p.AnchorPoint.X*size.X,p.AnchorPoint.Y*size.Y)
   local x=math.clamp(base.X+size.X/2-88,4,math.max(4,v.X-180))
   local y=base.Y+size.Y+6;if y+44>v.Y-4 then y=base.Y-50 end;y=math.clamp(y,48,math.max(48,v.Y-48))
   tray.root.Position=UDim2.fromOffset(x,y)
  end
 end
 function self:Destroy()
  self.dead=true;scene.HUDTuning=false
  for _,c in self.connections do c:Disconnect()end
  for _,h in handles do h:Destroy()end;for _,s in scales do s:Destroy()end;for _,t in trays do t.root:Destroy()end;toolbar:Destroy()
 end
 return self
end
return HUD
