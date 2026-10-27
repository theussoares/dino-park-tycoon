--!nonstrict
-- Configuração central do Dino Park Tycoon. Todos os números abaixo são HIPÓTESES de balanceamento
-- a testar com jogadores reais, não verdades de mercado.
local Config = {}

Config.SchemaVersion = 1
Config.DataStoreName = "DinoParkTycoon_v1"
-- Limites do mapa (servidor devolve ao spawn quem passar deles ou cair abaixo de VoidY)
Config.MapHalf = 132 -- muros em ±130; encostado no muro o jogador fica em ≈±129
Config.VoidY = -6
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
