--!nonstrict
-- Dino Park Tycoon — Parte 2: scripts do jogo (GERADO por tools/build.js — não edite à mão).
-- Cole na Command Bar do Roblox Studio. Cria: ReplicatedStorage.Shared, ServerScriptService.DinoParkServices,
-- ServerScriptService.DinoParkMain e StarterPlayerScripts.DinoParkClient.
-- Seguro para repetir: se já existir, PARA sem alterar nada (REPLACE_EXISTING = true recria SÓ esses objetos).
local REPLACE_EXISTING = false

local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local SPS = StarterPlayer:FindFirstChild("StarterPlayerScripts") or StarterPlayer:WaitForChild("StarterPlayerScripts", 5)
assert(SPS, "[DinoPark] StarterPlayerScripts não encontrado")

local targets = {
	{ RS, "Shared" }, { SSS, "DinoParkServices" }, { SSS, "DinoParkMain" }, { SPS, "DinoParkClient" },
}
for _, t in ipairs(targets) do
	local found = t[1]:FindFirstChild(t[2])
	if found then
		if not REPLACE_EXISTING then
			warn("[DinoPark] " .. t[1].Name .. "." .. t[2] .. " já existe. Nada foi alterado. Mude REPLACE_EXISTING para true para recriar.")
			return
		end
		found:Destroy()
	end
end

local function make(class, name, source, parent)
	local inst = Instance.new(class)
	inst.Name = name
	inst.Source = source
	inst.Parent = parent
	return inst
end

local sharedFolder = Instance.new("Folder")
sharedFolder.Name = "Shared"
local sharedFiles = {
	{ "ModuleScript", "Config", [==[
--!nonstrict
-- Configuração central do Dino Park Tycoon. Todos os números abaixo são HIPÓTESES de balanceamento
-- a testar com jogadores reais, não verdades de mercado.
local Config = {}

Config.SchemaVersion = 1
Config.DataStoreName = "DinoParkTycoon_v1"
Config.MaxPlayers = 4 -- = número de parques (Config.Plots)

-- Economia
Config.StartCoins = 100
Config.StartEggs = 1
Config.EggCost = 50
Config.IncubateSeconds = 12
Config.IncomeInterval = 5 -- segundos entre pagamentos de visitantes
Config.OfflineCapSeconds = 8 * 3600
Config.OfflineRate = 0.5 -- fração da renda normal paga offline
Config.MaxDinos = 60

-- Loja rotativa (baseada em horário Unix; igual para todos os servidores)
Config.ShopRotationSeconds = 1800
Config.ShopSlots = 4

-- Remotes / salvamento
Config.RequestMinInterval = 0.12
Config.AutosaveSeconds = 120
Config.MinSaveGap = 10

Config.BaseSlots = 1

Config.Species = {
	leafling = {
		id = "leafling", name = "Leafling", rarity = "Comum", weight = 70, income = 2, scale = 1,
		color = Color3.fromRGB(110, 200, 100),
		desc = "Herbívoro pequeno e simpático. Rende pouco, mas nunca falha.",
	},
	pebbleback = {
		id = "pebbleback", name = "Pebbleback", rarity = "Incomum", weight = 25, income = 5, scale = 1,
		color = Color3.fromRGB(120, 140, 170),
		desc = "Quadrúpede robusto com placas de pedra nas costas.",
	},
	embercrest = {
		id = "embercrest", name = "Embercrest", rarity = "Raro", weight = 5, income = 12, scale = 1,
		color = Color3.fromRGB(236, 150, 70),
		desc = "Ágil, com crista cor de brasa. Os visitantes adoram.",
	},
}
Config.SpeciesOrder = { "leafling", "pebbleback", "embercrest" }

Config.RarityColors = {
	["Comum"] = Color3.fromRGB(120, 200, 120),
	["Incomum"] = Color3.fromRGB(110, 170, 240),
	["Raro"] = Color3.fromRGB(250, 160, 60),
}

Config.Upgrades = {
	slots = { name = "Novo habitat", desc = "Libera mais um espaço para dinossauros.", maxLevel = 3, costs = { 150, 400, 900 } },
	income = { name = "Mais visitantes", desc = "+25% de renda por nível.", maxLevel = 5, costs = { 100, 250, 500, 1000, 2000 }, bonus = 0.25 },
	incubator = { name = "Incubadora rápida", desc = "-25% do tempo de incubação por nível.", maxLevel = 3, costs = { 120, 300, 700 }, reduction = 0.25 },
}
Config.UpgradeOrder = { "slots", "income", "incubator" }

-- Catálogo cosmético (nenhum item dá vantagem de jogo). spot = posição de decoração no parque.
Config.ShopCatalog = {
	{ id = "lamp", kind = "decor", name = "Poste de luz", price = 60, spot = 1 },
	{ id = "flowers", kind = "decor", name = "Canteiro de flores", price = 45, spot = 2 },
	{ id = "banner", kind = "decor", name = "Faixa colorida", price = 70, spot = 3 },
	{ id = "balloons", kind = "decor", name = "Balões", price = 80, spot = 4 },
	{ id = "rocks", kind = "decor", name = "Jardim de pedras", price = 55, spot = 5 },
	{ id = "fountain", kind = "decor", name = "Fonte", price = 120, spot = 6 },
	{ id = "fence_candy", kind = "fence", name = "Cerca doce", price = 90, color = Color3.fromRGB(245, 150, 190) },
	{ id = "fence_sky", kind = "fence", name = "Cerca céu", price = 90, color = Color3.fromRGB(120, 190, 245) },
	{ id = "fence_mint", kind = "fence", name = "Cerca menta", price = 90, color = Color3.fromRGB(130, 220, 170) },
}
Config.DefaultFenceColor = Color3.fromRGB(139, 94, 60)

Config.Missions = {
	{ id = "hatch", text = "Choque seu primeiro ovo", reward = 50 },
	{ id = "place", text = "Coloque um dinossauro no habitat", reward = 75 },
	{ id = "upgrade", text = "Compre uma melhoria", reward = 100 },
}

-- Mundo (usado pelo ParkService). Coordenadas X,Z do centro de cada parque de 44x44 studs.
Config.Plots = {
	{ x = -60, z = -50 },
	{ x = 60, z = -50 },
	{ x = -60, z = 50 },
	{ x = 60, z = 50 },
}
Config.PlotHalf = 22
-- Posições locais (x,z) dos habitats e das decorações. -Z local = lado da entrada do parque.
Config.PadPositions = { { -12, 10 }, { -4, 10 }, { 4, 10 }, { 12, 10 } }
Config.DecorSpots = { { -17, -15 }, { 17, -15 }, { -17, 2 }, { 17, 2 }, { -8, -18 }, { 8, -18 } }

return Config
]==] },
	{ "ModuleScript", "Logic", [==[
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
]==] },
	{ "ModuleScript", "DinoModels", [==[
--!nonstrict
-- Modelos procedurais (Parts) dos dinossauros e das decorações. Todos olham para -Z (frente local).
local Config = require(script.Parent:WaitForChild("Config"))

local M = {}

local function newBuilder(model, origin, s)
	return function(name, size, offset, color, shape, material)
		local x = Instance.new("Part")
		x.Name = name
		x.Anchored = true
		x.CanCollide = false
		x.Size = size * s
		x.CFrame = origin * CFrame.new(offset * s)
		x.Color = color
		x.Material = material or Enum.Material.SmoothPlastic
		x.TopSurface = Enum.SurfaceType.Smooth
		x.BottomSurface = Enum.SurfaceType.Smooth
		if shape then
			x.Shape = shape
		end
		x.Parent = model
		return x
	end
end

local function shade(c, f)
	return Color3.new(math.clamp(c.R * f, 0, 1), math.clamp(c.G * f, 0, 1), math.clamp(c.B * f, 0, 1))
end

local BALL = Enum.PartType.Ball
local EYE = Color3.new(0.05, 0.05, 0.05)

local function leafling(p, color)
	local belly = Color3.fromRGB(225, 240, 160)
	local dark = shade(color, 0.55)
	local torso = p("Body", Vector3.new(3, 2.6, 4.6), Vector3.new(0, 2.6, 0), color)
	p("Belly", Vector3.new(2.4, 1, 3.8), Vector3.new(0, 1.65, 0.1), belly)
	p("Neck", Vector3.new(1.4, 2.2, 1.4), Vector3.new(0, 4.2, -2), color)
	p("Head", Vector3.new(2.4, 2, 2.8), Vector3.new(0, 5.5, -2.7), color)
	p("Snout", Vector3.new(1.6, 1.1, 1.2), Vector3.new(0, 5.2, -4.4), color)
	p("EyeL", Vector3.new(0.5, 0.5, 0.5), Vector3.new(-1.05, 5.9, -3.4), EYE, BALL)
	p("EyeR", Vector3.new(0.5, 0.5, 0.5), Vector3.new(1.05, 5.9, -3.4), EYE, BALL)
	for i = 0, 2 do
		p("Spike" .. i, Vector3.new(0.5, 0.9, 0.9), Vector3.new(0, 4.25, -0.9 + i * 1.3), dark)
	end
	p("Tail1", Vector3.new(1.8, 1.6, 2.6), Vector3.new(0, 2.3, 3.4), color)
	p("Tail2", Vector3.new(1.1, 1.0, 2.4), Vector3.new(0, 2.1, 5.4), color)
	p("TailTip", Vector3.new(0.6, 0.6, 1.4), Vector3.new(0, 2.0, 6.9), dark)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1.4, 1.5 }) do
			p("Leg", Vector3.new(0.9, 1.4, 1.0), Vector3.new(sx * 1.0, 0.7, sz), dark)
		end
	end
	return torso, 7.2
end

local function pebbleback(p, color)
	local dark = shade(color, 0.6)
	local plate = Color3.fromRGB(95, 100, 115)
	local torso = p("Body", Vector3.new(4.6, 3.2, 6.4), Vector3.new(0, 2.9, 0), color)
	p("Belly", Vector3.new(3.8, 1, 5.6), Vector3.new(0, 1.55, 0), shade(color, 1.25))
	p("Head", Vector3.new(2.8, 2.4, 2.8), Vector3.new(0, 2.7, -4.4), color)
	p("Snout", Vector3.new(2, 1.2, 1.2), Vector3.new(0, 2.3, -5.9), color)
	p("EyeL", Vector3.new(0.5, 0.5, 0.5), Vector3.new(-1.1, 3.2, -5.4), EYE, BALL)
	p("EyeR", Vector3.new(0.5, 0.5, 0.5), Vector3.new(1.1, 3.2, -5.4), EYE, BALL)
	for i = 0, 3 do
		p("Plate" .. i, Vector3.new(3.4 - i * 0.3, 0.9, 1.1), Vector3.new(0, 4.8, -2.2 + i * 1.6), plate, nil, Enum.Material.Slate)
	end
	p("Tail1", Vector3.new(2.2, 1.8, 2.6), Vector3.new(0, 2.5, 4.4), color)
	p("Tail2", Vector3.new(1.4, 1.2, 2.2), Vector3.new(0, 2.2, 6.3), dark)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -2.2, 2.2 }) do
			p("Leg", Vector3.new(1.5, 1.8, 1.5), Vector3.new(sx * 1.7, 0.9, sz), dark)
		end
	end
	return torso, 5.6
