--!nonstrict
-- Interface do Dino Park Tycoon (cliente). Só mostra estado e pede ações; o servidor decide tudo.
-- Tokens e padrões: design/DESIGN.md. Layout, estados e copy: design/features/ui-ux-redesign/design.md.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
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

-- ===== tokens visuais (ver design/DESIGN.md) =====
local C = {
	bg = Color3.fromRGB(31, 51, 39),
	panel = Color3.fromRGB(43, 70, 54),
	card = Color3.fromRGB(54, 87, 63),
	ghost = Color3.fromRGB(70, 108, 82),
	primary = Color3.fromRGB(123, 214, 122),
	gold = Color3.fromRGB(255, 210, 90),
	disabled = Color3.fromRGB(78, 94, 84),
	text = Color3.fromRGB(244, 248, 241),
	muted = Color3.fromRGB(197, 211, 198),
	ink = Color3.fromRGB(19, 32, 26),
	ok = Color3.fromRGB(150, 240, 150),
	err = Color3.fromRGB(255, 170, 160),
	info = Color3.fromRGB(190, 225, 255),
}
local FONT_TITLE = Enum.Font.FredokaOne
local FONT_STRONG = Enum.Font.GothamBold
local FONT_BODY = Enum.Font.GothamMedium
local TEXT = { title = 22, card = 17, body = 15, caption = 13 } -- nada abaixo de 13 px
local BUTTON = {
	primary = { bg = C.primary, text = C.ink },
	gold = { bg = C.gold, text = C.ink },
	ghost = { bg = C.ghost, text = C.text },
	disabled = { bg = C.disabled, text = C.muted },
}
local PRESS = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local state = nil
local welcomeShown = nil
local saveWarned = false
local openPanel = nil
local busy = false
local knownDinos = nil -- ids já vistos, para detectar um dinossauro novo (revelação)
local lastCoins = nil
local liveLabels = {} -- funções chamadas a cada 0.5 s (contagens e barra de incubação)
local eggReadyRendered = nil
local revealDinoId = nil
local toastToken = 0
local camera = nil
local view = { W = 900, H = 560, compact = false, cellW = 170 } -- tamanho lógico da tela (ver layout)

-- ===== helpers de UI =====
local function corner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = inst
	return c
end

local function frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = C.card
	if props then
		for k, v in pairs(props) do
			f[k] = v
		end
	end
	f.Parent = parent
	return f
end

local function label(parent, text, size, color, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.Font = FONT_BODY
	l.TextSize = size or TEXT.body
	l.TextColor3 = color or C.text
	l.Text = text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.TextWrapped = true
	if props then
		for k, v in pairs(props) do
			l[k] = v
		end
	end
	l.Parent = parent
	return l
end

local function restyle(b, style)
	local look = BUTTON[style] or BUTTON.ghost
	b.BackgroundColor3 = look.bg
	b.TextColor3 = look.text
end

-- Botão com feedback de toque (encolhe ao pressionar). 'disabled' ainda aceita toque: o clique explica o motivo.
local function button(parent, text, style, size)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.Font = FONT_STRONG
	b.TextSize = TEXT.body
	b.TextWrapped = true
	b.Text = text
	b.Size = size or UDim2.fromOffset(120, 40)
	b.Parent = parent
	restyle(b, style)
	corner(b, 10)
	local sc = Instance.new("UIScale")
	sc.Parent = b
	b.MouseButton1Down:Connect(function()
		TweenService:Create(sc, PRESS, { Scale = 0.94 }):Play()
	end)
	local function release()
		TweenService:Create(sc, PRESS, { Scale = 1 }):Play()
	end
	b.MouseButton1Up:Connect(release)
	b.MouseLeave:Connect(release)
	return b
end

local function pill(parent, text, color, x, y)
	local w = TextService:GetTextSize(text, TEXT.caption, FONT_STRONG, Vector2.new(400, 40)).X + 16
	local p = frame(parent, { BackgroundColor3 = color, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, 20) })
	corner(p, 10)
	label(p, text, TEXT.caption, C.ink, { Size = UDim2.fromScale(1, 1), Font = FONT_STRONG, TextXAlignment = Enum.TextXAlignment.Center })
	return p
end

-- Barra de progresso: devolve (fundo, preenchimento). Largura do preenchimento é ajustada pelo chamador.
local function progressBar(parent, pos, size, color)
	local bg = frame(parent, { Position = pos, Size = size, BackgroundColor3 = C.bg })
	corner(bg, 5)
	local fill = frame(bg, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = color or C.gold })
	corner(fill, 5)
	return bg, fill
end

-- Cartão de lista (ou célula de grade): o tamanho é definido pelo layout do painel.
local order = 0
local scroll = nil
local function item(height)
	order = order + 1
	local f = frame(scroll, { Size = UDim2.new(1, -8, 0, height), LayoutOrder = order, BackgroundColor3 = C.card })
	corner(f, 12)
	return f
