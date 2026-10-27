-- Testes de fluxos da lógica pura (Config + Logic): casos felizes e infelizes por ação, migração, trava,
-- recibos, eventos, ponta a ponta e invariantes. Executado por tests/run_tests.js (Lua 5.3 via fengari). Sem APIs do Roblox.
-- Testes de regressão dos bugs corrigidos; ver docs/tests/2026-10-26-haiku-fluxos-logica.md.
Color3 = Color3 or { fromRGB = function(r, g, b) return { r, g, b } end }
local Config = assert(load(SRC_CONFIG, "Config"))()
local Logic = assert(load(SRC_LOGIC, "Logic"))()

local passed, failed = 0, 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then passed = passed + 1; print("PASS  " .. name)
	else failed = failed + 1; print("FAIL  " .. name .. " -> " .. tostring(err)) end
end
local function eq(a, b, msg) if a ~= b then error((msg or "") .. " esperado " .. tostring(b) .. ", obtido " .. tostring(a), 2) end end
local function yes(v, msg) if not v then error(msg or "esperado verdadeiro", 2) end end

local NOW = 1800000000
local DAY = 86400
local MON = 1793016000 -- segunda 26/10/2026 09:00 (Brasília)
local MIDNIGHT = (Logic.dayIndex(Config, MON) + 1) * DAY - Config.DayOffsetSeconds -- 00:00 de terça
local HUGE = string.rep("a", 100000)
local JUNK = { 42, -1, 1.5, 0 / 0, math.huge, true, {}, HUGE }

local function fresh(coins)
	local d = Logic.newData(Config, MON)
	if coins then d.coins = coins end
	return d
