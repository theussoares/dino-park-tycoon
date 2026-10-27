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

print(("RESULTADO: %d passaram, %d falharam"):format(passed, failed))
if failed > 0 then error("testes falharam") end
