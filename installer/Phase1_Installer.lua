--!nonstrict
-- Dino Park Tycoon — Fase 1: instalador do primeiro cenário jogável.
-- COMO USAR: Roblox Studio > View > Command Bar, cole TODO este arquivo e pressione Enter.
-- Cria tudo dentro de Workspace/DinoParkMVP. É seguro rodar de novo:
-- se a pasta já existir, o script PARA e avisa (não apaga nada sem você autorizar).
-- Para recriar, mude REPLACE_EXISTING para true (só apaga a pasta DinoParkMVP gerada por este script).

local REPLACE_EXISTING = false

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local existing = Workspace:FindFirstChild("DinoParkMVP")
if existing then
	if not REPLACE_EXISTING then
		warn("[DinoPark] Workspace.DinoParkMVP já existe. Nada foi alterado. Mude REPLACE_EXISTING para true para recriar.")
		return
	end
	existing:Destroy()
end

-- Paleta
local C = {
	grass = Color3.fromRGB(106, 190, 80),
	grassDark = Color3.fromRGB(86, 165, 66),
	path = Color3.fromRGB(226, 205, 150),
	wood = Color3.fromRGB(139, 94, 60),
	leaf = Color3.fromRGB(58, 140, 70),
	leafLight = Color3.fromRGB(88, 170, 88),
	water = Color3.fromRGB(80, 170, 220),
	gate = Color3.fromRGB(200, 90, 60),
}

local root = Instance.new("Folder")
root.Name = "DinoParkMVP"
root.Parent = Workspace

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent or root
	return p
end

local function folder(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = root
	return f
end

-- Chão (60x60 studs de parque, ao redor de y = 0)
local ground = folder("Ground")
part({ Name = "Grass", Size = Vector3.new(120, 1, 120), Position = Vector3.new(0, -0.5, 0), Color = C.grass, Material = Enum.Material.Grass }, ground)
part({ Name = "GrassPatchA", Size = Vector3.new(30, 0.2, 30), Position = Vector3.new(-30, 0.05, 25), Color = C.grassDark, Material = Enum.Material.Grass, CanCollide = false }, ground)
part({ Name = "GrassPatchB", Size = Vector3.new(24, 0.2, 24), Position = Vector3.new(32, 0.05, -28), Color = C.grassDark, Material = Enum.Material.Grass, CanCollide = false }, ground)

-- Caminho do portão até o habitat
local paths = folder("Paths")
part({ Name = "PathMain", Size = Vector3.new(8, 0.3, 50), Position = Vector3.new(0, 0.15, 25), Color = C.path, Material = Enum.Material.Sand }, paths)
part({ Name = "PathPlaza", Size = Vector3.new(22, 0.3, 22), Position = Vector3.new(0, 0.15, -5), Color = C.path, Material = Enum.Material.Sand }, paths)

-- Habitat: cerca quadrada com abertura no lado do caminho + lago pequeno
local habitat = folder("Habitat")
local H_CENTER = Vector3.new(0, 0, -5)
local H_HALF = 22 -- metade do lado
local function fenceSegment(name, center, size)
	part({ Name = name, Size = size, Position = center + Vector3.new(0, size.Y / 2, 0), Color = C.wood, Material = Enum.Material.Wood }, habitat)
end
local fh, fw = 3, 1
-- fundo, esquerda, direita
fenceSegment("FenceBack", H_CENTER + Vector3.new(0, 0, -H_HALF), Vector3.new(H_HALF * 2, fh, fw))
fenceSegment("FenceLeft", H_CENTER + Vector3.new(-H_HALF, 0, 0), Vector3.new(fw, fh, H_HALF * 2))
fenceSegment("FenceRight", H_CENTER + Vector3.new(H_HALF, 0, 0), Vector3.new(fw, fh, H_HALF * 2))
-- frente (lado do portão) com abertura de 8 studs no meio
local sideLen = (H_HALF * 2 - 8) / 2
fenceSegment("FenceFrontL", H_CENTER + Vector3.new(-(4 + sideLen / 2), 0, H_HALF), Vector3.new(sideLen, fh, fw))
fenceSegment("FenceFrontR", H_CENTER + Vector3.new(4 + sideLen / 2, 0, H_HALF), Vector3.new(sideLen, fh, fw))

part({ Name = "Pond", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 12, 12), CFrame = CFrame.new(H_CENTER + Vector3.new(-12, 0.2, -10)) * CFrame.Angles(0, 0, math.rad(90)), Color = C.water, Material = Enum.Material.Glass, Transparency = 0.2, CanCollide = false }, habitat)

