-- Shared race-duel tarot. Every card has the same back and no owner mark.
-- The server decides which card is drawn; the client only gets names after a take.
local R = { GoodIds = {}, BadIds = {}, ById = {} }

R.Good = {
 { id = "rose", name = "Роза", symbol = "❀", desc = "+10 HP сразу" },
 { id = "guardian", name = "Страж", symbol = "◇", desc = "+6 брони в этом раунде" },
 { id = "sun", name = "Солнце", symbol = "☀", desc = "Урон текущей зоны ×1.6" },
 { id = "moon", name = "Луна", symbol = "☾", desc = "Входящий урон ×0.65 до конца раунда" },
 { id = "scales", name = "Весы", symbol = "⚖", desc = "Точная зона: урон ×1.5" },
 { id = "clock", name = "Часы", symbol = "⌛", desc = "Подтягивает зону к цели, если разница ≤2" },
 { id = "focus", name = "Фокус", symbol = "◉", desc = "+1 сброс в этом раунде" },
 { id = "wheel", name = "Колесо", symbol = "✦", desc = "Побеждает в споре за карту" },
 { id = "justice", name = "Правосудие", symbol = "✧", desc = "Отменяет следующее плохое таро" },
 { id = "candle", name = "Свеча", symbol = "♧", desc = "Показывает 3 верхние карты колоды" },
}

R.Bad = {
 { id = "poison", name = "Яд", symbol = "☠", desc = "−5 HP сразу" },
 { id = "rust", name = "Ржавчина", symbol = "≈", desc = "Урон текущей зоны ×0.75" },
 { id = "chain", name = "Цепь", symbol = "⛓", desc = "Текущая зона закрывается: 0 урона" },
 { id = "load", name = "Груз", symbol = "▣", desc = "+4 к сумме текущей зоны" },
 { id = "tower", name = "Башня", symbol = "♜", desc = "Сбрасывает обычные карты текущей зоны" },
 { id = "death", name = "Смерть", symbol = "✕", desc = "Текущая зона не наносит урон" },
 { id = "thief", name = "Вор", symbol = "✂", desc = "−1 сброс в этом раунде" },
 { id = "hanged", name = "Повешенный", symbol = "⌇", desc = "Стан 1.5 с" },
 { id = "darkening", name = "Затмение", symbol = "◐", desc = "Скрывает следующие 3 открытия" },
 { id = "jester", name = "Шут", symbol = "☺", desc = "Следующая открытая карта уходит сопернику" },
}

R.List = {}
for _, d in R.Good do d.good = true; table.insert(R.List, d); table.insert(R.GoodIds, d.id); R.ById[d.id] = d end
for _, d in R.Bad do d.good = false; table.insert(R.List, d); table.insert(R.BadIds, d.id); R.ById[d.id] = d end

function R.Def(id) return R.ById[id] end
function R.IsGood(id) return R.ById[id] ~= nil and R.ById[id].good == true end
function R.IsBad(id) return R.ById[id] ~= nil and R.ById[id].good == false end
function R.Caption(id)
 local d = R.ById[id]
 return if d then d.desc else ""
end
function R.Name(id)
 local d = R.ById[id]
 return if d then d.name else id
end
function R.Symbol(id)
 local d = R.ById[id]
 return if d then d.symbol else "?"
end

local function shuffled(list, random)
 local out = table.clone(list)
 for i = #out, 2, -1 do
  local j = random:NextInteger(1, i)
  out[i], out[j] = out[j], out[i]
 end
 return out
end

-- One build is exactly `goodCount` good ids and `badCount` bad ids.
-- Missing or invalid entries are filled deterministically from the seed.
function R.NormalizeBuild(build, random, goodCount, badCount)
 goodCount = math.max(0, goodCount or 2)
 badCount = math.max(0, badCount or 2)
 local good, bad = {}, {}
 local seen = {}
 local function add(id, list, limit, wantGood)
  if #list >= limit or type(id) ~= "string" or seen[id] or not R.ById[id] then return end
  if R.ById[id].good ~= wantGood then return end
  seen[id] = true
  table.insert(list, id)
 end
 if type(build) == "table" then
  if type(build.good) == "table" then for _, id in build.good do add(id, good, goodCount, true) end end
  if type(build.bad) == "table" then for _, id in build.bad do add(id, bad, badCount, false) end end
  if type(build.tarot) == "table" then
   for _, id in build.tarot do
    if R.IsGood(id) then add(id, good, goodCount, true) elseif R.IsBad(id) then add(id, bad, badCount, false) end
   end
  end
 end
 for _, id in shuffled(R.GoodIds, random) do add(id, good, goodCount, true) end
 for _, id in shuffled(R.BadIds, random) do add(id, bad, badCount, false) end
 local tarot = {}
 for _, id in good do table.insert(tarot, id) end
 for _, id in bad do table.insert(tarot, id) end
 return { good = good, bad = bad, tarot = tarot }
end

-- Used by the wardrobe/network layer: four unique ids, exactly two good and two bad.
function R.ValidateLoadout(ids, goodCount, badCount)
 goodCount = math.max(0, goodCount or 2)
 badCount = math.max(0, badCount or 2)
 if type(ids) ~= "table" or #ids ~= goodCount + badCount then
  return false, string.format("Выбери %d хороших и %d плохих таро", goodCount, badCount)
 end
 local seen, good, bad = {}, 0, 0
 for _, id in ids do
  if type(id) ~= "string" or seen[id] or not R.ById[id] then return false, "Таро не найдено" end
  seen[id] = true
  if R.ById[id].good then good += 1 else bad += 1 end
 end
 if good ~= goodCount or bad ~= badCount then
  return false, string.format("Нужно ровно %d хороших и %d плохих таро", goodCount, badCount)
 end
 return true
end

return R
