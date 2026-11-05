-- One server-owned, two-seat match. No hidden deck is sent to either client.
local Duel=require(script.Parent.Duel)
local Battle=require(script.Parent.Battle)
local Loadout=require(game.ReplicatedStorage.VochkoPrototype.Loadout)
local Net={};Net.__index=Net
local function terminal(phase)return phase=='won'or phase=='lost'or phase=='draw'end
function Net.new(context)
 return setmetatable({ctx=context,slots={},members={},match=nil},Net)
end
function Net:Locked(p)local e=self.members[p];return e and self.match and not self.match.finished end
function Net:Notify()for p in self.members do self.ctx.push(p)end end
function Net:Join(p,index)
 if index~=1 and index~=2 then return false,'Выбери свободный стул'end
 if self.match and not self.match.finished then return false,'За столом идёт дуэль'end
 if self.match and self.match.finished then return false,'Дождись, пока игроки освободят стол'end
 if self.slots[index]and self.slots[index]~=p then return false,'Стул уже занят'end
 if self.members[p]then return true end
 local build=self.ctx.profile(p);local valid,why=Loadout.Validate(build.class,build.jokers,build.duelTarot)
 if not valid then return false,why end
 local ok,msg=self.ctx.sit(p,index);if not ok then return false,msg end
 self.slots[index]=p;self.members[p]={index=index,build={class=build.class,jokers=table.clone(build.jokers),tarot=table.clone(build.duelTarot)}}
 if self.slots[1]and self.slots[2]then
  local a,b=self.members[self.slots[1]].build,self.members[self.slots[2]].build
  local c=self.ctx.config();local seed=Random.new():NextInteger(1,1000000000)
  local s=Duel.New(c,seed,a.class,self.ctx.id(),a.tarot,b.tarot,a.jokers,{class=b.class,jokers=b.jokers})
  s.network=true;s.botReady=true;s.phase='countdown'
  self.match={state=s,ready={false,false},deadline=self.ctx.now()+3,players={self.slots[1],self.slots[2]}}
 end
 self:RefreshChairs();self:Notify();return true
end
function Net:RefreshChairs()
 if not self.ctx.chairs then return end
 for i,seat in self.ctx.chairs do
  local busy=self.slots[i]~=nil or (self.match and not self.match.finished)
  local prompt=seat:FindFirstChild('PvPSeatPrompt');if prompt then prompt.Enabled=not busy end
  local glow=seat:FindFirstChild('AvailableSeat');if glow then glow.Enabled=not busy end
 end
end
function Net:Leave(p)
 local entry=self.members[p];if not entry then return end
 local m=self.match
 if m and m.state.phase=='countdown'then
  self.match=nil
 elseif m and not m.finished then
  m.finished=true;m.forfeit=entry.index;m.reason=p.DisplayName..' покинул дуэль';m.state.phase='finished'
 end
 self.slots[entry.index]=nil;self.members[p]=nil;self.ctx.leave(p)
 if not next(self.members)then self.match=nil end
 self:RefreshChairs();self:Notify()
end
local function mirrorReceipt(r)
 if not r then return nil end
 local incoming=r.incoming
 return {round=r.round,damage=r.received,received=r.damage,heal=0,
  ownBefore=r.enemyHealBefore,ownHealed=r.enemyBefore,enemyHealBefore=r.ownBefore,
  enemyBefore=incoming.enemyBefore,enemyAfter=incoming.enemyAfter,hits=incoming.hits,returns=incoming.returns,
  ownArmorAfter=r.enemyArmorAfter,enemyArmorAfter=r.ownArmorAfter,
  incoming={enemyBefore=r.enemyBefore,enemyAfter=r.enemyAfter,hits=r.hits,returns=r.returns}}