end

-- Faíscas leves para a revelação: 10 pontos, removidos sozinhos.
local function sparkle(parent, color)
	for i = 1, 10 do
		local a = (i / 10) * math.pi * 2
		local dot = frame(parent, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = color, ZIndex = 32 })
		corner(dot, 4)
		TweenService:Create(dot, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, math.cos(a) * 170, 0.5, math.sin(a) * 120), BackgroundTransparency = 1,
		}):Play()
		Debris:AddItem(dot, 0.8)
	end
end

-- "+N" que sobe e some sobre o HUD.
local function floatText(parent, text, color, x, y)
	local l = label(parent, text, TEXT.title, color, { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(120, 28), Font = FONT_TITLE, ZIndex = 5 })
	TweenService:Create(l, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(x, y - 26), TextTransparency = 1,
	}):Play()
	Debris:AddItem(l, 1)
end

local gui = Instance.new("ScreenGui")
gui.Name = "DinoParkUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local function playPing(speed)
	local snd = Instance.new("Sound")
	snd.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	snd.Volume = 0.4
	snd.PlaybackSpeed = speed or 1
	snd.Parent = gui
	snd:Play()
	Debris:AddItem(snd, 2)
end

local root = Instance.new("Frame")
root.Name = "Root"
root.BackgroundTransparency = 1
root.Size = UDim2.fromScale(1, 1)
root.Parent = gui

local scale = Instance.new("UIScale")
scale.Parent = root

-- ===== tempo e formatação =====
local function timeLeft(readyAt)
	return math.max(0, readyAt - Workspace:GetServerTimeNow())
end

local function fmt(seconds)
	seconds = math.max(0, math.floor(seconds))
	return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

local function isEggReady()
	return state ~= nil and state.incubating ~= false and timeLeft(state.incubating.readyAt) <= 0
end

-- Texto do custo para o objetivo e a próxima melhoria.
local function costHint(cost)
	if cost <= state.coins then
		return ("Pronto: %d moedas"):format(cost)
	end
	return ("Faltam %d moedas"):format(cost - state.coins)
end

local function effectText(key, level, maxed)
	local def = Config.Upgrades[key]
	if maxed then
		return "Nível máximo alcançado."
	end
	if key == "slots" then
		return ("Habitats: %d → %d"):format(Config.BaseSlots + level, Config.BaseSlots + level + 1)
	elseif key == "income" then
		return ("Renda: +%d%% → +%d%%"):format(math.floor(level * def.bonus * 100 + 0.5), math.floor((level + 1) * def.bonus * 100 + 0.5))
	end
	local now = Config.IncubateSeconds * (1 - level * def.reduction)
	local nxt = Config.IncubateSeconds * (1 - (level + 1) * def.reduction)
	return ("Incubação: %d s → %d s"):format(math.floor(now + 0.5), math.floor(nxt + 0.5))
end

-- ===== camada de avisos (toast) =====
local toast = label(root, "", TEXT.body, C.text, {
	AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(420, 32), BackgroundTransparency = 0.05, BackgroundColor3 = C.bg,
	TextXAlignment = Enum.TextXAlignment.Center, Visible = false, ZIndex = 40,
})
corner(toast, 10)

local function showToast(text, kind)
	toastToken = toastToken + 1
	local mine = toastToken
	local prefix = (kind == "success" and "+ ") or (kind == "error" and "! ") or ""
	toast.Text = prefix .. text
	toast.TextColor3 = (kind == "error" and C.err) or (kind == "success" and C.ok) or C.text
	toast.Size = UDim2.fromOffset(math.min(440, view.W - 24), #text > 48 and 52 or 32)
	toast.Visible = true
	task.delay(3.5, function()
		if toastToken == mine then
			toast.Visible = false
		end
	end)
end

-- ===== HUD: moedas (topo esquerdo) =====
local hud = frame(root, { BackgroundColor3 = C.bg, BackgroundTransparency = 0.1, Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(250, 74) })
corner(hud, 12)
label(hud, "MOEDAS", TEXT.caption, C.muted, { Position = UDim2.fromOffset(14, 6), Size = UDim2.fromOffset(220, 16), Font = FONT_STRONG })
local coinsLabel = label(hud, "...", 26, C.gold, { Position = UDim2.fromOffset(14, 20), Size = UDim2.fromOffset(220, 34), Font = FONT_TITLE })
local rateLabel = label(hud, "", TEXT.caption, C.muted, { Position = UDim2.fromOffset(14, 52), Size = UDim2.fromOffset(226, 18) })

-- ===== objetivo (centro superior) e próxima melhoria (direita) =====
local objective = frame(root, { BackgroundColor3 = C.bg, BackgroundTransparency = 0.1, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(480, 64) })
corner(objective, 12)
local objTag = label(objective, "OBJETIVO", TEXT.caption, C.gold, { Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 0, 16), Font = FONT_STRONG })
local objText = label(objective, "", TEXT.body, C.text, { Position = UDim2.fromOffset(14, 22), Size = UDim2.new(1, -28, 0, 20), Font = FONT_STRONG })
local objHint = label(objective, "", TEXT.caption, C.muted, { Position = UDim2.fromOffset(14, 42), Size = UDim2.new(1, -28, 0, 18) })