-- Portão de entrada (fim do caminho, z = 50)
local gate = folder("Gate")
part({ Name = "PostL", Size = Vector3.new(2, 10, 2), Position = Vector3.new(-6, 5, 50), Color = C.wood, Material = Enum.Material.Wood }, gate)
part({ Name = "PostR", Size = Vector3.new(2, 10, 2), Position = Vector3.new(6, 5, 50), Color = C.wood, Material = Enum.Material.Wood }, gate)
part({ Name = "Beam", Size = Vector3.new(16, 2, 2), Position = Vector3.new(0, 10, 50), Color = C.gate, Material = Enum.Material.Wood }, gate)
local sign = part({ Name = "Sign", Size = Vector3.new(10, 3, 0.5), Position = Vector3.new(0, 7.5, 50), Color = C.wood, Material = Enum.Material.Wood }, gate)
local sg = Instance.new("SurfaceGui")
sg.Face = Enum.NormalId.Back
sg.Parent = sign
local sgl = Instance.new("TextLabel")
sgl.Size = UDim2.fromScale(1, 1)
sgl.BackgroundTransparency = 1
sgl.Text = "Dino Park"
sgl.TextScaled = true
sgl.Font = Enum.Font.FredokaOne
sgl.TextColor3 = Color3.new(1, 1, 1)
sgl.Parent = sg
local sg2 = sg:Clone()
sg2.Face = Enum.NormalId.Front
sg2.Parent = sign

-- Árvores low-poly
local trees = folder("Trees")
local treeSpots = {
	Vector3.new(-40, 0, 40), Vector3.new(-48, 0, 10), Vector3.new(-42, 0, -30), Vector3.new(-30, 0, -50),
	Vector3.new(40, 0, 42), Vector3.new(48, 0, 12), Vector3.new(44, 0, -32), Vector3.new(28, 0, -50),
	Vector3.new(-18, 0, 45), Vector3.new(18, 0, 38), Vector3.new(-12, 0, -52), Vector3.new(10, 0, -54),
}
for i, pos in ipairs(treeSpots) do
	local h = 6 + (i % 3) * 2
	local t = Instance.new("Model")
	t.Name = "Tree" .. i
	t.Parent = trees
	part({ Name = "Trunk", Size = Vector3.new(1.6, h, 1.6), Position = pos + Vector3.new(0, h / 2, 0), Color = C.wood, Material = Enum.Material.Wood }, t)
	part({ Name = "Crown1", Size = Vector3.new(8, 5, 8), Position = pos + Vector3.new(0, h + 1.5, 0), Color = C.leaf, Material = Enum.Material.Grass }, t)
	part({ Name = "Crown2", Size = Vector3.new(5.5, 4, 5.5), Position = pos + Vector3.new(0, h + 4.5, 0), Color = C.leafLight, Material = Enum.Material.Grass }, t)
end

-- Spawn (perto do portão, olhando para dentro do parque)
local spawn = Instance.new("SpawnLocation")
spawn.Name = "ParkSpawn"
spawn.Anchored = true
spawn.Size = Vector3.new(8, 1, 8)
spawn.Position = Vector3.new(0, 0.5, 40)
spawn.Color = C.path
spawn.Material = Enum.Material.SmoothPlastic
spawn.Neutral = true
spawn.TopSurface = Enum.SurfaceType.Smooth
spawn.CFrame = CFrame.lookAt(spawn.Position, Vector3.new(0, 0.5, 0))
spawn.Parent = root

