-- Client-only presentation. Never owns combat rules or unrevealed cards.
local TweenService=game:GetService("TweenService")
local Assets=require(script.Parent.Assets)
local Scene={}
local model,nodes,labels,edges,head,home,receipt,session
local function part(name,size,pos,color,material)
 local p=Instance.new("Part");p.Name=name;p.Size=size;p.Position=pos;p.Color=color;p.Material=material or Enum.Material.SmoothPlastic;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Parent=model;return p
end
local function label(p,content)
 local gui=Instance.new("SurfaceGui");gui.Face=Enum.NormalId.Top;gui.CanvasSize=Vector2.new(500,150);gui.Parent=p
 local t=Instance.new("TextLabel");t.Size=UDim2.fromScale(1,1);t.BackgroundTransparency=1;t.Text=content;t.TextColor3=Color3.fromRGB(240,215,161);t.TextSize=65;t.Font=Enum.Font.Garamond;t.Parent=gui;return t
end
function Scene.Destroy()
 local room=workspace:FindFirstChild("VochkoPrototype");local station=room and room:FindFirstChild("Table_campaign");local sign=station and station:FindFirstChild("StationSign",true);if sign then sign.Enabled=true end
 if model then model:Destroy()end;model=nil;nodes={};labels={};edges={};receipt=0;session=nil
end
function Scene.Create()
 Scene.Destroy();model=Instance.new("Model");model.Name="VochkoLocalBattleScene";model.Parent=workspace
 local room=workspace:FindFirstChild("VochkoPrototype");local station=room and room:FindFirstChild("Table_campaign");local sign=station and station:FindFirstChild("StationSign",true);if sign then sign.Enabled=false end
 -- Seated, stylised opponent. The silhouette stays clear behind the three zones.
 part("Coat",Vector3.new(3.4,2.8,1.5),Vector3.new(19,6.7,-13),Color3.fromRGB(38,27,24))
 part("Waistcoat",Vector3.new(1.7,2.2,.12),Vector3.new(19,6.7,-12.2),Color3.fromRGB(95,35,29))
 head=part("Head",Vector3.new(1.8,1.8,1.65),Vector3.new(19,9,-12.8),Color3.fromRGB(204,157,102));home=head.CFrame
 part("HatBrim",Vector3.new(3,.2,2.6),Vector3.new(19,10,-12.8),Color3.fromRGB(28,24,22))
 part("HatCrown",Vector3.new(2.1,1.2,1.9),Vector3.new(19,10.65,-12.8),Color3.fromRGB(28,24,22))
 part("HatRibbon",Vector3.new(2.14,.25,1.94),Vector3.new(19,10.23,-12.8),Color3.fromRGB(119,43,31))
 for _,x in {-1,1} do
  part("Sleeve",Vector3.new(1,1.2,2.4),Vector3.new(19+x*1.8,5.6,-11.7),Color3.fromRGB(38,27,24))
  part("Hand",Vector3.new(.9,.5,1),Vector3.new(19+x*1.8,5,-10.2),Color3.fromRGB(204,157,102))
  part("Eye",Vector3.new(.14,.17,.08),Vector3.new(19+x*.38,9.15,-11.94),Color3.fromRGB(25,21,18))
 end
 part("Smile",Vector3.new(.6,.08,.08),Vector3.new(19,8.55,-11.94),Color3.fromRGB(69,42,26))
 for i=1,3 do
  local x=19+(i-2)*3.2
  local plate=part("ZonePlaque"..i,Vector3.new(2.8,.08,.7),Vector3.new(x,4.65,-4.25),Color3.fromRGB(42,28,19));labels[i]=label(plate,"—")
  edges[i]={}
  for _,dx in {-1.35,1.35}do table.insert(edges[i],part("Selection",Vector3.new(.055,.04,3.6),Vector3.new(x+dx,4.65,-7),Color3.fromRGB(169,133,68),Enum.Material.Metal))end
 end
end
function Scene.Camera(viewport,animate)
 local camera=workspace.CurrentCamera;if not camera then return end
 local portrait=viewport.Y>viewport.X
 local position=if portrait then Vector3.new(19,12,6.4)else Vector3.new(19,10.4,2.7)
 local target=if portrait then Vector3.new(19,6.2,-8)else Vector3.new(19,6.3,-8.5)
 camera.CameraType=Enum.CameraType.Scriptable;camera.FieldOfView=if portrait then 72 else 62
 if animate then TweenService:Create(camera,TweenInfo.new(.55,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{CFrame=CFrame.lookAt(position,target)}):Play()else camera.CFrame=CFrame.lookAt(position,target)end
end
function Scene.Update(s)
 if not model then Scene.Create()end
 if session~=s.id then nodes={};session=s.id;receipt=0 end
 local keep={}
 for i,z in s.zones do
  local evaluation=s.forecast.zones[i];labels[i].Text="ЗОНА "..i.."  ·  "..(if #z.cards>0 then tostring(evaluation.sum)else "—")
  for _,edge in edges[i]do edge.Material=if s.active==i then Enum.Material.Neon else Enum.Material.Metal;edge.Color=if evaluation.bust then Color3.fromRGB(218,69,51)elseif s.active==i then Color3.fromRGB(107,216,139)else Color3.fromRGB(169,133,68)end
  for ci,card in z.cards do
   keep[card.id]=true
   local destination=CFrame.new(19+(i-2)*3.2+(ci-1)*.13,4.7+ci*.025,-8.3+(ci-1)*.6)
   local node=nodes[card.id]
   if not node then
    node=part("Card_"..card.id,Vector3.new(1.55,.035,2.15),Vector3.new(23.3,5,-9.2),Color3.fromRGB(228,207,159));nodes[card.id]=node
    local face=Instance.new("SurfaceGui");face.Face=Enum.NormalId.Top;face.CanvasSize=Vector2.new(216,300);face.Parent=node
    local image=Instance.new("ImageLabel");image.BackgroundTransparency=1;image.Size=UDim2.fromScale(1,1);image.Image=Assets.Cards;image.ImageRectOffset=Vector2.new((card.rankIndex-1)*Assets.CardWidth,(card.suitIndex-1)*Assets.CardHeight);image.ImageRectSize=Vector2.new(Assets.CardWidth,Assets.CardHeight);image.Parent=face
    TweenService:Create(node,TweenInfo.new(.22,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{CFrame=destination}):Play()
   else node.CFrame=destination end
  end
 end
 for id,node in nodes do if not keep[id]then node:Destroy();nodes[id]=nil end end
 if s.receipt and s.receipt.round>receipt then
  receipt=s.receipt.round
  local back=TweenService:Create(head,TweenInfo.new(.12),{CFrame=home*CFrame.Angles(math.rad(-12),0,0)});back:Play()
  task.delay(.14,function()if head and head.Parent then TweenService:Create(head,TweenInfo.new(.25),{CFrame=home}):Play()end end)
 end
end
return Scene
