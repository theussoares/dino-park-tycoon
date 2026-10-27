--!nonstrict
-- Autoridade do jogo: remotes validados, ações, renda periódica, ganhos offline e estado enviado ao cliente.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
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
	local ok, msg = Logic.place(session.data, Config, payload and payload.id, os.time())
	if ok then commit(player, session, true) end
	return ok, msg
end

function handlers.remove(player, session, payload)
	local ok, msg = Logic.remove(session.data, Config, payload and payload.id)
	if ok then commit(player, session, true) end
	return ok, msg
end

function handlers.buyUpgrade(player, session, payload)
	local ok, msg = Logic.buyUpgrade(session.data, Config, payload and payload.key, os.time())
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

	-- Rede de segurança: quem sair dos limites ou cair no vazio volta ao spawn
	task.spawn(function()
		local spawnPart = Workspace:FindFirstChild("ParkSpawn", true)
		while true do
			task.wait(0.5)
			spawnPart = (spawnPart and spawnPart.Parent) and spawnPart or Workspace:FindFirstChild("ParkSpawn", true)
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				local hrp = character and character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local p = hrp.Position
					if math.abs(p.X) > Config.MapHalf or math.abs(p.Z) > Config.MapHalf or p.Y < Config.VoidY then
						local target = spawnPart and (spawnPart.CFrame + Vector3.new(0, 4, 0)) or CFrame.new(0, 10, 85)
						hrp.AssemblyLinearVelocity = Vector3.zero
						character:PivotTo(target)
					end
				end
			end
		end
	end)

	-- Renda dos visitantes
	task.spawn(function()
		while true do
			task.wait(Config.IncomeInterval)
			for player, session in pairs(DataService.sessions()) do
				Logic.rollDay(session.data, Config, os.time()) -- fecha o dia antes de somar a renda (base das missões)
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