local unlock = frame(root, { BackgroundColor3 = C.bg, BackgroundTransparency = 0.1, AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(212, 64) })
corner(unlock, 12)
label(unlock, "PRÓXIMA MELHORIA", TEXT.caption, C.gold, { Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 0, 16), Font = FONT_STRONG })
local unlockName = label(unlock, "", TEXT.body, C.text, { Position = UDim2.fromOffset(14, 22), Size = UDim2.new(1, -28, 0, 20), Font = FONT_STRONG })
local unlockHint = label(unlock, "", TEXT.caption, C.muted, { Position = UDim2.fromOffset(14, 42), Size = UDim2.new(1, -28, 0, 18) })

-- ===== carregando =====
local loading = frame(gui, { BackgroundColor3 = C.bg, Size = UDim2.fromScale(1, 1), ZIndex = 50 })
local loadingText = label(loading, "Carregando seu parque...", 28, C.text, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(500, 50), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 51 })

-- ===== painel central =====
local panel = frame(root, { BackgroundColor3 = C.panel, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(520, 400), Visible = false })
corner(panel, 16)
local panelScale = Instance.new("UIScale")
panelScale.Parent = panel
local panelTitle = label(panel, "", TEXT.title, C.text, { Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -124, 0, 36), Font = FONT_TITLE })
local panelClose = button(panel, "Fechar", "ghost", UDim2.fromOffset(92, 38))
panelClose.Position = UDim2.new(1, -106, 0, 10)
scroll = Instance.new("ScrollingFrame")
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.Position = UDim2.fromOffset(12, 58)
scroll.Size = UDim2.new(1, -24, 1, -70)
scroll.ScrollBarThickness = 6
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new()
scroll.Parent = panel

-- Revelação de dinossauro (ao coletar um ovo). Não bloqueia: fecha com qualquer botão.
local reveal = frame(root, { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 30 })
local revealCard = frame(reveal, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(320, 290), BackgroundColor3 = C.panel, ZIndex = 31 })
corner(revealCard, 16)
local revealScale = Instance.new("UIScale")
revealScale.Parent = revealCard
local revealBand = frame(revealCard, { Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = C.primary, ZIndex = 32 })
corner(revealBand, 3)
label(revealCard, "NOVO DINOSSAURO!", TEXT.caption, C.gold, { Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Center, Font = FONT_STRONG })
local revealName = label(revealCard, "", 28, C.text, { Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 36), TextXAlignment = Enum.TextXAlignment.Center, Font = FONT_TITLE })
local revealRarity = frame(revealCard, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 82), Size = UDim2.fromOffset(120, 22) })
corner(revealRarity, 11)
local revealRarityText = label(revealRarity, "", TEXT.caption, C.ink, { Size = UDim2.fromScale(1, 1), Font = FONT_STRONG, TextXAlignment = Enum.TextXAlignment.Center })
local revealDesc = label(revealCard, "", TEXT.caption, C.muted, { Position = UDim2.fromOffset(20, 112), Size = UDim2.new(1, -40, 0, 44), TextXAlignment = Enum.TextXAlignment.Center })
local revealPlace = button(revealCard, "Colocar no habitat", "primary", UDim2.fromOffset(260, 44))
revealPlace.AnchorPoint = Vector2.new(0.5, 0)
revealPlace.Position = UDim2.new(0.5, 0, 0, 170)
local revealKeep = button(revealCard, "Guardar para depois", "ghost", UDim2.fromOffset(260, 40))
revealKeep.AnchorPoint = Vector2.new(0.5, 0)
revealKeep.Position = UDim2.new(0.5, 0, 0, 224)

local function closeReveal()
	reveal.Visible = false
	revealDinoId = nil
end

