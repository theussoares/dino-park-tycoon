--!nonstrict
-- Dino Park Tycoon — Parte 1: cenário estático (chão, avenidas, portão, árvores, spawn, luz).
-- Cole na Command Bar do Roblox Studio. Cria tudo em Workspace.DinoParkWorld.
-- Seguro para repetir: se a pasta já existir, PARA sem alterar nada (mude REPLACE_EXISTING para recriar;
-- isso só apaga Workspace.DinoParkWorld, gerada por este script).
local REPLACE_EXISTING = false

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local existing = Workspace:FindFirstChild("DinoParkWorld")
if existing then
	if not REPLACE_EXISTING then
		warn("[DinoPark] Workspace.DinoParkWorld já existe. Nada foi alterado.")
		return
	end
	existing:Destroy()
end

local C = {
	grass = Color3.fromRGB(106, 190, 80),
	grassDark = Color3.fromRGB(86, 165, 66),
	path = Color3.fromRGB(226, 205, 150),
	wood = Color3.fromRGB(139, 94, 60),
	leaf = Color3.fromRGB(58, 140, 70),
	leafLight = Color3.fromRGB(88, 170, 88),
	gate = Color3.fromRGB(200, 90, 60),
	stone = Color3.fromRGB(135, 140, 150),
}

local root = Instance.new("Folder")
root.Name = "DinoParkWorld"
root.Parent = Workspace

