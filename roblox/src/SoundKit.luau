-- Presentation-only audio feedback built entirely on local rbxasset:// sounds.
-- No published asset IDs, no permission questions: every file ships with the
-- Roblox client. A cue that fails to load is skipped with one diagnostic line.
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local SoundKit = { Ready = false }

-- tone = PlaybackSpeed of the base file; jitter adds a small random detune so
-- repeated card actions do not sound machine-stamped.
local CUES = {
	ui = { id = "rbxasset://sounds/electronicpingshort.mp3", volume = .22, tone = 1.25 },
	take = { id = "rbxasset://sounds/snap.mp3", volume = .5, tone = 1 },
	reveal = { id = "rbxasset://sounds/electronicpingshort.mp3", volume = .3, tone = .85 },
	armor = { id = "rbxasset://sounds/electronicpingshort.mp3", volume = .3, tone = 1.7 },
	discard = { id = "rbxasset://sounds/impact_water.mp3", volume = .35, tone = 1.35 },
	stand = { id = "rbxasset://sounds/electronicpingshort.mp3", volume = .26, tone = 1.05 },
	hit = { id = "rbxasset://sounds/impact_water.mp3", volume = .55, tone = .85 },
	heal = { id = "rbxasset://sounds/electronicpingshort.mp3", volume = .4, tone = 1.5 },
	good = { id = "rbxasset://sounds/electronicpingshort.mp3", volume = .45, tone = 1.5 },
	bad = { id = "rbxasset://sounds/uuhhh.mp3", volume = .4, tone = .9 },
	hurt = { id = "rbxasset://sounds/uuhhh.mp3", volume = .45, tone = 1.1 },
	stun = { id = "rbxasset://sounds/uuhhh.mp3", volume = .45, tone = .75 },
	win = { id = "rbxasset://sounds/electronicpingshort.mp3", volume = .45, tone = 1.2, fanfare = true },
	lose = { id = "rbxasset://sounds/uuhhh.mp3", volume = .6, tone = .8, fanfare = false },
}

local folder, templates, unavailable = nil, {}, {}
local warned

function SoundKit.Init()
	if folder or SoundKit.Ready then return end
	folder = Instance.new("Folder")
	folder.Name = "VochkoAudio"
	folder.Parent = SoundService
	local unique = {}
	for _, cue in CUES do unique[cue.id] = true end
	local list = {}
	for id in unique do
		local sound = Instance.new("Sound")
		sound.Name = id:gsub("rbxasset://sounds/", "")
		sound.SoundId = id
		sound.Volume = 1
		sound.Parent = folder
		templates[id] = sound
		table.insert(list, sound)
	end
	task.spawn(function()
		local ok = pcall(function()
			ContentProvider:PreloadAsync(list, function(_item, status)
				if status ~= Enum.AssetFetchStatus.Success then
					unavailable[_item.SoundId] = true
				end
			end)
		end)
		if not ok and not warned then
			warned = true
			print("[VOCHKO Audio] предзагрузка не удалась, звуки играют без проверки")
		end
		SoundKit.Ready = true
	end)
end

function SoundKit.Play(name)
	local cue = CUES[name]
	if not cue or not folder then return end
	if unavailable[cue.id] then
		if not warned then
			warned = true
			print("[VOCHKO Audio] звук " .. cue.id .. " недоступен, эта подсказка молчит")
		end
		return
	end
	local template = templates[cue.id]
	if not template then return end
	if cue.fanfare then
		for i = 1, 3 do
			task.delay((i - 1) * .13, function()
				local note = template:Clone()
				note.Volume = cue.volume
				note.PlaybackSpeed = (1 + .22 * (i - 1)) * (1 + (math.random() - .5) * .04)
				note.Parent = folder
				note:Play()
				Debris:AddItem(note, 4)
			end)
		end
		return
	end
	local sound = template:Clone()
	sound.Volume = cue.volume
	sound.PlaybackSpeed = cue.tone * (1 + (math.random() - .5) * .08)
	sound.Parent = folder
	sound:Play()
	Debris:AddItem(sound, 4)
end

return SoundKit