local function showReveal(dino)
	local sp = Config.Species[dino.species]
	revealDinoId = dino.id
	revealBand.BackgroundColor3 = sp.color
	revealName.Text = sp.name
	revealRarity.BackgroundColor3 = Config.RarityColors[sp.rarity]
	revealRarityText.Text = sp.rarity:upper()
	revealDesc.Text = sp.desc
	local hasSlot = state.placedCount < state.slots
	restyle(revealPlace, hasSlot and "primary" or "disabled")
	revealPlace.Text = hasSlot and "Colocar no habitat" or "Sem habitat livre"
	reveal.Visible = true
	revealScale.Scale = 0.7
	TweenService:Create(revealScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	sparkle(reveal, sp.color)
	playPing(1.4)
end

-- ===== barra inferior =====
local bar = frame(root, { AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = C.bg, BackgroundTransparency = 0.08, Size = UDim2.fromOffset(660, 60) })
corner(bar, 14)
local navGrid = Instance.new("UIGridLayout")
navGrid.CellPadding = UDim2.fromOffset(6, 0)
navGrid.CellSize = UDim2.fromOffset(100, 48)
navGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
navGrid.VerticalAlignment = Enum.VerticalAlignment.Center
navGrid.SortOrder = Enum.SortOrder.LayoutOrder
navGrid.Parent = bar
local barPad = Instance.new("UIPadding")
barPad.PaddingLeft = UDim.new(0, 6)
barPad.PaddingRight = UDim.new(0, 6)
barPad.Parent = bar

-- Botão de aba: estilo "primary" quando aberto. Badge "!" sinaliza atenção sem depender só de cor.
local navButtons = {}
local badges = {}
local function navButton(index, text, key)
	local b = button(bar, text, "ghost", UDim2.fromOffset(100, 48))
	b.LayoutOrder = index
	local badge = frame(b, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 6, 0, -6), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = C.gold, Visible = false, ZIndex = 2 })
	corner(badge, 9)
	label(badge, "!", TEXT.caption, C.ink, { Size = UDim2.fromScale(1, 1), Font = FONT_STRONG, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3 })
	badges[key] = badge
	navButtons[key] = b
	return b
end

local function updateNav()
	for key, b in pairs(navButtons) do
		restyle(b, key == openPanel and "primary" or "ghost")
	end
end

local function closePanel()
	openPanel = nil
	panel.Visible = false
	liveLabels = {}
	updateNav()
end

local renderers = {}
local function render()
	if not openPanel or not state then
		return
	end
	renderers[openPanel]()
end

local function setPanel(name)
	if openPanel == name then
		closePanel()
		return
	end
	openPanel = name
	panel.Visible = true
	panelScale.Scale = 0.96
	TweenService:Create(panelScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	updateNav()
	render()
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
		if not ok or type(result) ~= "table" then
			showToast("Falha de conexão. Tente de novo.", "error")
			return
		end
		-- a revelação do ovo já anuncia o dinossauro; não repetir aviso nem som
		local silent = action == "collect" and result.ok
		if result.message and result.message ~= "" and not silent then
			showToast(result.message, result.ok and "success" or "error")
		end
		if result.ok and not silent then
			playPing()
		end
	end)
end

local NAV = { { "Ovo", "egg" }, { "Coleção", "collection" }, { "Loja", "shop" }, { "Melhorias", "upgrades" }, { "Missões", "missions" } }
for i, nav in ipairs(NAV) do
	local b = navButton(i, nav[1], nav[2])
	b.MouseButton1Click:Connect(function()
		setPanel(nav[2])
	end)
end
local home = button(bar, "Meu Parque", "gold", UDim2.fromOffset(100, 48))
home.LayoutOrder = #NAV + 1
home.MouseButton1Click:Connect(function()
	request("goHome")
end)

panelClose.MouseButton1Click:Connect(closePanel)
revealPlace.MouseButton1Click:Connect(function()
	if state and state.placedCount < state.slots then
		local id = revealDinoId
		closeReveal()
		request("place", { id = id })
	else
		showToast("Sem habitat livre. Compre um novo em Melhorias.", "info")
	end
end)
revealKeep.MouseButton1Click:Connect(closeReveal)

-- ===== painéis =====
local function beginContent(grid)
	for _, child in ipairs(scroll:GetChildren()) do
		child:Destroy()
	end
	liveLabels = {}
	order = 0
	if grid then
		local g = Instance.new("UIGridLayout")
		g.CellSize = UDim2.fromOffset(view.cellW, 146)
		g.CellPadding = UDim2.fromOffset(8, 8)
		g.SortOrder = Enum.SortOrder.LayoutOrder
		g.Parent = scroll
	else
		local l = Instance.new("UIListLayout")
		l.Padding = UDim.new(0, 8)
		l.SortOrder = Enum.SortOrder.LayoutOrder
		l.Parent = scroll
	end
end

