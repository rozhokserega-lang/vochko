-- One server-owned, two-seat real-time race match.
-- Hidden deck order and closed tarot identities never leave the server.
local SharedDuel = require(script.Parent.SharedDuel)
local Loadout = require(game.ReplicatedStorage.VochkoPrototype.Loadout)

local Net = {}
Net.__index = Net

local function terminal(phase)
 return phase == "won" or phase == "lost" or phase == "draw"
end

local function ensureRaceTarot(profile)
 local list = profile.raceTarot
 if type(list) ~= "table" or not Loadout.ValidateRace(profile.class, profile.jokers, list) then
  list = Loadout.DefaultRaceTarot(profile.raceSeed or 1)
  profile.raceTarot = list
 end
 return list
end

local function buildFor(profile)
 return {
  class = profile.class, jokers = table.clone(profile.jokers),
  tarot = table.clone(ensureRaceTarot(profile)), id = "pvp",
 }
end

function Net.new(context)
 return setmetatable({ ctx = context, slots = {}, members = {}, pending = {}, match = nil }, Net)
end

function Net:Locked(p)
 local e = self.members[p]
 return e and self.match and not self.match.finished
end

function Net:Notify()
 for p in self.members do self.ctx.push(p) end
end

function Net:TryStart()
 if self.match then return end
 local p1, p2 = self.slots[1], self.slots[2]
 if not p1 or not p2 then return end
 for _, p in { p1, p2 } do
  local e = self.members[p]
  if not e or e.editing then return end
  local profile = self.ctx.profile(p)
  local tarot = ensureRaceTarot(profile)
  if not Loadout.ValidateRace(profile.class, profile.jokers, tarot) then return end
  e.build = buildFor(profile)
 end
 local now = self.ctx.now()
 local s = SharedDuel.New(self.ctx.config(), Random.new():NextInteger(1, 1000000000),
  { self.members[p1].build, self.members[p2].build }, { id = self.ctx.id() })
 self.match = {
  state = s, countdown = true, deadline = now + 3, finished = false,
  players = { p1, p2 }, lastPush = 0, lastRevision = -1,
 }
 self:RefreshChairs()
 self:Notify()
end

function Net:Join(p, index)
 if index ~= 1 and index ~= 2 then return false, "Выбери свободный стул" end
 if self.pending[p] then return false, "Посадка уже выполняется" end
 if self.match and not self.match.finished then return false, "За столом идёт дуэль" end
 if self.match and self.match.finished then return false, "Дождись, пока игроки освободят стол" end
 if self.slots[index] and self.slots[index] ~= p then return false, "Стул уже занят" end
 if self.members[p] then return true end
 local profile = self.ctx.profile(p)
 self.slots[index] = p
 self.pending[p] = true
 local ok, msg = self.ctx.sit(p, index)
 self.pending[p] = nil
 if not ok or not p.Parent then
  if self.slots[index] == p then self.slots[index] = nil end
  self:RefreshChairs()
  return false, msg
 end
 self.slots[index] = p
 self.members[p] = { index = index, build = buildFor(profile) }
 self:TryStart()
 self:RefreshChairs()
 self:Notify()
 return true
end

function Net:RefreshChairs()
 if not self.ctx.chairs then return end
 for i, seat in self.ctx.chairs do
  local busy = self.slots[i] ~= nil or self.match ~= nil
  local prompt = seat:FindFirstChild("PvPSeatPrompt")
  if prompt then prompt.Enabled = not busy end
  local glow = seat:FindFirstChild("AvailableSeat")
  if glow then glow.Enabled = not busy end
 end
end

function Net:Leave(p)
 local entry = self.members[p]
 if not entry then return end
 local m = self.match
 if m then
  if m.countdown or m.state.phase == "idle" then
   self.match = nil
  elseif not m.finished and m.state.phase ~= "finished" then
   SharedDuel.Forfeit(m.state, entry.index, self.ctx.now())
   m.finished = true
  end
 end
 self.slots[entry.index] = nil
 self.members[p] = nil
 self.ctx.leave(p)
 if not next(self.members) then self.match = nil end
 self:RefreshChairs()
 for other in self.members do self.ctx.push(other) end
end

function Net:View(p)
 local e = self.members[p]
 if not e then return nil end
 local m = self.match
 if not m then
  local b = self.ctx.profile(p)
  local tarot = ensureRaceTarot(b)
  local valid, why = Loadout.ValidateRace(b.class, b.jokers, tarot)
  return {
   screen = if e.editing then "pvpwardrobe" else "pvpwait",
   seated = true, seatIndex = e.index, loadoutLocked = false,
   notice = {
    title = "PvP · за столом",
    body = if not valid then why
     elseif self.slots[3 - e.index] then "Друг за столом · завершаем выбор сборок"
     else "Можно посидеть или выбрать сборку · ждём друга",
   },
  }
 end
 local s = m.state
 local now = self.ctx.now()
 local view = SharedDuel.View(s, e.index, now)
 view.network = true
 view.seatIndex = e.index
 view.enemyName = m.players[3 - e.index].DisplayName
 view.duel.opponentKind = "player"
 view.duel.enemyReady = true
 view.ready = true
 view.serverNow = now
 view.deadline = m.deadline
 if m.countdown then
  view.phase = "countdown"
  view.racePhase = "idle"
  view.timeLeft = math.max(0, m.deadline - now)
 elseif s.phase == "round" then
  view.phase = "combat"
  view.racePhase = "round"
 elseif s.phase == "resolving" then
  view.phase = "resolving"
  view.racePhase = "resolving"
 else
  view.racePhase = s.phase
 end
 view.remaining = math.max(0, math.ceil(view.timeLeft or 0))
 if terminal(s.phase) then view.racePhase = "finished" end
 return { screen = "battle", battle = view, loadoutLocked = true }