-- Dinossauro "Leafling" feito de Parts (ver docs; modelo gerado por função)
local function buildLeafling(origin)
	local body = Color3.fromRGB(110, 200, 100)
	local belly = Color3.fromRGB(225, 240, 160)
	local dark = Color3.fromRGB(60, 140, 70)
	local model = Instance.new("Model")
	model.Name = "Leafling"
	model:SetAttribute("SpeciesId", "leafling")
	model:SetAttribute("Rarity", "Common")

	local function p(name, size, offset, color, shape)
		local x = Instance.new("Part")
		x.Name = name
		x.Anchored = true
		x.Size = size
		x.CFrame = origin * CFrame.new(offset)
		x.Color = color
		x.Material = Enum.Material.SmoothPlastic
		x.TopSurface = Enum.SurfaceType.Smooth
		x.BottomSurface = Enum.SurfaceType.Smooth
		if shape then
			x.Shape = shape
		end
		x.Parent = model
		return x
	end

	local torso = p("Torso", Vector3.new(3, 2.6, 4.6), Vector3.new(0, 2.6, 0), body)
	p("Belly", Vector3.new(2.4, 1, 3.8), Vector3.new(0, 1.65, 0.1), belly)
	p("Neck", Vector3.new(1.4, 2.2, 1.4), Vector3.new(0, 4.2, -2), body)
	local head = p("Head", Vector3.new(2.4, 2, 2.8), Vector3.new(0, 5.5, -2.7), body)
	p("Snout", Vector3.new(1.6, 1.1, 1.2), Vector3.new(0, 5.2, -4.4), body)
	p("EyeL", Vector3.new(0.5, 0.5, 0.5), Vector3.new(-1.05, 5.9, -3.4), Color3.new(0.05, 0.05, 0.05), Enum.PartType.Ball)
	p("EyeR", Vector3.new(0.5, 0.5, 0.5), Vector3.new(1.05, 5.9, -3.4), Color3.new(0.05, 0.05, 0.05), Enum.PartType.Ball)
	for i = 0, 2 do
		p("Spike" .. i, Vector3.new(0.5, 0.9, 0.9), Vector3.new(0, 4.25, -0.9 + i * 1.3), dark)
	end
	-- cauda (duas partes, afinando)
	p("Tail1", Vector3.new(1.8, 1.6, 2.6), Vector3.new(0, 2.3, 3.4), body)
	p("Tail2", Vector3.new(1.1, 1.0, 2.4), Vector3.new(0, 2.1, 5.4), body)
	p("TailTip", Vector3.new(0.6, 0.6, 1.4), Vector3.new(0, 2.0, 6.9), dark)
	-- patas
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1.4, 1.5 }) do
			p("Leg", Vector3.new(0.9, 1.4, 1.0), Vector3.new(sx * 1.0, 0.7, sz), dark)
		end
	end

	model.PrimaryPart = torso
	return model, head
end

local dinoOrigin = CFrame.new(0, 0, -8) * CFrame.Angles(0, math.rad(180), 0) -- de frente para o portão
local dino, dinoHead = buildLeafling(dinoOrigin)
dino.Parent = root

-- Interação: ProximityPrompt no dinossauro (script de servidor embutido)
local prompt = Instance.new("ProximityPrompt")
prompt.ActionText = "Cumprimentar"
prompt.ObjectText = "Leafling"
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 14
prompt.RequiresLineOfSight = false
prompt.Parent = dino.PrimaryPart

local billboard = Instance.new("BillboardGui")
billboard.Name = "NameTag"
billboard.Size = UDim2.fromOffset(160, 44)
billboard.StudsOffset = Vector3.new(0, 4, 0)
billboard.AlwaysOnTop = true
billboard.Adornee = dinoHead
billboard.Parent = dino
local tag = Instance.new("TextLabel")
tag.Size = UDim2.fromScale(1, 1)
tag.BackgroundTransparency = 0.25
tag.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
tag.Text = "Leafling (Comum)"
tag.TextColor3 = Color3.new(1, 1, 1)
tag.TextScaled = true
tag.Font = Enum.Font.FredokaOne
tag.Parent = billboard
Instance.new("UICorner", tag)

local interact = Instance.new("Script")
interact.Name = "LeaflingInteraction"
interact.Source = [[
local dino = script.Parent
local prompt = dino.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
local busy = false
prompt.Triggered:Connect(function(player)
	if busy then return end
	busy = true
	local base = dino:GetPivot()
	for _ = 1, 2 do
		for step = 1, 8 do
			dino:PivotTo(base * CFrame.new(0, math.sin(step / 8 * math.pi) * 2.5, 0))
			task.wait(0.03)
		end
	end
	dino:PivotTo(base)
	busy = false
end)
]]
interact.Parent = dino

-- Iluminação e céu (cartoon claro)
Lighting.ClockTime = 14
Lighting.Brightness = 2.5
Lighting.Ambient = Color3.fromRGB(120, 130, 140)
Lighting.OutdoorAmbient = Color3.fromRGB(140, 150, 160)
Lighting.GeographicLatitude = 20
if not Lighting:FindFirstChild("DinoParkAtmosphere") then
	local a = Instance.new("Atmosphere")
	a.Name = "DinoParkAtmosphere"
	a.Density = 0.25
	a.Color = Color3.fromRGB(200, 225, 255)
	a.Parent = Lighting
end

-- Remove SpawnLocation/Baseplate padrão? NÃO removemos nada seu. Se o template já tem
-- um Baseplate ou SpawnLocation, apague manualmente para evitar spawn duplicado.
print("[DinoPark] Fase 1 instalada em Workspace.DinoParkMVP. Pressione Play (F5).")
