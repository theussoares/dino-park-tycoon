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
	{ RS, "Shared" }, { SSS, "DinoParkServices" }, { SSS, "DinoParkMain" }, { SPS, "DinoParkClient" }, { SPS, "RetentionClient" },
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

Config.SchemaVersion = 2
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
Config.LockSeconds = 300 -- trava de sessão expira se o servidor dono sumir (renovada a cada autosave)
Config.LockRetries = 5
Config.LockRetryWait = 3
Config.SaveRetries = 3
Config.ShutdownMaxWait = 25

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
	-- Sumidouro de longo prazo (meta de dias): renda +10% por nível, custo ~2,5x por nível.
	renovation = { name = "Reforma do parque", desc = "+10% de renda por nível. Meta de longo prazo.", maxLevel = 6, costs = { 4000, 12000, 40000, 120000, 350000, 900000 }, bonus = 0.10 },
}
Config.UpgradeOrder = { "slots", "income", "incubator", "renovation" }

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
	-- Sumidouros de fim de jogo (cosméticos caros, comprados só com Coins)
	{ id = "fence_lava", kind = "fence", name = "Cerca lava", price = 800, color = Color3.fromRGB(235, 90, 50) },
	{ id = "fence_ice", kind = "fence", name = "Cerca gelo", price = 800, color = Color3.fromRGB(190, 235, 255) },
	{ id = "fence_night", kind = "fence", name = "Cerca noturna", price = 1500, color = Color3.fromRGB(70, 60, 130) },
	-- Só por recompensa (nunca aparecem na loja, nunca à venda)
	{ id = "fence_gold", kind = "fence", name = "Cerca dourada", price = 0, rewardOnly = true, color = Color3.fromRGB(240, 195, 60) },
	{ id = "fence_royal", kind = "fence", name = "Cerca real", price = 0, rewardOnly = true, color = Color3.fromRGB(150, 90, 200) },
}
Config.DefaultFenceColor = Color3.fromRGB(139, 94, 60)

Config.Missions = {
	{ id = "hatch", text = "Choque seu primeiro ovo", reward = 50 },
	{ id = "place", text = "Coloque um dinossauro no habitat", reward = 75 },
	{ id = "upgrade", text = "Compre uma melhoria", reward = 100 },
}

-- ===== Retenção, economia e eventos (todos os números são HIPÓTESES; ver RETENTION_MONETIZATION_PLAN.md) =====
Config.DayOffsetSeconds = -3 * 3600 -- "dia" do jogo vira às 00:00 de Brasília (UTC-3), igual para todos os servidores
Config.DaySeconds = 86400

-- Controle de inflação: ovo fica mais caro a cada EggCostStepEvery ovos chocados (teto +EggCostMaxGrowth).
Config.EggCostStepEvery = 10
Config.EggCostStep = 0.10
Config.EggCostMaxGrowth = 1.0
Config.MaxEggs = 99

-- Calendário diário de 7 recompensas. Reclamar avança o ciclo; faltar um dia NÃO zera nada (sem punição).
-- coinsMinutes = minutos de renda atual (limitados por [coinsMin, coinsMax]); a renda vira "tamanho relativo".
Config.DailyRewards = {
	{ coinsMinutes = 3, coinsMin = 40, coinsMax = 600 },
	{ eggs = 1 },
	{ coinsMinutes = 6, coinsMin = 80, coinsMax = 1200 },
	{ boost = true },
	{ coinsMinutes = 10, coinsMin = 120, coinsMax = 2000 },
	{ eggs = 2 },
	{ coinsMinutes = 15, coinsMin = 200, coinsMax = 3000, eggs = 1, cosmetic = "fence_gold" },
}
Config.DailyCosmeticFallbackCoins = 300 -- se o cosmético da recompensa já é seu
Config.DailyBoost = { mult = 1.5, seconds = 600 }
Config.MaxBoostSeconds = 1800 -- teto de tempo de impulso acumulado (inclui produtos futuros)

-- Missões diárias: 3 por dia, sorteadas de forma determinística pelo dia (iguais para todos).
Config.DailyQuestCount = 3
Config.DailyQuestPool = {
	{ id = "q_hatch2", text = "Choque 2 ovos", stat = "hatched", target = 2, reward = 60 },
	{ id = "q_egg1", text = "Compre 1 ovo", stat = "eggsBought", target = 1, reward = 40 },
	{ id = "q_place1", text = "Coloque 1 dinossauro num habitat", stat = "placements", target = 1, reward = 40 },
	{ id = "q_shop1", text = "Compre 1 item da loja", stat = "shopBuys", target = 1, reward = 50 },
	{ id = "q_up1", text = "Compre 1 melhoria", stat = "upgradesBought", target = 1, reward = 80 },
	{ id = "q_earn400", text = "Ganhe 400 moedas", stat = "coinsEarned", target = 400, reward = 60 },
}
Config.DailyAllBonus = { eggs = 1, text = "Todas as missões do dia: +1 ovo" }

-- Metas de curto / médio / longo prazo (recompensa única; nada expira).
Config.Goals = {
	{ id = "g_hatch3", tier = "short", text = "Choque 3 ovos", stat = "hatched", target = 3, reward = { coins = 60 } },
	{ id = "g_slots2", tier = "short", text = "Tenha 2 habitats", stat = "slots", target = 2, reward = { coins = 100 } },
	{ id = "g_decor1", tier = "short", text = "Compre sua 1ª decoração ou cerca", stat = "cosmetics", target = 1, reward = { coins = 50 } },
	{ id = "g_dex3", tier = "mid", text = "Descubra as 3 espécies", stat = "discovered", target = 3, reward = { eggs = 1, coins = 150 } },
	{ id = "g_hatch15", tier = "mid", text = "Choque 15 ovos", stat = "hatched", target = 15, reward = { coins = 300 } },
	{ id = "g_income3", tier = "mid", text = "Mais visitantes nível 3", stat = "incomeLevel", target = 3, reward = { coins = 250 } },
	{ id = "g_slots4", tier = "mid", text = "Tenha os 4 habitats", stat = "slots", target = 4, reward = { coins = 400 } },
	{ id = "g_hatch50", tier = "long", text = "Choque 50 ovos", stat = "hatched", target = 50, reward = { coins = 1500, eggs = 2 } },
	{ id = "g_earn50k", tier = "long", text = "Ganhe 50.000 moedas no total", stat = "coinsEarned", target = 50000, reward = { cosmetic = "fence_royal", coins = 1000 } },
	{ id = "g_upall", tier = "long", text = "Todas as melhorias no máximo", stat = "upgradesTotal", target = 17, reward = { coins = 2500 } },
}
Config.GoalTierNames = { short = "Curto prazo", mid = "Médio prazo", long = "Longo prazo" }

-- Calendário semanal PREVISÍVEL (weekday: 0=segunda ... 6=domingo, no fuso de Config.DayOffsetSeconds).
-- Efeitos pequenos e temporários; nada é exclusivo nem punitivo.
Config.Events = {
	{ id = "decor_wed", name = "Quarta da Decoração", desc = "Itens da loja 20% mais baratos.", days = { 2 }, shopDiscount = 0.20 },
	{ id = "visitors_fri", name = "Sextou dos Visitantes", desc = "+15% de renda dos visitantes.", days = { 4 }, income = 0.15 },
	{ id = "eggs_weekend", name = "Fim de semana dos Ovos", desc = "Ovos 25% mais baratos.", days = { 5, 6 }, eggDiscount = 0.25 },
}
Config.WeekdayNames = { [0] = "segunda", "terça", "quarta", "quinta", "sexta", "sábado", "domingo" }

-- Ofertas (futuras, com Robux): regras para NUNCA aparecer cedo, nem em pop-up, nem repetidamente.
Config.Offers = {
	MinHatched = 5, -- só depois do loop principal ser entendido (tutorial já ficou para trás)
	MinSessions = 2, -- nunca na primeira sessão
	MinSessionSeconds = 600, -- nunca nos primeiros 10 min de uma sessão
	CooldownSeconds = 86400, -- no máximo 1 oferta passiva por dia
	MaxPerDay = 1,
}

-- Monetização opcional. DESLIGADA: não há MarketplaceService, ProcessReceipt nem preço em Robux ativo.
-- Os ids 0 são marcadores; só preencha depois do loop estar testado no Studio com DataStore e multiplayer.
Config.Monetization = {
	Enabled = false,
	MaxReceipts = 200,
	Passes = {
		auto_collect = { id = "auto_collect", name = "Coleta automática", priceRobux = 199, gamePassId = 0, repeatable = false,
			grants = "Coleta o ovo chocado sozinho quando você está no jogo. Não aumenta renda nem sorte.", duration = "Permanente" },
		founder = { id = "founder", name = "Pacote Fundador (cosmético)", priceRobux = 399, gamePassId = 0, repeatable = false,
			grants = "Cerca dourada + título no painel. Só visual.", duration = "Permanente", cosmetic = "fence_gold" },
	},
	Products = {
		boost_small = { id = "boost_small", name = "Impulso de visitantes", priceRobux = 25, productId = 0, repeatable = true,
			grants = "+50% de renda por 10 min. Não acumula além de 30 min.", duration = "10 minutos", boostMult = 1.5, boostSeconds = 600 },
		eggs_3 = { id = "eggs_3", name = "3 ovos", priceRobux = 75, productId = 0, repeatable = true,
			grants = "3 ovos (mesmas chances de todos; chances visíveis).", duration = "Consumível", eggs = 3 },
	},
}