end

function Net:Action(p, data)
 local e = self.members[p]
 if not e then return false end
 local kind = data.kind
 if kind == "return" then
  self:Leave(p)
  self.ctx.push(p)
  return true
 end
 local m = self.match
 if not m then
  if kind == "openBuild" then
   e.editing = true
  elseif kind == "closeBuild" then
   e.editing = false
   self:TryStart()
  elseif kind == "buildClass" or kind == "buildJoker" or kind == "buildTarot" then
   local b = self.ctx.profile(p)
   local id = data.item
   if type(id) ~= "string" then return true end
   if kind == "buildClass" then
    if Loadout.Class(id) then b.class = id end
   elseif kind == "buildJoker" then
    if not Loadout.Joker(id) then return true end
    local list = b.jokers
    local at = table.find(list, id)
    if at then
     table.remove(list, at)
    elseif #list < 2 then
     table.insert(list, id)
    else
     self.ctx.push(p, "Сначала убери одного джокера")
     return true
    end
   else
    local def = Loadout.RaceTarotDef(id)
    if not def then return true end
    local list = ensureRaceTarot(b)
    local at = table.find(list, id)
    if at then
     table.remove(list, at)
    else
     local good, bad = 0, 0
     for _, other in list do
      local d = Loadout.RaceTarotDef(other)
      if d then
       if d.good then good += 1 else bad += 1 end
      end
     end
     if def.good and good >= Loadout.RaceTarotGood then
      self.ctx.push(p, "Можно выбрать только " .. Loadout.RaceTarotGood .. " хороших таро")
      return true
     end
     if not def.good and bad >= Loadout.RaceTarotBad then
      self.ctx.push(p, "Можно выбрать только " .. Loadout.RaceTarotBad .. " плохих таро")
      return true
     end
     if #list >= Loadout.RaceTarotGood + Loadout.RaceTarotBad then
      self.ctx.push(p, "Сначала убери одно таро")
      return true
     end
     table.insert(list, id)
    end
   end
  else
   self.ctx.push(p, "Ты сидишь за PvP-столом")
   return true
  end
  self:Notify()
  return true
 end

 if data.sessionId ~= m.state.id then
  self.ctx.push(p, "Сессия дуэли изменилась")
  return true
 end
 if m.finished or m.state.phase == "finished" then
  self.ctx.push(p, "Дуэль завершена")
  return true
 end
 if m.countdown or m.state.phase == "idle" then
  self.ctx.push(p, "Дуэль начнётся через " .. math.max(0, math.ceil(m.deadline - self.ctx.now())) .. " с")
  return true
 end
 if m.state.phase ~= "round" then
  self.ctx.push(p, "Дождись следующего раунда")
  return true
 end

 local now = self.ctx.now()
 local s = m.state
 local ok, msg
 if kind == "grab" or kind == "draw" then
  ok, msg = SharedDuel.Grab(s, e.index, now)
 elseif kind == "discard" then
  ok, msg = SharedDuel.Discard(s, e.index, now)
 elseif kind == "stand" or kind == "stop" then
  ok, msg = SharedDuel.Stand(s, e.index, now)
 elseif kind == "play" then
  self.ctx.push(p, "В реальном времени карту берут кнопкой «Взять»")
  return true
 else
  self.ctx.push(p, "Во время PvP это действие недоступно")
  return true
 end
 m.lastRevision = s.revision
 self:Notify()
 if not ok then self.ctx.push(p, msg) end
 return true
end

function Net:Tick()
 for p in self.members do
  if not self.match then
   local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
   if not p.Parent or not h or h.Health <= 0 then
    self:Leave(p)
    return
   end
  end
 end
 local m = self.match
 if not m then return end
 for _, p in m.players do
  local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
  if not p.Parent or not h or h.Health <= 0 then
   self:Leave(p)
   return
  end
 end
 local now = self.ctx.now()
 local s = m.state
 if m.countdown and now >= m.deadline then
  m.countdown = false
  SharedDuel.Begin(s, now)
  m.lastRevision = s.revision
  self:Notify()
 elseif s.phase == "round" then
  SharedDuel.Tick(s, now)
 elseif s.phase == "resolving" and now >= s.resolvedAt + (s.config.ResolveDelay or 2.4) then
  SharedDuel.NextRound(s, now)
  self:Notify()
 end
 if s.phase == "finished" and not m.finished then
  m.finished = true
  self:Notify()
 end
 if not m.finished and now - (m.lastPush or 0) >= 0.1 then
  m.lastPush = now
  self:Notify()
 end
end

return Net
