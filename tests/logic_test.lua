-- Testes da lógica pura (Config + Logic) executados com Lua 5.3 (fengari). Não testam APIs do Roblox.
Color3 = { fromRGB = function(r, g, b) return { r, g, b } end }
local Config = assert(load(SRC_CONFIG, "Config"))()
local Logic = assert(load(SRC_LOGIC, "Logic"))()

local passed, failed = 0, 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then passed = passed + 1; print("PASS  " .. name)
	else failed = failed + 1; print("FAIL  " .. name .. " -> " .. tostring(err)) end
end
local function eq(a, b, msg) if a ~= b then error((msg or "") .. " esperado " .. tostring(b) .. ", obtido " .. tostring(a), 2) end end
local NOW = 1800000000

local function withDino(species, n)
	local d = Logic.newData(Config, NOW)
	for i = 1, n or 1 do
		d.dinos[#d.dinos + 1] = { id = "d" .. d.nextId, species = species }
		d.nextId = d.nextId + 1
	end
	return d
end

test("newData: moedas e ovo iniciais", function()
	local d = Logic.newData(Config, NOW)
	eq(d.coins, 100); eq(d.eggs, 1); eq(#d.dinos, 0); eq(Logic.slots(d, Config), 1)
end)

test("buyEgg: debita e falha sem saldo", function()
	local d = Logic.newData(Config, NOW)
	local ok = Logic.buyEgg(d, Config); eq(ok, true); eq(d.coins, 50); eq(d.eggs, 2)
	ok = Logic.buyEgg(d, Config); eq(ok, true); eq(d.coins, 0)
	ok = Logic.buyEgg(d, Config); eq(ok, false); eq(d.coins, 0, "saldo nunca negativo")
end)

test("incubar: exige ovo, não duplica, define readyAt", function()
	local d = Logic.newData(Config, NOW)
	eq((Logic.startIncubate(d, Config, NOW)), true); eq(d.eggs, 0); eq(d.incubating.readyAt, NOW + 12)
	eq((Logic.startIncubate(d, Config, NOW)), false)
	local e = Logic.newData(Config, NOW); e.eggs = 0
	eq((Logic.startIncubate(e, Config, NOW)), false)
end)

test("coletar: só após o tempo; primeiro é Leafling; depois sorteio", function()
	local d = Logic.newData(Config, NOW)
	Logic.startIncubate(d, Config, NOW)
	eq((Logic.collect(d, Config, NOW + 5, function() return 0.99 end)), false)
	local ok, _, sp = Logic.collect(d, Config, NOW + 12, function() return 0.99 end)
	eq(ok, true); eq(sp, "leafling", "primeiro ovo"); eq(d.hatched, 1); eq(d.incubating, nil); eq(#d.dinos, 1)
	d.eggs = 1; Logic.startIncubate(d, Config, NOW)
	local _, _, sp2 = Logic.collect(d, Config, NOW + 100, function() return 0.99 end)
	eq(sp2, "embercrest"); eq(d.dinos[2].id, "d2")
end)

test("rollSpecies: faixas ponderadas e soma 100%", function()
	local function r(v) return Logic.rollSpecies(Config, function() return v end) end
	eq(r(0), "leafling"); eq(r(0.69), "leafling"); eq(r(0.71), "pebbleback"); eq(r(0.94), "pebbleback"); eq(r(0.96), "embercrest"); eq(r(0.9999), "embercrest")
	local total = 0
	for _, o in ipairs(Logic.odds(Config)) do total = total + o.percent end
	eq(math.floor(total + 0.5), 100)
end)

test("colocar/guardar: respeita habitats e propriedade", function()
	local d = withDino("leafling", 2)
	eq((Logic.place(d, Config, "d1")), true)
	eq((Logic.place(d, Config, "d1")), false, "já colocado")
	eq((Logic.place(d, Config, "d2")), false, "sem habitat livre")
	eq((Logic.place(d, Config, "dX")), false, "não possui")
	eq((Logic.place(d, Config, 42)), false, "tipo inválido")
	eq((Logic.place(d, Config, string.rep("a", 40))), false, "id longo")
	d.coins = 1000
	eq((Logic.buyUpgrade(d, Config, "slots")), true)
	eq((Logic.place(d, Config, "d2")), true)
	eq((Logic.remove(d, Config, "d1")), true); eq(#d.placed, 1)
	eq((Logic.remove(d, Config, "d1")), false)
end)

test("renda: base, melhoria de visitantes e arredondamento", function()
	local d = withDino("leafling", 1); Logic.place(d, Config, "d1")
	eq(Logic.incomePerTick(d, Config), 2)
	d.upgrades.income = 2
	eq(Logic.incomePerTick(d, Config), 3)
	local e = withDino("embercrest", 1); Logic.place(e, Config, "d1")
	eq(Logic.incomePerTick(e, Config), 12)
	eq(Logic.incomePerTick(Logic.newData(Config, NOW), Config), 0)
end)

test("offline: fórmula, teto de 8h, tempo inválido", function()
	local d = withDino("leafling", 1); Logic.place(d, Config, "d1")
	d.lastSeen = NOW - 100
	local earned, el = Logic.offlineEarnings(d, Config, NOW)
	eq(earned, 20); eq(el, 100)
	d.lastSeen = NOW - 999999
	earned, el = Logic.offlineEarnings(d, Config, NOW)
	eq(el, 8 * 3600); eq(earned, 5760)
	d.lastSeen = NOW + 500
	eq((Logic.offlineEarnings(d, Config, NOW)), 0, "relógio no futuro")
	d.lastSeen = 0 / 0
	eq((Logic.offlineEarnings(d, Config, NOW)), 0, "NaN")
end)

test("loja: determinística, 4 itens únicos, rotaciona", function()
	local s1, n1 = Logic.shopStock(Config, NOW)
	local s2, n2 = Logic.shopStock(Config, NOW + 10)
	eq(#s1, 4); eq(table.concat(s1, ","), table.concat(s2, ",")); eq(n1, n2)
	eq(n1 % 1800, 0); eq(n1 > NOW, true)
	local seen = {}
	for _, id in ipairs(s1) do eq(seen[id], nil, "repetido " .. id); seen[id] = true end
	local different = false
	for k = 1, 10 do
		local s3 = Logic.shopStock(Config, NOW + k * 1800)
		if table.concat(s3, ",") ~= table.concat(s1, ",") then different = true end
	end
	eq(different, true, "estoque muda entre janelas")
end)

test("comprar na loja: valida estoque, posse, saldo; cerca equipa", function()
	local d = Logic.newData(Config, NOW)
	local stock = { "lamp", "fence_candy" }
	eq((Logic.buyShop(d, Config, "fountain", stock)), false, "fora de estoque")
	eq((Logic.buyShop(d, Config, 5, stock)), false, "tipo inválido")
	eq((Logic.buyShop(d, Config, "lamp", stock)), true); eq(d.coins, 40); eq(d.owned.lamp, true)
	eq((Logic.buyShop(d, Config, "lamp", stock)), false, "já possui")
	eq((Logic.buyShop(d, Config, "fence_candy", stock)), false, "sem saldo"); eq(d.coins, 40)
	d.coins = 500
	eq((Logic.buyShop(d, Config, "fence_candy", stock)), true); eq(d.fence, "fence_candy")
end)

test("melhorias: custos, níveis e máximo", function()
	local d = Logic.newData(Config, NOW); d.coins = 100000
	eq(Logic.upgradeCost(d, Config, "income"), 100)
	for i = 1, 5 do eq((Logic.buyUpgrade(d, Config, "income")), true) end
	eq((Logic.buyUpgrade(d, Config, "income")), false, "máximo"); eq(Logic.upgradeCost(d, Config, "income"), nil)
	eq((Logic.buyUpgrade(d, Config, "nope")), false)
	eq(d.coins, 100000 - (100 + 250 + 500 + 1000 + 2000))
	d.upgrades.incubator = 3
	eq(Logic.incubateSeconds(d, Config), 3)
end)

test("missões: pagam uma única vez", function()
	local d = withDino("leafling", 1)
	d.hatched = 1
	local done = Logic.checkMissions(d, Config); eq(#done, 1); eq(d.coins, 150)
	eq(#Logic.checkMissions(d, Config), 0)
	Logic.place(d, Config, "d1"); eq(#Logic.checkMissions(d, Config), 1); eq(d.coins, 225)
end)

test("migrate: sanitiza dados corrompidos", function()
	local d = Logic.migrate("lixo", Config, NOW); eq(d.coins, 100)
	local raw = {
		coins = -50, eggs = 3.7, lastSeen = NOW + 9999, fence = "hack", owned = { lamp = true, hax = true },
		dinos = { { id = "d1", species = "leafling" }, { id = "d1", species = "leafling" }, { id = "d2", species = "trex" }, { id = 5 } },
		placed = { "d1", "d1", "zz" }, upgrades = { slots = 99, income = -3 },
		incubating = { startedAt = "x", readyAt = NOW + 5 },
	}
	d = Logic.migrate(raw, Config, NOW)
	eq(d.coins, 0); eq(d.eggs, 3); eq(d.lastSeen, NOW); eq(d.fence, "wood")
	eq(d.owned.lamp, true); eq(d.owned.hax, nil)
	eq(#d.dinos, 1); eq(#d.placed, 1); eq(d.upgrades.slots, 3); eq(d.upgrades.income, 0)
	eq(d.incubating.readyAt, NOW + 5)
end)

test("trava de sessão: outro servidor, expiração e liberação", function()
	local rec = Logic.record({ coins = 5 }, "A", 1000, false)
	eq(rec._lock.jobId, "A"); eq(rec.coins, 5)
	eq(Logic.lockedByOther(rec, "A", 1010, 300), false)
	eq(Logic.lockedByOther(rec, "B", 1010, 300), true)
	eq(Logic.lockedByOther(rec, "B", 1400, 300), false)
	eq(Logic.lockedByOther(nil, "B", 1010, 300), false)
	eq(Logic.lockedByOther({ _lock = "x" }, "B", 1010, 300), false)
	local rel = Logic.record(rec, "A", 1020, true)
	eq(rel._lock, nil); eq(Logic.lockedByOther(rel, "B", 1021, 300), false)
	eq(rec._lock.jobId, "A") -- original não é alterado
	local d = Logic.migrate(rec, Config, 1100); eq(d._lock, nil)
end)

test("currentGoal: segue a ordem das missões; nil quando todas concluídas", function()
	local v = { missions = { hatch = false, place = false, upgrade = false } }
	eq(Logic.currentGoal(v, Config).id, "hatch")
	v.missions.hatch = true
	eq(Logic.currentGoal(v, Config).id, "place"); eq(Logic.currentGoal(v, Config).reward, 75)
	v.missions.place = true; v.missions.upgrade = true
	eq(Logic.currentGoal(v, Config), nil)
end)

test("nextUpgrade: menor custo entre os não máximos; nil se todas no máximo", function()
	local v = { upgrades = { { key = "slots", level = 0, cost = 150 }, { key = "income", level = 0, cost = 100 }, { key = "incubator", level = 3, cost = false } } }
	eq(Logic.nextUpgrade(v).key, "income")
	v.upgrades[1].cost = false; v.upgrades[2].cost = false
	eq(Logic.nextUpgrade(v), nil)
end)

-- ===== Retenção, economia e monetização (schema v2) =====
local DAY = 86400
local MON = 1793016000 -- segunda-feira 2026-10-26 12:00 UTC (09:00 em Brasília)

local function placed(d, species)
	d.dinos[#d.dinos + 1] = { id = "d" .. d.nextId, species = species }
	d.placed[#d.placed + 1] = "d" .. d.nextId
	d.nextId = d.nextId + 1
	d.discovered[species] = true
end

test("schema v2: novo save tem campos; save v1 migra sem perder progresso", function()
	eq(Config.SchemaVersion, 2)
	local d = Logic.newData(Config, NOW)
	eq(d.schemaVersion, 2); eq(d.login.cycle, 0); eq(d.stats.coinsEarned, 0)
	local v1 = { schemaVersion = 1, coins = 321, eggs = 2, hatched = 4, nextId = 3,
		dinos = { { id = "d1", species = "leafling" }, { id = "d2", species = "embercrest" } }, placed = { "d1" },
		upgrades = { slots = 1, income = 2, incubator = 0 }, owned = { lamp = true }, fence = "wood", missions = { hatch = true } }
	local m = Logic.migrate(v1, Config, NOW)
	eq(m.coins, 321); eq(m.hatched, 4); eq(m.schemaVersion, 2); eq(m.upgrades.income, 2); eq(m.owned.lamp, true)
	eq(m.discovered.leafling, true); eq(m.discovered.embercrest, true); eq(m.discovered.pebbleback, nil, "só o que possui")
	eq(m.login.sessions, 0); eq(#m.dinos, 2)
end)

test("migrate v2: sanitiza campos novos (recibos, boost, ciclo, metas inventadas)", function()
	local m = Logic.migrate({
		login = { cycle = 99, totalClaims = -5, firstDay = "x", lastDay = 1e9 },
		goalsClaimed = { g_hatch3 = true, hacker = true }, receipts = { a = 1, [5] = 2, b = "x" },
		boost = { mult = 100, endsAt = 1e15 }, passes = { founder = true, fake = true },
		stats = { coinsEarned = -1, eggsBought = 1e20 }, discovered = { leafling = true, trex = true },
		eco = { src = { income = 50, ["x"] = "bad" } },
	}, Config, NOW)
	eq(m.login.cycle, 6); eq(m.login.totalClaims, 0); eq(m.login.firstDay, 0); eq(m.login.lastDay, 1e6)
	eq(m.goalsClaimed.g_hatch3, true); eq(m.goalsClaimed.hacker, nil)
	eq(m.receipts.a, 1); eq(m.receipts[5], nil); eq(m.receipts.b, nil)
	eq(m.boost.mult, 3); eq(m.boost.endsAt, NOW + Config.MaxBoostSeconds)
	eq(m.passes.founder, true); eq(m.passes.fake, nil)
	eq(m.stats.coinsEarned, 0); eq(m.stats.eggsBought, 1e12)
	eq(m.discovered.leafling, true); eq(m.discovered.trex, nil)
	eq(m.eco.src.income, 50); eq(m.eco.src.x, 0)
end)

test("livro-razão: earn/spend registram fonte e sumidouro; ecoDiff só devolve o novo", function()
	local d = Logic.newData(Config, NOW)
	local snap = Logic.ecoSnapshot(d)
	Logic.earn(d, 40, "income"); Logic.earn(d, 10, "daily"); Logic.buyEgg(d, Config)
	eq(d.coins, 100 + 50 - 50); eq(d.stats.coinsEarned, 50)
	local diff = Logic.ecoDiff(snap, d)
	eq(#diff, 3); eq(diff[1].flow, "sink"); eq(diff[1].amount, 50); eq(diff[2].reason, "daily"); eq(diff[3].reason, "income")
	snap = Logic.ecoSnapshot(d)
	eq(#Logic.ecoDiff(snap, d), 0)
	eq(Logic.earn(d, -5, "x"), 0); eq(Logic.earn(d, 0.9, "x"), 0); eq(d.coins, 100)
	d.coins = 1e12 - 3; eq(Logic.earn(d, 100, "income"), 3, "teto de moedas")
end)

test("ovo: preço sobe com o progresso (teto) e cai no evento de fim de semana", function()
	local d = Logic.newData(Config, NOW)
	eq(Logic.eggCost(d, Config), 50)
	d.hatched = 10; eq(Logic.eggCost(d, Config), 55)
	d.hatched = 55; eq(Logic.eggCost(d, Config), 75)
	d.hatched = 5000; eq(Logic.eggCost(d, Config), 100, "teto +100%")
	d.hatched = 0
	eq(Logic.eggCost(d, Config, MON), 50, "segunda sem evento")
	eq(Logic.eggCost(d, Config, MON + 5 * DAY), 38, "sábado -25%")
	d.coins = 38; local ok = Logic.buyEgg(d, Config, MON + 5 * DAY); eq(ok, true); eq(d.coins, 0)
end)

test("calendário de eventos: dia da semana, fim e próximo, efeitos", function()
	eq(Logic.weekday(Config, MON), 0)
	eq(Logic.weekday(Config, MON + 2 * DAY), 2)
	eq(Logic.weekday(Config, MON + 6 * DAY), 6)
	eq(#Logic.activeEvents(Config, MON), 0)
	local up = Logic.upcomingEvents(Config, MON)
	eq(up[1].id, "decor_wed"); eq(up[2].id, "visitors_fri"); eq(up[3].id, "eggs_weekend")
	eq(up[1].startsAt, Logic.dayEndsAt(Config, MON) + DAY, "quarta começa 2 dias depois, à meia-noite local")
	local sat = Logic.activeEvents(Config, MON + 5 * DAY)
	eq(sat[1].id, "eggs_weekend"); eq(sat[1].endsAt, Logic.dayEndsAt(Config, MON + 5 * DAY) + DAY, "vale sábado e domingo")
	eq(Logic.activeEvents(Config, MON + 6 * DAY)[1].endsAt, Logic.dayEndsAt(Config, MON + 6 * DAY))
	eq(Logic.eventEffects(Config, MON + 4 * DAY).income, 0.15)
	eq(Logic.eventEffects(Config, MON + 2 * DAY).shopDiscount, 0.20)
	-- virada de dia usa o fuso do jogo (UTC-3): 02:59 UTC ainda é "ontem"
	local midnightLocal = (Logic.dayIndex(Config, MON) + 1) * DAY - Config.DayOffsetSeconds
	eq(Logic.dayIndex(Config, midnightLocal - 1), Logic.dayIndex(Config, MON))
	eq(Logic.dayIndex(Config, midnightLocal), Logic.dayIndex(Config, MON) + 1)
end)

test("renda: impulso e evento só valem enquanto ativos; sem 'now' é a renda-base", function()
	local d = Logic.newData(Config, NOW); placed(d, "pebbleback")
	eq(Logic.incomePerTick(d, Config), 5)
	eq(Logic.incomePerTick(d, Config, MON), 5)
	Logic.grantBoost(d, Config, 1.5, 600, MON)
	eq(Logic.incomePerTick(d, Config, MON + 10), 8, "5*1.5=7.5 -> 8")
	eq(Logic.incomePerTick(d, Config, MON + 601), 5, "impulso expirou")
	eq(Logic.incomePerTick(d, Config, MON + 4 * DAY + 601), 6, "sexta +15%: 5.75 -> 6")
	Logic.grantBoost(d, Config, 1.5, 600, MON); Logic.grantBoost(d, Config, 1.5, 99999, MON)
	eq(d.boost.endsAt, MON + Config.MaxBoostSeconds, "impulso acumulado tem teto")
end)

test("recompensa diária: 1x por dia, avança o ciclo, sem punir ausência", function()
	local d = Logic.newData(Config, NOW)
	local ok = Logic.claimDaily(d, Config, MON); eq(ok, true); eq(d.coins, 100 + 40, "mín. 40 sem renda"); eq(d.login.cycle, 1)
	ok = Logic.claimDaily(d, Config, MON + 3600); eq(ok, false); eq(d.login.cycle, 1); eq(d.coins, 140)
	-- ficou 5 dias fora: continua do dia 2 do calendário (nada zera)
	ok = Logic.claimDaily(d, Config, MON + 5 * DAY); eq(ok, true); eq(d.login.cycle, 2); eq(d.eggs, 2); eq(d.login.totalClaims, 2)
	local view = Logic.retentionView(d, Config, MON + 5 * DAY)
	eq(view.daily.canClaim, false)
	eq(view.daily.days[1].claimed, true); eq(view.daily.days[3].next, true)
end)

test("recompensa diária escala com a renda, mas respeita mínimo e teto", function()
	local d = Logic.newData(Config, NOW)
	local r = Config.DailyRewards[1]
	eq(Logic.dailyRewardCoins(d, Config, r), 40)
	placed(d, "embercrest"); placed(d, "embercrest"); d.upgrades.income = 5
	-- 24*2.25 = 54/tick*12 ticks/min = 648/min -> 3 min = 1944 -> teto 600
	eq(Logic.dailyRewardCoins(d, Config, r), 600)
	local d2 = Logic.newData(Config, NOW); placed(d2, "pebbleback")
	eq(Logic.dailyRewardCoins(d2, Config, r), 180, "5/tick*12=60/min*3")
end)

test("calendário completo: dia 4 dá impulso, dia 7 dá cerca dourada (e vira moedas se repetida)", function()
	local d = Logic.newData(Config, NOW)
	for i = 1, 4 do Logic.claimDaily(d, Config, MON + i * DAY) end
	eq(Logic.boostMult(d, MON + 4 * DAY + 5), 1.5)
	for i = 5, 7 do Logic.claimDaily(d, Config, MON + i * DAY) end
	eq(d.owned.fence_gold, true); eq(d.login.cycle, 0, "ciclo recomeça")
	local before = d.coins
	for i = 8, 14 do Logic.claimDaily(d, Config, MON + i * DAY) end
	eq(d.owned.fence_gold, true)
	eq(d.coins > before + Config.DailyCosmeticFallbackCoins, true, "repetida vira moedas, nada se perde")
end)

test("missões diárias: determinísticas, progresso relativo ao dia, pagam 1x, bônus do dia", function()
	local a, b = Logic.dailyQuests(Config, 100), Logic.dailyQuests(Config, 100)
	eq(#a, 3); eq(a[1].id, b[1].id); eq(a[3].id, b[3].id)
	local seen, ids = {}, {}
	for day = 1, 40 do for _, q in ipairs(Logic.dailyQuests(Config, day)) do ids[q.id] = true end end
	for _ in pairs(ids) do seen[#seen + 1] = 1 end
	eq(#seen, #Config.DailyQuestPool, "todas as missões do pool aparecem ao longo dos dias")
	local d = Logic.newData(Config, NOW); d.hatched = 7; d.stats.eggsBought = 3
	Logic.rollDay(d, Config, MON)
	local qs = Logic.dailyQuests(Config, d.daily.day)
	eq(Logic.claimQuest(d, Config, qs[1].id, MON), false, "progresso conta só a partir do início do dia")
	eq(Logic.claimQuest(d, Config, "inventada", MON), false)
	-- cumpre todas via estatísticas
	for _, q in ipairs(qs) do
		if q.stat == "hatched" then d.hatched = d.hatched + q.target else d.stats[q.stat] = (d.stats[q.stat] or 0) + q.target end
	end
	eq(Logic.claimQuestBonus(d, Config, MON), false, "bônus exige as 3 recebidas")
	local coins = d.coins
	for _, q in ipairs(qs) do
		eq((Logic.claimQuest(d, Config, q.id, MON)), true)
		eq((Logic.claimQuest(d, Config, q.id, MON)), false, "sem recompensa dupla")
	end
	eq(d.coins > coins, true)
	local eggs = d.eggs
	eq((Logic.claimQuestBonus(d, Config, MON)), true); eq(d.eggs, eggs + 1)
	eq((Logic.claimQuestBonus(d, Config, MON)), false)
	-- novo dia: missões reiniciam
	Logic.rollDay(d, Config, MON + DAY); eq(next(d.daily.claimed), nil); eq(d.daily.bonusClaimed, false)
end)

test("metas: só após cumprir, 1x, entregam ovos/cosmético; progresso nunca passa do alvo", function()
	local d = Logic.newData(Config, NOW)
	eq((Logic.claimGoal(d, Config, "g_hatch3")), false)
	eq((Logic.claimGoal(d, Config, "nao_existe")), false)
	eq((Logic.claimGoal(d, Config, nil)), false)
	d.hatched = 3
	local c = d.coins
	eq((Logic.claimGoal(d, Config, "g_hatch3")), true); eq(d.coins, c + 60)
	eq((Logic.claimGoal(d, Config, "g_hatch3")), false); eq(d.coins, c + 60, "anti-duplicação")
	d.stats.coinsEarned = 50000
	eq((Logic.claimGoal(d, Config, "g_earn50k")), true); eq(d.owned.fence_royal, true)
	d.hatched = 3
	local view = Logic.retentionView(d, Config, MON)
	for _, g in ipairs(view.goals) do eq(g.progress <= g.target, true) end
	eq(view.goals[1].tier, "short"); eq(view.goals[#view.goals].tier, "long")
end)

test("coleção: chocar descobre a espécie; vista mostra o dex e conta recompensas pendentes", function()
	local d = Logic.newData(Config, NOW)
	Logic.startIncubate(d, Config, NOW); Logic.collect(d, Config, NOW + 20, function() return 0 end)
	eq(d.discovered.leafling, true); eq(Logic.statValue(d, Config, "discovered"), 1)
	local v = Logic.retentionView(d, Config, MON)
	eq(#v.dex, 3); eq(v.dex[1].discovered, true); eq(v.dex[3].discovered, false)
	eq(v.claimable, 1 + 0, "só a recompensa diária (nenhuma meta/missão pronta)")
	d.hatched = 3
	eq(Logic.retentionView(d, Config, MON).claimable >= 2, true, "meta de 3 ovos pronta")
end)

test("loja: itens só-recompensa nunca entram no estoque nem são comprados", function()
	for w = 0, 400 do
		for _, id in ipairs((Logic.shopStock(Config, w * Config.ShopRotationSeconds))) do
			eq(Logic.catalogItem(Config, id).rewardOnly, nil, "estoque limpo")
		end
	end
	local d = Logic.newData(Config, NOW); d.coins = 1e6
	eq((Logic.buyShop(d, Config, "fence_gold", { "fence_gold" })), false)
	eq(d.owned.fence_gold, nil)
end)

test("loja: desconto de evento no preço e no débito", function()
	local d = Logic.newData(Config, NOW); d.coins = 1000
	local stock = Logic.shopStock(Config, MON)
	local id = stock[1]
	local item = Logic.catalogItem(Config, id)
	eq(Logic.shopPrice(Config, item, MON), item.price)
	local wed = MON + 2 * DAY
	local price = Logic.shopPrice(Config, item, wed)
	eq(price < item.price, true)
	local ok = Logic.buyShop(d, Config, id, { id }, wed); eq(ok, true); eq(d.coins, 1000 - price)
	eq(d.stats.shopBuys, 1)
end)

test("recibos: idempotentes (mesmo recibo não concede 2x), produto desconhecido, poda", function()
	local d = Logic.newData(Config, NOW)
	eq(Logic.processReceipt(d, Config, "r1", "eggs_3", MON), "granted"); eq(d.eggs, 4)
	eq(Logic.processReceipt(d, Config, "r1", "eggs_3", MON), "already"); eq(d.eggs, 4)
	eq(Logic.processReceipt(d, Config, "r2", "boost_small", MON), "granted"); eq(Logic.boostMult(d, MON + 1), 1.5)
	eq(Logic.processReceipt(d, Config, "r3", "nao_existe", MON), "unknown"); eq(d.receipts.r3, nil, "desconhecido não consome recibo")
	eq(Logic.processReceipt(d, Config, "", "eggs_3", MON), "invalid")
	eq(Logic.processReceipt(d, Config, 5, "eggs_3", MON), "invalid")
	for i = 1, 300 do Logic.processReceipt(d, Config, "x" .. i, "eggs_3", MON + i) end
	local n = 0; for _ in pairs(d.receipts) do n = n + 1 end
	eq(n, Config.Monetization.MaxReceipts); eq(d.receipts.x300 ~= nil, true, "mantém os mais novos"); eq(d.receipts.r1, nil)
end)

test("passes: concessão idempotente e cosmético do Fundador", function()
	local d = Logic.newData(Config, NOW)
	eq(Logic.grantPass(d, Config, "founder"), true); eq(Logic.grantPass(d, Config, "founder"), true)
	eq(d.passes.founder, true); eq(d.owned.fence_gold, true)
	eq(Logic.grantPass(d, Config, "inexistente"), false)
end)

test("ofertas: desligadas por padrão; quando ligadas respeitam tutorial, sessão, intervalo e limite diário", function()
	local d = Logic.newData(Config, NOW)
	local ok, why = Logic.offerEligible(d, Config, { sessionSeconds = 9999 }, MON)
	eq(ok, false); eq(why, "monetização desligada"); eq(Config.Monetization.Enabled, false)
	local cfg = setmetatable({ Monetization = { Enabled = true, MaxReceipts = 200 } }, { __index = Config })
	d.hatched = 6; d.tutorialDismissed = true; d.login.sessions = 3
	eq((Logic.offerEligible(d, cfg, { sessionSeconds = 700 }, MON)), true)
	eq((Logic.offerEligible(d, cfg, { sessionSeconds = 100 }, MON)), false, "sessão recém-iniciada")
	d.login.sessions = 1; eq((Logic.offerEligible(d, cfg, { sessionSeconds = 700 }, MON)), false, "1ª sessão"); d.login.sessions = 3
	d.hatched = 2; eq((Logic.offerEligible(d, cfg, { sessionSeconds = 700 }, MON)), false, "começo do jogo"); d.hatched = 6
	d.tutorialDismissed = false
	cfg.Offers = { MinHatched = 5, MinSessions = 2, MinSessionSeconds = 600, CooldownSeconds = 86400, MaxPerDay = 1 }
	eq((Logic.offerEligible(d, cfg, { sessionSeconds = 700 }, MON)), false, "tutorial ainda ativo (precisa de 10 ovos)")
	d.tutorialDismissed = true
	Logic.markOfferShown(d, cfg, MON)
	eq((Logic.offerEligible(d, cfg, { sessionSeconds = 700 }, MON + 3600)), false, "intervalo mínimo")
	eq((Logic.offerEligible(d, cfg, { sessionSeconds = 700 }, MON + DAY + 10)), true, "no dia seguinte")
end)

test("guia da loja: cada compra diz o que concede, duração e se repete", function()
	local g = Logic.storeGuide(Config)
	eq(#g.coins >= 5, true); eq(g.robuxEnabled, false)
	for _, e in ipairs(g.coins) do eq(e.name ~= nil and e.grants ~= nil and e.duration ~= nil and e.repeatable ~= nil and e.price ~= nil, true, e.name) end
	for _, e in ipairs(g.robux) do eq(e.duration ~= nil and e.repeatable ~= nil and e.grants ~= nil, true, e.name) end
	eq(#g.robux, 4)
end)

test("início de sessão: dias desde o 1º acesso, novo dia, contador de sessões", function()
	local d = Logic.newData(Config, NOW)
	local i1 = Logic.startSession(d, Config, MON)
	eq(i1.daysSinceFirst, 0); eq(i1.sessions, 1); eq(i1.isNewDay, true)
	local i2 = Logic.startSession(d, Config, MON + 3600)
	eq(i2.isNewDay, false); eq(i2.sessions, 2)
	local i3 = Logic.startSession(d, Config, MON + DAY)
	eq(i3.daysSinceFirst, 1, "retorno D1"); eq(i3.isNewDay, true)
	local i4 = Logic.startSession(d, Config, MON + 7 * DAY)
	eq(i4.daysSinceFirst, 7)
end)

test("funil de onboarding: marcos acendem na ordem das ações", function()
	local d = Logic.newData(Config, NOW)
	local f = Logic.onboardingFlags(d); eq(f[1].reached, false)
	Logic.startIncubate(d, Config, NOW); Logic.collect(d, Config, NOW + 20, function() return 0 end)
	eq(Logic.onboardingFlags(d)[1].reached, true)
	Logic.place(d, Config, "d1"); eq(Logic.onboardingFlags(d)[2].reached, true)
	d.coins = 500; Logic.buyUpgrade(d, Config, "income"); eq(Logic.onboardingFlags(d)[3].reached, true)
end)

-- Simulação determinística de um jogador "ativo e racional" (compra melhorias na ordem, mantém o melhor dino nos habitats).
-- Mede o ritmo da economia sob as HIPÓTESES de Config; NÃO é playtest e não prova diversão nem retenção.
local function simulate(seconds, buyEggsLate)
	local d = Logic.newData(Config, NOW)
	local t = NOW
	local seed = 12345
	local function rnd() seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648 end
	local log = {}
	local function mark(name) if not log[name] then log[name] = t - NOW end end
	local function income(id) return Config.Species[Logic.findDino(d, id).species].income end
	for _ = 1, seconds / 5 do -- decisões a cada 5 s (igual ao intervalo de renda)
		t = t + 5
		if d.incubating and t >= d.incubating.readyAt and #d.dinos < Config.MaxDinos then Logic.collect(d, Config, t, rnd) end
		for _, dino in ipairs(d.dinos) do Logic.place(d, Config, dino.id) end
		-- troca o pior dino colocado por um melhor guardado
		if #d.placed >= Logic.slots(d, Config) then
			local worst
			for _, id in ipairs(d.placed) do if not worst or income(id) < income(worst) then worst = id end end
			for _, dino in ipairs(d.dinos) do
				if not Logic.isPlaced(d, dino.id) and income(dino.id) > income(worst) then
					Logic.remove(d, Config, worst); Logic.place(d, Config, dino.id); break
				end
			end
		end
		Logic.earn(d, Logic.incomePerTick(d, Config, t), "income")
		for _, key in ipairs(Config.UpgradeOrder) do
			if Logic.buyUpgrade(d, Config, key) then mark(key .. d.upgrades[key]) end
		end
		local freeSlot = Logic.slots(d, Config) - #d.dinos > 0
		if not d.incubating and d.eggs == 0 and #d.dinos < Config.MaxDinos - 1 and (freeSlot or (buyEggsLate and d.upgrades.slots == 3)) then
			if Logic.buyEgg(d, Config, t) then mark("egg" .. d.stats.eggsBought) end
		end
		if not d.incubating then Logic.startIncubate(d, Config, t) end
		if d.coins < 0 then error("saldo negativo") end
	end
	return d, log
end

local function ledger(d)
	local src, snk = 0, 0
	for _, v in pairs(d.eco.src) do src = src + v end
	for _, v in pairs(d.eco.snk) do snk = snk + v end
	return src, snk
end

test("simulação de economia (4 h ativas, hipótese): ritmo das melhorias e dos sumidouros", function()
	local d, log = simulate(4 * 3600, true)
	local function m(k) return log[k] and ("%dmin"):format(math.floor(log[k] / 60)) or "nunca" end
	print(("  SIM 4h: slots1=%s slots2=%s slots3=%s income5=%s incubator3=%s reforma1=%s reforma3=%s"):format(
		m("slots1"), m("slots2"), m("slots3"), m("income5"), m("incubator3"), m("renovation1"), m("renovation3")))
	local src, snk = ledger(d)
	print(("  SIM 4h: ovos=%d renda/tick=%d moedas=%d entrou=%d saiu=%d (%.0f%% reinvestido)"):format(d.hatched, Logic.incomePerTick(d, Config), d.coins, src, snk, snk / math.max(1, src) * 100))
	eq(log.slots1 ~= nil and log.slots1 <= 900, true, "1º habitat extra em até 15 min: " .. tostring(log.slots1))
	eq(log.slots3 ~= nil and log.slots3 <= 3 * 3600, true, "4 habitats em até 3 h")
	eq(src - snk, d.coins - Config.StartCoins, "o livro-razão fecha com o saldo")
end)

test("simulação de economia (24 h ativas): ainda há sumidouro (reforma) depois do muro das 2-3 h", function()
	local d, log = simulate(24 * 3600, true)
	local src, snk = ledger(d)
	local function m(k) return log[k] and ("%.1fh"):format(log[k] / 3600) or "nunca" end
	print(("  SIM 24h: reforma1=%s reforma3=%s reforma6=%s ovos=%d renda/tick=%d moedas=%d reinvestido=%.0f%%"):format(
		m("renovation1"), m("renovation3"), m("renovation6"), d.hatched, Logic.incomePerTick(d, Config), d.coins, snk / math.max(1, src) * 100))
	eq(log.renovation1 ~= nil and log.renovation1 <= 4 * 3600, true, "1ª reforma em até 4 h")
	eq(log.renovation6 == nil or log.renovation6 >= 8 * 3600, true, "reforma máxima não antes de 8 h ativas: " .. m("renovation6"))
	eq(src - snk, d.coins - Config.StartCoins)
end)

print(("RESULTADO: %d passaram, %d falharam"):format(passed, failed))
if failed > 0 then error("testes falharam") end
