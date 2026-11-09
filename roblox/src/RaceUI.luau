-- Slim real-time race status strip. The shared deck, open card and the three
-- actions live on the table itself (TableScene); this keeps only live stats.
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

function RaceUI.Create(parent, send)
	local root = make("Frame", {
		Name = "RaceUI", BackgroundTransparency = 1, Size = UDim2.fromOffset(340,190),
		Position = UDim2.new(0,10,0,54), Visible = false, ZIndex = 18,
	}, parent)

	local panel = make("Frame", {
		Name = "RaceStrip", Size = UDim2.fromScale(1,1), BackgroundColor3 = C.ink,
		BackgroundTransparency = .35, BorderSizePixel = 0, ZIndex = 19,
	}, root)
	make("UICorner", { CornerRadius = UDim.new(0,10) }, panel)
	stroke(panel, C.gold, 2)

	local timer = label(panel, "Timer", "20.0 с", 30, UDim2.fromOffset(10,4), UDim2.new(.5,-14,0,42), C.paper, Enum.TextXAlignment.Left)
	local hint = label(panel, "Hint", "", 14, UDim2.new(.5,0,0,10), UDim2.new(.5,-10,0,32), C.muted)
	local stats = label(panel, "Stats", "", 15, UDim2.fromOffset(10,50), UDim2.new(1,-20,0,22), C.paper, Enum.TextXAlignment.Left)
	local contest = label(panel, "Contest", "", 15, UDim2.fromOffset(10,74), UDim2.new(1,-20,0,22), C.gold, Enum.TextXAlignment.Left)
	local last = label(panel, "Last", "", 13, UDim2.fromOffset(10,98), UDim2.new(1,-20,0,20), C.muted, Enum.TextXAlignment.Left)
	local peek = label(panel, "Peek", "", 13, UDim2.fromOffset(10,120), UDim2.new(1,-20,0,20), C.muted, Enum.TextXAlignment.Left)
	label(panel, "Keys", "Space взять · F сброс · Enter стоп", 12, UDim2.fromOffset(10,144), UDim2.new(1,-20,0,20), C.muted, Enum.TextXAlignment.Left)

	local ui = {}
	function ui.Update(view)
		if not view or view.mode ~= "race" or not view.race then root.Visible = false; return end
		root.Visible = true
		local race = view.race
		local me = race.seats and race.seats[race.you] or {}
		local open = race.open
		timer.Text = string.format("%.1f с", math.max(0, view.timeLeft or race.timeLeft or 0))
		if not open then hint.Text = "Ждём открытия карты"
		elseif open.kind == "tarot" then hint.Text = "Закрытое таро · личность при взятии"
		else hint.Text = "Открытая карта" end
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
	end

	return ui
end

return RaceUI