-- Telemetria (AnalyticsService). Sem dados pessoais: só nomes de eventos, números e ids de itens.
Config.Analytics = { Enabled = true, Debug = false }
-- Eventos que o cliente pode reportar (lista fechada; o servidor ignora qualquer outro).
Config.ClientEvents = { shop_view = true, today_view = true, store_guide_view = true, egg_view = true }

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
		upgrades = { slots = 0, income = 0, incubator = 0, renovation = 0 },
		owned = {},
		fence = "wood",
		incubating = nil,
		missions = { hatch = false, place = false, upgrade = false },
		hatched = 0,
		tutorialDismissed = false,
		lastSeen = now,
		-- v2: retenção / economia / métricas
		stats = { coinsEarned = 0, eggsBought = 0, placements = 0, upgradesBought = 0, shopBuys = 0 },
		eco = { src = {}, snk = {} },
		login = { firstDay = nil, lastDay = -1, lastClaimDay = -1, cycle = 0, totalClaims = 0, sessions = 0 },
		daily = { day = -1, base = {}, claimed = {}, bonusClaimed = false },
		goalsClaimed = {},
		discovered = {},
		boost = nil,
		offers = { lastShownAt = 0, day = -1, count = 0 },
		receipts = {},
		passes = {},
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
	d.schemaVersion = cfg.SchemaVersion
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
	-- v2 (saves v1 não têm estes campos: ficam nos padrões; espécies já possuídas contam como descobertas)
	if type(raw.stats) == "table" then
		for k in pairs(d.stats) do
			d.stats[k] = floor(num(raw.stats[k], 0, 0, 1e12))
		end
	end
	if type(raw.eco) == "table" then
		for _, flow in ipairs({ "src", "snk" }) do
			if type(raw.eco[flow]) == "table" then
				local n = 0
				for reason, v in pairs(raw.eco[flow]) do
					if type(reason) == "string" and #reason <= 24 and n < 40 then
						n = n + 1
						d.eco[flow][reason] = floor(num(v, 0, 0, 1e13))
					end
				end
			end
		end
	end
	if type(raw.login) == "table" then
		local l, rl = d.login, raw.login
		l.firstDay = rl.firstDay ~= nil and floor(num(rl.firstDay, 0, 0, 1e6)) or nil
		l.lastDay = floor(num(rl.lastDay, -1, -1, 1e6))
		l.lastClaimDay = floor(num(rl.lastClaimDay, -1, -1, 1e6))
		l.cycle = floor(num(rl.cycle, 0, 0, #cfg.DailyRewards - 1))
		l.totalClaims = floor(num(rl.totalClaims, 0, 0, 1e6))
		l.sessions = floor(num(rl.sessions, 0, 0, 1e6))
	end
	if type(raw.daily) == "table" then
		d.daily.day = floor(num(raw.daily.day, -1, -1, 1e6))
		d.daily.bonusClaimed = raw.daily.bonusClaimed == true
		for _, q in ipairs(cfg.DailyQuestPool) do
			if type(raw.daily.claimed) == "table" and raw.daily.claimed[q.id] == true then
				d.daily.claimed[q.id] = true
			end
		end
		if type(raw.daily.base) == "table" then
			for k in pairs(d.stats) do
				d.daily.base[k] = floor(num(raw.daily.base[k], 0, 0, 1e12))
			end
			d.daily.base.hatched = floor(num(raw.daily.base.hatched, 0, 0, 1e12))
		end
	end
	for _, g in ipairs(cfg.Goals) do
		if type(raw.goalsClaimed) == "table" and raw.goalsClaimed[g.id] == true then
			d.goalsClaimed[g.id] = true
		end
	end
	for _, dino in ipairs(d.dinos) do
		d.discovered[dino.species] = true
	end
	if type(raw.discovered) == "table" then
		for id in pairs(cfg.Species) do
			if raw.discovered[id] == true then
				d.discovered[id] = true
			end
		end
	end
	if type(raw.boost) == "table" and type(raw.boost.endsAt) == "number" then
		d.boost = { mult = num(raw.boost.mult, 1, 1, 3), endsAt = num(raw.boost.endsAt, 0, 0, now + cfg.MaxBoostSeconds) }
	end
	if type(raw.offers) == "table" then
		d.offers.lastShownAt = num(raw.offers.lastShownAt, 0, 0, now)
		d.offers.day = floor(num(raw.offers.day, -1, -1, 1e6))
		d.offers.count = floor(num(raw.offers.count, 0, 0, 1000))
	end
	if type(raw.receipts) == "table" then
		local n = 0
		for id, t in pairs(raw.receipts) do
			if type(id) == "string" and #id <= 64 and type(t) == "number" and n < cfg.Monetization.MaxReceipts then
				n = n + 1
				d.receipts[id] = t
			end
		end
	end
	if type(raw.passes) == "table" then
		for id in pairs(cfg.Monetization.Passes) do
			if raw.passes[id] == true then
				d.passes[id] = true
			end
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
-- 'now' (opcional) inclui impulso ativo e evento do dia; sem 'now' devolve a renda-base.
function Logic.incomeRaw(data, cfg, now)
	local sum = 0
	for _, id in ipairs(data.placed) do
		local dino = Logic.findDino(data, id)
		if dino then
			sum = sum + cfg.Species[dino.species].income
		end
	end
	local raw = sum * (1 + data.upgrades.income * cfg.Upgrades.income.bonus + data.upgrades.renovation * cfg.Upgrades.renovation.bonus)
	if now then
		raw = raw * Logic.boostMult(data, now) * (1 + Logic.eventEffects(cfg, now).income)
	end
	return raw
end

function Logic.incomePerTick(data, cfg, now)
	return floor(Logic.incomeRaw(data, cfg, now) + 0.5)
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
		if not item.rewardOnly then
			ids[#ids + 1] = item.id
		end
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

function Logic.buyShop(data, cfg, itemId, stock, now)
	if type(itemId) ~= "string" then
		return false, "Item inválido."
	end
	local item = Logic.catalogItem(cfg, itemId)
	if not item or item.rewardOnly or not listHas(stock, itemId) then
		return false, "Esse item não está na loja agora."
	end
	if data.owned[itemId] then
		return false, "Você já tem esse item."
	end
	local price = Logic.shopPrice(cfg, item, now)
	if data.coins < price then
		return false, "Moedas insuficientes."
	end
	Logic.spend(data, price, "shop")
	data.stats.shopBuys = data.stats.shopBuys + 1
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
	Logic.spend(data, cost, "upgrade")
	data.stats.upgradesBought = data.stats.upgradesBought + 1
	data.upgrades[key] = data.upgrades[key] + 1
	return true, cfg.Upgrades[key].name .. " melhorada!"
end

function Logic.buyEgg(data, cfg, now)
	if data.eggs >= cfg.MaxEggs then
		return false, "Você já tem ovos demais."
	end
	local cost = Logic.eggCost(data, cfg, now)
	if data.coins < cost then
		return false, "Moedas insuficientes."
	end
	Logic.spend(data, cost, "egg")
	data.stats.eggsBought = data.stats.eggsBought + 1
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
	data.discovered[species] = true
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
	data.stats.placements = data.stats.placements + 1
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
		Logic.earn(data, m.reward, "mission")
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

-- ===== Economia: toda moeda que entra/sai passa por earn/spend (livro-razão em data.eco) =====
function Logic.earn(data, amount, reason)
	amount = floor(num(amount, 0, 0, 1e12))
	local room = 1e12 - data.coins
	if amount > room then
		amount = room
	end
	if amount <= 0 then
		return 0
	end
	data.coins = data.coins + amount
	data.stats.coinsEarned = math.min(data.stats.coinsEarned + amount, 1e12)
	data.eco.src[reason] = (data.eco.src[reason] or 0) + amount
	return amount
end

function Logic.spend(data, amount, reason)
	data.coins = data.coins - amount
	data.eco.snk[reason] = (data.eco.snk[reason] or 0) + amount
end

function Logic.ecoSnapshot(data)
	local snap = { src = {}, snk = {} }
	for k, v in pairs(data.eco.src) do
		snap.src[k] = v
	end
	for k, v in pairs(data.eco.snk) do
		snap.snk[k] = v
	end
	return snap
end

-- Diferenças do livro-razão desde o snapshot: lista de { flow = "source"|"sink", reason, amount }.
function Logic.ecoDiff(snap, data)
	local out = {}
	for _, pair in ipairs({ { "src", "source" }, { "snk", "sink" } }) do
		for reason, v in pairs(data.eco[pair[1]]) do
			local delta = v - (snap[pair[1]][reason] or 0)
			if delta > 0 then
				out[#out + 1] = { flow = pair[2], reason = reason, amount = delta }
			end
		end
	end
	table.sort(out, function(a, b)
		return a.flow .. a.reason < b.flow .. b.reason
	end)
	return out
end

-- ===== Tempo: dia de jogo, dia da semana, eventos previsíveis =====
function Logic.dayIndex(cfg, now)
	return floor((now + cfg.DayOffsetSeconds) / cfg.DaySeconds)
end

function Logic.dayEndsAt(cfg, now)
	return (Logic.dayIndex(cfg, now) + 1) * cfg.DaySeconds - cfg.DayOffsetSeconds
end

-- 0 = segunda ... 6 = domingo (o dia 0 do Unix, 01/01/1970, foi quinta-feira)
function Logic.weekday(cfg, now)
	return (Logic.dayIndex(cfg, now) + 3) % 7
end

local function eventOnWeekday(ev, wd)
	return listHas(ev.days, wd)
end

function Logic.activeEvents(cfg, now)
	local wd = Logic.weekday(cfg, now)
	local out = {}
	for _, ev in ipairs(cfg.Events) do
		if eventOnWeekday(ev, wd) then
			local extra = 0
			while extra < 6 and eventOnWeekday(ev, (wd + extra + 1) % 7) do
				extra = extra + 1
			end
			out[#out + 1] = { id = ev.id, name = ev.name, desc = ev.desc, endsAt = Logic.dayEndsAt(cfg, now) + extra * cfg.DaySeconds }
		end
	end
	return out
end

function Logic.upcomingEvents(cfg, now)
	local wd = Logic.weekday(cfg, now)
	local out = {}
	for _, ev in ipairs(cfg.Events) do
		if not eventOnWeekday(ev, wd) then
			for k = 1, 7 do
				if eventOnWeekday(ev, (wd + k) % 7) then
					out[#out + 1] = { id = ev.id, name = ev.name, desc = ev.desc, startsAt = Logic.dayEndsAt(cfg, now) + (k - 1) * cfg.DaySeconds }
					break
				end
			end
		end
	end
	table.sort(out, function(a, b)
		return a.startsAt < b.startsAt
	end)
	return out
end

function Logic.eventEffects(cfg, now)
	local fx = { income = 0, eggDiscount = 0, shopDiscount = 0 }
	local wd = Logic.weekday(cfg, now)
	for _, ev in ipairs(cfg.Events) do
		if eventOnWeekday(ev, wd) then
			fx.income = fx.income + (ev.income or 0)
			fx.eggDiscount = math.max(fx.eggDiscount, ev.eggDiscount or 0)
			fx.shopDiscount = math.max(fx.shopDiscount, ev.shopDiscount or 0)
		end
	end
	return fx
end

function Logic.boostMult(data, now)
	if data.boost and data.boost.endsAt > now then
		return data.boost.mult
	end
	return 1
end

function Logic.grantBoost(data, cfg, mult, seconds, now)
	local active = data.boost and data.boost.endsAt > now
	local from = active and data.boost.endsAt or now
	local endsAt = math.min(from + seconds, now + cfg.MaxBoostSeconds)
	data.boost = { mult = math.max(mult, active and data.boost.mult or 1), endsAt = endsAt }
end

-- Custo do ovo: cresce devagar com o progresso (sumidouro) e cai nos eventos.
function Logic.eggCost(data, cfg, now)
	local growth = math.min(floor(data.hatched / cfg.EggCostStepEvery) * cfg.EggCostStep, cfg.EggCostMaxGrowth)
	local cost = cfg.EggCost * (1 + growth)
	if now then
		cost = cost * (1 - Logic.eventEffects(cfg, now).eggDiscount)
	end
	return math.max(1, floor(cost + 0.5))
end

function Logic.shopPrice(cfg, item, now)
	local price = item.price
	if now then
		price = price * (1 - Logic.eventEffects(cfg, now).shopDiscount)
	end
	return math.max(1, floor(price + 0.5))
end

-- ===== Estatísticas, missões diárias, metas =====
local STAT_KEYS = { "hatched", "coinsEarned", "eggsBought", "placements", "upgradesBought", "shopBuys" }

local function cosmeticCount(data, cfg)
	local n = 0
	for _, item in ipairs(cfg.ShopCatalog) do
		if data.owned[item.id] and not item.rewardOnly then
			n = n + 1
		end
	end
	return n
end

function Logic.statValue(data, cfg, key)
	if key == "hatched" then
		return data.hatched
	elseif key == "discovered" then
		local n = 0
		for _ in pairs(data.discovered) do
			n = n + 1
		end
		return n
	elseif key == "slots" then
		return Logic.slots(data, cfg)
	elseif key == "incomeLevel" then
		return data.upgrades.income
	elseif key == "upgradesTotal" then
		local total = 0
		for _, k in ipairs(cfg.UpgradeOrder) do
			total = total + data.upgrades[k]
		end
		return total
	elseif key == "cosmetics" then
		return cosmeticCount(data, cfg)
	end
	return data.stats[key] or 0
end

function Logic.rollDay(data, cfg, now)
	local today = Logic.dayIndex(cfg, now)
	if data.daily.day == today then
		return false
	end
	local base = {}
	for _, k in ipairs(STAT_KEYS) do
		base[k] = Logic.statValue(data, cfg, k)
	end
	data.daily = { day = today, base = base, claimed = {}, bonusClaimed = false }
	return true
end

-- Missões do dia: iguais para todos os jogadores, determinísticas pelo dia.
function Logic.dailyQuests(cfg, day)
	local state = (day * 7919) % 2147483646 + 1
	local function nextRand()
		state = (state * 16807) % 2147483647
		return state
	end
	local idx = {}
	for i = 1, #cfg.DailyQuestPool do
		idx[i] = i
	end
	for i = #idx, 2, -1 do
		local j = nextRand() % i + 1
		idx[i], idx[j] = idx[j], idx[i]
	end
	local out = {}
	for i = 1, math.min(cfg.DailyQuestCount, #idx) do
		out[i] = cfg.DailyQuestPool[idx[i]]
	end
	return out
end

local function questProgress(data, cfg, q)
	local base = data.daily.base[q.stat]
	local cur = Logic.statValue(data, cfg, q.stat)
	if base == nil then
		return 0
	end
	return math.max(0, math.min(q.target, cur - base))
end

-- Entrega moedas/ovos/cosmético; cosmético repetido vira moedas (nunca se perde recompensa).
local function applyBundle(data, cfg, coins, eggs, cosmetic, reason)
	local parts = {}
	if cosmetic then
		if data.owned[cosmetic] then
			coins = (coins or 0) + cfg.DailyCosmeticFallbackCoins
		else
			data.owned[cosmetic] = true
			local item = Logic.catalogItem(cfg, cosmetic)
			parts[#parts + 1] = item and item.name or cosmetic
		end
	end
	if coins and coins > 0 then
		local got = Logic.earn(data, coins, reason)
		parts[#parts + 1] = got .. " moedas"
	end
	if eggs and eggs > 0 then
		data.eggs = math.min(data.eggs + eggs, 1e6)
		parts[#parts + 1] = eggs .. (eggs == 1 and " ovo" or " ovos")
	end
	return table.concat(parts, " + ")
end

function Logic.claimQuest(data, cfg, id, now)
	Logic.rollDay(data, cfg, now)
	if type(id) ~= "string" then
		return false, "Missão inválida."
	end
	for _, q in ipairs(Logic.dailyQuests(cfg, data.daily.day)) do
		if q.id == id then
			if data.daily.claimed[id] then
				return false, "Você já recebeu essa recompensa."
			end
			if questProgress(data, cfg, q) < q.target then
				return false, "Missão ainda não concluída."
			end
			data.daily.claimed[id] = true
			local text = applyBundle(data, cfg, q.reward, 0, nil, "quest")
			return true, "Missão concluída: " .. text .. "!"
		end
	end
	return false, "Essa missão não é de hoje."
end

function Logic.claimQuestBonus(data, cfg, now)
	Logic.rollDay(data, cfg, now)
	if data.daily.bonusClaimed then
		return false, "Bônus do dia já recebido."
	end
	for _, q in ipairs(Logic.dailyQuests(cfg, data.daily.day)) do
		if not data.daily.claimed[q.id] then
			return false, "Receba todas as missões do dia primeiro."
		end
	end
	data.daily.bonusClaimed = true
	local text = applyBundle(data, cfg, cfg.DailyAllBonus.coins, cfg.DailyAllBonus.eggs, nil, "quest")
	return true, "Bônus do dia: " .. text .. "!"
end

function Logic.goalById(cfg, id)
	for _, g in ipairs(cfg.Goals) do
		if g.id == id then
			return g
		end
	end
	return nil
end

function Logic.claimGoal(data, cfg, id)
	local g = type(id) == "string" and Logic.goalById(cfg, id) or nil
	if not g then
		return false, "Meta inválida."
	end
	if data.goalsClaimed[id] then
		return false, "Você já recebeu essa recompensa."
	end
	if Logic.statValue(data, cfg, g.stat) < g.target then
		return false, "Meta ainda não concluída."
	end
	data.goalsClaimed[id] = true
	local text = applyBundle(data, cfg, g.reward.coins, g.reward.eggs, g.reward.cosmetic, "goal")
	return true, "Meta concluída: " .. text .. "!"
end

-- ===== Recompensa diária (calendário de 7; faltar um dia não pune) =====
function Logic.dailyRewardCoins(data, cfg, r)
	if not r.coinsMinutes then
		return 0
	end
	local perMinute = Logic.incomeRaw(data, cfg) * 60 / cfg.IncomeInterval
	local c = floor(perMinute * r.coinsMinutes + 0.5)
	return math.max(r.coinsMin, math.min(r.coinsMax, c))
end

function Logic.rewardLabel(data, cfg, r)
	local parts = {}
	if r.coinsMinutes then
		parts[#parts + 1] = Logic.dailyRewardCoins(data, cfg, r) .. " moedas"
	end
	if r.eggs then
		parts[#parts + 1] = r.eggs .. (r.eggs == 1 and " ovo" or " ovos")
	end
	if r.boost then
		parts[#parts + 1] = ("Impulso +%d%% por %d min"):format(floor((cfg.DailyBoost.mult - 1) * 100 + 0.5), floor(cfg.DailyBoost.seconds / 60))
	end
	if r.cosmetic then
		local item = Logic.catalogItem(cfg, r.cosmetic)
		local name = item and item.name or r.cosmetic
		if data.owned[r.cosmetic] then
			name = ("%s (você já tem: +%d moedas no lugar)"):format(name, cfg.DailyCosmeticFallbackCoins)
		end
		parts[#parts + 1] = name
	end
	return table.concat(parts, " + ")
end

function Logic.claimDaily(data, cfg, now)
	local today = Logic.dayIndex(cfg, now)
	local l = data.login
	if l.lastClaimDay == today then
		return false, "Você já recebeu hoje. Volte amanhã!"
	end
	local r = cfg.DailyRewards[l.cycle + 1]
	local label = Logic.rewardLabel(data, cfg, r)
	local coins = Logic.dailyRewardCoins(data, cfg, r)
	if r.boost then
		Logic.grantBoost(data, cfg, cfg.DailyBoost.mult, cfg.DailyBoost.seconds, now)
	end
	applyBundle(data, cfg, coins, r.eggs, r.cosmetic, "daily")
	l.lastClaimDay = today
	l.cycle = (l.cycle + 1) % #cfg.DailyRewards
	l.totalClaims = l.totalClaims + 1
	return true, "Recompensa diária: " .. label .. "!", l.cycle
end

-- Início de sessão: devolve dados para telemetria (dias desde o 1º acesso etc.).
function Logic.startSession(data, cfg, now)
	local today = Logic.dayIndex(cfg, now)
	local l = data.login
	if l.firstDay == nil then
		l.firstDay = today
	end
	local isNewDay = l.lastDay ~= today
	l.lastDay = today
	l.sessions = l.sessions + 1
	Logic.rollDay(data, cfg, now)
	return { sessions = l.sessions, daysSinceFirst = math.max(0, today - l.firstDay), isNewDay = isNewDay }
end

-- Marcos de onboarding (telemetria de funil): lista ordenada de { name, reached }.
function Logic.onboardingFlags(data)
	return {
		{ name = "first_hatch", reached = data.hatched > 0 },
		{ name = "first_place", reached = data.stats.placements > 0 },
		{ name = "first_upgrade", reached = data.stats.upgradesBought > 0 },
		{ name = "first_shop_buy", reached = data.stats.shopBuys > 0 },
		{ name = "first_daily_claim", reached = data.login.totalClaims > 0 },
	}
end

-- Dicas contextuais e discretas (texto no painel "Hoje"; nunca pop-up, nunca compra).
function Logic.hints(data, cfg, now)
	local out = {}
	if #data.placed < Logic.slots(data, cfg) and #data.dinos > #data.placed then
		out[#out + 1] = "Você tem um dinossauro guardado e um habitat livre."
	end
	if data.eggs > 0 and not data.incubating then
		out[#out + 1] = "Há um ovo esperando na incubadora."
	end
	local slotCost = Logic.upgradeCost(data, cfg, "slots")
	if slotCost and data.coins >= slotCost then
		out[#out + 1] = "Você já tem moedas para liberar um novo habitat."
	end
	return out
end

-- ===== Ofertas futuras (Robux): quando é aceitável MOSTRAR uma oferta passiva =====
function Logic.offerEligible(data, cfg, ctx, now)
	local o = cfg.Offers
	if not cfg.Monetization.Enabled then
		return false, "monetização desligada"
	end
	if data.hatched < o.MinHatched then
		return false, "jogador ainda no começo"
	end
	if not data.tutorialDismissed and data.hatched < o.MinHatched * 2 then
		return false, "tutorial ainda ativo"
	end
	if data.login.sessions < o.MinSessions then
		return false, "primeira sessão"
	end
	if (ctx.sessionSeconds or 0) < o.MinSessionSeconds then
		return false, "sessão recém-iniciada"
	end
	if now - data.offers.lastShownAt < o.CooldownSeconds then
		return false, "intervalo mínimo entre ofertas"
	end
	if data.offers.day == Logic.dayIndex(cfg, now) and data.offers.count >= o.MaxPerDay then
		return false, "limite diário"
	end
	return true, "ok"
end

function Logic.markOfferShown(data, cfg, now)
	local day = Logic.dayIndex(cfg, now)
	if data.offers.day ~= day then
		data.offers.day = day
		data.offers.count = 0
	end
	data.offers.count = data.offers.count + 1
	data.offers.lastShownAt = now
end

-- ===== Compras (desligadas): concessão idempotente por recibo =====
local function pruneReceipts(data, cfg)
	local n = 0
	for _ in pairs(data.receipts) do
		n = n + 1
	end
	while n > cfg.Monetization.MaxReceipts do
		local oldestId, oldestT
		for id, t in pairs(data.receipts) do
			if oldestT == nil or t < oldestT then
				oldestId, oldestT = id, t
			end
		end
		data.receipts[oldestId] = nil
		n = n - 1
	end
end

-- Devolve "granted" | "already" | "unknown" | "invalid". Chamada repetida com o mesmo recibo NÃO concede de novo.
function Logic.processReceipt(data, cfg, receiptId, productKey, now)
	if type(receiptId) ~= "string" or #receiptId == 0 or #receiptId > 64 then
		return "invalid"
	end
	if data.receipts[receiptId] then
		return "already"
	end
	local product = type(productKey) == "string" and cfg.Monetization.Products[productKey] or nil
	if not product then
		return "unknown"
	end
	if product.eggs then
		data.eggs = math.min(data.eggs + product.eggs, 1e6)
	end
	if product.boostSeconds then
		Logic.grantBoost(data, cfg, product.boostMult, product.boostSeconds, now)
	end
	data.receipts[receiptId] = now
	pruneReceipts(data, cfg)
	return "granted"
end

function Logic.grantPass(data, cfg, passKey)
	local pass = type(passKey) == "string" and cfg.Monetization.Passes[passKey] or nil
	if not pass then
		return false
	end
	data.passes[passKey] = true
	if pass.cosmetic then
		data.owned[pass.cosmetic] = true
	end
	return true
end

-- ===== Guia da loja: o que cada compra concede, quanto dura e se repete (usado pelo cliente) =====
function Logic.storeGuide(cfg)
	local out = { coins = {}, robux = {}, robuxEnabled = cfg.Monetization.Enabled }
	out.coins[#out.coins + 1] = {
		name = "Ovo", price = cfg.EggCost .. "+ moedas", grants = "1 ovo; as chances aparecem na aba Ovos.",
		duration = "Consumível", repeatable = "Pode comprar quantas vezes quiser (o preço sobe devagar com o progresso)",
	}
	for _, key in ipairs(cfg.UpgradeOrder) do
		local def = cfg.Upgrades[key]
		out.coins[#out.coins + 1] = {
			name = def.name, price = def.costs[1] .. " a " .. def.costs[#def.costs] .. " moedas", grants = def.desc,
			duration = "Permanente", repeatable = ("Até o nível %d"):format(def.maxLevel),
		}
	end
	out.coins[#out.coins + 1] = {
		name = "Decorações e cercas", price = "45 a 1500 moedas", grants = "Só visual: sem vantagem de jogo.",
		duration = "Permanente", repeatable = "Compra única de cada item",
	}
	for _, p in pairs(cfg.Monetization.Passes) do
		out.robux[#out.robux + 1] = { name = p.name, price = p.priceRobux .. " Robux", grants = p.grants, duration = p.duration, repeatable = p.repeatable and "Pode comprar de novo" or "Compra única" }
	end
	for _, p in pairs(cfg.Monetization.Products) do
		out.robux[#out.robux + 1] = { name = p.name, price = p.priceRobux .. " Robux", grants = p.grants, duration = p.duration, repeatable = p.repeatable and "Pode comprar de novo" or "Compra única" }
	end
	table.sort(out.robux, function(a, b)
		return a.name < b.name
	end)
	return out
end

-- ===== Visão para o cliente (somente leitura): tudo que o painel "Hoje" mostra =====
function Logic.retentionView(data, cfg, now)
	Logic.rollDay(data, cfg, now)
	local today = Logic.dayIndex(cfg, now)
	local l = data.login
	local view = { claimable = 0, resetsAt = Logic.dayEndsAt(cfg, now) }

	local canClaim = l.lastClaimDay ~= today
	local days = {}
	for i, r in ipairs(cfg.DailyRewards) do
		days[i] = { label = Logic.rewardLabel(data, cfg, r), claimed = i <= l.cycle, next = i == l.cycle + 1 }
	end
	view.daily = { canClaim = canClaim, days = days, totalClaims = l.totalClaims }
	if canClaim then
		view.claimable = view.claimable + 1
	end

	local quests, allClaimed = {}, true
	for _, q in ipairs(Logic.dailyQuests(cfg, data.daily.day)) do
		local progress = questProgress(data, cfg, q)
		local claimed = data.daily.claimed[q.id] == true
		local done = progress >= q.target
		if not claimed then
			allClaimed = false
		end
		if done and not claimed then
			view.claimable = view.claimable + 1
		end
		quests[#quests + 1] = { id = q.id, text = q.text, progress = progress, target = q.target, reward = q.reward .. " moedas", claimed = claimed, done = done }
	end
	view.quests = quests
	view.bonus = { text = cfg.DailyAllBonus.text, available = allClaimed and not data.daily.bonusClaimed, claimed = data.daily.bonusClaimed }
	if view.bonus.available then
		view.claimable = view.claimable + 1
	end

	local goals = {}
	for _, tier in ipairs({ "short", "mid", "long" }) do
		for _, g in ipairs(cfg.Goals) do
			if g.tier == tier then
				local value = Logic.statValue(data, cfg, g.stat)
				local claimed = data.goalsClaimed[g.id] == true
				local done = value >= g.target
				if done and not claimed then
					view.claimable = view.claimable + 1
				end
				local text = {}
				if g.reward.coins then text[#text + 1] = g.reward.coins .. " moedas" end
				if g.reward.eggs then text[#text + 1] = g.reward.eggs .. (g.reward.eggs == 1 and " ovo" or " ovos") end
				if g.reward.cosmetic then
					local item = Logic.catalogItem(cfg, g.reward.cosmetic)
					text[#text + 1] = item and item.name or g.reward.cosmetic
				end
				goals[#goals + 1] = {
					id = g.id, tier = tier, text = g.text, progress = math.min(value, g.target), target = g.target,
					reward = table.concat(text, " + "), claimed = claimed, done = done,
				}
			end
		end
	end
	view.goals = goals

	local dex = {}
	for _, id in ipairs(cfg.SpeciesOrder) do
		local sp = cfg.Species[id]
		dex[#dex + 1] = { id = id, name = sp.name, rarity = sp.rarity, desc = sp.desc, discovered = data.discovered[id] == true }
	end
	view.dex = dex

	view.events = { active = Logic.activeEvents(cfg, now), upcoming = Logic.upcomingEvents(cfg, now) }
	view.boost = (data.boost and data.boost.endsAt > now) and { mult = data.boost.mult, endsAt = data.boost.endsAt } or false
	view.hints = Logic.hints(data, cfg, now)
	view.eggCost = Logic.eggCost(data, cfg, now)
	return view
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
	{ "ModuleScript", "Telemetry", [==[
--!nonstrict
-- Camada fina sobre o AnalyticsService: nunca quebra o jogo (tudo em pcall), sem dados pessoais
-- (só nome do evento, números e ids de itens). Config.Analytics.Enabled=false desliga o envio.
local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Telemetry = {}
Telemetry.counts = {} -- contadores locais por evento (depuração; não persistem)

-- Tipo de transação do AnalyticsService por motivo de entrada/saída de moedas.
local TX_TYPE = {
	income = "Gameplay", mission = "Onboarding", quest = "Gameplay", goal = "Gameplay",
	daily = "TimedReward", offline = "TimedReward", egg = "Shop", upgrade = "Shop", shop = "Shop",
}

-- Até 3 campos extras, valores em texto curto.
local function fieldsOf(fields)
	if type(fields) ~= "table" then
		return nil
	end
	local keys = {}
	for k in pairs(fields) do
		keys[#keys + 1] = k
	end
	table.sort(keys)
	local out = {}
	for i = 1, math.min(3, #keys) do
		out[keys[i]] = string.sub(tostring(fields[keys[i]]), 1, 40)
	end
	return out
end

local function bump(name)
	Telemetry.counts[name] = (Telemetry.counts[name] or 0) + 1
end

function Telemetry.event(player, name, value, fields)
	bump(name)
	if Config.Analytics.Debug then
		print("[Telemetry]", name, value, fields)
	end
	if not Config.Analytics.Enabled then
		return
	end
	local ok, err = pcall(function()
		AnalyticsService:LogCustomEvent(player, name, value or 1, fieldsOf(fields))
	end)
	if not ok and Config.Analytics.Debug then
		warn("[Telemetry] LogCustomEvent falhou: " .. tostring(err))
	end
end

function Telemetry.economy(player, flow, reason, amount, balance)
	bump("economy_" .. flow .. "_" .. reason)
	if Config.Analytics.Debug then
		print("[Telemetry] economia", flow, reason, amount, balance)
	end
	if not Config.Analytics.Enabled then
		return
	end
	local ok, err = pcall(function()
		local flowType = flow == "source" and Enum.AnalyticsEconomyFlowType.Source or Enum.AnalyticsEconomyFlowType.Sink
		local txType = Enum.AnalyticsEconomyTransactionType[TX_TYPE[reason] or "Gameplay"]
		AnalyticsService:LogEconomyEvent(player, flowType, "Coins", balance, amount, txType, reason)
	end)
	if not ok and Config.Analytics.Debug then
		warn("[Telemetry] LogEconomyEvent falhou: " .. tostring(err))
	end
end

function Telemetry.funnel(player, funnelName, funnelSessionId, step, stepName)
	bump("funnel_" .. funnelName .. "_" .. stepName)
	if Config.Analytics.Debug then
		print("[Telemetry] funil", funnelName, step, stepName)
	end
	if not Config.Analytics.Enabled then
		return
	end
	local ok, err = pcall(function()
		AnalyticsService:LogFunnelStepEvent(player, funnelName, funnelSessionId, step, stepName)
	end)
	if not ok and Config.Analytics.Debug then
		warn("[Telemetry] LogFunnelStepEvent falhou: " .. tostring(err))
	end
end

return Telemetry
]==] },
	{ "ModuleScript", "MonetizationService", [==[
--!nonstrict
-- Compras com Robux: DESLIGADO por padrão (Config.Monetization.Enabled=false). Com a flag desligada este módulo
-- não toca em MarketplaceService, não registra ProcessReceipt e não vende nada.
-- NÃO TESTADO no Studio. Só ligue depois de o loop estar validado com DataStore real e multiplayer.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Logic = require(Shared:WaitForChild("Logic"))

local MonetizationService = {}
MonetizationService.enabled = false

local function productKeyById(productId)
	for key, p in pairs(Config.Monetization.Products) do
		if p.productId ~= 0 and p.productId == productId then
			return key
		end
	end
	return nil
end

local function passKeyById(passId)
	for key, p in pairs(Config.Monetization.Passes) do
		if p.gamePassId ~= 0 and p.gamePassId == passId then
			return key
		end
	end
	return nil
end

-- deps: { DataService, Telemetry, push }
function MonetizationService.init(deps)
	if not Config.Monetization.Enabled then
		return false
	end
	local MarketplaceService = game:GetService("MarketplaceService")
	MonetizationService.enabled = true

	-- Idempotente: o mesmo PurchaseId nunca concede duas vezes (data.receipts, salvo junto com o inventário).
	-- Só devolve PurchaseGranted depois de o dado estar SALVO; qualquer dúvida => NotProcessedYet (o Roblox repete).
	MarketplaceService.ProcessReceipt = function(info)
		local player = Players:GetPlayerByUserId(info.PlayerId)
		local session = player and deps.DataService.get(player)
		if not player or not session or not session.canSave then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local key = productKeyById(info.ProductId)
		local result = Logic.processReceipt(session.data, Config, tostring(info.PurchaseId), key, os.time())
		if result == "unknown" or result == "invalid" then
			warn("[DinoPark] recibo desconhecido: produto " .. tostring(info.ProductId))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if result == "granted" then
			deps.DataService.markDirty(player)
			deps.Telemetry.event(player, "purchase_granted", info.CurrencySpent or 0, { product = key })
		end
		if session.dirty and not deps.DataService.save(player, true) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		deps.push(player)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		local key = passKeyById(passId)
		local session = deps.DataService.get(player)
		if wasPurchased and key and session and Logic.grantPass(session.data, Config, key) then
			deps.DataService.markDirty(player)
			deps.Telemetry.event(player, "purchase_granted", 1, { pass = key })
			deps.DataService.save(player, true)
			deps.push(player)
		end
	end)
	return true
end

-- Abre a janela de compra do Roblox (a UI só chama isto por ação explícita do jogador).
function MonetizationService.prompt(player, kind, key)
	if not MonetizationService.enabled then
		return false
	end
	local MarketplaceService = game:GetService("MarketplaceService")
	if kind == "product" and Config.Monetization.Products[key] and Config.Monetization.Products[key].productId ~= 0 then
		MarketplaceService:PromptProductPurchase(player, Config.Monetization.Products[key].productId)
		return true
	elseif kind == "pass" and Config.Monetization.Passes[key] and Config.Monetization.Passes[key].gamePassId ~= 0 then
		MarketplaceService:PromptGamePassPurchase(player, Config.Monetization.Passes[key].gamePassId)
		return true
	end
	return false
end

return MonetizationService
]==] },
	{ "ModuleScript", "DataService", [==[
--!nonstrict
-- Persistência com DataStoreService: trava de sessão (UpdateAsync), carga com tentativas, nunca sobrescreve
-- dados válidos com padrões após falha de carga (canSave=false), salvamento com retry/backoff e limite de frequência.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Logic = require(Shared:WaitForChild("Logic"))

local DataService = {}
local sessions = {} -- [Player] = { data=, canSave=, dirty=, lastSave=, isNew=, locked= }

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

-- Tenta reservar o perfil. Devolve "ok", raw | "locked" | "error".
local function claim(player)
	local status, raw = "error", nil
	local ok, err = pcall(function()
		store:UpdateAsync(keyFor(player), function(old)
			local now = os.time()
			if Logic.lockedByOther(old, game.JobId, now, Config.LockSeconds) then
				status = "locked"
				return nil -- cancela a escrita
			end
			status = "ok"
			raw = old
			return Logic.record(old, game.JobId, now, false)
		end)
	end)
	if not ok then
		warn("[DinoPark] erro ao reservar perfil de " .. player.Name .. ": " .. tostring(err))
		return "error"
	end
	return status, raw
end

-- Carrega (yield). Sempre devolve uma sessão. canSave=false se não foi possível ler (nunca salvamos por cima).
-- session.locked=true: dados em uso em outro servidor (o GameService remove o jogador).
function DataService.load(player)
	local now = os.time()
	local raw, status = nil, "error"
	if store then
		for attempt = 1, Config.LockRetries do
			status, raw = claim(player)
			if status == "ok" then
				break
			end
			warn(("[DinoPark] perfil de %s: %s (tentativa %d)"):format(player.Name, status, attempt))
			task.wait(Config.LockRetryWait)
		end
	end
	local loaded = status == "ok"
	local session = {
		data = Logic.migrate(raw, Config, now),
		canSave = loaded,
		dirty = false,
		lastSave = os.clock(),
		isNew = loaded and (raw == nil or raw.schemaVersion == nil),
		locked = status == "locked",
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

-- Uma tentativa de gravação. release=true remove a trava. Cancela se outro servidor assumiu o perfil.
local function writeOnce(player, session, release)
	local lostLock = false
	local ok, err = pcall(function()
		store:UpdateAsync(keyFor(player), function(old)
			local now = os.time()
			if Logic.lockedByOther(old, game.JobId, now, Config.LockSeconds) then
				lostLock = true
				return nil
			end
			session.data.lastSeen = now
			return Logic.record(session.data, game.JobId, now, release)
		end)
	end)
	if not ok then
		return false, tostring(err)
	end
	if lostLock then
		session.canSave = false -- outro servidor tem o perfil: parar de salvar para não duplicar
		return false, "perfil em uso por outro servidor"
	end
	return true
end

-- Salva se necessário. force=true ignora o intervalo mínimo e tenta de novo com backoff.
-- touch=true grava mesmo sem mudanças (renova a trava). release=true libera a trava.
function DataService.save(player, force, touch, release)
	local s = sessions[player]
	if not s or not s.canSave or not store then
		return false
	end
	if not force and not touch and (not s.dirty or os.clock() - s.lastSave < Config.MinSaveGap) then
		return false
	end
	local attempts = force and Config.SaveRetries or 1
	for attempt = 1, attempts do
		local ok, err = writeOnce(player, s, release)
		if ok then
			s.dirty = false
			s.lastSave = os.clock()
			return true
		end
		warn(("[DinoPark] Falha ao salvar %s (tentativa %d): %s"):format(player.Name, attempt, tostring(err)))
		if not s.canSave then
			return false
		end
		if attempt < attempts then
			task.wait(attempt * 1.5)
		end
	end
	return false
end

function DataService.release(player)
	DataService.save(player, true, true, true)
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
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))
local MonetizationService = require(script.Parent:WaitForChild("MonetizationService"))

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
		shop[#shop + 1] = { id = id, name = item.name, kind = item.kind, price = Logic.shopPrice(Config, item, now), basePrice = item.price, owned = data.owned[id] == true }
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
		perTick = Logic.incomePerTick(data, Config, now),
		eggCost = Logic.eggCost(data, Config, now),
		retention = Logic.retentionView(data, Config, now),
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

-- Telemetria de economia: envia ao AnalyticsService só a diferença do livro-razão desde o último envio.
local function flushEconomy(player, session)
	for _, e in ipairs(Logic.ecoDiff(session.ecoSnap, session.data)) do
		Telemetry.economy(player, e.flow, e.reason, e.amount, session.data.coins)
	end
	session.ecoSnap = Logic.ecoSnapshot(session.data)
end

local function reachedSteps(session)
	local set = {}
	for _, f in ipairs(Logic.onboardingFlags(session.data)) do
		set[f.name] = f.reached
	end
	return set
end

-- Eventos de ação (funil, compras, falta de moedas). Sem dados pessoais.
local function logAction(player, session, action, payload, success, message, extra, before)
	if not success then
		if message == "Moedas insuficientes." then
			Telemetry.event(player, "insufficient_coins", 1, { action = action })
		end
		return
	end
	local data = session.data
	if action == "buyEgg" then
		Telemetry.event(player, "egg_bought", data.stats.eggsBought, { cost = Logic.eggCost(data, Config) })
	elseif action == "collect" then
		Telemetry.event(player, "dino_hatched", data.hatched, { species = extra })
	elseif action == "buyUpgrade" then
		Telemetry.event(player, "upgrade_bought", data.stats.upgradesBought, { key = payload.key, level = data.upgrades[payload.key] })
	elseif action == "buyShop" then
		Telemetry.event(player, "shop_buy", data.stats.shopBuys, { item = payload.id })
	elseif action == "claimDaily" then
		Telemetry.event(player, "daily_claim", data.login.totalClaims, { day = extra })
	elseif action == "claimQuest" then
		Telemetry.event(player, "quest_claim", 1, { quest = payload.id })
	elseif action == "claimQuestBonus" then
		Telemetry.event(player, "quest_bonus_claim", 1)
	elseif action == "claimGoal" then
		Telemetry.event(player, "goal_claim", 1, { goal = payload.id })
	end
	-- funil de onboarding: registra só marcos alcançados NESTA ação
	local after = reachedSteps(session)
	for i, f in ipairs(Logic.onboardingFlags(data)) do
		if after[f.name] and not before[f.name] then
			Telemetry.funnel(player, "onboarding", session.funnelId, i, f.name)
		end
	end
	flushEconomy(player, session)
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
	local ok, msg = Logic.buyEgg(session.data, Config, os.time())
	if ok then commit(player, session, false) end
	return ok, msg
end

function handlers.incubate(player, session)
	local ok, msg = Logic.startIncubate(session.data, Config, os.time())
	if ok then commit(player, session, false) end
	return ok, msg
end

function handlers.collect(player, session)
	local ok, msg, species = Logic.collect(session.data, Config, os.time(), function()
		return rng:NextNumber()
	end)
	if ok then commit(player, session, false) end
	return ok, msg, species
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
	local now = os.time()
	local stock = Logic.shopStock(Config, now)
	local ok, msg = Logic.buyShop(session.data, Config, payload and payload.id, stock, now)
	if ok then commit(player, session, true) end
	return ok, msg
end

function handlers.claimDaily(player, session)
	local ok, msg, cycle = Logic.claimDaily(session.data, Config, os.time())
	if ok then commit(player, session, true) end
	return ok, msg, cycle
end

function handlers.claimQuest(player, session, payload)
	local ok, msg = Logic.claimQuest(session.data, Config, payload and payload.id, os.time())
	if ok then commit(player, session, false) end
	return ok, msg
end

function handlers.claimQuestBonus(player, session)
	local ok, msg = Logic.claimQuestBonus(session.data, Config, os.time())
	if ok then commit(player, session, false) end
	return ok, msg
end

function handlers.claimGoal(player, session, payload)
	local ok, msg = Logic.claimGoal(session.data, Config, payload and payload.id)
	if ok then commit(player, session, true) end
	return ok, msg
end

-- O cliente só pode reportar eventos de uma lista fechada (Config.ClientEvents); o resto é ignorado.
function handlers.track(player, session, payload)
	local name = payload and payload.name
	if type(name) == "string" and Config.ClientEvents[name] then
		Telemetry.event(player, name, 1)
	end
	return true, ""
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
	local before = reachedSteps(session)
	local ok, success, message, extra = pcall(handler, player, session, payload)
	if not ok then
		warn("[DinoPark] erro em '" .. action .. "': " .. tostring(success))
		return { ok = false, message = "Erro interno." }
	end
	if action == "getState" then
		push(player)
	end
	logAction(player, session, action, payload or {}, success == true, message, extra, before)
	return { ok = success == true, message = message or "" }
end

local function onPlayerAdded(player)
	local session = DataService.load(player)
	if not player.Parent then
		DataService.release(player)
		return
	end
	if session.locked then
		DataService.release(player) -- não grava: o perfil pertence a outro servidor
		player:Kick("Seus dados estão em uso em outro servidor. Tente entrar de novo em alguns minutos.")
		return
	end
	local index = ParkService.claim(player)
	if not index then
		player:Kick("Servidor cheio: todos os parques estão ocupados.")
		return
	end
	local data = session.data
	session.joinedAt = os.time()
	session.funnelId = ("%d_%d"):format(player.UserId, session.joinedAt)
	session.ecoSnap = Logic.ecoSnapshot(data)
	-- Ganhos offline: calculado no servidor com limite configurável.
	local earned, elapsed = Logic.offlineEarnings(data, Config, os.time())
	if earned > 0 and not session.isNew then
		Logic.earn(data, earned, "offline")
		DataService.markDirty(player)
		session.welcome = ("Bem-vindo de volta! Seus visitantes renderam %d moedas em %d min."):format(earned, math.floor(elapsed / 60))
	end
	data.lastSeen = os.time()
	local info = Logic.startSession(data, Config, os.time())
	DataService.markDirty(player)
	Telemetry.event(player, "session_start", info.daysSinceFirst, { sessions = info.sessions })
	if info.isNewDay and info.daysSinceFirst > 0 then
		Telemetry.event(player, "return_day", info.daysSinceFirst)
	end
	if session.isNew then
		Telemetry.funnel(player, "onboarding", session.funnelId, 0, "first_join")
	end
	flushEconomy(player, session)
	ParkService.refresh(player, data)
	push(player)
end

local function onPlayerRemoving(player)
	local session = DataService.get(player)
	if session and session.ecoSnap then
		flushEconomy(player, session)
		Telemetry.event(player, "session_end", os.time() - (session.joinedAt or os.time()))
	end
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
	MonetizationService.init({ DataService = DataService, Telemetry = Telemetry, push = push }) -- no-op com a flag desligada

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
				local tick = Logic.incomePerTick(session.data, Config, os.time())
				if tick > 0 then
					Logic.earn(session.data, tick, "income")
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
				for player, session in pairs(DataService.sessions()) do
					if session.ecoSnap then
						flushEconomy(player, session)
					end
					-- touch=true: grava mesmo sem mudanças para renovar a trava de sessão
					task.spawn(DataService.save, player, false, true, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		-- salva todos em paralelo, com espera limitada (o Roblox encerra o servidor após ~30 s)
		local pending = 0
		for player in pairs(DataService.sessions()) do
			pending = pending + 1
			task.spawn(function()
				DataService.save(player, true, true, true)
				pending = pending - 1
			end)
		end
		local waited = 0
		while pending > 0 and waited < Config.ShutdownMaxWait do
			task.wait(0.5)
			waited = waited + 0.5
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
	local s = math.clamp(math.min(v.X / 900, v.Y / 560), 0.6, 1.25)
	scale.Scale = s
	-- o UIScale também escala o próprio Root: compensa para ele continuar ocupando a tela inteira
	root.Size = UDim2.fromScale(1 / s, 1 / s)
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
hud.Size = UDim2.fromOffset(300, 58)
hud.Parent = root
corner(hud, 10)
local coinsLabel = label(hud, "Moedas: ...", 22, COLORS.gold, { Position = UDim2.fromOffset(12, 4), Size = UDim2.fromOffset(276, 28), Font = Enum.Font.GothamBold })
local rateLabel = label(hud, "", 14, COLORS.muted, { Position = UDim2.fromOffset(12, 32), Size = UDim2.fromOffset(276, 20) })

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
	textRow(("Você tem %d ovo(s). Cada ovo custa %d moedas."):format(state.eggs, (state.eggCost or Config.EggCost)), COLORS.text, 36)
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
	label(buy, ("Comprar ovo - %d moedas"):format((state.eggCost or Config.EggCost)), 16, COLORS.text, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -150, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
	local b = button(buy, "Comprar", state.coins >= (state.eggCost or Config.EggCost) and COLORS.button or COLORS.buttonOff, UDim2.fromOffset(110, 38))
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

local rc = { "LocalScript", "RetentionClient", [==[
--!nonstrict
-- Painel "Hoje" (retenção): recompensa diária, missões, metas, coleção, eventos e guia da loja.
-- Só mostra o estado calculado pelo servidor (s.retention) e pede ações; não decide nada.
-- Fica escondido até o primeiro ovo chocar, para não competir com o tutorial.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Logic = require(Shared:WaitForChild("Logic"))

local remotes = ReplicatedStorage:WaitForChild("DinoParkRemotes")
local requestRF = remotes:WaitForChild("Request")
local stateRE = remotes:WaitForChild("State")

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local C = {
	bg = Color3.fromRGB(34, 52, 40), panel = Color3.fromRGB(48, 72, 56), row = Color3.fromRGB(62, 90, 70),
	button = Color3.fromRGB(88, 170, 96), off = Color3.fromRGB(110, 120, 112), danger = Color3.fromRGB(210, 90, 80),
	text = Color3.fromRGB(245, 250, 240), muted = Color3.fromRGB(190, 205, 190), gold = Color3.fromRGB(255, 214, 90),
	tab = Color3.fromRGB(70, 104, 80), tabOn = Color3.fromRGB(120, 190, 120),
}

local s = nil -- último estado do servidor
local current = "daily"
local busy = false
local live = {} -- funções de contagem regressiva

local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = inst
end

local function label(parent, text, size, color, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamMedium
	l.TextSize = size or 14
	l.TextColor3 = color or C.text
	l.Text = text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	l.Parent = parent
	return l
end

local function button(parent, text, color, size)
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = color or C.button
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.TextColor3 = C.text
	b.Text = text
	b.Size = size or UDim2.fromOffset(100, 32)
	b.Parent = parent
	corner(b, 8)
	return b
end

local gui = Instance.new("ScreenGui")
gui.Name = "DinoParkToday"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local root = Instance.new("Frame")
root.BackgroundTransparency = 1
root.Size = UDim2.fromScale(1, 1)
root.Parent = gui
local scale = Instance.new("UIScale")
scale.Parent = root
local function updateScale()
	local v = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1000, 600)
	scale.Scale = math.clamp(math.min(v.X / 900, v.Y / 560), 0.6, 1.25)
	root.Size = UDim2.fromScale(1 / scale.Scale, 1 / scale.Scale)
end
updateScale()
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

local openBtn = button(root, "Hoje", C.button, UDim2.fromOffset(84, 40))
openBtn.Position = UDim2.fromOffset(12, 78)
openBtn.Visible = false
local badge = label(openBtn, "", 12, C.bg, {
	BackgroundTransparency = 0, BackgroundColor3 = C.gold, Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -14, 0, -8),
	TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBold, Visible = false,
})
corner(badge, 11)

local panel = Instance.new("Frame")
panel.BackgroundColor3 = C.panel
panel.Position = UDim2.fromOffset(12, 124)
panel.Size = UDim2.fromOffset(450, 340)
panel.Visible = false
panel.Parent = root
corner(panel, 14)
label(panel, "Hoje no parque", 20, C.text, { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -70, 0, 28), Font = Enum.Font.GothamBold })
local closeBtn = button(panel, "X", C.danger, UDim2.fromOffset(30, 30))
closeBtn.Position = UDim2.new(1, -40, 0, 8)

local tabBar = Instance.new("Frame")
tabBar.BackgroundTransparency = 1
tabBar.Position = UDim2.fromOffset(10, 42)
tabBar.Size = UDim2.new(1, -20, 0, 30)
tabBar.Parent = panel
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 4)
tabLayout.Parent = tabBar

local scroll = Instance.new("ScrollingFrame")
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.Position = UDim2.fromOffset(10, 78)
scroll.Size = UDim2.new(1, -20, 1, -88)
scroll.ScrollBarThickness = 6
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new()
scroll.Parent = panel
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 6)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = scroll

local order = 0
local function row(height)
	order = order + 1
	local f = Instance.new("Frame")
	f.BackgroundColor3 = C.row
	f.Size = UDim2.new(1, -8, 0, height)
	f.LayoutOrder = order
	f.Parent = scroll
	corner(f, 8)
	return f
end

local function note(text, height, color)
	local f = row(height or 30)
	label(f, text, 13, color or C.muted, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
	return f
end

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return ("%d:%02d:%02d"):format(math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60)
end

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
		if ok and type(result) == "table" and result.message and result.message ~= "" and result.ok then
			note(result.message, 30, C.gold) -- confirmação discreta; o servidor reenvia o estado logo em seguida
		end
	end)
end

-- Linha com texto, subtexto e botão opcional à direita.
local function item(title, sub, btnText, btnOn, onClick, titleColor)
	local f = row(54)
	label(f, title, 15, titleColor or C.text, { Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -120, 0, 22), Font = Enum.Font.GothamBold })
	label(f, sub, 12, C.muted, { Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -120, 0, 26) })
	if btnText then
		local b = button(f, btnText, btnOn and C.button or C.off, UDim2.fromOffset(96, 32))
		b.Position = UDim2.new(1, -104, 0.5, -16)
		if btnOn and onClick then
			b.MouseButton1Click:Connect(onClick)
		end
	end
	return f
end

local R = {}

function R.daily(r)
	note("Calendário de 7 recompensas. Sem pressa: se você faltar um dia, continua de onde parou.", 36)
	for i, d in ipairs(r.daily.days) do
		local state = d.claimed and "recebido" or (d.next and (r.daily.canClaim and "disponível agora" or "amanhã") or "")
		item(("Dia %d"):format(i), d.label, nil, false, nil, d.claimed and C.muted or (d.next and C.gold or C.text))
		local last = nil
		for _, child in ipairs(scroll:GetChildren()) do
			if child:IsA("Frame") then last = child end
		end
		if state ~= "" and last then
			label(last, state, 12, d.next and C.gold or C.muted, { Position = UDim2.new(1, -110, 0, 4), Size = UDim2.fromOffset(100, 20), TextXAlignment = Enum.TextXAlignment.Right })
		end
	end
	local f = row(46)
	if r.daily.canClaim then
		local b = button(f, "Receber recompensa de hoje", C.button, UDim2.new(1, -20, 0, 34))
		b.Position = UDim2.fromOffset(10, 6)
		b.MouseButton1Click:Connect(function() request("claimDaily") end)
	else
		local l = label(f, "", 14, C.muted, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
		live[#live + 1] = function() l.Text = "Hoje já foi recebido. Próxima em " .. clock(r.resetsAt - Workspace:GetServerTimeNow()) end
	end
	for _, h in ipairs(r.hints) do
		note("Dica: " .. h, 30, C.text)
	end
end

function R.quests(r)
	local f = note("", 30)
	local l = f:FindFirstChildOfClass("TextLabel")
	live[#live + 1] = function() l.Text = "Missões do dia (novas em " .. clock(r.resetsAt - Workspace:GetServerTimeNow()) .. ")" end
	for _, q in ipairs(r.quests) do
		local text = q.claimed and "Recebido" or (q.done and "Receber" or "Em andamento")
		local id = q.id
		item(q.text, ("%d/%d  -  recompensa: %s"):format(q.progress, q.target, q.reward), text, q.done and not q.claimed, function() request("claimQuest", { id = id }) end)
	end
	item(r.bonus.text, "Complete e receba as 3 missões do dia.", r.bonus.claimed and "Recebido" or "Receber", r.bonus.available, function() request("claimQuestBonus") end, C.gold)
end

function R.goals(r)
	note("Metas para jogar no seu ritmo. Nada expira e todas dão a recompensa uma única vez.", 36)
	local tier = nil
	for _, g in ipairs(r.goals) do
		if g.tier ~= tier then
			tier = g.tier
			note(Config.GoalTierNames[tier], 24, C.gold)
		end
		local id = g.id
		item(g.text, ("%d/%d  -  recompensa: %s"):format(g.progress, g.target, g.reward), g.claimed and "Recebido" or (g.done and "Receber" or "Em andamento"), g.done and not g.claimed, function() request("claimGoal", { id = id }) end)
	end
end

function R.dex(r)
	local n = 0
	for _, d in ipairs(r.dex) do
		if d.discovered then n = n + 1 end
	end
	note(("Coleção: %d de %d espécies descobertas. Novas espécies chegam em atualizações."):format(n, #r.dex), 36)
	for _, d in ipairs(r.dex) do
		if d.discovered then
			item(d.name .. "  (" .. d.rarity .. ")", d.desc, nil, false, nil, Config.RarityColors[d.rarity])
		else
			item("???  (" .. d.rarity .. ")", "Ainda não descoberta. Choque ovos para encontrá-la.", nil, false, nil, C.muted)
		end
	end
end

function R.events(r)
	note("O calendário é fixo, semana após semana. Nenhum evento é exclusivo: sempre volta.", 36)
	if r.boost then
		local f = note("", 30, C.gold)
		local l = f:FindFirstChildOfClass("TextLabel")
		live[#live + 1] = function() l.Text = ("Impulso de visitantes x%.1f ativo: %s"):format(r.boost.mult, clock(r.boost.endsAt - Workspace:GetServerTimeNow())) end
	end
	for _, ev in ipairs(r.events.active) do
		local f = item("AGORA: " .. ev.name, ev.desc, nil, false, nil, C.gold)
		local l = label(f, "", 12, C.gold, { Position = UDim2.new(1, -150, 0, 4), Size = UDim2.fromOffset(140, 20), TextXAlignment = Enum.TextXAlignment.Right })
		live[#live + 1] = function() l.Text = "termina em " .. clock(ev.endsAt - Workspace:GetServerTimeNow()) end
	end
	for _, ev in ipairs(r.events.upcoming) do
		local f = item("Em breve: " .. ev.name, ev.desc)
		local l = label(f, "", 12, C.muted, { Position = UDim2.new(1, -150, 0, 4), Size = UDim2.fromOffset(140, 20), TextXAlignment = Enum.TextXAlignment.Right })
		live[#live + 1] = function() l.Text = "começa em " .. clock(ev.startsAt - Workspace:GetServerTimeNow()) end
	end
	local days = {}
	for _, ev in ipairs(Config.Events) do
		local names = {}
		for _, d in ipairs(ev.days) do names[#names + 1] = Config.WeekdayNames[d] end
		days[#days + 1] = ev.name .. ": " .. table.concat(names, " e ")
	end
	note("Semana: " .. table.concat(days, "  |  "), 56)
end

function R.guide(_)
	local g = Logic.storeGuide(Config)
	note("O que cada compra dá, quanto dura e se pode repetir. Tudo se compra jogando, com moedas.", 36)
	for _, e in ipairs(g.coins) do
		item(e.name .. "  -  " .. e.price, e.grants .. "  Duração: " .. e.duration .. ". " .. e.repeatable .. ".")
	end
	if g.robuxEnabled then
		for _, e in ipairs(g.robux) do
			item(e.name .. "  -  " .. e.price, e.grants .. "  Duração: " .. e.duration .. ". " .. e.repeatable .. ".")
		end
	else
		note("Não há compras com Robux neste jogo por enquanto. Tudo é alcançável jogando.", 36, C.gold)
	end
end

local TABS = {
	{ "daily", "Diário" }, { "quests", "Missões" }, { "goals", "Metas" }, { "dex", "Coleção" }, { "events", "Eventos" }, { "guide", "Loja" },
}
local tabButtons = {}
for _, t in ipairs(TABS) do
	local b = button(tabBar, t[2], C.tab, UDim2.fromOffset(68, 28))
	b.TextSize = 12
	tabButtons[t[1]] = b
end

local function render()
	if not s or not s.retention then
		return
	end
	local keep = scroll.CanvasPosition
	for _, child in ipairs(scroll:GetChildren()) do
		if not child:IsA("UIListLayout") then child:Destroy() end
	end
	live = {}
	order = 0
	for key, b in pairs(tabButtons) do
		b.BackgroundColor3 = key == current and C.tabOn or C.tab
	end
	R[current](s.retention)
	scroll.CanvasPosition = keep
end

for key, b in pairs(tabButtons) do
	b.MouseButton1Click:Connect(function()
		current = key
		scroll.CanvasPosition = Vector2.new(0, 0)
		render()
		if key == "guide" then
			request("track", { name = "store_guide_view" })
		end
	end)
end

openBtn.MouseButton1Click:Connect(function()
	panel.Visible = not panel.Visible
	if panel.Visible then
		render()
		request("track", { name = "today_view" })
	end
end)
closeBtn.MouseButton1Click:Connect(function()
	panel.Visible = false
end)

stateRE.OnClientEvent:Connect(function(state)
	s = state
	openBtn.Visible = (s.hatched or 0) >= 1 or s.tutorialDismissed == true
	local n = s.retention and s.retention.claimable or 0
	badge.Visible = n > 0
	badge.Text = tostring(n)
	if panel.Visible then
		render()
	end
end)

task.spawn(function()
	while true do
		task.wait(0.5)
		if panel.Visible then
			for _, fn in ipairs(live) do
				fn()
			end
		end
	end
end)
]==] }
make(rc[1], rc[2], rc[3], SPS)

print("[DinoPark] Parte 2 (scripts) instalada. Salve o lugar e pressione Play (F5).")