function renderers.egg()
	beginContent(false)
	panelTitle.Text = "Ovo e incubadora"
	local inc = item(128)
	label(inc, "Incubadora", TEXT.card, C.text, { Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 22), Font = FONT_STRONG })
	local status = label(inc, "", TEXT.body, C.text, { Position = UDim2.fromOffset(16, 38), Size = UDim2.new(1, -176, 0, 22) })
	local action = button(inc, "", "primary", UDim2.fromOffset(124, 40))
	action.Position = UDim2.new(1, -140, 0, 34)
	local barBg, barFill = progressBar(inc, UDim2.fromOffset(16, 84), UDim2.new(1, -32, 0, 10), C.gold)
	label(inc, ("Incubação leva %d s. Melhorias reduzem esse tempo."):format(state.incubateSeconds), TEXT.caption, C.muted, { Position = UDim2.fromOffset(16, 100), Size = UDim2.new(1, -32, 0, 18) })
	eggReadyRendered = isEggReady()
	barBg.Visible = false
	if state.incubating and not eggReadyRendered then
		local readyAt = state.incubating.readyAt
		local total = state.incubateSeconds
		local function refresh()
			local left = timeLeft(readyAt)
			status.Text = "Chocando... " .. fmt(left)
			barFill.Size = UDim2.fromScale(math.clamp(1 - left / total, 0, 1), 1)
		end
		barBg.Visible = true
		refresh()
		liveLabels[#liveLabels + 1] = refresh
		action.Text = "Aguarde"
		restyle(action, "disabled")
		action.MouseButton1Click:Connect(function()
			showToast("Ainda não chocou: faltam " .. fmt(timeLeft(readyAt)) .. ".", "info")
		end)
	elseif state.incubating then
		status.Text = "Pronto! Colete o dinossauro."
		action.Text = "Coletar"
		restyle(action, "gold")
		action.MouseButton1Click:Connect(function()
			request("collect")
		end)
	elseif state.eggs > 0 then
		status.Text = ("Pronto para incubar. Você tem %d ovo(s)."):format(state.eggs)
		action.Text = "Incubar"
		action.MouseButton1Click:Connect(function()
			request("incubate")
		end)
	else
		status.Text = "Sem ovos. Compre um abaixo."
		action.Text = "Incubar"
		restyle(action, "disabled")
		action.MouseButton1Click:Connect(function()
			showToast("Você não tem ovos. Compre um abaixo.", "info")
		end)
	end

	local buy = item(76)
	label(buy, "Comprar ovo", TEXT.card, C.text, { Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 22), Font = FONT_STRONG })
	label(buy, ("Custa %d moedas. Você tem %d."):format(Config.EggCost, state.eggs), TEXT.caption, C.muted, { Position = UDim2.fromOffset(16, 38), Size = UDim2.new(1, -176, 0, 18) })
	if state.coins >= Config.EggCost then
		local b = button(buy, "Comprar", "primary", UDim2.fromOffset(124, 40))
		b.Position = UDim2.new(1, -140, 0, 18)
		b.MouseButton1Click:Connect(function()
			request("buyEgg")
		end)
	else
		local missing = Config.EggCost - state.coins
		local b = button(buy, "Faltam " .. missing, "disabled", UDim2.fromOffset(124, 40))
		b.Position = UDim2.new(1, -140, 0, 18)
		b.MouseButton1Click:Connect(function()
			showToast(("Faltam %d moedas para comprar um ovo."):format(missing), "info")
		end)
	end

	local odds = Logic.odds(Config)
	local oddsCard = item(64 + #odds * 26)
	label(oddsCard, "Chances de nascer", TEXT.card, C.text, { Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 22), Font = FONT_STRONG })
	label(oddsCard, "O primeiro ovo sempre é um Leafling.", TEXT.caption, C.muted, { Position = UDim2.fromOffset(16, 36), Size = UDim2.new(1, -32, 0, 18) })
	for i, o in ipairs(odds) do
		local sp = Config.Species[o.id]
		local color = Config.RarityColors[sp.rarity]
		local y = 60 + (i - 1) * 26
		label(oddsCard, sp.name, TEXT.body, color, { Position = UDim2.fromOffset(16, y), Size = UDim2.fromOffset(120, 22), Font = FONT_STRONG })
		local track = frame(oddsCard, { Position = UDim2.new(0, 140, 0, y + 6), Size = UDim2.new(1, -250, 0, 10), BackgroundColor3 = C.bg })
		corner(track, 5)
		local share = frame(track, { Size = UDim2.fromScale(o.percent / 100, 1), BackgroundColor3 = color })
		corner(share, 5)
		label(oddsCard, ("%.0f%% · %s"):format(o.percent, sp.rarity), TEXT.caption, C.muted, { Position = UDim2.new(1, -106, 0, y), Size = UDim2.fromOffset(94, 22), TextXAlignment = Enum.TextXAlignment.Right })
	end
end

