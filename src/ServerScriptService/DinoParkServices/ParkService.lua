--!nonstrict
-- Parques por jogador: constrói 4 parques estáticos no início e redesenha a parte dinâmica
-- (dinossauros, cercas, decorações, habitats) quando os dados mudam.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Logic = require(Shared:WaitForChild("Logic"))
local DinoModels = require(Shared:WaitForChild("DinoModels"))

local ParkService = {}

local plots = {} -- [index] = { base=CFrame, owner=Player|nil, folder=, dynamic=, fenceParts={}, signLabel=, incubLabel=, eggPart= }
local ownerPlot = {} -- [Player] = index
local root = nil

local function mk(parent, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function billboard(adornee, text, offsetY, width)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(width or 150, 36)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 80
	gui.Adornee = adornee
	gui.Parent = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(30, 50, 35)
	label.BackgroundTransparency = 0.25
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.Parent = label
	return label
end

local function buildPlot(index, def)
	local center = Vector3.new(def.x, 0, def.z)
	local base = CFrame.lookAt(center, Vector3.new(0, 0, def.z)) -- -Z local aponta para a avenida central
	local function at(x, y, z)
		return base * CFrame.new(x, y, z)
	end
	local H = Config.PlotHalf
	local folder = Instance.new("Folder")
	folder.Name = "Plot" .. index
	folder.Parent = root
	local plot = { base = base, owner = nil, folder = folder, fenceParts = {} }

	mk(folder, "Floor", Vector3.new(H * 2, 0.3, H * 2), at(0, 0.15, 0), Color3.fromRGB(150, 215, 120), Enum.Material.Grass)
	local woodColor = Config.DefaultFenceColor
	local function fence(name, size, x, z)
		local p = mk(folder, name, size, at(x, size.Y / 2, z), woodColor, Enum.Material.Wood)
		plot.fenceParts[#plot.fenceParts + 1] = p
	end
	fence("FenceBack", Vector3.new(H * 2, 3, 1), 0, H)
	fence("FenceLeft", Vector3.new(1, 3, H * 2), -H, 0)
	fence("FenceRight", Vector3.new(1, 3, H * 2), H, 0)
	local side = (H * 2 - 8) / 2
	fence("FenceFrontL", Vector3.new(side, 3, 1), -(4 + side / 2), -H)
	fence("FenceFrontR", Vector3.new(side, 3, 1), 4 + side / 2, -H)

	-- placa do parque (lado da entrada)
	mk(folder, "SignPost", Vector3.new(0.8, 6, 0.8), at(-11, 3, -H - 1.5), Color3.fromRGB(110, 75, 50), Enum.Material.Wood)
	local board = mk(folder, "SignBoard", Vector3.new(9, 2.8, 0.4), at(-11, 6.4, -H - 1.5), Color3.fromRGB(235, 215, 170), Enum.Material.Wood)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(70, 45, 25)
	label.Text = "Parque livre"
	label.Parent = gui
	plot.signLabel = label

	-- incubadora
	mk(folder, "IncubatorBase", Vector3.new(5, 1.2, 5), at(0, 0.9, -10), Color3.fromRGB(190, 160, 120), Enum.Material.Wood)
	local egg = mk(folder, "Egg", Vector3.new(3.4, 3.4, 3.4), at(0, 3.2, -10), Color3.fromRGB(250, 240, 215), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	egg.CanCollide = false -- decorativo: não deixa o jogador ficar em cima dele
	plot.eggPart = egg
	for i = 1, 3 do
		mk(folder, "EggSpot" .. i, Vector3.new(0.7, 0.7, 0.7), at(-1 + i * 0.9, 3 + (i % 2) * 0.9, -11.5), Color3.fromRGB(120, 200, 110), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
	plot.incubLabel = billboard(egg, "Incubadora vazia", 3.2, 200)

	local dynamic = Instance.new("Folder")
	dynamic.Name = "Dynamic"
	dynamic.Parent = folder
	plot.dynamic = dynamic
	plots[index] = plot
end

function ParkService.init()
	root = Instance.new("Folder")
	root.Name = "DinoParkPlots"
	root.Parent = Workspace
	for index, def in ipairs(Config.Plots) do
		buildPlot(index, def)
	end
end

function ParkService.claim(player)
	if ownerPlot[player] then
		return ownerPlot[player]
	end
	for index, plot in ipairs(plots) do
		if not plot.owner then
			plot.owner = player
			ownerPlot[player] = index
			plot.signLabel.Text = "Parque de " .. player.DisplayName
			return index
		end
	end
	return nil
end

local function clear(plot)
	plot.dynamic:ClearAllChildren()
	for _, part in ipairs(plot.fenceParts) do
		part.Color = Config.DefaultFenceColor
	end
end

function ParkService.release(player)
	local index = ownerPlot[player]
	if not index then
		return
	end
	local plot = plots[index]
	clear(plot)
	plot.owner = nil
	plot.signLabel.Text = "Parque livre"
	plot.incubLabel.Text = "Incubadora vazia"
	ownerPlot[player] = nil
end

function ParkService.plotIndex(player)
	return ownerPlot[player]
end

-- Entrada do parque (para o botão "Meu Parque"), um pouco acima do chão.
function ParkService.entranceCFrame(player)
	local index = ownerPlot[player]
	if not index then
		return nil
	end
	return plots[index].base * CFrame.new(0, 4, -Config.PlotHalf - 6) * CFrame.Angles(0, math.rad(180), 0)
end

-- Redesenha dinossauros, habitats, decorações e cercas a partir dos dados do jogador.
function ParkService.refresh(player, data)
	local index = ownerPlot[player]
	if not index then
		return
	end
	local plot = plots[index]
	clear(plot)
	local slots = Logic.slots(data, Config)
	for i, pos in ipairs(Config.PadPositions) do
		local unlocked = i <= slots
		local color = unlocked and Color3.fromRGB(120, 190, 95) or Color3.fromRGB(150, 150, 150)
		local pad = mk(plot.dynamic, "Pad" .. i, Vector3.new(0.4, 7, 7), plot.base * CFrame.new(pos[1], 0.5, pos[2]) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.Grass, Enum.PartType.Cylinder)
		if not unlocked then
			pad.Material = Enum.Material.Slate
			pad.Transparency = 0.35
		end
	end
	for i, dinoId in ipairs(data.placed) do
		local dino = Logic.findDino(data, dinoId)
		local pos = Config.PadPositions[i]
		if dino and pos then
			local cf = plot.base * CFrame.new(pos[1], 0.7, pos[2])
			local model, height = DinoModels.buildDino(dino.species, cf, plot.dynamic)
			if model then
				local sp = Config.Species[dino.species]
				billboard(model.PrimaryPart, sp.name, height - 1.5, 130)
			end
		end
	end
	for _, item in ipairs(Config.ShopCatalog) do
		if data.owned[item.id] and item.kind == "decor" then
			local spot = Config.DecorSpots[item.spot]
			if spot then
				DinoModels.buildDecor(item.id, plot.base * CFrame.new(spot[1], 0.3, spot[2]), plot.dynamic)
			end
		end
	end
	local fenceItem = Logic.catalogItem(Config, data.fence)
	local color = (fenceItem and fenceItem.kind == "fence" and fenceItem.color) or Config.DefaultFenceColor
	for _, part in ipairs(plot.fenceParts) do
		part.Color = color
	end
end

-- Texto da incubadora (chamado ~1x/s).
function ParkService.updateIncubator(player, data, now)
	local index = ownerPlot[player]
	if not index then
		return
	end
	local plot = plots[index]
	local inc = data.incubating
	if not inc then
		plot.incubLabel.Text = "Incubadora vazia"
	elseif now >= inc.readyAt then
		plot.incubLabel.Text = "Pronto! Abra Ovo > Coletar"
	else
		plot.incubLabel.Text = ("Chocando... %ds"):format(math.ceil(inc.readyAt - now))
	end
end

return ParkService