end

local function embercrest(p, color)
	local crest = Color3.fromRGB(255, 110, 30)
	local dark = shade(color, 0.6)
	local torso = p("Body", Vector3.new(2.2, 2.4, 3.2), Vector3.new(0, 3.3, 0), color)
	p("Belly", Vector3.new(1.7, 1, 2.6), Vector3.new(0, 2.4, -0.1), Color3.fromRGB(255, 232, 190))
	p("Neck", Vector3.new(1.1, 2.2, 1.1), Vector3.new(0, 5, -1.5), color)
	p("Head", Vector3.new(1.8, 1.6, 2.4), Vector3.new(0, 6.3, -2.1), color)
	p("Snout", Vector3.new(1.2, 0.9, 1.1), Vector3.new(0, 6.1, -3.6), color)
	p("EyeL", Vector3.new(0.45, 0.45, 0.45), Vector3.new(-0.85, 6.6, -2.8), Color3.fromRGB(255, 230, 80), BALL)
	p("EyeR", Vector3.new(0.45, 0.45, 0.45), Vector3.new(0.85, 6.6, -2.8), Color3.fromRGB(255, 230, 80), BALL)
	for i = 0, 3 do
		local c = p("Crest" .. i, Vector3.new(0.35, 1.5 - i * 0.2, 0.9), Vector3.new(0, 7.4 - i * 0.55, -1.4 + i * 0.75), crest)
		c.CFrame = c.CFrame * CFrame.Angles(math.rad(-15), 0, 0)
	end
	p("Tail1", Vector3.new(1.2, 1.2, 3), Vector3.new(0, 3, 3.4), color)
	p("Tail2", Vector3.new(0.8, 0.8, 3), Vector3.new(0, 2.8, 6.2), color)
	p("TailTip", Vector3.new(0.5, 0.5, 1.2), Vector3.new(0, 2.7, 8.2), crest)
	for _, sx in ipairs({ -1, 1 }) do
		p("Leg", Vector3.new(0.9, 2.2, 1.1), Vector3.new(sx * 0.9, 1.1, 0.3), dark)
		p("Arm", Vector3.new(0.5, 0.5, 1), Vector3.new(sx * 1.25, 3.3, -1.4), dark)
	end
	return torso, 8.6
end

local builders = { leafling = leafling, pebbleback = pebbleback, embercrest = embercrest }

-- Constrói o modelo da espécie em 'origin' (CFrame no chão). Devolve Model e altura (para a etiqueta).
function M.buildDino(speciesId, origin, parent)
	local sp = Config.Species[speciesId]
	local builder = builders[speciesId]
	if not sp or not builder then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = sp.name
	model:SetAttribute("SpeciesId", speciesId)
	local p = newBuilder(model, origin, sp.scale)
	local primary, height = builder(p, sp.color)
	model.PrimaryPart = primary
	model.Parent = parent
	return model, height * sp.scale
