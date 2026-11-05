-- Server-owned physical seating; combat HP is independent of the avatar Humanoid.
local Seating={}
local occupied={}
function Seating.Leave(player)
 local entry=occupied[player];occupied[player]=nil
 if not entry then return end
 local h=entry.humanoid
 if h and h.Parent then
  h.Sit=false;h.WalkSpeed=entry.speed;h.AutoRotate=entry.rotate
  h.JumpPower=entry.jumpPower;h.JumpHeight=entry.jumpHeight;h:SetStateEnabled(Enum.HumanoidStateType.Jumping,entry.jumping)
  local character=h.Parent
  task.defer(function()
   task.wait(.05)
   if character.Parent and not occupied[player]then character:PivotTo(entry.exitFrame)end
  end)
 end
end
function Seating.Enter(player,mode,side)
 local character=player.Character;local h=character and character:FindFirstChildOfClass("Humanoid")
 if not h or h.Health<=0 then return false,"Персонаж ещё не готов"end
 local key=if mode=="duel"or mode=="training"then "training"elseif mode=="pvp"then "pvp"else "campaign"
 local room=workspace:FindFirstChild("VochkoPrototype");local station=room and room:FindFirstChild("Table_"..key)
 local seat=station and station:FindFirstChild(if mode=='pvp'then 'PvPSeat'..(side or 1)else 'PlayerSeat')
 if not seat then return false,"У стола пока нет места для игрока"end
 if seat.Occupant and seat.Occupant~=h then return false,"Это место уже занято"end
 local existing=occupied[player]
 if existing and existing.seat==seat and h.SeatPart==seat then return true end
 Seating.Leave(player)
 occupied[player]={seat=seat,humanoid=h,exitFrame=seat.CFrame*CFrame.new(0,1.5,3),speed=h.WalkSpeed,rotate=h.AutoRotate,jumpPower=h.JumpPower,jumpHeight=h.JumpHeight,jumping=h:GetStateEnabled(Enum.HumanoidStateType.Jumping)}
 h.WalkSpeed=0;h.AutoRotate=false;h.JumpPower=0;h.JumpHeight=0;h:SetStateEnabled(Enum.HumanoidStateType.Jumping,false)
 character:PivotTo(seat.CFrame*CFrame.new(0,2,0))
 for _=1,3 do
  if not character.Parent or h.Health<=0 then Seating.Leave(player);return false,'Персонаж больше не доступен'end
  seat:Sit(h);task.wait(.05)
  if seat.Occupant==h and h.SeatPart==seat then return true end
 end
 Seating.Leave(player);return false,'Не удалось сесть. Попробуй занять стул ещё раз'
end
return Seating
