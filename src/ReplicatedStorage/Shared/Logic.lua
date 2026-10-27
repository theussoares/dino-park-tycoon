--!nonstrict
-- Lógica pura do jogo (sem APIs do Roblox): testável fora do Studio.
-- Toda função que muda dados devolve (ok, mensagem). O servidor é a única autoridade que a chama.
local Logic = {}

local function floor(x)
	return math.floor(x)
end

function Logic.newData(cfg, now)
	return {
		schemaVersion = cfg.SchemaVersion,
		coins = cfg.StartCoins,
		eggs = cfg.StartEggs,
		dinos = {},
		nextId = 1,
		placed = {},
		upgrades = { slots = 0, income = 0, incubator = 0 },
		owned = {},
		fence = "wood",
		incubating = nil,
		missions = { hatch = false, place = false, upgrade = false },
		hatched = 0,
		tutorialDismissed = false,
		lastSeen = now,
	}
end

local function num(v, default, lo, hi)
	if type(v) ~= "number" or v ~= v then
		return default
	end
	if v < lo then
		return lo
	end
	if v > hi then
		return hi
	end
	return v
end

-- Valida/sanitiza dados carregados (nunca confia no que veio do DataStore).
function Logic.migrate(raw, cfg, now)
	local d = Logic.newData(cfg, now)
	if type(raw) ~= "table" then
		return d
	end
	d.coins = floor(num(raw.coins, d.coins, 0, 1e12))
	d.eggs = floor(num(raw.eggs, d.eggs, 0, 1e6))
	d.nextId = floor(num(raw.nextId, 1, 1, 1e9))
	d.hatched = floor(num(raw.hatched, 0, 0, 1e9))
	d.tutorialDismissed = raw.tutorialDismissed == true
	d.lastSeen = num(raw.lastSeen, now, 0, now)
	local ids = {}
	if type(raw.dinos) == "table" then
		for _, dino in ipairs(raw.dinos) do
			if type(dino) == "table" and type(dino.id) == "string" and #dino.id <= 32
				and cfg.Species[dino.species] and not ids[dino.id] and #d.dinos < cfg.MaxDinos then
				ids[dino.id] = true
				d.dinos[#d.dinos + 1] = { id = dino.id, species = dino.species }
			end
		end
	end
	if type(raw.upgrades) == "table" then
		for key, def in pairs(cfg.Upgrades) do
			d.upgrades[key] = floor(num(raw.upgrades[key], 0, 0, def.maxLevel))
		end
	end
	if type(raw.owned) == "table" then
		for _, item in ipairs(cfg.ShopCatalog) do
			if raw.owned[item.id] == true then
				d.owned[item.id] = true
			end
		end
	end
	if raw.fence == "wood" or d.owned[raw.fence or ""] then
		d.fence = raw.fence
	end
	if type(raw.placed) == "table" then
		local seen = {}
		local slots = Logic.slots(d, cfg)
		for _, id in ipairs(raw.placed) do
			if ids[id] and not seen[id] and #d.placed < slots then
				seen[id] = true
				d.placed[#d.placed + 1] = id
			end
		end
	end
	if type(raw.incubating) == "table" and type(raw.incubating.readyAt) == "number" then
		d.incubating = { startedAt = num(raw.incubating.startedAt, now, 0, now), readyAt = raw.incubating.readyAt }
	end
	if type(raw.missions) == "table" then
		for k in pairs(d.missions) do
			d.missions[k] = raw.missions[k] == true
		end
	end
	return d
end

-- Trava de sessão: impede dois servidores de salvarem o mesmo jogador (evita duplicar/perder progresso).
-- O registro salvo é uma cópia rasa dos dados + campo _lock = { jobId, t }.
function Logic.lockedByOther(old, jobId, now, lockSeconds)
	if type(old) ~= "table" or type(old._lock) ~= "table" then
		return false
	end
	local l = old._lock
	if type(l.jobId) ~= "string" or type(l.t) ~= "number" then
		return false
	end
	if l.jobId == jobId then
		return false
	end
	return now - l.t < lockSeconds
end

-- release=true remove a trava (saída do jogador); caso contrário carimba/renova.
function Logic.record(data, jobId, now, release)
	local out = {}
	if type(data) == "table" then
		for k, v in pairs(data) do
			out[k] = v
		end
	end
	out._lock = nil
	if not release then
		out._lock = { jobId = jobId, t = now }
	end
	return out
end

function Logic.slots(data, cfg)
	return cfg.BaseSlots + data.upgrades.slots
end

function Logic.findDino(data, id)
	for _, dino in ipairs(data.dinos) do
		if dino.id == id then
			return dino
		end
	end
	return nil
end

function Logic.isPlaced(data, id)
	for _, pid in ipairs(data.placed) do
		if pid == id then
			return true
		end
	end
	return false
end

-- Renda por pagamento (a cada Config.IncomeInterval segundos), sem arredondar.
function Logic.incomeRaw(data, cfg)
	local sum = 0
	for _, id in ipairs(data.placed) do
		local dino = Logic.findDino(data, id)
		if dino then
			sum = sum + cfg.Species[dino.species].income
		end
	end
	return sum * (1 + data.upgrades.income * cfg.Upgrades.income.bonus)
end

function Logic.incomePerTick(data, cfg)
	return floor(Logic.incomeRaw(data, cfg) + 0.5)
end

function Logic.incubateSeconds(data, cfg)
	local mult = 1 - data.upgrades.incubator * cfg.Upgrades.incubator.reduction
	if mult < 0.2 then
		mult = 0.2
	end
	return floor(cfg.IncubateSeconds * mult + 0.5)
end

-- rnd() devolve número em [0,1). Sorteio ponderado por Config.Species[*].weight.
function Logic.rollSpecies(cfg, rnd)
	local total = 0
	for _, id in ipairs(cfg.SpeciesOrder) do
		total = total + cfg.Species[id].weight
	end
	local r = rnd() * total
	local acc = 0
	for _, id in ipairs(cfg.SpeciesOrder) do
		acc = acc + cfg.Species[id].weight
		if r < acc then
			return id
		end
	end
	return cfg.SpeciesOrder[#cfg.SpeciesOrder]
end

function Logic.odds(cfg)
	local total = 0
	for _, id in ipairs(cfg.SpeciesOrder) do
		total = total + cfg.Species[id].weight
	end
	local out = {}
	for _, id in ipairs(cfg.SpeciesOrder) do
		out[#out + 1] = { id = id, percent = cfg.Species[id].weight / total * 100 }
	end
	return out
end

-- Ganhos offline: limitado por cfg.OfflineCapSeconds; 'now' vem do servidor.
function Logic.offlineEarnings(data, cfg, now)
	local elapsed = now - data.lastSeen
	if type(elapsed) ~= "number" or elapsed ~= elapsed or elapsed <= 0 then
		return 0, 0
	end
	if elapsed > cfg.OfflineCapSeconds then
		elapsed = cfg.OfflineCapSeconds
	end
	local perSecond = Logic.incomeRaw(data, cfg) / cfg.IncomeInterval
	return floor(perSecond * elapsed * cfg.OfflineRate), elapsed
end

-- Loja rotativa determinística (Park-Miller) por janela de tempo.
function Logic.shopStock(cfg, now)
	local window = floor(now / cfg.ShopRotationSeconds)
	local state = window % 2147483646 + 1
	local function nextRand()
		state = (state * 16807) % 2147483647
		return state
	end
	local ids = {}
	for _, item in ipairs(cfg.ShopCatalog) do
		ids[#ids + 1] = item.id
	end
	for i = #ids, 2, -1 do
		local j = nextRand() % i + 1
		ids[i], ids[j] = ids[j], ids[i]
	end
	local stock = {}
	for i = 1, math.min(cfg.ShopSlots, #ids) do
		stock[i] = ids[i]
	end
	return stock, (window + 1) * cfg.ShopRotationSeconds
end

function Logic.catalogItem(cfg, id)
	for _, item in ipairs(cfg.ShopCatalog) do
		if item.id == id then
			return item
		end
	end
	return nil
end

local function listHas(list, v)
	for _, x in ipairs(list) do
		if x == v then
			return true
		end
	end
	return false
end

function Logic.buyShop(data, cfg, itemId, stock)
	if type(itemId) ~= "string" then
		return false, "Item inválido."
	end
	local item = Logic.catalogItem(cfg, itemId)
	if not item or not listHas(stock, itemId) then
		return false, "Esse item não está na loja agora."
	end
	if data.owned[itemId] then
		return false, "Você já tem esse item."
	end
	if data.coins < item.price then
		return false, "Moedas insuficientes."
	end
	data.coins = data.coins - item.price
	data.owned[itemId] = true
	if item.kind == "fence" then
		data.fence = itemId
	end
	return true, "Comprou " .. item.name .. "!"
end

function Logic.upgradeCost(data, cfg, key)
	local def = cfg.Upgrades[key]
	if not def then
		return nil
	end
	local level = data.upgrades[key]
	if level >= def.maxLevel then
		return nil
	end
	return def.costs[level + 1]
end

function Logic.buyUpgrade(data, cfg, key)
	if type(key) ~= "string" or not cfg.Upgrades[key] then
		return false, "Melhoria inválida."
	end
	local cost = Logic.upgradeCost(data, cfg, key)
	if not cost then
		return false, "Nível máximo."
	end
	if data.coins < cost then
		return false, "Moedas insuficientes."
	end
	data.coins = data.coins - cost
	data.upgrades[key] = data.upgrades[key] + 1
	return true, cfg.Upgrades[key].name .. " melhorada!"
end

function Logic.buyEgg(data, cfg)
	if data.eggs >= 99 then
		return false, "Você já tem ovos demais."
	end
	if data.coins < cfg.EggCost then
		return false, "Moedas insuficientes."
	end
	data.coins = data.coins - cfg.EggCost
	data.eggs = data.eggs + 1
	return true, "Ovo comprado!"
end

function Logic.startIncubate(data, cfg, now)
	if data.incubating then
		return false, "A incubadora já está ocupada."
	end
	if data.eggs <= 0 then
		return false, "Você não tem ovos."
	end
	data.eggs = data.eggs - 1
	data.incubating = { startedAt = now, readyAt = now + Logic.incubateSeconds(data, cfg) }
	return true, "Ovo na incubadora!"
end

function Logic.collect(data, cfg, now, rnd)
	local inc = data.incubating
	if not inc then
		return false, "Nada para coletar."
	end
	if now < inc.readyAt then
		return false, "Ainda não chocou."
	end
	if #data.dinos >= cfg.MaxDinos then
		return false, "Inventário cheio."
	end
	local species
	if data.hatched == 0 then
		species = "leafling" -- primeiro ovo sempre é um Leafling (tutorial)
	else
		species = Logic.rollSpecies(cfg, rnd)
	end
	local id = "d" .. data.nextId
	data.nextId = data.nextId + 1
	data.dinos[#data.dinos + 1] = { id = id, species = species }
	data.hatched = data.hatched + 1
	data.incubating = nil
	return true, "Nasceu um " .. cfg.Species[species].name .. "!", species
end

function Logic.place(data, cfg, dinoId)
	if type(dinoId) ~= "string" or #dinoId > 32 then
		return false, "Dinossauro inválido."
	end
	if not Logic.findDino(data, dinoId) then
		return false, "Você não tem esse dinossauro."
	end
	if Logic.isPlaced(data, dinoId) then
		return false, "Já está no habitat."
	end
	if #data.placed >= Logic.slots(data, cfg) then
		return false, "Sem habitat livre. Compre um novo em Melhorias."
	end
	data.placed[#data.placed + 1] = dinoId
	return true, "Dinossauro no habitat!"
end

function Logic.remove(data, cfg, dinoId)
	if type(dinoId) ~= "string" then
		return false, "Dinossauro inválido."
	end
	for i, id in ipairs(data.placed) do
		if id == dinoId then
			table.remove(data.placed, i)
			return true, "Dinossauro guardado."
		end
	end
	return false, "Ele não está no habitat."
end

-- Próximo passo do onboarding: primeira missão ainda não concluída (ordem de Config.Missions), ou nil.
-- 'view' é o estado enviado ao cliente (campo missions); usado só para orientar a interface.
function Logic.currentGoal(view, cfg)
	for _, m in ipairs(cfg.Missions) do
		if view.missions[m.id] ~= true then
			return { id = m.id, text = m.text, reward = m.reward }
		end
	end
	return nil
end

-- Melhoria mais barata que ainda não está no máximo (view.upgrades[i].cost é false no máximo), ou nil.
function Logic.nextUpgrade(view)
	local best = nil
	for _, up in ipairs(view.upgrades) do
		if up.cost and (best == nil or up.cost < best.cost) then
			best = up
		end
	end
	return best
end

-- Missões simples (recompensa única). Devolve lista de textos completados agora.
function Logic.checkMissions(data, cfg)
	local done = {}
	local function complete(m)
		data.missions[m.id] = true
		data.coins = data.coins + m.reward
		done[#done + 1] = { text = m.text, reward = m.reward }
	end
	local upgraded = data.upgrades.slots + data.upgrades.income + data.upgrades.incubator > 0
	for _, m in ipairs(cfg.Missions) do
		if not data.missions[m.id] then
			if m.id == "hatch" and data.hatched > 0 then
				complete(m)
			elseif m.id == "place" and #data.placed > 0 then
				complete(m)
			elseif m.id == "upgrade" and upgraded then
				complete(m)
			end
		end
	end
	return done
end

return Logic