end

-- Decorações cosméticas (origin = CFrame no chão).
local decor = {}

function decor.lamp(p)
	p("Post", Vector3.new(0.6, 7, 0.6), Vector3.new(0, 3.5, 0), Color3.fromRGB(70, 70, 80), nil, Enum.Material.Metal)
	local bulb = p("Bulb", Vector3.new(1.6, 1.6, 1.6), Vector3.new(0, 7.6, 0), Color3.fromRGB(255, 235, 150), BALL, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 1.5
	light.Color = Color3.fromRGB(255, 225, 150)
	light.Parent = bulb
end

function decor.flowers(p)
	p("Bed", Vector3.new(5, 0.6, 3), Vector3.new(0, 0.3, 0), Color3.fromRGB(110, 75, 50), nil, Enum.Material.Wood)
	local colors = { Color3.fromRGB(255, 120, 150), Color3.fromRGB(255, 220, 90), Color3.fromRGB(190, 130, 255) }
	for i = 1, 6 do
		p("Flower" .. i, Vector3.new(0.8, 0.8, 0.8), Vector3.new(-2 + (i - 1) * 0.8, 1.1, ((i % 2) - 0.5) * 1.2), colors[i % 3 + 1], BALL)
	end
end

function decor.banner(p)
	p("PostL", Vector3.new(0.5, 8, 0.5), Vector3.new(-3, 4, 0), Color3.fromRGB(139, 94, 60), nil, Enum.Material.Wood)
	p("PostR", Vector3.new(0.5, 8, 0.5), Vector3.new(3, 4, 0), Color3.fromRGB(139, 94, 60), nil, Enum.Material.Wood)
	local colors = { Color3.fromRGB(240, 90, 90), Color3.fromRGB(250, 200, 70), Color3.fromRGB(90, 190, 240) }
	for i = 1, 3 do
		p("Flag" .. i, Vector3.new(1.6, 1.8, 0.2), Vector3.new(-2 + (i - 1) * 2, 7, 0), colors[i])
	end
end

function decor.balloons(p)
	p("Weight", Vector3.new(1.2, 0.8, 1.2), Vector3.new(0, 0.4, 0), Color3.fromRGB(110, 110, 120))
	local colors = { Color3.fromRGB(250, 90, 110), Color3.fromRGB(90, 190, 250), Color3.fromRGB(255, 215, 80) }
	for i = 1, 3 do
		p("String" .. i, Vector3.new(0.1, 5 + i, 0.1), Vector3.new((i - 2) * 0.9, 2.8 + i / 2, 0), Color3.fromRGB(230, 230, 230))
		p("Balloon" .. i, Vector3.new(2.2, 2.6, 2.2), Vector3.new((i - 2) * 1.2, 6.2 + i, 0), colors[i], BALL)
	end
end

function decor.rocks(p)
	local g = Color3.fromRGB(135, 140, 150)
	p("Rock1", Vector3.new(3, 2, 2.6), Vector3.new(0, 1, 0), g, nil, Enum.Material.Slate)
	p("Rock2", Vector3.new(2, 1.4, 2), Vector3.new(2.4, 0.7, 0.8), shade(g, 0.85), nil, Enum.Material.Slate)
	p("Rock3", Vector3.new(1.4, 1, 1.4), Vector3.new(-2, 0.5, 0.6), shade(g, 1.1), nil, Enum.Material.Slate)
end

function decor.fountain(p)
	p("Basin", Vector3.new(0.4, 6, 6), Vector3.new(0, 0.6, 0), Color3.fromRGB(190, 190, 200), Enum.PartType.Cylinder, Enum.Material.Marble)
	p("Water", Vector3.new(0.2, 5.2, 5.2), Vector3.new(0, 0.9, 0), Color3.fromRGB(90, 180, 235), Enum.PartType.Cylinder, Enum.Material.Glass)
	p("Column", Vector3.new(0.9, 3, 0.9), Vector3.new(0, 2, 0), Color3.fromRGB(200, 200, 210), nil, Enum.Material.Marble)
	p("Top", Vector3.new(1.8, 0.5, 1.8), Vector3.new(0, 3.6, 0), Color3.fromRGB(90, 180, 235), nil, Enum.Material.Glass)
end

function M.buildDecor(id, origin, parent)
	local fn = decor[id]
	if not fn then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Decor_" .. id
	local p = newBuilder(model, origin, 1)
	fn(p)
	-- cilindros precisam girar para ficar deitados (eixo X -> Y)
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("Part") and part.Shape == Enum.PartType.Cylinder then
			part.CFrame = part.CFrame * CFrame.Angles(0, 0, math.rad(90))
		end
	end
	model.Parent = parent
	return model
end

return M
]==] },
}
for _, f in ipairs(sharedFiles) do make(f[1], f[2], f[3], sharedFolder) end
sharedFolder.Parent = RS