local function folder(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = root
	return f
end

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

-- Chão
local ground = folder("Ground")
part({ Name = "Grass", Size = Vector3.new(260, 1, 260), Position = Vector3.new(0, -0.5, 0), Color = C.grass, Material = Enum.Material.Grass }, ground)
part({ Name = "PatchA", Size = Vector3.new(40, 0.2, 40), Position = Vector3.new(-20, 0.05, 0), Color = C.grassDark, Material = Enum.Material.Grass, CanCollide = false }, ground)
part({ Name = "PatchB", Size = Vector3.new(34, 0.2, 34), Position = Vector3.new(24, 0.05, 6), Color = C.grassDark, Material = Enum.Material.Grass, CanCollide = false }, ground)
-- muro baixo de borda (delimita o mapa)
local bounds = folder("Bounds")
for _, d in ipairs({ { 0, 130, 262, 1 }, { 0, -130, 262, 1 }, { 130, 0, 1, 262 }, { -130, 0, 1, 262 } }) do
	part({ Name = "Wall", Size = Vector3.new(d[3], 8, d[4]), Position = Vector3.new(d[1], 4, d[2]), Color = C.stone, Material = Enum.Material.Slate, Transparency = 0.5 }, bounds)
end

-- Avenidas: principal (eixo Z) e travessas até cada parque (eixo X)
local paths = folder("Paths")
part({ Name = "AvenueMain", Size = Vector3.new(10, 0.3, 240), Position = Vector3.new(0, 0.15, 0), Color = C.path, Material = Enum.Material.Sand }, paths)
part({ Name = "Plaza", Size = Vector3.new(26, 0.32, 26), Position = Vector3.new(0, 0.16, 0), Color = Color3.fromRGB(238, 222, 175), Material = Enum.Material.Sand }, paths)
for _, z in ipairs({ -50, 50 }) do
	part({ Name = "Branch" .. z, Size = Vector3.new(80, 0.3, 8), Position = Vector3.new(0, 0.15, z), Color = C.path, Material = Enum.Material.Sand }, paths)
end

-- Praça: fonte de pedra e canteiros
local plaza = folder("Plaza")
part({ Name = "FountainBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 9, 9), CFrame = CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = C.stone, Material = Enum.Material.Marble }, plaza)
part({ Name = "FountainWater", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 7.6, 7.6), CFrame = CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(90, 180, 235), Material = Enum.Material.Glass, Transparency = 0.2 }, plaza)
part({ Name = "FountainColumn", Size = Vector3.new(1.4, 4, 1.4), Position = Vector3.new(0, 3, 0), Color = C.stone, Material = Enum.Material.Marble }, plaza)

-- Portão de entrada (spawn fica antes dele, olhando para a praça)
local gate = folder("Gate")
part({ Name = "PostL", Size = Vector3.new(2.4, 12, 2.4), Position = Vector3.new(-8, 6, 100), Color = C.wood, Material = Enum.Material.Wood }, gate)
part({ Name = "PostR", Size = Vector3.new(2.4, 12, 2.4), Position = Vector3.new(8, 6, 100), Color = C.wood, Material = Enum.Material.Wood }, gate)
part({ Name = "Beam", Size = Vector3.new(20, 2.4, 2.4), Position = Vector3.new(0, 12, 100), Color = C.gate, Material = Enum.Material.Wood }, gate)
local sign = part({ Name = "Sign", Size = Vector3.new(14, 4, 0.6), Position = Vector3.new(0, 8.8, 100), Color = C.wood, Material = Enum.Material.Wood }, gate)
for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.Parent = sign
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = "Dino Park"
	l.TextScaled = true
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Parent = sg
end

-- Árvores low-poly (fora das áreas dos parques)
local trees = folder("Trees")
local spots = {
	{ -105, 105 }, { -112, 70 }, { -100, 0 }, { -108, -60 }, { -100, -105 }, { -70, -112 },
	{ 105, 105 }, { 112, 70 }, { 100, 0 }, { 108, -60 }, { 100, -105 }, { 70, -112 },
	{ -20, -110 }, { 22, -112 }, { -24, 112 }, { 26, 114 }, { -20, 30 }, { 22, -28 }, { -22, -78 }, { 24, 80 },
	{ -35, 0 }, { 36, 0 }, { -90, 20 }, { 90, -18 },
}
for i, s in ipairs(spots) do
	local h = 6 + (i % 3) * 2
	local m = Instance.new("Model")
	m.Name = "Tree" .. i
	m.Parent = trees
	local pos = Vector3.new(s[1], 0, s[2])
	part({ Name = "Trunk", Size = Vector3.new(1.8, h, 1.8), Position = pos + Vector3.new(0, h / 2, 0), Color = C.wood, Material = Enum.Material.Wood }, m)
	part({ Name = "Crown1", Size = Vector3.new(9, 5, 9), Position = pos + Vector3.new(0, h + 1.5, 0), Color = C.leaf, Material = Enum.Material.Grass }, m)
	part({ Name = "Crown2", Size = Vector3.new(6, 4, 6), Position = pos + Vector3.new(0, h + 4.5, 0), Color = C.leafLight, Material = Enum.Material.Grass }, m)
end

-- Pedras decorativas
local rocks = folder("Rocks")
for i, s in ipairs({ { -14, 90 }, { 15, 88 }, { -16, -90 }, { 14, -92 }, { -40, 14 }, { 42, -12 } }) do
	part({ Name = "Rock" .. i, Size = Vector3.new(3 + i % 3, 2 + i % 2, 3), CFrame = CFrame.new(s[1], 1, s[2]) * CFrame.Angles(0, math.rad(i * 37), 0), Color = C.stone, Material = Enum.Material.Slate }, rocks)
end

-- Spawn
local spawn = Instance.new("SpawnLocation")
spawn.Name = "ParkSpawn"
spawn.Anchored = true
spawn.Neutral = true
spawn.Size = Vector3.new(12, 1, 12)
spawn.Color = Color3.fromRGB(238, 222, 175)
spawn.Material = Enum.Material.SmoothPlastic
spawn.TopSurface = Enum.SurfaceType.Smooth
spawn.CFrame = CFrame.lookAt(Vector3.new(0, 0.5, 85), Vector3.new(0, 0.5, 0))
spawn.Parent = root

-- Iluminação
Lighting.ClockTime = 14
Lighting.Brightness = 2.5
Lighting.Ambient = Color3.fromRGB(120, 130, 140)
Lighting.OutdoorAmbient = Color3.fromRGB(140, 150, 160)
if not Lighting:FindFirstChild("DinoParkAtmosphere") then
	local a = Instance.new("Atmosphere")
	a.Name = "DinoParkAtmosphere"
	a.Density = 0.25
	a.Color = Color3.fromRGB(200, 225, 255)
	a.Parent = Lighting
end

print("[DinoPark] Parte 1 (cenário) instalada. Agora rode a Parte 2 (scripts).")
print("[DinoPark] Apague o Baseplate e o SpawnLocation padrão do template, se existirem.")
