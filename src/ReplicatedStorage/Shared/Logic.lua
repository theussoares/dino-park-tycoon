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