local servicesFolder = Instance.new("Folder")
servicesFolder.Name = "DinoParkServices"
local serviceFiles = {
	{ "ModuleScript", "DataService", [==[
--!nonstrict
-- Persistência com DataStoreService: carrega com tentativas, nunca sobrescreve dados válidos com
-- padrões após falha de carga (canSave=false), salva com UpdateAsync e limite de frequência.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Logic = require(Shared:WaitForChild("Logic"))

local DataService = {}
local sessions = {} -- [Player] = { data=, canSave=, dirty=, lastSave=, loadFailed= }

local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[DinoPark] DataStore indisponível: " .. tostring(result))
	end
end

local function keyFor(player)
	return "u_" .. tostring(player.UserId)
end

-- Carrega (yield). Sempre devolve uma sessão; canSave=false se o carregamento falhou.
function DataService.load(player)
	local now = os.time()
	local raw, loaded = nil, false
	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return store:GetAsync(keyFor(player))
			end)
			if ok then
				raw, loaded = result, true
				break
			end
			warn(("[DinoPark] Falha ao carregar %s (tentativa %d): %s"):format(player.Name, attempt, tostring(result)))
			task.wait(1.5 * attempt)
		end
	end
	local session = {
		data = Logic.migrate(raw, Config, now),
		canSave = loaded, -- se não carregou, NÃO salvamos (evita apagar progresso real)
		dirty = false,
		lastSave = 0,
		isNew = loaded and raw == nil,
	}
	sessions[player] = session
	return session
end

function DataService.get(player)
	return sessions[player]
end

function DataService.markDirty(player)
	local s = sessions[player]
	if s then
		s.dirty = true
	end
end

-- Salva se necessário. force=true ignora o intervalo mínimo (saída do jogador / desligamento).
function DataService.save(player, force)
	local s = sessions[player]
	if not s or not s.canSave or not store then
		return false
	end
	if not force and (not s.dirty or os.clock() - s.lastSave < Config.MinSaveGap) then
		return false
	end
	s.data.lastSeen = os.time()
	local snapshot = s.data
	local ok, err = pcall(function()
		store:UpdateAsync(keyFor(player), function()
			return snapshot
		end)
	end)
	if ok then
		s.dirty = false
		s.lastSave = os.clock()
		return true
	end
	warn(("[DinoPark] Falha ao salvar %s: %s"):format(player.Name, tostring(err)))
	return false
end

function DataService.release(player)
	DataService.save(player, true)
	sessions[player] = nil
end

function DataService.sessions()
	return sessions
end

return DataService
]==] },
	{ "ModuleScript", "ParkService", [==[
--!nonstrict
-- Parques por jogador: constrói 4 parques estáticos no início e redesenha a parte dinâmica
-- (dinossauros, cercas, decorações, habitats) quando os dados mudam.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Logic = require(Shared:WaitForChild("Logic"))
local DinoModels = require(Shared:WaitForChild("DinoModels"))

local ParkService = {}

local plots = {} -- [index] = { base=CFrame, owner=Player|nil, folder=, dynamic=, fenceParts={}, signLabel=, incubLabel=, eggPart= }
local ownerPlot = {} -- [Player] = index
local root = nil

local function mk(parent, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function billboard(adornee, text, offsetY, width)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(width or 150, 36)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 80
	gui.Adornee = adornee
	gui.Parent = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(30, 50, 35)
	label.BackgroundTransparency = 0.25
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.Parent = label
	return label
end

local function buildPlot(index, def)
	local center = Vector3.new(def.x, 0, def.z)
	local base = CFrame.lookAt(center, Vector3.new(0, 0, def.z)) -- -Z local aponta para a avenida central
	local function at(x, y, z)
		return base * CFrame.new(x, y, z)
	end
	local H = Config.PlotHalf
	local folder = Instance.new("Folder")
	folder.Name = "Plot" .. index
	folder.Parent = root
	local plot = { base = base, owner = nil, folder = folder, fenceParts = {} }

	mk(folder, "Floor", Vector3.new(H * 2, 0.3, H * 2), at(0, 0.15, 0), Color3.fromRGB(150, 215, 120), Enum.Material.Grass)
	local woodColor = Config.DefaultFenceColor
	local function fence(name, size, x, z)
		local p = mk(folder, name, size, at(x, size.Y / 2, z), woodColor, Enum.Material.Wood)
		plot.fenceParts[#plot.fenceParts + 1] = p
	end
	fence("FenceBack", Vector3.new(H * 2, 3, 1), 0, H)
	fence("FenceLeft", Vector3.new(1, 3, H * 2), -H, 0)
	fence("FenceRight", Vector3.new(1, 3, H * 2), H, 0)
	local side = (H * 2 - 8) / 2
	fence("FenceFrontL", Vector3.new(side, 3, 1), -(4 + side / 2), -H)
	fence("FenceFrontR", Vector3.new(side, 3, 1), 4 + side / 2, -H)

	-- placa do parque (lado da entrada)
	mk(folder, "SignPost", Vector3.new(0.8, 6, 0.8), at(-11, 3, -H - 1.5), Color3.fromRGB(110, 75, 50), Enum.Material.Wood)
	local board = mk(folder, "SignBoard", Vector3.new(9, 2.8, 0.4), at(-11, 6.4, -H - 1.5), Color3.fromRGB(235, 215, 170), Enum.Material.Wood)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(70, 45, 25)
	label.Text = "Parque livre"
	label.Parent = gui
	plot.signLabel = label

	-- incubadora
	mk(folder, "IncubatorBase", Vector3.new(5, 1.2, 5), at(0, 0.9, -10), Color3.fromRGB(190, 160, 120), Enum.Material.Wood)
	local egg = mk(folder, "Egg", Vector3.new(3.4, 3.4, 3.4), at(0, 3.2, -10), Color3.fromRGB(250, 240, 215), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	plot.eggPart = egg
	for i = 1, 3 do
		mk(folder, "EggSpot" .. i, Vector3.new(0.7, 0.7, 0.7), at(-1 + i * 0.9, 3 + (i % 2) * 0.9, -11.5), Color3.fromRGB(120, 200, 110), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
	plot.incubLabel = billboard(egg, "Incubadora vazia", 3.2, 200)

	local dynamic = Instance.new("Folder")
	dynamic.Name = "Dynamic"
	dynamic.Parent = folder
	plot.dynamic = dynamic
	plots[index] = plot
end

function ParkService.init()
	root = Instance.new("Folder")
	root.Name = "DinoParkPlots"
	root.Parent = Workspace
	for index, def in ipairs(Config.Plots) do
		buildPlot(index, def)
	end
end

function ParkService.claim(player)
	if ownerPlot[player] then
		return ownerPlot[player]
	end
	for index, plot in ipairs(plots) do
		if not plot.owner then
			plot.owner = player
			ownerPlot[player] = index
			plot.signLabel.Text = "Parque de " .. player.DisplayName
			return index
		end
	end
	return nil
end

local function clear(plot)
	plot.dynamic:ClearAllChildren()
	for _, part in ipairs(plot.fenceParts) do
		part.Color = Config.DefaultFenceColor
	end
end

function ParkService.release(player)
	local index = ownerPlot[player]
	if not index then
		return
	end
	local plot = plots[index]
	clear(plot)
	plot.owner = nil
	plot.signLabel.Text = "Parque livre"
	plot.incubLabel.Text = "Incubadora vazia"
	ownerPlot[player] = nil
end

function ParkService.plotIndex(player)
	return ownerPlot[player]
end

-- Entrada do parque (para o botão "Meu Parque"), um pouco acima do chão.
function ParkService.entranceCFrame(player)
	local index = ownerPlot[player]
	if not index then
		return nil
	end
	return plots[index].base * CFrame.new(0, 4, -Config.PlotHalf - 6) * CFrame.Angles(0, math.rad(180), 0)
end

-- Redesenha dinossauros, habitats, decorações e cercas a partir dos dados do jogador.
function ParkService.refresh(player, data)
	local index = ownerPlot[player]
	if not index then
		return
	end
	local plot = plots[index]
	clear(plot)
	local slots = Logic.slots(data, Config)
	for i, pos in ipairs(Config.PadPositions) do
		local unlocked = i <= slots
		local color = unlocked and Color3.fromRGB(120, 190, 95) or Color3.fromRGB(150, 150, 150)
		local pad = mk(plot.dynamic, "Pad" .. i, Vector3.new(0.4, 7, 7), plot.base * CFrame.new(pos[1], 0.5, pos[2]) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.Grass, Enum.PartType.Cylinder)
		if not unlocked then
			pad.Material = Enum.Material.Slate
			pad.Transparency = 0.35
		end
	end
	for i, dinoId in ipairs(data.placed) do
		local dino = Logic.findDino(data, dinoId)
		local pos = Config.PadPositions[i]
		if dino and pos then
			local cf = plot.base * CFrame.new(pos[1], 0.7, pos[2])
			local model, height = DinoModels.buildDino(dino.species, cf, plot.dynamic)
			if model then
				local sp = Config.Species[dino.species]
				billboard(model.PrimaryPart, sp.name, height - 1.5, 130)
			end
		end
	end
	for _, item in ipairs(Config.ShopCatalog) do
		if data.owned[item.id] and item.kind == "decor" then
			local spot = Config.DecorSpots[item.spot]
			if spot then
				DinoModels.buildDecor(item.id, plot.base * CFrame.new(spot[1], 0.3, spot[2]), plot.dynamic)
			end
		end
	end
	local fenceItem = Logic.catalogItem(Config, data.fence)
	local color = (fenceItem and fenceItem.kind == "fence" and fenceItem.color) or Config.DefaultFenceColor
	for _, part in ipairs(plot.fenceParts) do
		part.Color = color
	end
end

-- Texto da incubadora (chamado ~1x/s).
function ParkService.updateIncubator(player, data, now)
	local index = ownerPlot[player]
	if not index then
		return
	end
	local plot = plots[index]
	local inc = data.incubating
	if not inc then
		plot.incubLabel.Text = "Incubadora vazia"
	elseif now >= inc.readyAt then
		plot.incubLabel.Text = "Pronto! Abra Ovo > Coletar"
	else
		plot.incubLabel.Text = ("Chocando... %ds"):format(math.ceil(inc.readyAt - now))
	end
end

return ParkService
]==] },
	{ "ModuleScript", "GameService", [==[
--!nonstrict
-- Autoridade do jogo: remotes validados, ações, renda periódica, ganhos offline e estado enviado ao cliente.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Logic = require(Shared:WaitForChild("Logic"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local ParkService = require(script.Parent:WaitForChild("ParkService"))

local GameService = {}

local requestRF, stateRE, notifyRE
local rng = Random.new()
local lastRequest = {} -- [Player] = os.clock()

local function notify(player, message, kind)
	notifyRE:FireClient(player, { message = message, kind = kind or "info" })
end

-- Estado completo enviado ao cliente (somente leitura; o cliente nunca é fonte de verdade).
local function buildState(player, session)
	local data = session.data
	local now = os.time()
	local stock, nextRotation = Logic.shopStock(Config, now)
	local shop = {}
	for _, id in ipairs(stock) do
		local item = Logic.catalogItem(Config, id)
		shop[#shop + 1] = { id = id, name = item.name, kind = item.kind, price = item.price, owned = data.owned[id] == true }
	end
	local upgrades = {}
	for _, key in ipairs(Config.UpgradeOrder) do
		upgrades[#upgrades + 1] = { key = key, level = data.upgrades[key], cost = Logic.upgradeCost(data, Config, key) or false }
	end
	local placed = {}
	for _, id in ipairs(data.placed) do
		placed[id] = true
	end
	local dinos = {}
	for _, dino in ipairs(data.dinos) do
		dinos[#dinos + 1] = { id = dino.id, species = dino.species, placed = placed[dino.id] == true }
	end
	return {
		coins = data.coins,
		eggs = data.eggs,
		dinos = dinos,
		placedCount = #data.placed,
		slots = Logic.slots(data, Config),
		upgrades = upgrades,
		shop = shop,
		nextRotation = nextRotation,
		serverNow = now,
		incubating = data.incubating and { readyAt = data.incubating.readyAt } or false,
		incubateSeconds = Logic.incubateSeconds(data, Config),
		perTick = Logic.incomePerTick(data, Config),
		missions = data.missions,
		hatched = data.hatched,
		tutorialDismissed = data.tutorialDismissed,
		canSave = session.canSave,
		hasPlot = ParkService.plotIndex(player) ~= nil,
		welcome = session.welcome or false,
	}
end

local function push(player)
	local session = DataService.get(player)
	if session then
		stateRE:FireClient(player, buildState(player, session))
	end
end

-- Após qualquer mudança: missões, marcar para salvar, redesenhar parque (se necessário) e enviar estado.
local function commit(player, session, redraw)
	for _, m in ipairs(Logic.checkMissions(session.data, Config)) do
		notify(player, ("Missão: %s (+%d moedas)"):format(m.text, m.reward), "success")
	end
	DataService.markDirty(player)
	if redraw then
		ParkService.refresh(player, session.data)
	end
	push(player)
end

local handlers = {}

function handlers.getState()
	return true, ""
end

function handlers.buyEgg(player, session)
	local ok, msg = Logic.buyEgg(session.data, Config)
	if ok then commit(player, session, false) end
	return ok, msg
end

function handlers.incubate(player, session)
	local ok, msg = Logic.startIncubate(session.data, Config, os.time())
	if ok then commit(player, session, false) end
	return ok, msg
end

function handlers.collect(player, session)
	local ok, msg = Logic.collect(session.data, Config, os.time(), function()
		return rng:NextNumber()
	end)
	if ok then commit(player, session, false) end
	return ok, msg
end

function handlers.place(player, session, payload)
	local ok, msg = Logic.place(session.data, Config, payload and payload.id)
	if ok then commit(player, session, true) end
	return ok, msg
end

function handlers.remove(player, session, payload)
	local ok, msg = Logic.remove(session.data, Config, payload and payload.id)
	if ok then commit(player, session, true) end
	return ok, msg
end

function handlers.buyUpgrade(player, session, payload)
	local ok, msg = Logic.buyUpgrade(session.data, Config, payload and payload.key)
	if ok then commit(player, session, true) end
	return ok, msg
end

function handlers.buyShop(player, session, payload)
	local stock = Logic.shopStock(Config, os.time())
	local ok, msg = Logic.buyShop(session.data, Config, payload and payload.id, stock)
	if ok then commit(player, session, true) end
	return ok, msg
end

function handlers.dismissTutorial(player, session)
	session.data.tutorialDismissed = true
	commit(player, session, false)
	return true, ""
end

function handlers.goHome(player)
	local cf = ParkService.entranceCFrame(player)
	local character = player.Character
	if cf and character and character.PrimaryPart then
		character:PivotTo(cf)
		return true, "Bem-vindo ao seu parque!"
	end
	return false, "Seu parque ainda não está pronto."
end

local function onRequest(player, action, payload)
	-- validação de entrada
	if type(action) ~= "string" or #action > 24 then
		return { ok = false, message = "Pedido inválido." }
	end
	if payload ~= nil and type(payload) ~= "table" then
		return { ok = false, message = "Pedido inválido." }
	end
	local now = os.clock()
	if now - (lastRequest[player] or 0) < Config.RequestMinInterval then
		return { ok = false, message = "Devagar!" }
	end
	lastRequest[player] = now
	local handler = handlers[action]
	local session = DataService.get(player)
	if not handler or not session then
		return { ok = false, message = session and "Ação desconhecida." or "Ainda carregando..." }
	end
	local ok, success, message = pcall(handler, player, session, payload)
	if not ok then
		warn("[DinoPark] erro em '" .. action .. "': " .. tostring(success))
		return { ok = false, message = "Erro interno." }
	end
	if action == "getState" then
		push(player)
	end
	return { ok = success == true, message = message or "" }
end

local function onPlayerAdded(player)
	local session = DataService.load(player)
	if not player.Parent then
		DataService.release(player)
		return
	end
	local index = ParkService.claim(player)
	if not index then
		player:Kick("Servidor cheio: todos os parques estão ocupados.")
		return
	end
	local data = session.data
	-- Ganhos offline: calculado no servidor com limite configurável.
	local earned, elapsed = Logic.offlineEarnings(data, Config, os.time())
	if earned > 0 and not session.isNew then
		data.coins = data.coins + earned
		DataService.markDirty(player)
		session.welcome = ("Bem-vindo de volta! Seus visitantes renderam %d moedas em %d min."):format(earned, math.floor(elapsed / 60))
	end
	data.lastSeen = os.time()
	ParkService.refresh(player, data)
	push(player)
end

local function onPlayerRemoving(player)
	ParkService.release(player)
	DataService.release(player)
	lastRequest[player] = nil
end

function GameService.start()
	local remotes = Instance.new("Folder")
	remotes.Name = "DinoParkRemotes"
	remotes.Parent = ReplicatedStorage
	requestRF = Instance.new("RemoteFunction")
	requestRF.Name = "Request"
	requestRF.Parent = remotes
	stateRE = Instance.new("RemoteEvent")
	stateRE.Name = "State"
	stateRE.Parent = remotes
	notifyRE = Instance.new("RemoteEvent")
	notifyRE.Name = "Notify"
	notifyRE.Parent = remotes
	requestRF.OnServerInvoke = onRequest

	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	-- Renda dos visitantes
	task.spawn(function()
		while true do
			task.wait(Config.IncomeInterval)
			for player, session in pairs(DataService.sessions()) do
				local tick = Logic.incomePerTick(session.data, Config)
				if tick > 0 then
					session.data.coins = session.data.coins + tick
					DataService.markDirty(player)
					push(player)
				end
			end
		end
	end)

	-- Incubadoras (texto) e autosave
	task.spawn(function()
		local sinceSave = 0
		while true do
			task.wait(1)
			local now = os.time()
			for player, session in pairs(DataService.sessions()) do
				ParkService.updateIncubator(player, session.data, now)
			end
			sinceSave = sinceSave + 1
			if sinceSave >= Config.AutosaveSeconds then
				sinceSave = 0
				for player in pairs(DataService.sessions()) do
					task.spawn(DataService.save, player, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		for player in pairs(DataService.sessions()) do
			DataService.save(player, true)
		end
	end)
end

return GameService
]==] },
}
for _, f in ipairs(serviceFiles) do make(f[1], f[2], f[3], servicesFolder) end
servicesFolder.Parent = SSS

local m = { "Script", "DinoParkMain", [==[
--!nonstrict
-- Ponto de entrada do servidor do Dino Park Tycoon.
local services = script.Parent:WaitForChild("DinoParkServices")
local ParkService = require(services:WaitForChild("ParkService"))
local GameService = require(services:WaitForChild("GameService"))

ParkService.init()
GameService.start()
print("[DinoPark] Servidor iniciado.")
]==] }
make(m[1], m[2], m[3], SSS)

local c = { "LocalScript", "DinoParkClient", [==[
--!nonstrict
-- Interface do Dino Park Tycoon (cliente). Só mostra estado e pede ações; o servidor decide tudo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Logic = require(Shared:WaitForChild("Logic"))

local remotes = ReplicatedStorage:WaitForChild("DinoParkRemotes")
local requestRF = remotes:WaitForChild("Request")
local stateRE = remotes:WaitForChild("State")
local notifyRE = remotes:WaitForChild("Notify")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local COLORS = {
	bg = Color3.fromRGB(34, 52, 40),
	panel = Color3.fromRGB(48, 72, 56),
	row = Color3.fromRGB(62, 90, 70),
	button = Color3.fromRGB(88, 170, 96),
	buttonOff = Color3.fromRGB(110, 120, 112),
	danger = Color3.fromRGB(210, 90, 80),
	text = Color3.fromRGB(245, 250, 240),
	muted = Color3.fromRGB(190, 205, 190),
	gold = Color3.fromRGB(255, 214, 90),
}

local state = nil
local welcomeShown = nil
local saveWarned = false
local openPanel = nil
local busy = false

-- ===== helpers de UI =====
local function corner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = inst
	return c
end

local function label(parent, text, size, color, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamMedium
	l.TextSize = size or 16
	l.TextColor3 = color or COLORS.text
	l.Text = text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	if props then
		for k, v in pairs(props) do
			l[k] = v
		end
	end
	l.Parent = parent
	return l
end

local function button(parent, text, color, size)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = color or COLORS.button
	b.Font = Enum.Font.GothamBold
	b.TextSize = 15
	b.TextColor3 = COLORS.text
	b.Text = text
	b.Size = size or UDim2.fromOffset(110, 34)
	b.Parent = parent
	corner(b, 8)
	return b
end

local gui = Instance.new("ScreenGui")
gui.Name = "DinoParkUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local root = Instance.new("Frame")
root.Name = "Root"
root.BackgroundTransparency = 1
root.Size = UDim2.fromScale(1, 1)
root.Parent = gui

local scale = Instance.new("UIScale")
scale.Parent = root
local function updateScale()
	local v = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1000, 600)
	scale.Scale = math.clamp(math.min(v.X / 900, v.Y / 560), 0.6, 1.25)
end
updateScale()
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

-- Moedas e renda (topo esquerdo)
local hud = Instance.new("Frame")
hud.BackgroundColor3 = COLORS.bg
hud.BackgroundTransparency = 0.15
hud.Position = UDim2.fromOffset(12, 10)
hud.Size = UDim2.fromOffset(230, 58)
hud.Parent = root
corner(hud, 10)
local coinsLabel = label(hud, "Moedas: ...", 22, COLORS.gold, { Position = UDim2.fromOffset(12, 4), Size = UDim2.fromOffset(210, 28), Font = Enum.Font.GothamBold })
local rateLabel = label(hud, "", 14, COLORS.muted, { Position = UDim2.fromOffset(12, 32), Size = UDim2.fromOffset(210, 20) })

-- Tutorial (topo centro)
local tutorial = Instance.new("Frame")
tutorial.BackgroundColor3 = COLORS.bg
tutorial.BackgroundTransparency = 0.1
tutorial.AnchorPoint = Vector2.new(0.5, 0)
tutorial.Position = UDim2.new(0.5, 0, 0, 10)
tutorial.Size = UDim2.fromOffset(380, 56)
tutorial.Visible = false
tutorial.Parent = root
corner(tutorial, 10)
local tutorialText = label(tutorial, "", 15, COLORS.text, { Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -60, 1, -8), TextYAlignment = Enum.TextYAlignment.Center })
local tutorialClose = button(tutorial, "X", COLORS.danger, UDim2.fromOffset(32, 32))
tutorialClose.Position = UDim2.new(1, -40, 0.5, -16)

-- Toasts
local toast = label(root, "", 17, COLORS.text, {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 74), Size = UDim2.fromOffset(420, 30),
	BackgroundTransparency = 0.15, BackgroundColor3 = COLORS.bg, TextXAlignment = Enum.TextXAlignment.Center, Visible = false, TextWrapped = true,
})
corner(toast, 8)
local toastToken = 0
local function showToast(text, kind)
	toastToken = toastToken + 1
	local mine = toastToken
	toast.Text = text
	toast.TextColor3 = (kind == "error") and Color3.fromRGB(255, 160, 150) or ((kind == "success") and Color3.fromRGB(170, 255, 170) or COLORS.text)
	toast.Size = UDim2.fromOffset(420, #text > 55 and 52 or 30)
	toast.Visible = true
	task.delay(3.5, function()
		if toastToken == mine then
			toast.Visible = false
		end
	end)
end

local function playPing()
	local snd = Instance.new("Sound")
	snd.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	snd.Volume = 0.4
	snd.Parent = gui
	snd:Play()
	game:GetService("Debris"):AddItem(snd, 2)
end

-- Carregando
local loading = Instance.new("Frame")
loading.BackgroundColor3 = COLORS.bg
loading.Size = UDim2.fromScale(1, 1)
loading.ZIndex = 50
loading.Parent = gui
local loadingText = label(loading, "Carregando seu parque...", 28, COLORS.text, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(500, 50), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 51 })

-- Painel central
local panel = Instance.new("Frame")
panel.BackgroundColor3 = COLORS.panel
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(460, 400)
panel.Visible = false
panel.Parent = root
corner(panel, 14)
local panelTitle = label(panel, "", 22, COLORS.text, { Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -70, 0, 30), Font = Enum.Font.GothamBold })
local panelClose = button(panel, "X", COLORS.danger, UDim2.fromOffset(34, 34))
panelClose.Position = UDim2.new(1, -46, 0, 8)
local scroll = Instance.new("ScrollingFrame")
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.Position = UDim2.fromOffset(12, 50)
scroll.Size = UDim2.new(1, -24, 1, -62)
scroll.ScrollBarThickness = 6
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new()
scroll.Parent = panel
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 8)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = scroll

local liveLabels = {} -- rótulos atualizados a cada 0.5s (contagens regressivas)

local function clearList()
	for _, child in ipairs(scroll:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	liveLabels = {}
end

local order = 0
local function row(height)
	order = order + 1
	local f = Instance.new("Frame")
	f.BackgroundColor3 = COLORS.row
	f.Size = UDim2.new(1, -8, 0, height or 58)
	f.LayoutOrder = order
	f.Parent = scroll
	corner(f, 10)
	return f
end

local function textRow(text, color, height)
	local f = row(height or 36)
	label(f, text, 15, color or COLORS.text, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
	return f
end

-- Envia pedido ao servidor (sem travar a interface) e mostra o resultado.
local function request(action, payload)
	if busy then
		return
	end
	busy = true
	task.spawn(function()
		local ok, result = pcall(function()
			return requestRF:InvokeServer(action, payload)
		end)
		busy = false
		if not ok or type(result) ~= "table" then
			showToast("Falha de conexão. Tente de novo.", "error")
			return
		end
		if result.message and result.message ~= "" then
			showToast(result.message, result.ok and "success" or "error")
		end
		if result.ok then
			playPing()
		end
	end)
end

local function timeLeft(readyAt)
	return math.max(0, readyAt - Workspace:GetServerTimeNow())
end

local function fmt(seconds)
	seconds = math.max(0, math.floor(seconds))
	return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

-- ===== painéis =====
local renderers = {}

function renderers.egg()
	panelTitle.Text = "Ovos e incubadora"
	textRow(("Você tem %d ovo(s). Cada ovo custa %d moedas."):format(state.eggs, Config.EggCost), COLORS.text, 36)
	local f = row(150)
	label(f, "Chances ao chocar (o primeiro ovo é sempre um Leafling):", 14, COLORS.muted, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 36) })
	local y = 44
	for _, o in ipairs(Logic.odds(Config)) do
		local sp = Config.Species[o.id]
		label(f, ("%s (%s): %.0f%%"):format(sp.name, sp.rarity, o.percent), 15, Config.RarityColors[sp.rarity], { Position = UDim2.fromOffset(12, y), Size = UDim2.new(1, -24, 0, 22) })
		y = y + 24
	end
	local inc = row(96)
	if state.incubating then
		local l = label(inc, "", 16, COLORS.text, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -150, 0, 40), TextYAlignment = Enum.TextYAlignment.Center })
		liveLabels[#liveLabels + 1] = function()
			local left = timeLeft(state.incubating.readyAt)
			l.Text = left > 0 and ("Chocando... " .. fmt(left)) or "Seu ovo chocou!"
		end
		local b = button(inc, "Coletar", COLORS.button, UDim2.fromOffset(110, 38))
		b.Position = UDim2.new(1, -124, 0, 8)
		b.MouseButton1Click:Connect(function() request("collect") end)
		label(inc, ("Incubação leva %ds (melhore em Melhorias)."):format(state.incubateSeconds), 13, COLORS.muted, { Position = UDim2.fromOffset(12, 56), Size = UDim2.new(1, -24, 0, 30) })
	else
		label(inc, "Incubadora vazia.", 16, COLORS.text, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -150, 0, 40), TextYAlignment = Enum.TextYAlignment.Center })
		local b = button(inc, "Incubar", state.eggs > 0 and COLORS.button or COLORS.buttonOff, UDim2.fromOffset(110, 38))
		b.Position = UDim2.new(1, -124, 0, 8)
		b.MouseButton1Click:Connect(function() request("incubate") end)
		label(inc, ("Incubação leva %ds."):format(state.incubateSeconds), 13, COLORS.muted, { Position = UDim2.fromOffset(12, 56), Size = UDim2.new(1, -24, 0, 30) })
	end
	local buy = row(58)
	label(buy, ("Comprar ovo - %d moedas"):format(Config.EggCost), 16, COLORS.text, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -150, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
	local b = button(buy, "Comprar", state.coins >= Config.EggCost and COLORS.button or COLORS.buttonOff, UDim2.fromOffset(110, 38))
	b.Position = UDim2.new(1, -124, 0.5, -19)
	b.MouseButton1Click:Connect(function() request("buyEgg") end)
end

function renderers.inventory()
	panelTitle.Text = ("Inventário  (habitats %d/%d)"):format(state.placedCount, state.slots)
	if #state.dinos == 0 then
		textRow("Nenhum dinossauro ainda. Choque um ovo!", COLORS.muted, 40)
		return
	end
	for _, dino in ipairs(state.dinos) do
		local sp = Config.Species[dino.species]
		local f = row(64)
		label(f, sp.name .. "  (" .. sp.rarity .. ")", 17, Config.RarityColors[sp.rarity], { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -150, 0, 22), Font = Enum.Font.GothamBold })
		label(f, ("Renda: +%d moedas / %ds"):format(sp.income, Config.IncomeInterval), 13, COLORS.muted, { Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -150, 0, 28) })
		local b = button(f, dino.placed and "Guardar" or "Colocar", dino.placed and COLORS.buttonOff or COLORS.button, UDim2.fromOffset(110, 38))
		b.Position = UDim2.new(1, -124, 0.5, -19)
		local id = dino.id
		b.MouseButton1Click:Connect(function()
			request(dino.placed and "remove" or "place", { id = id })
		end)
	end
end

function renderers.shop()
	panelTitle.Text = "Loja rotativa"
	local f = textRow("", COLORS.muted, 36)
	local l = f:FindFirstChildOfClass("TextLabel")
	liveLabels[#liveLabels + 1] = function()
		l.Text = "Próxima rotação em " .. fmt(state.nextRotation - Workspace:GetServerTimeNow()) .. " (itens cosméticos, sem vantagem de jogo)"
	end
	for _, item in ipairs(state.shop) do
		local r = row(58)
		label(r, item.name, 17, COLORS.text, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -150, 0, 24), Font = Enum.Font.GothamBold })
		label(r, (item.kind == "fence" and "Cor de cerca" or "Decoração") .. " - " .. item.price .. " moedas", 13, COLORS.muted, { Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -150, 0, 22) })
		local text = item.owned and "Comprado" or "Comprar"
		local b = button(r, text, (item.owned or state.coins < item.price) and COLORS.buttonOff or COLORS.button, UDim2.fromOffset(110, 38))
		b.Position = UDim2.new(1, -124, 0.5, -19)
		local id = item.id
		b.MouseButton1Click:Connect(function()
			if not item.owned then request("buyShop", { id = id }) end
		end)
	end
end

function renderers.upgrades()
	panelTitle.Text = "Melhorias"
	for _, up in ipairs(state.upgrades) do
		local def = Config.Upgrades[up.key]
		local r = row(76)
		label(r, ("%s  (nível %d/%d)"):format(def.name, up.level, def.maxLevel), 17, COLORS.text, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -150, 0, 24), Font = Enum.Font.GothamBold })
		label(r, def.desc, 13, COLORS.muted, { Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -150, 0, 38) })
		local maxed = up.cost == false
		local b = button(r, maxed and "Máximo" or (up.cost .. " moedas"), (maxed or state.coins < up.cost) and COLORS.buttonOff or COLORS.button, UDim2.fromOffset(110, 38))
		b.Position = UDim2.new(1, -124, 0.5, -19)
		local key = up.key
		b.MouseButton1Click:Connect(function()
			if not maxed then request("buyUpgrade", { key = key }) end
		end)
	end
