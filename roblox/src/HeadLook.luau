-- Local, bounded head movement. No orbit, zoom or gameplay state changes.
local UIS=game:GetService('UserInputService')
local Run=game:GetService('RunService')
local HeadLook={}
function HeadLook.Create(scene)
 local self={};local drag,start,lastMouse,step
 local yaw,pitch,targetYaw,targetPitch=0,0,0,0
 local connections={}
 local function stop()
  if step then step:Disconnect();step=nil end
 end
 local function animate()
  if step then return end
  step=Run.RenderStepped:Connect(function(dt)
   if scene.CameraTuning or scene.HUDTuning then drag=nil;targetYaw=0;targetPitch=0 end
   local alpha=1-math.exp(-18*math.min(dt,.1))
   yaw+=(targetYaw-yaw)*alpha;pitch+=(targetPitch-pitch)*alpha
   local camera=workspace.CurrentCamera
   if camera and scene.CameraBase then camera.CFrame=scene.CameraBase*CFrame.Angles(math.rad(pitch),math.rad(yaw),0)end
   if not drag and math.abs(yaw)<.02 and math.abs(pitch)<.02 then
    if camera and scene.CameraBase then camera.CFrame=scene.CameraBase end
    yaw=0;pitch=0;stop()
   end
  end)
 end
 function self:Begin(input)
  if scene.CameraTuning or scene.HUDTuning or scene.ImpactActive then return end
  drag=input;start=Vector2.new(input.Position.X,input.Position.Y);lastMouse=UIS:GetMouseLocation()
  targetYaw=0;targetPitch=0;animate()
 end
 table.insert(connections,UIS.InputChanged:Connect(function(input)
  if not drag then return end
  local mouse=drag.UserInputType==Enum.UserInputType.MouseButton2
  if (mouse and input.UserInputType~=Enum.UserInputType.MouseMovement)or(not mouse and input~=drag)then return end
  local delta
  if mouse then local pos=UIS:GetMouseLocation();delta=pos-lastMouse;lastMouse=pos
   targetYaw=math.clamp(targetYaw-delta.X*.13,-24,24);targetPitch=math.clamp(targetPitch+delta.Y*.16,-10,45)
  else delta=Vector2.new(input.Position.X,input.Position.Y)-start
   targetYaw=math.clamp(-delta.X*.13,-24,24);targetPitch=math.clamp(delta.Y*.16,-10,45)
  end
 end))
 table.insert(connections,UIS.InputEnded:Connect(function(input)
  if input==drag or (drag and drag.UserInputType==Enum.UserInputType.MouseButton2 and input.UserInputType==Enum.UserInputType.MouseButton2)then drag=nil;targetYaw=0;targetPitch=0 end
 end))
 function self:Destroy()
  drag=nil;stop();for _,c in connections do c:Disconnect()end
 end
 return self
end
return HeadLook
