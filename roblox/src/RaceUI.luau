-- Compact real-time race panel: shared deck, open card, timer, armor/discards
-- and the three actions. It is deliberately separate from the table renderer.
local Assets = require(script.Parent.Assets)
local RaceTarot = require(script.Parent.RaceTarot)

local RaceUI = {}

local C = {
 ink = Color3.fromRGB(9,25,16), panel = Color3.fromRGB(15,37,26),
 gold = Color3.fromRGB(210,178,104), paper = Color3.fromRGB(238,224,187),
 muted = Color3.fromRGB(160,180,151), red = Color3.fromRGB(128,46,36),
 good = Color3.fromRGB(139,214,156), bad = Color3.fromRGB(238,151,136),
 armor = Color3.fromRGB(103,196,218),
}

local function make(class, props, parent)
 local item = Instance.new(class)
 for key, value in props do item[key] = value end
 item.Parent = parent
 return item
end

local function stroke(item, color, thickness)
 make("UIStroke", { Color = color or C.gold, Thickness = thickness or 1, Transparency = .2 }, item)
end

local function label(parent, name, content, size, pos, dim, color, align)
 return make("TextLabel", {
  Name = name, Text = content, TextSize = size or 16, Font = Enum.Font.Garamond,
  TextColor3 = color or C.paper, BackgroundTransparency = 1, TextWrapped = true,
  TextXAlignment = align or Enum.TextXAlignment.Center, Position = pos, Size = dim,
 }, parent)
end

local function setEnabled(button, value)
 button.Active = value
 button.AutoButtonColor = value
 button.TextTransparency = if value then 0 else .55
 button.BackgroundTransparency = if value then 0 else .48
end