end

function renderers.missions()
	panelTitle.Text = "Missões"
	for _, m in ipairs(Config.Missions) do
		local done = state.missions[m.id] == true
		textRow((done and "[feito] " or "[ ] ") .. m.text .. "  (+" .. m.reward .. " moedas)", done and Color3.fromRGB(170, 255, 170) or COLORS.text, 40)
	end
	textRow("Recompensas são pagas automaticamente ao completar.", COLORS.muted, 36)
end

local function render()
	if not openPanel or not state then
		return
	end
	order = 0
	clearList()
	renderers[openPanel]()
end

local function setPanel(name)
	if openPanel == name then
		openPanel = nil
		panel.Visible = false
		return
	end
	openPanel = name
	panel.Visible = true
	render()
end
panelClose.MouseButton1Click:Connect(function()
	openPanel = nil
	panel.Visible = false
end)

-- Barra inferior
local bar = Instance.new("Frame")
bar.BackgroundColor3 = COLORS.bg
bar.BackgroundTransparency = 0.15
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -10)
bar.Size = UDim2.fromOffset(660, 54)
bar.Parent = root
corner(bar, 12)
local barLayout = Instance.new("UIListLayout")
barLayout.FillDirection = Enum.FillDirection.Horizontal
barLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
barLayout.VerticalAlignment = Enum.VerticalAlignment.Center
barLayout.Padding = UDim.new(0, 8)
barLayout.Parent = bar