function renderers.collection()
	local hasDinos = #state.dinos > 0
	beginContent(hasDinos)
	panelTitle.Text = ("Coleção · habitats %d/%d"):format(state.placedCount, state.slots)
	if not hasDinos then
		local empty = item(118)
		label(empty, "Você ainda não tem dinossauros.", TEXT.body, C.text, { Position = UDim2.fromOffset(16, 14), Size = UDim2.new(1, -32, 0, 22), Font = FONT_STRONG })
		label(empty, "Incube um ovo para começar sua coleção.", TEXT.caption, C.muted, { Position = UDim2.fromOffset(16, 40), Size = UDim2.new(1, -32, 0, 18) })
		local go = button(empty, "Ir para Ovo", "primary", UDim2.fromOffset(150, 40))
		go.Position = UDim2.fromOffset(16, 66)
		go.MouseButton1Click:Connect(function()
			setPanel("egg")
		end)
		return
	end
	local freeSlot = state.placedCount < state.slots
	for _, dino in ipairs(state.dinos) do
		local sp = Config.Species[dino.species]
		local cell = item(146)
		frame(cell, { Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = sp.color })
		label(cell, sp.name, TEXT.card, C.text, { Position = UDim2.fromOffset(12, 14), Size = UDim2.new(1, -24, 0, 22), Font = FONT_TITLE })
		pill(cell, sp.rarity:upper(), Config.RarityColors[sp.rarity], 12, 40)
		local status, statusColor
		if dino.placed then
			status, statusColor = "No habitat", C.ok
		elseif freeSlot then
			status, statusColor = "Disponível", C.text
		else
			status, statusColor = "Aguardando vaga", C.muted
		end
		label(cell, status, TEXT.caption, statusColor, { Position = UDim2.fromOffset(12, 68), Size = UDim2.new(1, -24, 0, 18), Font = FONT_STRONG })
		label(cell, ("+%d moedas a cada %d s"):format(sp.income, Config.IncomeInterval), TEXT.caption, C.muted, { Position = UDim2.fromOffset(12, 88), Size = UDim2.new(1, -24, 0, 18) })
		local id = dino.id
		if dino.placed then
			local b = button(cell, "Guardar", "ghost", UDim2.new(1, -24, 0, 34))
			b.Position = UDim2.fromOffset(12, 104)
			b.MouseButton1Click:Connect(function()
				request("remove", { id = id })
			end)
		elseif freeSlot then
			local b = button(cell, "Colocar", "primary", UDim2.new(1, -24, 0, 34))
			b.Position = UDim2.fromOffset(12, 104)
			b.MouseButton1Click:Connect(function()
				request("place", { id = id })
			end)
		else
			local b = button(cell, "Sem vaga", "disabled", UDim2.new(1, -24, 0, 34))
			b.Position = UDim2.fromOffset(12, 104)
			b.MouseButton1Click:Connect(function()
				showToast("Sem habitat livre. Compre um novo em Melhorias.", "info")
			end)
		end
	end
end

function renderers.shop()
	beginContent(false)
	panelTitle.Text = "Loja cosmética"
	local note = item(44)
	local noteText = label(note, "", TEXT.caption, C.muted, { Position = UDim2.fromOffset(16, 4), Size = UDim2.new(1, -32, 1, -8) })
	local function refreshNote()
		noteText.Text = "Troca em " .. fmt(state.nextRotation - Workspace:GetServerTimeNow()) .. " · mesmos itens para todos · só enfeites, sem vantagem de jogo"
	end
	refreshNote()
	liveLabels[#liveLabels + 1] = refreshNote
	for _, it in ipairs(state.shop) do
		local r = item(64)
		label(r, it.name, TEXT.card, C.text, { Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -170, 0, 22), Font = FONT_STRONG })
		label(r, it.kind == "fence" and "Cor de cerca" or "Decoração", TEXT.caption, C.muted, { Position = UDim2.fromOffset(16, 36), Size = UDim2.new(1, -170, 0, 18) })
		local id = it.id
		if it.owned then
			local b = button(r, "Na coleção", "ghost", UDim2.fromOffset(130, 40))
			b.Position = UDim2.new(1, -146, 0, 12)
		elseif state.coins >= it.price then
			local b = button(r, ("%d moedas"):format(it.price), "primary", UDim2.fromOffset(130, 40))
			b.Position = UDim2.new(1, -146, 0, 12)
			b.MouseButton1Click:Connect(function()
				request("buyShop", { id = id })
			end)
		else
			local missing = it.price - state.coins
			local b = button(r, "Faltam " .. missing, "disabled", UDim2.fromOffset(130, 40))
			b.Position = UDim2.new(1, -146, 0, 12)
			b.MouseButton1Click:Connect(function()
				showToast(("Faltam %d moedas para comprar %s."):format(missing, it.name), "info")
			end)
		end
	end
end

