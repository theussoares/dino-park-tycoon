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