local navItems = {
	{ "Ovo", "egg" }, { "Inventário", "inventory" }, { "Loja", "shop" }, { "Melhorias", "upgrades" }, { "Missões", "missions" },
}
for _, nav in ipairs(navItems) do
	local b = button(bar, nav[1], COLORS.button, UDim2.fromOffset(92, 38))
	b.MouseButton1Click:Connect(function() setPanel(nav[2]) end)
end
local home = button(bar, "Meu Parque", COLORS.gold, UDim2.fromOffset(104, 38))
home.TextColor3 = Color3.fromRGB(60, 45, 10)
home.MouseButton1Click:Connect(function() request("goHome") end)

tutorialClose.MouseButton1Click:Connect(function()
	tutorial.Visible = false
	request("dismissTutorial")
end)

-- ===== estado =====
local function tutorialMessage()
	if state.tutorialDismissed then
		return nil
	end
	if state.hatched == 0 then
		if state.incubating then
			return "Seu ovo está chocando. Abra Ovo e toque em Coletar quando terminar."
		end
		return "Bem-vindo! Toque em Ovo e depois em Incubar para chocar seu primeiro dinossauro."
	end
	if state.placedCount == 0 then
		return "Abra Inventário e toque em Colocar para pôr o dinossauro no habitat."
	end
	if not state.missions.upgrade then
		return "Os visitantes pagam moedas com o tempo. Compre uma melhoria em Melhorias!"
	end
	return nil
