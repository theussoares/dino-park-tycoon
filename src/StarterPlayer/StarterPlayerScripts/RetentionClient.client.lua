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
-- Canto inferior esquerdo: o chat padrão do Roblox cobre o canto superior esquerdo e engole cliques.
openBtn.AnchorPoint = Vector2.new(0, 1)
openBtn.Position = UDim2.new(0, 12, 1, -12)
openBtn.Visible = false
local badge = label(openBtn, "", 12, C.bg, {
	BackgroundTransparency = 0, BackgroundColor3 = C.gold, Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -14, 0, -8),
	TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBold, Visible = false,
})
corner(badge, 11)

local panel = Instance.new("Frame")
panel.BackgroundColor3 = C.panel
panel.AnchorPoint = Vector2.new(0, 1)
panel.Position = UDim2.new(0, 12, 1, -60)
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
