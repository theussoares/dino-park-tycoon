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
	textRow(("Você tem %d ovo(s). Cada ovo custa %d moedas."):format(state.eggs, Config.EggCost), COLORS.text, 36)
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
	local f = row(150)
	label(f, "Chances ao chocar (o primeiro ovo é sempre um Leafling):", 14, COLORS.muted, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 36) })
	local y = 44
	for _, o in ipairs(Logic.odds(Config)) do
		local sp = Config.Species[o.id]
		label(f, ("%s (%s): %.0f%%"):format(sp.name, sp.rarity, o.percent), 15, Config.RarityColors[sp.rarity], { Position = UDim2.fromOffset(12, y), Size = UDim2.new(1, -24, 0, 22) })
		y = y + 24
	end
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

-- Cada push de estado reconstrói o painel; se isso acontecer entre o apertar e o soltar do clique,
-- o botão é destruído e o clique se perde. Adia a reconstrução enquanto o ponteiro estiver pressionado.
local UserInputService = game:GetService("UserInputService")
local pointerDown, renderPending = false, false
local function isPointer(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end
local function renderSafe()
	if pointerDown then
		renderPending = true
		return
	end
	render()
end
UserInputService.InputBegan:Connect(function(input)
	if isPointer(input) then
		pointerDown = true
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if isPointer(input) then
		pointerDown = false
		if renderPending then
			renderPending = false
			task.delay(0.1, render) -- depois do Click do botão ser processado
		end
	end
end)

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
	renderSafe()
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
