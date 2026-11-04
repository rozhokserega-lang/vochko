-- Temporary framing controls for playtesting; preferences survive battle navigation.
local UIS=game:GetService("UserInputService")
local Controls={}
local C={ink=Color3.fromRGB(12,27,21),gold=Color3.fromRGB(211,176,104),paper=Color3.fromRGB(241,224,184),green=Color3.fromRGB(35,65,48)}
local function make(class,props,parent)
 local o=Instance.new(class);for k,v in props do o[k]=v end;o.Parent=parent;return o
end
local function text(parent,name,value,x,y,w,h,size)
 return make("TextLabel",{Name=name,Text=value,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,Font=Enum.Font.GothamMedium,TextSize=size or 15,TextColor3=C.paper,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true},parent)
end
local function button(parent,name,value,pos,size)
 local b=make("TextButton",{Name=name,Text=value,Position=pos,Size=size,BackgroundColor3=C.green,BorderSizePixel=0,TextColor3=C.paper,TextSize=15,Font=Enum.Font.GothamBold},parent)
 make("UICorner",{CornerRadius=UDim.new(0,7)},b);make("UIStroke",{Color=C.gold,Transparency=.25},b);return b
end
function Controls.Create(parent,scene,viewport)
 local self={connections={},sliders={},dead=false}
 local active,dragInput
 local panel=make("Frame",{Name="CameraSettings",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-12,0,150),Size=UDim2.fromOffset(330,380),BackgroundColor3=C.ink,BackgroundTransparency=.04,BorderSizePixel=0,Visible=false,Active=true,ZIndex=40},parent)
 make("UICorner",{CornerRadius=UDim.new(0,10)},panel);make("UIStroke",{Color=C.gold},panel)
 local toggle=button(parent,"CameraToggle","Камера",UDim2.new(1,-230,0,7),UDim2.fromOffset(104,32));toggle.ZIndex=41
 text(panel,"Title","Ракурс камеры",14,9,255,28,20)
 local close=button(panel,"Close","×",UDim2.fromOffset(288,9),UDim2.fromOffset(28,28))
 local stateLabel=text(panel,"State","Настрой ракурс и зафиксируй его",14,37,302,28,12)
 local definitions={
  {key="distance",name="Ближе / дальше",min=-3,max=8,unit=""},
  {key="height",name="Высота",min=7,max=18,unit=""},
  {key="pitch",name="Наклон взгляда",min=18,max=60,unit="°"},
  {key="fov",name="Ширина обзора",min=45,max=95,unit="°"},
 }
 local function connect(signal,callback)local c=signal:Connect(callback);table.insert(self.connections,c);return c end
 local function apply()scene.Camera(viewport(),false)end
 local fix=button(panel,"Fix","Зафиксировать",UDim2.fromOffset(14,310),UDim2.fromOffset(184,36))
 local reset=button(panel,"Reset","Сбросить",UDim2.fromOffset(210,310),UDim2.fromOffset(106,36))
 local export=text(panel,"Values","",14,351,302,22,11)
 local function refresh()
  if self.dead then return end
  local values=scene.GetCameraSettings(viewport())
  local locked=scene.CameraLocked
  stateLabel.Text=if locked then "Ракурс зафиксирован для этой проверки" else "Изменения сразу видны в игре"
  fix.Text=if locked then "Изменить ракурс" else "Зафиксировать"
  for _,d in definitions do
   local row=self.sliders[d.key];local n=values[d.key]
   row.value.Text=string.format("%.1f%s",n,d.unit)
   row.knob.Position=UDim2.fromScale((n-d.min)/(d.max-d.min),.5)
   row.fill.Size=UDim2.fromScale((n-d.min)/(d.max-d.min),1)
   row.hit.Active=not locked;row.knob.BackgroundColor3=if locked then Color3.fromRGB(134,139,121)else C.gold
  end
  export.Text=string.format("Z %.2f · H %.2f · наклон %.2f° · обзор %.2f°",values.distance,values.height,values.pitch,values.fov)
 end
 local function drag(d,x)
  if scene.CameraLocked or self.dead then return end
  local rail=self.sliders[d.key].rail
  local ratio=math.clamp((x-rail.AbsolutePosition.X)/math.max(1,rail.AbsoluteSize.X),0,1)
  scene.SetCameraSetting(viewport(),d.key,d.min+(d.max-d.min)*ratio);apply();refresh()
 end
 for i,d in definitions do
  local y=70+(i-1)*58
  text(panel,d.key.."Label",d.name,14,y,214,24,15)
  local value=text(panel,d.key.."Value","",230,y,86,24,14);value.TextXAlignment=Enum.TextXAlignment.Right
  local rail=make("Frame",{Name=d.key.."Rail",Position=UDim2.fromOffset(22,y+36),Size=UDim2.fromOffset(286,7),BackgroundColor3=C.green,BorderSizePixel=0},panel)
  make("UICorner",{CornerRadius=UDim.new(1,0)},rail)
  local fill=make("Frame",{Name="Fill",Size=UDim2.fromScale(.5,1),BackgroundColor3=C.gold,BorderSizePixel=0},rail)
  local knob=make("Frame",{Name="Knob",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(20,20),BackgroundColor3=C.gold,BorderSizePixel=0},rail)
  make("UICorner",{CornerRadius=UDim.new(1,0)},knob)
  local hit=make("TextButton",{Name=d.key.."Slider",Text="",Position=UDim2.fromOffset(14,y+22),Size=UDim2.fromOffset(302,34),BackgroundTransparency=1,Active=true,AutoButtonColor=false},panel)
  self.sliders[d.key]={rail=rail,fill=fill,knob=knob,hit=hit,value=value}
  connect(hit.InputBegan,function(input)
   if scene.CameraLocked then return end
   if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then active=d;dragInput=input;drag(d,input.Position.X)end
  end)
 end
 local function open(value)
  panel.Visible=value;scene.CameraTuning=value;active=nil;dragInput=nil
  toggle.Text=if value then "Камера ×" else "Камера";refresh()
 end
 connect(toggle.Activated,function()open(not panel.Visible)end)
 connect(close.Activated,function()open(false)end)
 connect(fix.Activated,function()scene.CameraLocked=not scene.CameraLocked;active=nil;refresh();if scene.CameraLocked then open(false)end end)
 connect(reset.Activated,function()scene.CameraLocked=false;scene.ResetCameraSettings(viewport());apply();refresh()end)
 connect(UIS.InputChanged,function(input)
  if active and panel.Visible and (input.UserInputType==Enum.UserInputType.MouseMovement or input==dragInput)then drag(active,input.Position.X)end
 end)
 connect(UIS.InputEnded,function(input)
  if input.UserInputType==Enum.UserInputType.MouseButton1 or input==dragInput then active=nil;dragInput=nil end
 end)
 -- No world action should pass through the camera panel while framing a shot.
 for _,o in panel:GetDescendants()do if o:IsA("GuiObject")then o.ZIndex=41 end end
 function self:Refresh()
  local compact=viewport().X<650
  panel.Position=UDim2.new(1,-12,0,if compact then 145 else 150)
  local scale=math.min(1,math.max(.65,(viewport().Y-160)/380))
  local uiScale=panel:FindFirstChildOfClass("UIScale") or make("UIScale",{},panel);uiScale.Scale=scale
  refresh()
 end
 function self:Destroy()
  self.dead=true;active=nil;scene.CameraTuning=false
  for _,c in self.connections do c:Disconnect()end
  panel:Destroy();toggle:Destroy()
 end
 self:Refresh();return self
end
return Controls