function renderers.upgrades()
	beginContent(false)
	panelTitle.Text = "Melhorias"
	for _, up in ipairs(state.upgrades) do
		local def = Config.Upgrades[up.key]
		local maxed = up.cost == false
		local r = item(112)
		label(r, def.name, TEXT.card, C.text, { Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -196, 0, 22), Font = FONT_STRONG })
		local _, fill = progressBar(r, UDim2.fromOffset(16, 38), UDim2.new(1, -196, 0, 8), C.primary)
		fill.Size = UDim2.fromScale(up.level / def.maxLevel, 1)
		label(r, ("Nível %d de %d"):format(up.level, def.maxLevel), TEXT.caption, C.muted, { Position = UDim2.fromOffset(16, 52), Size = UDim2.new(1, -196, 0, 18) })
		label(r, def.desc, TEXT.caption, C.muted, { Position = UDim2.fromOffset(16, 72), Size = UDim2.new(1, -32, 0, 18) })
		label(r, effectText(up.key, up.level, maxed), TEXT.caption, C.info, { Position = UDim2.fromOffset(16, 90), Size = UDim2.new(1, -32, 0, 18), Font = FONT_STRONG })
		local key = up.key
		if maxed then
			local b = button(r, "Máximo", "ghost", UDim2.fromOffset(130, 40))
			b.Position = UDim2.new(1, -146, 0, 14)
		elseif state.coins >= up.cost then
			local b = button(r, ("%d moedas"):format(up.cost), "primary", UDim2.fromOffset(130, 40))
			b.Position = UDim2.new(1, -146, 0, 14)
			b.MouseButton1Click:Connect(function()
				request("buyUpgrade", { key = key })
			end)
		else
			local missing = up.cost - state.coins
			local b = button(r, "Faltam " .. missing, "disabled", UDim2.fromOffset(130, 40))
			b.Position = UDim2.new(1, -146, 0, 14)
			b.MouseButton1Click:Connect(function()
				showToast(("Faltam %d moedas para %s."):format(missing, def.name), "info")
			end)
		end
	end
end

function renderers.missions()
	beginContent(false)
	panelTitle.Text = "Missões"
	local done, total = 0, #Config.Missions
	for _, m in ipairs(Config.Missions) do
		if state.missions[m.id] == true then
			done = done + 1
		end
	end
	local head = item(40)
	label(head, ("Concluídas: %d de %d"):format(done, total), TEXT.body, C.text, { Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -32, 1, 0), Font = FONT_STRONG })
	for _, m in ipairs(Config.Missions) do
		local isDone = state.missions[m.id] == true
		local r = item(60)
		pill(r, isDone and "FEITO" or "PENDENTE", isDone and C.ok or C.muted, 16, 20)
		label(r, m.text, TEXT.body, C.text, { Position = UDim2.fromOffset(120, 0), Size = UDim2.new(1, -236, 1, 0) })
		label(r, "+" .. m.reward, TEXT.body, C.gold, { Position = UDim2.new(1, -100, 0, 0), Size = UDim2.fromOffset(84, 60), Font = FONT_STRONG, TextXAlignment = Enum.TextXAlignment.Right })
	end
	local foot = item(36)
	label(foot, "Recompensas são pagas automaticamente ao completar.", TEXT.caption, C.muted, { Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -32, 1, 0) })
end

-- ===== layout responsivo (coordenadas lógicas; o UIScale ajusta à tela) =====
local function layout()
	-- AbsoluteSize do gui já desconta a barra superior do Roblox (IgnoreGuiInset = false)
	local v = gui.AbsoluteSize.X > 0 and gui.AbsoluteSize or (camera and camera.ViewportSize) or Vector2.new(1000, 600)
	local s = math.clamp(math.min(v.X / 900, v.Y / 560), 0.6, 1.25)
	scale.Scale = s
	root.Size = UDim2.fromScale(1 / s, 1 / s) -- o UIScale também escala o Root: compensa para ele cobrir a tela
	local W, H = v.X / s, v.Y / s
	view.W, view.H = W, H
	view.compact = W < 900

	local topY
	if view.compact then
		hud.Size = UDim2.fromOffset(math.min(250, W - 24), 74)
		objective.Position = UDim2.fromOffset(W / 2, 92)
		objective.Size = UDim2.fromOffset(W - 24, 64)
		unlock.Visible = false
		topY = 164
	else
		hud.Size = UDim2.fromOffset(250, 74)
		objective.Position = UDim2.fromOffset(W / 2, 10)
		objective.Size = UDim2.fromOffset(math.min(480, W - 540), 64)
		unlock.Visible = true
		unlock.Position = UDim2.fromOffset(W - 12, 10)
		topY = 84
	end
	toast.Position = UDim2.fromOffset(W / 2, topY)

	local panelW = math.min(560, W - 24)
	local panelH = math.max(260, math.min(view.compact and 640 or 460, H - topY - 96))
	panel.Position = UDim2.fromOffset(W / 2, topY + 8)
	panel.Size = UDim2.fromOffset(panelW, panelH)
	local cols = panelW >= 480 and 3 or 2
	view.cellW = math.floor((panelW - 30 - (cols - 1) * 8) / cols)

	local barW = math.min(720, W - 24)
	bar.Size = UDim2.fromOffset(barW, 60)
	bar.Position = UDim2.fromOffset(W / 2, H - 12)
	local cell = math.floor((barW - 12 - 5 * 6) / 6)
	navGrid.CellSize = UDim2.fromOffset(cell, 48)
	home.Size = UDim2.fromOffset(cell, 48)
