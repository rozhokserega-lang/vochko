-- Presentation only: the server receipt owns every damage amount and final HP.
local TweenService=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local Impact={}
local function make(class,props,parent)
 local o=Instance.new(class);for k,v in props do o[k]=v end;o.Parent=parent;return o
end
function Impact.Play(args)
 local folder=make("Folder",{Name="CardImpact"},args.parent)
 local job={cancelled=false}
 local head=args.head;local home=head.CFrame;local skin=head.Color
 local hits=table.clone(args.receipt.hits or {})
 for _,entry in args.receipt.returns or {}do local item=table.clone(entry);item.returning=true;table.insert(hits,item)end
 local remaining=#hits
 local hp=args.receipt.enemyBefore
 local function done()
  if job.cancelled then return end
  job.cancelled=true
  if head.Parent then head.CFrame=home;head.Color=skin end
  folder:Destroy();args.done()
 end
 function job:Cancel()
  if self.cancelled then return end;self.cancelled=true
  if head.Parent then head.CFrame=home;head.Color=skin end
  folder:Destroy()
 end
 if remaining==0 then task.delay(.18,done);return job end
 for i,hit in hits do
  task.delay((i-1)*.065,function()
   if job.cancelled or not head.Parent then return end
   local node=args.nodes[hit.card.id]
   if not node then
    remaining-=1;if remaining==0 then done()end;return
   end
   local center=node.AbsolutePosition+node.AbsoluteSize/2
   local plane=args.plane
   local point=plane.CFrame:PointToWorldSpace(Vector3.new((center.Y/(args.canvasHeight or 900)-.5)*plane.Size.X,plane.Size.Y/2+.04,(.5-center.X/1800)*plane.Size.Z))
   local card=make("Part",{Name="StrikingCard",Size=Vector3.new(1.9,.035,1.38),CFrame=CFrame.new(point)*plane.CFrame.Rotation,Color=Color3.fromRGB(234,213,166),Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false},folder)
   local gui=make("SurfaceGui",{Face=Enum.NormalId.Top,CanvasSize=Vector2.new(144,200),LightInfluence=0},card)
   local face=node:Clone();face.Visible=true;face.Position=UDim2.new();face.Rotation=0;face.Size=UDim2.fromScale(1,1);face.Parent=gui
   node.Visible=false
   local goal=if hit.returning and args.deck then args.deck.Position+Vector3.new(0,.08,0)else head.Position+Vector3.new((i%3-1)*.32,-.35,.85)
   local mid=(point+goal)/2+Vector3.new(0,1.65,0)
   local lift=TweenService:Create(card,TweenInfo.new(.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{CFrame=CFrame.new(mid)*plane.CFrame.Rotation*CFrame.Angles(0,.3,0)})
   lift:Play()
   lift.Completed:Once(function(state)
    if job.cancelled or state~=Enum.PlaybackState.Completed then return end
    local strike=TweenService:Create(card,TweenInfo.new(.19,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{CFrame=CFrame.new(goal)*plane.CFrame.Rotation*CFrame.Angles(.6,0,.25),Size=Vector3.new(1.45,.035,1.05)})
    strike:Play()
    strike.Completed:Once(function(status)
     if job.cancelled or status~=Enum.PlaybackState.Completed then return end
     card:Destroy()
     if hit.returning then
      remaining-=1;if remaining==0 then task.delay(.22,done)end
      return
     end
     hp=math.max(args.receipt.enemyAfter,hp-hit.damage)
     args.hit(hp,args.maxHp,hit.damage)
     if hit.damage>0 then
      head.Color=Color3.fromRGB(255,146,110)
      TweenService:Create(head,TweenInfo.new(.08),{CFrame=home*CFrame.new(0,0,-.14)*CFrame.Angles(math.rad(-7),0,0)}):Play()
      task.delay(.09,function()if not job.cancelled and head.Parent then TweenService:Create(head,TweenInfo.new(.13),{CFrame=home,Color=skin}):Play()end end)
      local pop=make("BillboardGui",{Name="CardDamage",Adornee=head,Size=UDim2.fromOffset(150,60),StudsOffset=Vector3.new((i%3-1)*.6,1,0),AlwaysOnTop=true},folder)
      local text=make("TextLabel",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="−"..hit.damage,TextColor3=Color3.fromRGB(255,218,125),TextStrokeTransparency=.3,TextSize=35,Font=Enum.Font.GothamBold},pop)
      TweenService:Create(text,TweenInfo.new(.5),{Position=UDim2.fromOffset(0,-35),TextTransparency=1,TextStrokeTransparency=1}):Play();Debris:AddItem(pop,.55)
      for n=1,4 do
       local spark=make("Part",{Name="ImpactSpark",Size=Vector3.new(.055,.055,.3),CFrame=CFrame.new(goal),Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,Material=Enum.Material.Neon,Color=Color3.fromRGB(255,205,99)},folder)
       TweenService:Create(spark,TweenInfo.new(.18),{Position=goal+Vector3.new(math.cos(n*1.57)*.5,math.sin(n*1.57)*.5,.2),Transparency=1}):Play();Debris:AddItem(spark,.2)
      end
     end
     remaining-=1
     if remaining==0 then task.delay(.22,done)end
    end)
   end)
  end)
 end
 -- Completion fallback for a destroyed card/tween. Never leaves controls stuck.
 task.delay(3,function()if not job.cancelled then args.hit(args.receipt.enemyAfter,args.maxHp,0);done()end end)
 return job
end
return Impact