end
function Net:View(p)
 local e=self.members[p];if not e then return nil end
 local m=self.match
 if not m then return {screen='pvpwait',notice={title='Ждём соперника',body='Ты занял стул. Друг может сесть на подсвеченный стул напротив. Можно встать и вернуться позже.'}}end
 local s=m.state;local perspective=table.clone(s)
 if e.index==2 then perspective.player=s.bot;perspective.bot=s.player;perspective.receipt=mirrorReceipt(s.receipt)end
 local view=Duel.View(perspective);view.network=true;view.seatIndex=e.index
 view.enemyName=m.players[3-e.index].DisplayName
 view.duel.opponentKind='player';view.duel.enemyReady=m.ready[3-e.index];view.ready=m.ready[e.index]
 view.deadline=m.deadline;view.remaining=math.max(0,math.ceil(m.deadline-self.ctx.now()))
 view.phase=if s.phase=='countdown'then 'countdown'else s.phase
 if m.finished then
  view.phase=if m.forfeit then (if m.forfeit==e.index then 'lost'else 'won')elseif view.hp==view.enemyHp then 'draw'elseif view.hp>view.enemyHp then 'won'else 'lost'
 end
 return {screen='battle',battle=view,loadoutLocked=true}
end
function Net:Resolve()
 local m=self.match;if not m or m.finished or m.state.phase~='combat'then return end
 m.state.botReady=true
 local ok,why=Duel.Play(m.state);assert(ok,why)
 if terminal(m.state.phase)then m.finished=true else m.deadline=self.ctx.now()+math.max(5,m.state.config.ResolveSeconds)end
 self:Notify()
end
function Net:Action(p,data)
 local e=self.members[p];if not e then return false end
 if data.kind=='return'then self:Leave(p);self.ctx.push(p);return true end
 local m=self.match
 if not m then self.ctx.push(p,'Ждём соперника');return true end
 if data.sessionId~=m.state.id then self.ctx.push(p,'Сессия дуэли изменилась');return true end
 if m.finished or m.state.phase~='combat'or m.ready[e.index]then self.ctx.push(p,'Дождись следующего раунда');return true end
 local side=if e.index==1 then m.state.player else m.state.bot
 local wrapper=table.clone(m.state);wrapper.player=side
 local ok,msg
 if data.kind=='play'then m.ready[e.index]=true;ok=true
 elseif data.kind=='draw'then ok,msg=Duel.Draw(wrapper)
 elseif data.kind=='stop'then ok,msg=Duel.Stop(wrapper)
 elseif data.kind=='consume'then ok,msg=Duel.Consume(wrapper,data.item,data.zone)
 else self.ctx.push(p,'Во время PvP это действие недоступно');return true end
 m.state.revision+=1
 if m.ready[1]and m.ready[2]then self:Resolve()else self:Notify()end
 if not ok then self.ctx.push(p,msg)end
 return true
end
function Net:Tick()
 for p in self.members do if not self.match then local h=p.Character and p.Character:FindFirstChildOfClass('Humanoid');if not p.Parent or not h or h.Health<=0 then self:Leave(p);return end end end
 local m=self.match;if not m or m.finished then return end
 for i,p in m.players do
  local h=p.Character and p.Character:FindFirstChildOfClass('Humanoid')
  if not p.Parent or not h or h.Health<=0 then self:Leave(p);return end
 end
 local now=self.ctx.now();local s=m.state
 if s.phase=='countdown'and now>=m.deadline then
  s.phase='combat';s.player.phase='combat';s.bot.phase='combat';m.ready={false,false};m.deadline=now+(s.config.PvPRoundSeconds or 60);self:Notify()
 elseif s.phase=='combat'and now>=m.deadline then m.ready={true,true};self:Resolve()
 elseif s.phase=='resolving'and now>=m.deadline then
  Duel.Next(s);s.botTurn=nil;s.botReady=true;m.ready={false,false};m.deadline=now+(s.config.PvPRoundSeconds or 60);self:Notify()
 end
 self:Notify()
end
return Net