end

-- ===== atualização de HUD, badges e objetivo =====
local function goalHint(id)
	if id == "hatch" then
		return state.incubating and "Seu ovo está chocando. Colete quando terminar." or "Abra Ovo e toque em Incubar."
	elseif id == "place" then
		return #state.dinos == 0 and "Choque um ovo primeiro." or "Abra Coleção e toque em Colocar."
	end
	local up = Logic.nextUpgrade(state)
	return up and (Config.Upgrades[up.key].name .. ": " .. costHint(up.cost)) or "Abra Melhorias e compre uma."
end

local function updateHud()
	coinsLabel.Text = tostring(state.coins)
	if state.canSave then
		rateLabel.Text = ("+%d moedas a cada %d s"):format(state.perTick, Config.IncomeInterval)
		rateLabel.TextColor3 = C.muted
	else
		rateLabel.Text = "Progresso não é salvo nesta sessão"
		rateLabel.TextColor3 = C.err
	end

	local goal = Logic.currentGoal(state, Config)
	local up = Logic.nextUpgrade(state)
	if goal then
		objTag.Text = "OBJETIVO"
		objText.Text = ("%s  ·  +%d moedas"):format(goal.text, goal.reward)
		objHint.Text = goalHint(goal.id)
	else
		objTag.Text = "PRÓXIMO PASSO"
		objText.Text = up and ("Comprar: " .. Config.Upgrades[up.key].name) or "Parque completo! Continue jogando."
		objHint.Text = up and costHint(up.cost) or "Todas as melhorias estão no máximo."
	end

	unlockName.Text = up and Config.Upgrades[up.key].name or "Tudo no máximo"
	unlockHint.Text = up and costHint(up.cost) or "Nada pendente"
	unlockHint.TextColor3 = (up and up.cost <= state.coins) and C.ok or C.muted
end

local function updateBadges()
	if not state then
		return
	end
	local up = Logic.nextUpgrade(state)
	badges.egg.Visible = isEggReady() or (state.incubating == false and state.eggs > 0)
	badges.collection.Visible = #state.dinos > state.placedCount and state.placedCount < state.slots
	badges.upgrades.Visible = up ~= nil and up.cost <= state.coins
end

-- ===== estado e avisos vindos do servidor =====
stateRE.OnClientEvent:Connect(function(s)
	local firstState = state == nil
	state = s
	loading.Visible = false

	if lastCoins and s.coins > lastCoins then
		floatText(hud, "+" .. (s.coins - lastCoins), C.gold, 170, 14)
	end
	lastCoins = s.coins

	-- dinossauro novo na lista = ovo coletado agora: mostra a revelação (não ao entrar, quando já existiam)
	local ids = {}
	for _, d in ipairs(s.dinos) do
		ids[d.id] = true
	end
	if knownDinos and not firstState then
		for _, d in ipairs(s.dinos) do
			if not knownDinos[d.id] then
				showReveal(d)
				break
			end
		end
	end
	knownDinos = ids

	if s.welcome and s.welcome ~= welcomeShown then
		welcomeShown = s.welcome
		showToast(s.welcome, "success")
	end
	if not s.canSave and not saveWarned then
		saveWarned = true
		showToast("Salvamento indisponível: o progresso desta sessão não será salvo.", "error")
	end

	updateHud()
	updateBadges()
	render()
end)

notifyRE.OnClientEvent:Connect(function(n)
	if type(n) == "table" and type(n.message) == "string" then
		showToast(n.message, n.kind)
	end
end)

-- ===== ciclo de 0,5 s: contagens regressivas, badges e troca de "pronto" =====
task.spawn(function()
	while true do
		task.wait(0.5)
		if state then
			for _, fn in ipairs(liveLabels) do
				fn()
			end
			updateBadges()
			if openPanel == "egg" and isEggReady() ~= eggReadyRendered then
				render()
			end
		end
	end
end)

-- ===== câmera: recalcula o layout quando a janela muda =====
local viewportConn = nil
local function watchCamera()
	camera = Workspace.CurrentCamera
	if viewportConn then
		viewportConn:Disconnect()
		viewportConn = nil
	end
	if camera then
		viewportConn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	end
	layout()
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
watchCamera()

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