end

stateRE.OnClientEvent:Connect(function(s)
	state = s
	loading.Visible = false
	coinsLabel.Text = "Moedas: " .. s.coins
	rateLabel.Text = ("Renda: +%d a cada %ds"):format(s.perTick, Config.IncomeInterval) .. (s.canSave and "" or "  (sem salvamento)")
	if s.welcome and s.welcome ~= welcomeShown then
		welcomeShown = s.welcome
		showToast(s.welcome, "success")
	end
	if not s.canSave and not saveWarned then
		saveWarned = true
		showToast("Salvamento indisponível: o progresso desta sessão não será salvo.", "error")
	end
	local msg = tutorialMessage()
	tutorial.Visible = msg ~= nil
	if msg then
		tutorialText.Text = msg
	end
	render()
end)

notifyRE.OnClientEvent:Connect(function(n)
	if type(n) == "table" and type(n.message) == "string" then
		showToast(n.message, n.kind)
	end
end)

-- contagens regressivas
task.spawn(function()
	while true do
		task.wait(0.5)
		if state and openPanel then
			for _, fn in ipairs(liveLabels) do
				fn()
			end
		end
	end
end)

-- pede o estado inicial (caso o push do servidor tenha chegado antes do cliente conectar) e trata erro de carga
task.spawn(function()
	for attempt = 1, 20 do
		if state then
			return
		end
		pcall(function()
			requestRF:InvokeServer("getState")
		end)
		task.wait(1)
	end
	if not state then
		loadingText.Text = "Não foi possível carregar. Saia e entre de novo."
	end
end)
]==] }
make(c[1], c[2], c[3], SPS)

print("[DinoPark] Parte 2 (scripts) instalada. Salve o lugar e pressione Play (F5).")