function RaceUI.Create(parent, send)
 local root = make("Frame", {
  Name = "RaceUI", Size = UDim2.fromScale(1,1), BackgroundTransparency = 1, Visible = false, ZIndex = 18,
 }, parent)

 local panel = make("Frame", {
  Name = "RacePanel", AnchorPoint = Vector2.new(.5,.5), Position = UDim2.new(.5,0,.47,0),
  Size = UDim2.fromOffset(372,328), BackgroundColor3 = C.panel, BackgroundTransparency = .05, BorderSizePixel = 0, ZIndex = 19,
 }, root)
 make("UICorner", { CornerRadius = UDim.new(0,12) }, panel)
 stroke(panel, C.gold, 2)
 make("UISizeConstraint", { MaxSize = Vector2.new(430,360), MinSize = Vector2.new(300,300) }, panel)

 local deck = label(panel, "Deck", "КОЛОДА 0", 14, UDim2.fromOffset(12,7), UDim2.new(.34,-12,0,22), C.muted, Enum.TextXAlignment.Left)
 local target = label(panel, "Target", "ЦЕЛЬ 21", 14, UDim2.new(.33,0,0,7), UDim2.new(.34,0,0,22), C.gold)
 local timer = label(panel, "Timer", "20.0 с", 23, UDim2.new(.67,0,0,3), UDim2.new(.33,-12,0,28), C.paper, Enum.TextXAlignment.Right)

 local card = make("Frame", {
  Name = "OpenCard", AnchorPoint = Vector2.new(.5,0), Position = UDim2.new(.5,0,0,38),
  Size = UDim2.fromOffset(96,134), BackgroundColor3 = Color3.fromRGB(29,57,44), BorderSizePixel = 0, ZIndex = 21,
 }, panel)
 make("UICorner", { CornerRadius = UDim.new(0,7) }, card)
 stroke(card, C.gold, 2)
 local image = make("ImageLabel", {
  Name = "Face", Image = Assets.Cards, BackgroundTransparency = 1, Size = UDim2.fromScale(1,1),
  ImageRectSize = Vector2.new(Assets.CardWidth, Assets.CardHeight), ScaleType = Enum.ScaleType.Stretch, Visible = false,
 }, card)
 make("UICorner", { CornerRadius = UDim.new(0,7) }, image)
 local back = make("Frame", {
  Name = "Back", Size = UDim2.fromScale(1,1), BackgroundColor3 = C.red, BorderSizePixel = 0, Visible = false,
 }, card)
 make("UICorner", { CornerRadius = UDim.new(0,7) }, back)
 label(back, "Spade", "♠", 42, UDim2.new(), UDim2.fromScale(1,1), C.paper)
 local tarot = make("Frame", {
  Name = "Tarot", Size = UDim2.fromScale(1,1), BackgroundColor3 = Color3.fromRGB(42,35,55), BorderSizePixel = 0, Visible = false,
 }, card)
 make("UICorner", { CornerRadius = UDim.new(0,7) }, tarot)
 label(tarot, "Symbol", "?", 36, UDim2.new(0,0,0,22), UDim2.new(1,0,0,48), C.gold)
 label(tarot, "Title", "ТАРО", 12, UDim2.new(0,0,0,82), UDim2.new(1,0,0,22), C.muted)
 label(tarot, "Hint", "личность\nпри взятии", 11, UDim2.new(0,0,0,102), UDim2.new(1,0,0,28), C.muted)
 local empty = label(card, "Empty", "—", 30, UDim2.new(), UDim2.fromScale(1,1), C.muted)

 local hint = label(panel, "Hint", "Ждём карту", 13, UDim2.fromOffset(12,179), UDim2.new(1,-24,0,20), C.muted)
 local stats = label(panel, "Stats", "◇ 0   ·   Сбросы 2/2   ·   Стан 0.0", 13, UDim2.fromOffset(12,202), UDim2.new(1,-24,0,20), C.paper)
 local contest = label(panel, "Contest", "", 13, UDim2.fromOffset(12,224), UDim2.new(1,-24,0,20), C.gold)
 local last = label(panel, "Last", "", 12, UDim2.fromOffset(12,245), UDim2.new(1,-24,0,18), C.muted)
 local peek = label(panel, "Peek", "", 12, UDim2.fromOffset(12,264), UDim2.new(1,-24,0,18), C.muted)

 local actions = make("Frame", {
  Name = "Actions", AnchorPoint = Vector2.new(.5,0), Position = UDim2.new(.5,0,0,286),
  Size = UDim2.fromOffset(348,38), BackgroundTransparency = 1, ZIndex = 22,
 }, panel)
 local function action(name, text, x, color, callback)
  local button = make("TextButton", {
   Name = name, Text = text, Position = UDim2.fromOffset(x,0), Size = UDim2.fromOffset(110,38),
   BackgroundColor3 = color, TextColor3 = C.paper, Font = Enum.Font.GothamBold,
   TextSize = 14, BorderSizePixel = 0, AutoButtonColor = true, ZIndex = 23,
  }, actions)
  make("UICorner", { CornerRadius = UDim.new(0,8) }, button)
  stroke(button, C.gold, 1)
  button.Activated:Connect(function() if button.Active then callback() end end)
  return button
 end
 local grab = action("Grab", "ВЗЯТЬ\nSpace", 0, C.green or Color3.fromRGB(28,86,49), function() send("grab") end)
 local discard = action("Discard", "СБРОС\nF", 119, C.red, function() send("discard") end)
 local stand = action("Stand", "СТОП\nEnter", 238, Color3.fromRGB(102,84,40), function() send("stand") end)

 local ui = {}
 local function showOpen(open)
  image.Visible = false; back.Visible = false; tarot.Visible = false; empty.Visible = false
  if not open then empty.Visible = true; empty.Text = "—"; return end
  if open.kind == "tarot" then
   tarot.Visible = true
   if open.hidden or open.back then
    tarot.Symbol.Text = "?"
    tarot.Title.Text = "ТАРО"
    tarot.Hint.Text = "личность\nпри взятии"
   else
    tarot.Symbol.Text = open.symbol or RaceTarot.Symbol(open.id)
    tarot.Title.Text = open.name or RaceTarot.Name(open.id)
    tarot.Hint.Text = if open.good then "хорошее" else "плохое"
   end
  elseif open.hidden or open.back then
   back.Visible = true
  elseif open.rankIndex and open.suitIndex then
   image.Visible = true
   image.ImageRectOffset = Vector2.new((open.rankIndex - 1) * Assets.CardWidth, (open.suitIndex - 1) * Assets.CardHeight)
  else
   empty.Visible = true; empty.Text = "?"
  end
 end

 function ui.Update(view)
  if not view or view.mode ~= "race" or not view.race then root.Visible = false; return end
  root.Visible = true
  local race = view.race
  local me = race.seats and race.seats[race.you] or {}
  local open = race.open
  deck.Text = "КОЛОДА " .. tostring(view.deckCount or race.deckCount or 0) .. " / " .. tostring(view.deckTotal or 0)
  target.Text = "ЦЕЛЬ " .. tostring(view.target or race.target or 0)
  timer.Text = string.format("%.1f с", math.max(0, view.timeLeft or race.timeLeft or 0))
  showOpen(open)
  if not open then hint.Text = "Ждём открытия карты"
  elseif open.kind == "tarot" then hint.Text = "Закрытое таро · личность откроется при взятии"
  elseif open.hidden or open.back then hint.Text = "Карта скрыта"
  else hint.Text = "Открытая карта · можно взять или сбросить" end
  local discards = me.discardsLeft or 0
  local limit = view.discardLimit or 2
  stats.Text = string.format("◇ %d   ·   Сбросы %d/%d   ·   Стан %.1f", view.armor or me.armor or 0, discards, limit, me.stunIn or 0)
  stats.TextColor3 = if (me.stunIn or 0) > 0 then C.bad else C.paper
  if race.contest and race.contest.active then
   contest.Text = "Спор за карту · " .. string.format("%.1f", race.contest.endsIn or 0) .. " с"
  elseif race.tarotTimeoutIn and race.tarotTimeoutIn > 0 then
   contest.Text = "Таро уйдёт через " .. string.format("%.1f", race.tarotTimeoutIn) .. " с"
  else
   contest.Text = ""
  end
  if race.lastTake and race.lastTake.round == view.round and race.lastTake.card then
   local c = race.lastTake.card
   local name = if c.kind == "tarot" then (c.name or RaceTarot.Name(c.id)) .. (if c.good then " (хорошее)" else " (плохое)") else tostring(c.rank or "") .. tostring(c.suit or "")
   last.Text = "Взято: " .. name .. (if race.lastTake.seat == race.you then " · ты" else " · соперник")
  else last.Text = "" end
  local peekCards = race.peek or view.peek
  if peekCards and #peekCards > 0 then
   local names = {}
   for _, c in peekCards do
    if c.kind == "tarot" then table.insert(names, "таро")
    else table.insert(names, tostring(c.rank or "?") .. tostring(c.suit or "")) end
   end
   peek.Text = "Далее: " .. table.concat(names, " / ")
  else peek.Text = "" end
  local active = view.phase == "combat" and (view.timeLeft or 0) > 0 and not (race.contest and race.contest.yours)
  local canGrab = active and open ~= nil and (me.stunIn or 0) <= 0 and (me.grabReadyIn or 0) <= 0
  local canDiscard = active and open ~= nil and discards > 0 and (me.stunIn or 0) <= 0 and (me.discardReadyIn or 0) <= 0
  local zone = view.active and view.zones and view.zones[view.active]
  local canStand = active and zone ~= nil and #zone.cards > 0 and not (race.contest and race.contest.active)
  setEnabled(grab, canGrab); setEnabled(discard, canDiscard); setEnabled(stand, canStand)
  grab.Text = if (me.grabReadyIn or 0) > 0 then string.format("ВЗЯТЬ\n%.1f", me.grabReadyIn) else "ВЗЯТЬ\nSpace"
  discard.Text = if (me.discardReadyIn or 0) > 0 then string.format("СБРОС\n%.1f", me.discardReadyIn) else "СБРОС\nF"
  if (me.stunIn or 0) > 0 then grab.Text = "СТАН\n" .. string.format("%.1f", me.stunIn) end
 end

 return ui
end

return RaceUI