end
-- Dinossauro no inventário (não colocado). Devolve o id.
local function addDino(d, species)
	species = species or "leafling"
	local id = "d" .. d.nextId
	d.nextId = d.nextId + 1
	d.dinos[#d.dinos + 1] = { id = id, species = species }
	d.discovered[species] = true
	return id
end
local function rndOf(v) return function() return v end end
-- Choca um ovo (comprando se preciso). Devolve ok e o instante em que ficou pronto.
local function hatchOne(d, t)
	if d.eggs == 0 then Logic.buyEgg(d, Config, t) end
	Logic.startIncubate(d, Config, t)
	local ready = t + Logic.incubateSeconds(d, Config)
	local ok = Logic.collect(d, Config, ready, rndOf(0.5))
	return ok, ready
end
local function ledgerTotals(d)
	local src, snk = 0, 0
	for _, v in pairs(d.eco.src) do src = src + v end
	for _, v in pairs(d.eco.snk) do snk = snk + v end
	return src, snk
end
-- Missões diárias do dia de t (lista igual para todos).
local function questsOn(t) return Logic.dailyQuests(Config, Logic.dayIndex(Config, t)) end
local function questFor(t, stat)
	for _, q in ipairs(questsOn(t)) do
		if q.stat == stat then return q end
	end
	return nil
end
-- Primeiro dia (a partir de segunda) em que existe missão com esse stat.
local function dayWithStat(stat)
	for k = 0, 40 do
		local t = MON + k * DAY
		if questFor(t, stat) then return t end
	end
	error("nenhum dia com missão de " .. stat)
end
-- Marca a missão como concluída (mesmo efeito que as ações do jogo teriam).
local function completeQuest(d, q, t)
	Logic.rollDay(d, Config, t)
	if q.stat == "hatched" then
		d.hatched = d.hatched + q.target
	else
		d.stats[q.stat] = (d.stats[q.stat] or 0) + q.target
	end
end
local function questView(view, id)
	for _, q in ipairs(view.quests) do
		if q.id == id then return q end
	end
	error("missão " .. id .. " ausente da visão")
end

-- ===== buyEgg =====
test("buyEgg | feliz: cobra o preço cheio e entrega 1 ovo", function()
	local d = fresh(100)
	yes(Logic.buyEgg(d, Config, MON))
	eq(d.coins, 50); eq(d.eggs, 2); eq(d.stats.eggsBought, 1); eq(d.eco.snk.egg, 50)
end)

test("buyEgg | falta de moedas: recusa sem debitar nem dar ovo", function()
	local d = fresh(49)
	local ok, msg = Logic.buyEgg(d, Config, MON)
	eq(ok, false); eq(msg, "Moedas insuficientes."); eq(d.coins, 49); eq(d.eggs, 1)
end)

test("buyEgg | limite de ovos: recusa com 99 ovos mesmo com moedas de sobra", function()
	local d = fresh(1000); d.eggs = Config.MaxEggs
	local ok, msg = Logic.buyEgg(d, Config, MON)
	eq(ok, false); eq(msg, "Você já tem ovos demais."); eq(d.coins, 1000); eq(d.eggs, Config.MaxEggs)
end)

test("buyEgg | repetição: dinheiro exato para 2 ovos; a 3ª falha e o saldo não fica negativo", function()
	local d = fresh(100)
	yes(Logic.buyEgg(d, Config, MON)); yes(Logic.buyEgg(d, Config, MON))
	eq(d.coins, 0); eq(d.eggs, 3)
	eq(Logic.buyEgg(d, Config, MON), false); eq(d.coins, 0)
end)

test("buyEgg | fim de semana: preço cai 25% (38) e o débito bate", function()
	local d = fresh(100)
	yes(Logic.buyEgg(d, Config, MON + 5 * DAY))
	eq(d.coins, 62)
end)

-- ===== incubate =====
test("incubate | feliz: consome 1 ovo e marca pronto em agora + 12 s", function()
	local d = fresh()
	yes(Logic.startIncubate(d, Config, MON))
	eq(d.eggs, 0); eq(d.incubating.readyAt, MON + 12)
end)

test("incubate | sem ovos: recusa e não cria incubação", function()
	local d = fresh(); d.eggs = 0
	local ok, msg = Logic.startIncubate(d, Config, MON)
	eq(ok, false); eq(msg, "Você não tem ovos."); eq(d.incubating, nil)
end)

test("incubate | incubadora ocupada: a 2ª tentativa falha e não consome ovo", function()
	local d = fresh(); d.eggs = 2
	yes(Logic.startIncubate(d, Config, MON))
	local ok, msg = Logic.startIncubate(d, Config, MON + 1)
	eq(ok, false); eq(msg, "A incubadora já está ocupada."); eq(d.eggs, 1); eq(d.incubating.readyAt, MON + 12, "tempo não reiniciado")
end)

test("incubate | incubadora nível 3 encurta para 3 s", function()
	local d = fresh(); d.upgrades.incubator = 3
	yes(Logic.startIncubate(d, Config, MON))
	eq(d.incubating.readyAt, MON + 3)
end)

-- ===== collect =====
test("collect | antes da hora: recusa e mantém o ovo na incubadora", function()
	local d = fresh()
	Logic.startIncubate(d, Config, MON)
	local ok, msg = Logic.collect(d, Config, MON + 11, rndOf(0))
	eq(ok, false); eq(msg, "Ainda não chocou."); yes(d.incubating ~= nil); eq(#d.dinos, 0)
end)

test("collect | exatamente na hora: choca o primeiro ovo como Leafling", function()
	local d = fresh()
	Logic.startIncubate(d, Config, MON)
	local ok, _, species = Logic.collect(d, Config, MON + 12, rndOf(0.99))
	eq(ok, true); eq(species, "leafling"); eq(d.incubating, nil); eq(#d.dinos, 1); eq(d.hatched, 1)
end)

test("collect | sem incubação: recusa com 'Nada para coletar.'", function()
	local ok, msg = Logic.collect(fresh(), Config, MON, rndOf(0))
	eq(ok, false); eq(msg, "Nada para coletar.")
end)

test("collect | inventário cheio (MaxDinos): recusa e mantém o ovo", function()
	local d = fresh()
	for _ = 1, Config.MaxDinos do addDino(d) end
	Logic.startIncubate(d, Config, MON)
	local ok, msg = Logic.collect(d, Config, MON + 60, rndOf(0))
	eq(ok, false); eq(msg, "Inventário cheio."); eq(#d.dinos, Config.MaxDinos); yes(d.incubating ~= nil)
end)

test("collect | repetição: coletar de novo não choca outro dino", function()
	local d = fresh()
	Logic.startIncubate(d, Config, MON)
	yes(Logic.collect(d, Config, MON + 12, rndOf(0)))
	local ok, msg = Logic.collect(d, Config, MON + 13, rndOf(0))
	eq(ok, false); eq(msg, "Nada para coletar."); eq(#d.dinos, 1); eq(d.hatched, 1)
end)

test("collect | sorteio no limite (rnd quase 1) dá a espécie mais rara após o 1º ovo", function()
	local d = fresh(); d.hatched = 1
	Logic.startIncubate(d, Config, MON)
	local _, _, species = Logic.collect(d, Config, MON + 12, rndOf(0.9999))
	eq(species, "embercrest")
end)

-- ===== place =====
test("place | feliz: coloca o dino no habitat e conta a colocação", function()
	local d = fresh()
	local id = addDino(d)
	yes(Logic.place(d, Config, id))
	eq(#d.placed, 1); eq(d.placed[1], id); eq(d.stats.placements, 1)
end)

test("place | id inexistente: recusa sem tocar no habitat", function()
	local d = fresh()
	addDino(d)
	local ok, msg = Logic.place(d, Config, "d99")
	eq(ok, false); eq(msg, "Você não tem esse dinossauro."); eq(#d.placed, 0)
end)

test("place | tipos errados (número, fracionário, negativo, NaN, infinito, booleano, tabela): todos recusados", function()
	local d = fresh()
	addDino(d)
	for _, v in ipairs(JUNK) do
		if v ~= HUGE then
			eq((Logic.place(d, Config, v)), false, "aceitou " .. tostring(v))
		end
	end
	eq(#d.placed, 0)
end)

test("place | string enorme (100 mil caracteres): recusa sem erro", function()
	local d = fresh()
	addDino(d)
	local ok, msg = Logic.place(d, Config, HUGE)
	eq(ok, false); eq(msg, "Dinossauro inválido."); eq(#d.placed, 0)
end)

test("place | nil e string vazia: recusados", function()
	local d = fresh()
	addDino(d)
	eq((Logic.place(d, Config, nil)), false); eq((Logic.place(d, Config, "")), false); eq(#d.placed, 0)
end)

test("place | repetição: o mesmo dino não entra duas vezes nem conta duas colocações", function()
	local d = fresh()
	local id = addDino(d)
	yes(Logic.place(d, Config, id))
	local ok, msg = Logic.place(d, Config, id)
	eq(ok, false); eq(msg, "Já está no habitat."); eq(#d.placed, 1); eq(d.stats.placements, 1)
end)

test("place | habitat cheio com 1 habitat: o 2º dino é recusado", function()
	local d = fresh()
	local a, b = addDino(d), addDino(d)
	yes(Logic.place(d, Config, a))
	local ok, msg = Logic.place(d, Config, b)
	eq(ok, false); eq(msg, "Sem habitat livre. Compre um novo em Melhorias."); eq(#d.placed, 1)
end)

test("place | limite de 4 habitats: aceita 4 dinos e recusa o 5º", function()
	local d = fresh(); d.upgrades.slots = 3
	local ids = {}
	for i = 1, 5 do ids[i] = addDino(d) end
	for i = 1, 4 do yes(Logic.place(d, Config, ids[i])) end
	eq((Logic.place(d, Config, ids[5])), false); eq(#d.placed, 4)
end)

-- ===== remove =====
test("remove | feliz: tira do habitat e o dino continua no inventário", function()
	local d = fresh()
	local id = addDino(d)
	Logic.place(d, Config, id)
	yes(Logic.remove(d, Config, id))
	eq(#d.placed, 0); eq(#d.dinos, 1)
end)

test("remove | dino no inventário mas fora do habitat: recusa", function()
	local d = fresh()
	local id = addDino(d)
	local ok, msg = Logic.remove(d, Config, id)
	eq(ok, false); eq(msg, "Ele não está no habitat.")
end)

test("remove | id inexistente, nil e número: recusados", function()
	local d = fresh()
	eq((Logic.remove(d, Config, "zz")), false); eq((Logic.remove(d, Config, nil)), false); eq((Logic.remove(d, Config, 5)), false)
end)

test("remove | string enorme: recusa sem erro", function()
	local ok = Logic.remove(fresh(), Config, HUGE)
	eq(ok, false)
end)

test("remove | repetição: remover duas vezes tira só uma vez", function()
	local d = fresh()
	local id = addDino(d)
	Logic.place(d, Config, id)
	yes(Logic.remove(d, Config, id))
	eq((Logic.remove(d, Config, id)), false); eq(#d.dinos, 1)
end)

-- ===== buyUpgrade =====
test("buyUpgrade | feliz: debita o custo do nível e sobe 1 nível", function()
	local d = fresh(1000)
	yes(Logic.buyUpgrade(d, Config, "income"))
	eq(d.coins, 900); eq(d.upgrades.income, 1); eq(d.stats.upgradesBought, 1); eq(d.eco.snk.upgrade, 100)
end)

test("buyUpgrade | falta de moedas: custo 100 com saldo 99 não compra", function()
	local d = fresh(99)
	local ok, msg = Logic.buyUpgrade(d, Config, "income")
	eq(ok, false); eq(msg, "Moedas insuficientes."); eq(d.coins, 99); eq(d.upgrades.income, 0)
end)

test("buyUpgrade | exatamente o custo: compra e zera o saldo", function()
	local d = fresh(100)
	yes(Logic.buyUpgrade(d, Config, "income"))
	eq(d.coins, 0)
end)

test("buyUpgrade | nível máximo: recusa sem cobrar", function()
	local d = fresh(1000000); d.upgrades.slots = 3
	local ok, msg = Logic.buyUpgrade(d, Config, "slots")
	eq(ok, false); eq(msg, "Nível máximo."); eq(d.coins, 1000000); eq(d.upgrades.slots, 3)
end)

test("buyUpgrade | chave inválida (nil, número, desconhecida, vazia, campo do save, texto enorme): recusa", function()
	local d = fresh(1000000)
	eq((Logic.buyUpgrade(d, Config, nil)), false, "aceitou nil") -- ipairs pararia no nil
	for _, key in ipairs({ 1, "nope", "", "maxLevel", "upgrades", HUGE }) do
		eq((Logic.buyUpgrade(d, Config, key)), false, "aceitou " .. tostring(key))
	end
	eq(d.coins, 1000000)
end)

test("buyUpgrade | repetição até o máximo cobra exatamente a soma dos 5 níveis", function()
	local d = fresh(1000000)
	for _ = 1, 5 do yes(Logic.buyUpgrade(d, Config, "income")) end
	eq((Logic.buyUpgrade(d, Config, "income")), false)
	eq(d.coins, 1000000 - (100 + 250 + 500 + 1000 + 2000))
end)

-- ===== buyShop =====
test("buyShop | feliz decoração: entra no inventário e não troca a cerca", function()
	local d = fresh(100)
	yes(Logic.buyShop(d, Config, "lamp", { "lamp" }, MON))
	eq(d.coins, 40); eq(d.owned.lamp, true); eq(d.fence, "wood")
end)

test("buyShop | feliz cerca: vira a cerca equipada", function()
	local d = fresh(100)
	yes(Logic.buyShop(d, Config, "fence_candy", { "fence_candy" }, MON))
	eq(d.coins, 10); eq(d.fence, "fence_candy")
end)

test("buyShop | fora do estoque: recusa mesmo com saldo", function()
	local d = fresh(1000)
	local ok, msg = Logic.buyShop(d, Config, "fountain", { "lamp" }, MON)
	eq(ok, false); eq(msg, "Esse item não está na loja agora."); eq(d.coins, 1000); eq(d.owned.fountain, nil)
end)

test("buyShop | item só-recompensa (cerca dourada) nunca é vendido, mesmo listado no estoque", function()
	local d = fresh(100000)
	local ok = Logic.buyShop(d, Config, "fence_gold", { "fence_gold" }, MON)
	eq(ok, false); eq(d.owned.fence_gold, nil); eq(d.coins, 100000)
end)

test("buyShop | já possuído: recusa e não cobra de novo", function()
	local d = fresh(1000)
	yes(Logic.buyShop(d, Config, "lamp", { "lamp" }, MON))
	local ok, msg = Logic.buyShop(d, Config, "lamp", { "lamp" }, MON)
	eq(ok, false); eq(msg, "Você já tem esse item."); eq(d.coins, 940)
end)

test("buyShop | falta de moedas (59 para um item de 60): não marca como possuído", function()
	local d = fresh(59)
	local ok, msg = Logic.buyShop(d, Config, "lamp", { "lamp" }, MON)
	eq(ok, false); eq(msg, "Moedas insuficientes."); eq(d.owned.lamp, nil); eq(d.coins, 59)
end)

test("buyShop | id inválido (nil, número, fracionário, texto enorme, id fora do catálogo): recusa", function()
	local d = fresh(100000)
	eq((Logic.buyShop(d, Config, nil, { nil }, MON)), false, "aceitou nil") -- ipairs pararia no nil
	for _, id in ipairs({ 5, 1.5, HUGE, "fence_xyz" }) do
		eq((Logic.buyShop(d, Config, id, { id }, MON)), false, "aceitou " .. tostring(id))
	end
	eq(d.coins, 100000)
end)

test("buyShop | evento de quarta (-20%): cobra 48 de um item de 60", function()
	local d = fresh(100)
	yes(Logic.buyShop(d, Config, "lamp", { "lamp" }, MON + 2 * DAY))
	eq(d.coins, 52)
end)

test("buyShop | estoque real do horário: cada item compra 1 vez; a 2ª rodada é toda recusada", function()
	local d = fresh(1000000)
	local stock = Logic.shopStock(Config, MON)
	for _, id in ipairs(stock) do yes(Logic.buyShop(d, Config, id, stock, MON), id) end
	for _, id in ipairs(stock) do eq((Logic.buyShop(d, Config, id, stock, MON)), false, "comprou de novo " .. id) end
end)

-- ===== claimDaily =====
test("claimDaily | feliz no 1º dia: paga o mínimo sem renda, avança o ciclo e conta o resgate", function()
	local d = fresh()
	local ok, msg, cycle = Logic.claimDaily(d, Config, MON)
	eq(ok, true); yes(msg:find("Recompensa", 1, true) ~= nil); eq(cycle, 1)
	eq(d.coins, 140); eq(d.login.cycle, 1); eq(d.login.totalClaims, 1); eq(d.eco.src.daily, 40)
end)

test("claimDaily | repetição no mesmo dia: a 2ª tentativa não paga nada", function()
	local d = fresh()
	yes(Logic.claimDaily(d, Config, MON))
	local ok, msg = Logic.claimDaily(d, Config, MON + 3600)
	eq(ok, false); eq(msg, "Você já recebeu hoje. Volte amanhã!"); eq(d.coins, 140); eq(d.login.cycle, 1)
end)

test("claimDaily | virada do dia: 1 s antes da meia-noite ainda é hoje; à meia-noite já pode resgatar", function()
	local d = fresh()
	eq(Logic.dayIndex(Config, MIDNIGHT - 1) + 1, Logic.dayIndex(Config, MIDNIGHT), "meia-noite de Brasília")
	yes(Logic.claimDaily(d, Config, MIDNIGHT - 1))
	eq((Logic.claimDaily(d, Config, MIDNIGHT - 2)), false, "mesmo dia não repete")
	yes(Logic.claimDaily(d, Config, MIDNIGHT))
	eq(d.login.cycle, 2); eq(d.login.totalClaims, 2)
end)

test("claimDaily | sem punição: 3 dias sem entrar não zeram o ciclo nem tiram moedas", function()
	local d = fresh()
	yes(Logic.claimDaily(d, Config, MON))
	local v = Logic.retentionView(d, Config, MON + 4 * DAY)
	eq(v.daily.canClaim, true, "ainda pode resgatar"); eq(v.daily.days[2].next, true, "próximo é o dia 2")
	yes(Logic.claimDaily(d, Config, MON + 4 * DAY))
	eq(d.login.cycle, 2); eq(d.eggs, 2, "dia 2 do calendário dá 1 ovo"); eq(d.coins, 140)
end)

test("claimDaily | sequência de 7 dias seguidos: ciclo volta a 0 e o dia 7 entrega a cerca dourada", function()
	local d = fresh()
	for i = 0, 6 do yes(Logic.claimDaily(d, Config, MON + i * DAY), "dia " .. i) end
	eq(d.login.cycle, 0); eq(d.owned.fence_gold, true); eq(d.login.totalClaims, 7)
	eq(d.coins, 100 + 40 + 80 + 120 + 200); eq(d.eggs, 1 + 1 + 2 + 1)
end)

test("claimDaily | cerca dourada repetida vira 300 moedas no lugar, sem perder a recompensa", function()
	local d = fresh(100)
	d.owned.fence_gold = true; d.login.cycle = 6
	yes(Logic.claimDaily(d, Config, MON))
	eq(d.coins, 100 + 200 + 300, "200 mínimo + 300 do cosmético repetido"); eq(d.eggs, 2); eq(d.owned.fence_gold, true)
end)

test("claimDaily | relógio voltando um dia não libera nova recompensa no mesmo calendário", function()
	local d = fresh()
	yes(Logic.claimDaily(d, Config, MON))
	local ok = Logic.claimDaily(d, Config, MON - DAY)
	eq(ok, false, "recebeu de novo ao voltar o relógio")
end)

-- ===== claimQuest / claimQuestBonus =====
test("claimQuest | feliz: missão concluída paga a recompensa em moedas uma vez", function()
	local d = fresh(100)
	local q = questsOn(MON)[1]
	completeQuest(d, q, MON)
	yes(Logic.claimQuest(d, Config, q.id, MON))
	eq(d.coins, 100 + q.reward); eq(d.daily.claimed[q.id], true)
end)

test("claimQuest | antes de concluir: recusa sem pagar", function()
	local d = fresh(100)
	local q = questsOn(MON)[1]
	Logic.rollDay(d, Config, MON)
	local ok, msg = Logic.claimQuest(d, Config, q.id, MON)
	eq(ok, false); eq(msg, "Missão ainda não concluída."); eq(d.coins, 100)
end)

test("claimQuest | repetição: resgatar de novo não paga 2 vezes", function()
	local d = fresh(100)
	local q = questsOn(MON)[1]
	completeQuest(d, q, MON)
	yes(Logic.claimQuest(d, Config, q.id, MON))
	local ok, msg = Logic.claimQuest(d, Config, q.id, MON)
	eq(ok, false); eq(msg, "Você já recebeu essa recompensa."); eq(d.coins, 100 + q.reward)
end)

test("claimQuest | id inválido, inexistente ou de outro dia: recusa", function()
	local d = fresh(100)
	local ok1, m1 = Logic.claimQuest(d, Config, nil, MON)
	eq(ok1, false); eq(m1, "Missão inválida.")
	local ok2, m2 = Logic.claimQuest(d, Config, 42, MON)
	eq(ok2, false); eq(m2, "Missão inválida.")
	local ok3, m3 = Logic.claimQuest(d, Config, "inventada", MON)
	eq(ok3, false); eq(m3, "Essa missão não é de hoje.")
	eq((Logic.claimQuest(d, Config, HUGE, MON)), false)
	eq(d.coins, 100)
end)

test("claimQuest | depois de expirar: missão de ontem concluída e não resgatada não paga hoje", function()
	local d = fresh(100)
	local qy = questsOn(MON - DAY)[1]
	completeQuest(d, qy, MON - DAY)
	local ok = Logic.claimQuest(d, Config, qy.id, MON)
	eq(ok, false, "recompensa atrasada"); eq(d.coins, 100)
end)

test("claimQuestBonus | antes de receber as 3 missões: recusa", function()
	local d = fresh()
	local ok, msg = Logic.claimQuestBonus(d, Config, MON)
	eq(ok, false); eq(msg, "Receba todas as missões do dia primeiro.")
end)

test("claimQuestBonus | com 2 de 3 recebidas: ainda recusa", function()
	local d = fresh(100)
	local qs = questsOn(MON)
	for _, q in ipairs(qs) do completeQuest(d, q, MON) end
	yes(Logic.claimQuest(d, Config, qs[1].id, MON)); yes(Logic.claimQuest(d, Config, qs[2].id, MON))
	eq((Logic.claimQuestBonus(d, Config, MON)), false)
end)

test("claimQuestBonus | feliz com as 3: entrega 1 ovo e marca como recebido", function()
	local d = fresh(100)
	local qs = questsOn(MON)
	for _, q in ipairs(qs) do completeQuest(d, q, MON) end
	for _, q in ipairs(qs) do yes(Logic.claimQuest(d, Config, q.id, MON)) end
	yes(Logic.claimQuestBonus(d, Config, MON))
	eq(d.eggs, 2); eq(d.daily.bonusClaimed, true)
end)

test("claimQuestBonus | repetição no mesmo dia: não entrega de novo", function()
	local d = fresh(100)
	local qs = questsOn(MON)
	for _, q in ipairs(qs) do completeQuest(d, q, MON) end
	for _, q in ipairs(qs) do yes(Logic.claimQuest(d, Config, q.id, MON)) end
	yes(Logic.claimQuestBonus(d, Config, MON))
	local ok, msg = Logic.claimQuestBonus(d, Config, MON)
	eq(ok, false); eq(msg, "Bônus do dia já recebido."); eq(d.eggs, 2)
end)

test("claimQuestBonus | novo dia: o bônus volta a exigir as 3 missões do novo dia", function()
	local d = fresh(100)
	local qs = questsOn(MON)
	for _, q in ipairs(qs) do completeQuest(d, q, MON) end
	for _, q in ipairs(qs) do yes(Logic.claimQuest(d, Config, q.id, MON)) end
	yes(Logic.claimQuestBonus(d, Config, MON))
	local ok, msg = Logic.claimQuestBonus(d, Config, MON + DAY)
	eq(ok, false); eq(msg, "Receba todas as missões do dia primeiro."); eq(d.daily.bonusClaimed, false)
end)

test("claimQuest | relógio voltando e voltando de novo não zera as missões já recebidas do dia", function()
	local d = fresh(100)
	local q = questsOn(MON)[1]
	completeQuest(d, q, MON)
	yes(Logic.claimQuest(d, Config, q.id, MON))
	Logic.retentionView(d, Config, MON - DAY)
	Logic.retentionView(d, Config, MON)
	eq(questView(Logic.retentionView(d, Config, MON), q.id).claimed, true, "flag de recebida perdida")
end)

test("claimQuest | a 1ª ação do dia (antes de qualquer leitura da tela) conta para a missão 'Compre 1 ovo'", function()
	local t = dayWithStat("eggsBought")
	local start = Logic.dayIndex(Config, t) * DAY - Config.DayOffsetSeconds -- 00:00 do dia de t
	local d = fresh(1000)
	Logic.retentionView(d, Config, start - 1) -- último instante da tela no dia anterior
	yes(Logic.buyEgg(d, Config, start + 60)) -- primeira ação do novo dia
	local q = questFor(t, "eggsBought")
	eq(questView(Logic.retentionView(d, Config, start + 60), q.id).progress, 1, "progresso da compra do dia")
end)

-- ===== claimGoal =====
test("claimGoal | antes de cumprir: recusa sem pagar", function()
	local d = fresh(100)
	local ok, msg = Logic.claimGoal(d, Config, "g_hatch3")
	eq(ok, false); eq(msg, "Meta ainda não concluída."); eq(d.coins, 100)
end)

test("claimGoal | feliz: 'Choque 3 ovos' entrega 60 moedas", function()
	local d = fresh(100); d.hatched = 3
	yes(Logic.claimGoal(d, Config, "g_hatch3"))
	eq(d.coins, 160); eq(d.goalsClaimed.g_hatch3, true)
end)

test("claimGoal | repetição: a segunda vez não paga", function()
	local d = fresh(100); d.hatched = 3
	yes(Logic.claimGoal(d, Config, "g_hatch3"))
	local ok, msg = Logic.claimGoal(d, Config, "g_hatch3")
	eq(ok, false); eq(msg, "Você já recebeu essa recompensa."); eq(d.coins, 160)
end)

test("claimGoal | id inválido (nil, número, inexistente, texto enorme): recusa", function()
	local d = fresh(100)
	eq((Logic.claimGoal(d, Config, nil)), false, "aceitou nil") -- ipairs pararia no nil
	for _, id in ipairs({ 5, "nao_existe", HUGE }) do
		local ok, msg = Logic.claimGoal(d, Config, id)
		eq(ok, false); eq(msg, "Meta inválida.", "aceitou " .. tostring(id))
	end
	eq(d.coins, 100)
end)

test("claimGoal | meta mista: 'Descubra as 3 espécies' entrega 1 ovo + 150 moedas", function()
	local d = fresh(100)
	for _, id in ipairs(Config.SpeciesOrder) do d.discovered[id] = true end
	yes(Logic.claimGoal(d, Config, "g_dex3"))
	eq(d.coins, 250); eq(d.eggs, 2)
end)

test("claimGoal | cosmético já possuído vira 300 moedas no lugar (além das 1000 da meta)", function()
	local d = fresh(100)
	d.stats.coinsEarned = 50000; d.owned.fence_royal = true
	yes(Logic.claimGoal(d, Config, "g_earn50k"))
	eq(d.coins, 100 + 1000 + 300)
end)

test("claimGoal | metas não expiram: resgatar meses depois ainda funciona", function()
	local d = fresh(100); d.hatched = 3
	Logic.retentionView(d, Config, MON + 120 * DAY) -- passam 4 meses sem resgatar
	yes(Logic.claimGoal(d, Config, "g_hatch3"), "meta expirou")
	eq(d.coins, 160)
end)

test("claimGoal | decoração comprada conta para 'Compre sua 1ª decoração ou cerca'", function()
	local d = fresh(100)
	yes(Logic.buyShop(d, Config, "lamp", { "lamp" }, MON))
	yes(Logic.claimGoal(d, Config, "g_decor1"))
	eq(d.coins, 40 + 50)
end)

-- ===== track / getState / dismissTutorial / goHome: partes que a Logic cobre =====
test("track | lista fechada: só os 4 eventos do cliente passam; eventos de compra e servidor ficam de fora", function()
	local n = 0
	for _ in pairs(Config.ClientEvents) do n = n + 1 end
	eq(n, 4)
	yes(Config.ClientEvents.shop_view == true)
	yes(Config.ClientEvents.purchase_granted == nil)
	yes(Config.ClientEvents.session_end == nil)
	yes(Config.ClientEvents.insufficient_coins == nil)
end)

test("getState | montar a visão não muda moedas, ovos, estatísticas nem histórico de resgates", function()
	local d = fresh(777); d.hatched = 4; d.stats.coinsEarned = 300; d.login.totalClaims = 2
	Logic.retentionView(d, Config, MON)
	eq(d.coins, 777); eq(d.eggs, 1); eq(d.stats.coinsEarned, 300); eq(d.login.totalClaims, 2); eq(d.hatched, 4)
end)

-- ===== Logic.migrate (save v1/v2 e corrompido) =====
test("migrate | nil e tipos errados (texto, número, booleano, função) devolvem um save novo", function()
	for _, raw in ipairs({ "lixo", 5, true, print }) do
		local d = Logic.migrate(raw, Config, NOW)
		eq(d.coins, 100, "tipo " .. type(raw)); eq(d.eggs, 1); eq(d.schemaVersion, 2)
	end
	eq(Logic.migrate(nil, Config, NOW).coins, 100)
end)

test("migrate | save vazio {} vira save novo sem erros", function()
	local d = Logic.migrate({}, Config, NOW)
	eq(d.coins, 100); eq(d.eggs, 1); eq(d.schemaVersion, 2); eq(d.login.cycle, 0); eq(d.daily.day, -1)
end)

test("migrate | campos de tipo errado não derrubam o carregamento e viram padrão", function()
	local d = Logic.migrate({ coins = "abc", eggs = {}, dinos = "x", upgrades = 5, owned = "x", placed = true, login = 3,
		daily = "x", stats = "x", eco = 7, goalsClaimed = 1, boost = "x", offers = false, receipts = 9, passes = false,
		missions = 4, incubating = "x", discovered = 2, tutorialDismissed = "sim", lastSeen = "ontem" }, Config, NOW)
	eq(d.coins, 100); eq(d.eggs, 1); eq(#d.dinos, 0); eq(d.login.cycle, 0); eq(d.daily.day, -1); eq(d.boost, nil)
	eq(d.tutorialDismissed, false); eq(d.lastSeen, NOW); eq(d.incubating, nil)
end)

test("migrate | campos a mais são ignorados e não viram estado (inclusive trava do save)", function()
	local d = Logic.migrate({ coins = 10, hack = true, admin = { coins = 1e9 }, _lock = { jobId = "X", t = NOW } }, Config, NOW)
	eq(d.coins, 10); eq(d.hack, nil); eq(d.admin, nil); eq(d._lock, nil)
end)

test("migrate | moedas e ovos negativos viram 0; fracionários são arredondados para baixo", function()
	local d = Logic.migrate({ coins = -50, eggs = 2.9 }, Config, NOW)
	eq(d.coins, 0); eq(d.eggs, 2)
	eq(Logic.migrate({ eggs = -3 }, Config, NOW).eggs, 0)
end)

test("migrate | moedas acima do teto (1e15) são limitadas a 1e12", function()
	eq(Logic.migrate({ coins = 1e15 }, Config, NOW).coins, 1e12)
end)

test("migrate | NaN em moedas volta ao valor inicial (nunca vira NaN)", function()
	local d = Logic.migrate({ coins = 0 / 0 }, Config, NOW)
	yes(d.coins == 100, "moedas = " .. tostring(d.coins))
end)

test("migrate | id de dino com 100 mil caracteres é descartado", function()
	local d = Logic.migrate({ dinos = { { id = HUGE, species = "leafling" } } }, Config, NOW)
	eq(#d.dinos, 0)
end)

test("migrate | espécie desconhecida e id repetido são descartados (fica o 1º válido)", function()
	local d = Logic.migrate({ dinos = { { id = "d1", species = "trex" }, { id = "d2", species = "leafling" }, { id = "d2", species = "embercrest" } } }, Config, NOW)
	eq(#d.dinos, 1); eq(d.dinos[1].species, "leafling")
end)

test("migrate | fence de cerca não possuída cai para madeira", function()
	local d = Logic.migrate({ fence = "fence_gold", owned = {} }, Config, NOW)
	eq(d.fence, "wood")
end)

test("migrate | eco: no máximo 40 motivos por fluxo", function()
	local src = {}
	for i = 1, 100 do src["r" .. i] = i end
	local n = 0
	for _ in pairs(Logic.migrate({ eco = { src = src } }, Config, NOW).eco.src) do n = n + 1 end
	yes(n <= 40, "motivos = " .. n)
end)

test("migrate | readyAt em texto descarta a incubação", function()
	local d = Logic.migrate({ incubating = { startedAt = 1, readyAt = "x" } }, Config, NOW)
	eq(d.incubating, nil)
end)

test("migrate | fence apontando para decoração possuída (poste de luz) vira a cerca equipada", function()
	local d = Logic.migrate({ owned = { lamp = true }, fence = "lamp" }, Config, NOW)
	eq(d.fence, "wood", "decoração foi equipada como cerca")
end)

test("migrate | nextId menor que o maior id de dino existente gera ids duplicados ao coletar", function()
	local d = Logic.migrate({ coins = 500, dinos = { { id = "d1", species = "leafling" }, { id = "d2", species = "leafling" } }, nextId = 1 }, Config, NOW)
	Logic.startIncubate(d, Config, NOW)
	Logic.collect(d, Config, NOW + 12, rndOf(0))
	local seen, dup = {}, false
	for _, dino in ipairs(d.dinos) do
		if seen[dino.id] then dup = true end
		seen[dino.id] = true
	end
	eq(dup, false, "ids repetidos no inventário")
end)

test("migrate | readyAt NaN libera a coleta antes do tempo", function()
	local d = Logic.migrate({ incubating = { startedAt = NOW, readyAt = 0 / 0 } }, Config, NOW)
	local ok = Logic.collect(d, Config, NOW, rndOf(0))
	eq(ok, false, "coletou com readyAt inválido")
end)

-- ===== Trava de sessão =====
test("trava | carimbo NaN é tratado como inválido (não bloqueia), como carimbo de tipo errado", function()
	eq(Logic.lockedByOther({ _lock = { jobId = "A", t = 0 / 0 } }, "B", NOW, 300), false)
end)

test("trava | carimbo muito no futuro (relógio de outro servidor) bloqueia além de LockSeconds", function()
	local locked = Logic.lockedByOther({ _lock = { jobId = "A", t = NOW + 2 * DAY } }, "B", NOW, Config.LockSeconds)
	eq(locked, false, "bloqueado por 2 dias")
end)

-- ===== Recibos e passes (monetização desligada, lógica testada assim mesmo) =====
test("recibos | tipo errado, vazio ou texto acima de 64 caracteres: inválido e não grava", function()
	local d = fresh()
	eq(Logic.processReceipt(d, Config, "", "eggs_3", MON), "invalid")
	eq(Logic.processReceipt(d, Config, {}, "eggs_3", MON), "invalid")
	eq(Logic.processReceipt(d, Config, HUGE, "eggs_3", MON), "invalid")
	eq(d.eggs, 1); eq(next(d.receipts), nil)
end)

test("recibos | produto de tipo errado ou desconhecido: não consome o recibo", function()
	local d = fresh()
	eq(Logic.processReceipt(d, Config, "r9", 5, MON), "unknown"); eq(Logic.processReceipt(d, Config, "r9", "founder", MON), "unknown")
	eq(d.receipts.r9, nil)
end)

test("recibos | recibo de compra antiga (200 compras depois, dentro de 30 dias) continua reconhecido", function()
	local d = fresh()
	eq(Logic.processReceipt(d, Config, "r1", "eggs_3", MON), "granted")
	for i = 1, Config.Monetization.MaxReceipts / 10 do Logic.processReceipt(d, Config, "x" .. i, "eggs_3", MON + i) end
	eq(Logic.processReceipt(d, Config, "r1", "eggs_3", MON + 500), "already", "PurchaseId repetido concedeu de novo")
end)

test("recibos | recibo além de 30 dias é podado (e só então pode ser reconhecido de novo)", function()
	local d = fresh()
	Logic.processReceipt(d, Config, "r1", "eggs_3", MON)
	eq(Logic.processReceipt(d, Config, "r2", "eggs_3", MON + Config.Monetization.ReceiptKeepSeconds + 1), "granted")
	eq(d.receipts.r1, nil)
end)

test("passes | id desconhecido ou de tipo errado: recusa; Fundador repetido não duplica", function()
	local d = fresh()
	eq(Logic.grantPass(d, Config, 5), false); eq(Logic.grantPass(d, Config, "nao_existe"), false)
	yes(Logic.grantPass(d, Config, "founder")); yes(Logic.grantPass(d, Config, "founder"))
	eq(d.owned.fence_gold, true); eq(d.passes.founder, true)
end)

-- ===== Eventos (acabam no dia certo) =====
test("eventos | desconto de quarta vale na quarta e acaba na quinta", function()
	local lamp = Logic.catalogItem(Config, "lamp")
	eq(Logic.shopPrice(Config, lamp, MON + 2 * DAY), 48)
	eq(Logic.shopPrice(Config, lamp, MON + 3 * DAY), 60, "quinta: sem evento")
end)

test("eventos | fim de semana: ovo barato no sábado, preço cheio na segunda seguinte", function()
	eq(Logic.eggCost(fresh(), Config, MON + 5 * DAY), 38)
	eq(Logic.eggCost(fresh(), Config, MON + 7 * DAY), 50)
end)

test("eventos | sábado sem sexta: bônus de visitantes da sexta já não vale", function()
	eq(Logic.eventEffects(Config, MON + 5 * DAY).income, 0)
	eq(Logic.eventEffects(Config, MON + 4 * DAY).income, 0.15)
end)

test("eventos | evento ativo não aparece em 'próximos'", function()
	for _, ev in ipairs(Logic.upcomingEvents(Config, MON + 2 * DAY)) do
		eq(ev.id ~= "decor_wed", true, "quarta ainda listada como próxima")
	end
end)

test("checkMissions | 'Compre uma melhoria' não conta quando a 1ª compra é a reforma (4000 moedas)", function()
	local d = fresh(5000)
	yes(Logic.buyUpgrade(d, Config, "renovation"))
	Logic.checkMissions(d, Config)
	eq(d.missions.upgrade, true, "missão de melhoria não concluída pela reforma")
end)

-- ===== Ponta a ponta =====
test("fluxo | sessão nova até a primeira melhoria (missões pagam 50, 75 e 100)", function()
	local d = Logic.newData(Config, MON)
	local info = Logic.startSession(d, Config, MON)
	eq(info.sessions, 1); eq(info.isNewDay, true)
	local t = MON
	yes(Logic.startIncubate(d, Config, t)); eq(d.eggs, 0)
	t = t + Config.IncubateSeconds
	yes(Logic.collect(d, Config, t, rndOf(0)))
	local done = Logic.checkMissions(d, Config)
	eq(#done, 1); eq(done[1].reward, 50); eq(d.coins, 150)
	yes(Logic.place(d, Config, "d1"))
	done = Logic.checkMissions(d, Config)
	eq(#done, 1); eq(d.coins, 225)
	eq(Logic.currentGoal({ missions = d.missions }, Config).id, "upgrade")
	for _ = 1, 12 do -- 1 minuto de visitantes: 12 pagamentos de 2 moedas
		t = t + Config.IncomeInterval
		Logic.earn(d, Logic.incomePerTick(d, Config, t), "income")
	end
	eq(d.coins, 249)
	yes(Logic.buyUpgrade(d, Config, "income"))
	eq(d.coins, 149)
	done = Logic.checkMissions(d, Config)
	eq(#done, 1); eq(done[1].reward, 100); eq(d.coins, 249)
	eq(Logic.currentGoal({ missions = d.missions }, Config), nil)
	local src, snk = ledgerTotals(d)
	eq(src - snk, d.coins - Config.StartCoins, "livro-razão fecha")
end)

test("fluxo | encher habitat e inventário: 4 habitats, 60 dinossauros, recusas nos limites e metas", function()
	local d = fresh()
	Logic.earn(d, 20000, "teste") -- dinheiro de teste; entra no livro-razão
	for _ = 1, 3 do yes(Logic.buyUpgrade(d, Config, "slots")) end
	eq(Logic.slots(d, Config), 4)
	local t = MON
	for _ = 1, Config.MaxDinos do
		if d.eggs == 0 then yes(Logic.buyEgg(d, Config, t)) end
		yes(Logic.startIncubate(d, Config, t))
		local ok, ready = hatchOne(d, t)
		yes(ok)
		t = ready
	end
	eq(#d.dinos, Config.MaxDinos)
	for i = 1, 4 do yes(Logic.place(d, Config, "d" .. i)) end
	local ok, msg = Logic.place(d, Config, "d5")
	eq(ok, false); eq(msg, "Sem habitat livre. Compre um novo em Melhorias.")
	yes(Logic.remove(d, Config, "d1")); yes(Logic.place(d, Config, "d5")); eq(#d.placed, 4)
	yes(Logic.buyEgg(d, Config, t)); yes(Logic.startIncubate(d, Config, t))
	ok, msg = Logic.collect(d, Config, t + 3600, rndOf(0))
	eq(ok, false); eq(msg, "Inventário cheio."); yes(d.incubating ~= nil, "ovo continua na incubadora")
	yes(Logic.claimGoal(d, Config, "g_slots4"))
	yes(Logic.claimGoal(d, Config, "g_hatch50"))
	eq(d.eggs, 1 + 2, "1 ovo do teste + 2 da meta")
	eq((Logic.claimGoal(d, Config, "g_upall")), false, "melhorias não estão no máximo")
	local src, snk = ledgerTotals(d)
	eq(src - snk, d.coins - Config.StartCoins, "livro-razão fecha")
end)

test("fluxo | semana de logins diários com faltas: sem punição, calendário avança só com resgates", function()
	local d = fresh()
	local attend = { [0] = true, [1] = true, [3] = true, [4] = true, [6] = true, [8] = true, [9] = true }
	local claims, lastCoins = 0, d.coins
	for k = 0, 9 do
		local t = MON + k * DAY
		if attend[k] then
			local info = Logic.startSession(d, Config, t)
			if k == 9 then eq(info.daysSinceFirst, 9, "dias desde o 1º acesso") end
			yes(Logic.claimDaily(d, Config, t), "dia " .. k)
			claims = claims + 1
		else
			local v = Logic.retentionView(d, Config, t)
			eq(v.daily.canClaim, true, "dia perdido ainda deixa resgatar (sem punição) no dia " .. k)
			eq(v.daily.totalClaims, claims)
			if k == 2 then eq(v.events.active[1].id, "decor_wed") end
			if k == 5 then yes(v.events.active[1].id == "eggs_weekend") end
		end
		yes(d.coins >= lastCoins, "moedas caíram no dia " .. k)
		lastCoins = d.coins
	end
	eq(claims, 7); eq(d.login.cycle, 0); eq(d.owned.fence_gold, true)
	eq(d.coins, 100 + 40 + 80 + 120 + 200, "soma das 7 recompensas (sem renda)"); eq(d.eggs, 1 + 1 + 2 + 1)
	eq(d.login.sessions, 7)
	yes(Logic.claimDaily(d, Config, MON + 14 * DAY), "semana seguinte")
	eq(d.coins, 540 + 40); eq(d.login.cycle, 1)
	local src, snk = ledgerTotals(d)
	eq(src - snk, d.coins - Config.StartCoins, "livro-razão fecha")
end)

-- ===== Invariantes: sorteio fixo de 3000 ações (inclusive inválidas) =====
test("invariante | fuzz: 3000 ações aleatórias (sorteio fixo) mantêm moedas ≥ 0, livro-razão, ids e habitat válidos", function()
	local seed = 987654
	local function rnd() seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648 end
	local function pick(list) return list[math.floor(rnd() * #list) + 1] end
	local UP = { "slots", "income", "incubator", "renovation" }
	local SHOP, GOALS = {}, {}
	for _, item in ipairs(Config.ShopCatalog) do SHOP[#SHOP + 1] = item.id end
	for _, g in ipairs(Config.Goals) do GOALS[#GOALS + 1] = g.id end
	local ORDER = { "buyEgg", "incubate", "collect", "place", "remove", "buyUpgrade", "buyShop", "claimDaily", "claimQuest", "claimQuestBonus", "claimGoal", "tick" }
	local CLAIMS = { claimDaily = true, claimQuest = true, claimQuestBonus = true, claimGoal = true, tick = true }
	local d = fresh()
	local t = MON
	local function anyDinoId()
		if rnd() < 0.1 then return pick(JUNK) end
		return "d" .. math.floor(rnd() * (d.nextId + 2))
	end
	local acts = {
		buyEgg = function() return Logic.buyEgg(d, Config, t) end,
		incubate = function() return Logic.startIncubate(d, Config, t) end,
		collect = function() return Logic.collect(d, Config, t, rnd) end,
		place = function() return Logic.place(d, Config, anyDinoId()) end,
		remove = function() return Logic.remove(d, Config, anyDinoId()) end,
		buyUpgrade = function() return Logic.buyUpgrade(d, Config, rnd() < 0.1 and pick(JUNK) or pick(UP)) end,
		buyShop = function() return Logic.buyShop(d, Config, rnd() < 0.1 and pick(JUNK) or pick(SHOP), Logic.shopStock(Config, t), t) end,
		claimDaily = function() return Logic.claimDaily(d, Config, t) end,
		claimQuest = function()
			local id = rnd() < 0.2 and pick(JUNK) or pick(questsOn(t)).id
			return Logic.claimQuest(d, Config, id, t)
		end,
		claimQuestBonus = function() return Logic.claimQuestBonus(d, Config, t) end,
		claimGoal = function() return Logic.claimGoal(d, Config, rnd() < 0.1 and pick(JUNK) or pick(GOALS)) end,
		tick = function() Logic.earn(d, Logic.incomePerTick(d, Config, t), "income"); return true end,
	}
	local okCount, noCount = 0, 0
	for step = 1, 3000 do
		t = t + math.floor(rnd() * 1800)
		local name = pick(ORDER)
		local coinsBefore, eggsBefore = d.coins, d.eggs
		local ok = acts[name]()
		local where = ("passo %d (%s)"):format(step, name)
		if ok then okCount = okCount + 1 else noCount = noCount + 1 end
		if not ok and (d.coins ~= coinsBefore or d.eggs ~= eggsBefore) then error(where .. ": ação recusada mexeu em moedas/ovos") end
		if d.coins > coinsBefore and not CLAIMS[name] then error(where .. ": moedas ganhas sem custo nem resgate") end
		if d.coins < 0 or d.coins ~= math.floor(d.coins) then error(where .. ": moedas inválidas " .. tostring(d.coins)) end
		if d.eggs < 0 then error(where .. ": ovos negativos") end
		if #d.dinos > Config.MaxDinos then error(where .. ": inventário acima do máximo") end
		local seen = {}
		for _, dino in ipairs(d.dinos) do
			if seen[dino.id] then error(where .. ": id de dinossauro repetido " .. dino.id) end
			seen[dino.id] = true
		end
		local placedSeen = {}
		for _, pid in ipairs(d.placed) do
			if placedSeen[pid] or not seen[pid] then error(where .. ": habitat com id repetido ou órfão " .. tostring(pid)) end
			placedSeen[pid] = true
		end
		if #d.placed > Logic.slots(d, Config) then error(where .. ": habitat acima dos slots") end
		local src, snk = ledgerTotals(d)
		if src - snk ~= d.coins - Config.StartCoins then error(where .. ": livro-razão não fecha") end
	end
	print(("  FUZZ: %d ações aceitas, %d recusadas, moedas finais %d"):format(okCount, noCount, d.coins))
	yes(okCount > 0 and noCount > 0, "sorteio não cobriu aceitas e recusadas")
end)

print(("RESULTADO fluxos: %d passaram, %d falharam"):format(passed, failed))
if failed > 0 then error("testes de fluxos falharam: " .. failed) end
