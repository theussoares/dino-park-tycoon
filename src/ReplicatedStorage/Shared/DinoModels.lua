--!nonstrict
-- Modelos procedurais (Parts) dos dinossauros e das decorações. Todos olham para -Z (frente local).
local Config = require(script.Parent:WaitForChild("Config"))

local M = {}

local function newBuilder(model, origin, s)
	return function(name, size, offset, color, shape, material)
		local x = Instance.new("Part")
		x.Name = name
		x.Anchored = true
		x.CanCollide = false
		x.Size = size * s
		x.CFrame = origin * CFrame.new(offset * s)
		x.Color = color
		x.Material = material or Enum.Material.SmoothPlastic
		x.TopSurface = Enum.SurfaceType.Smooth
		x.BottomSurface = Enum.SurfaceType.Smooth
		if shape then
			x.Shape = shape
		end
		x.Parent = model
		return x
	end
end

local function shade(c, f)
	return Color3.new(math.clamp(c.R * f, 0, 1), math.clamp(c.G * f, 0, 1), math.clamp(c.B * f, 0, 1))
end

local BALL = Enum.PartType.Ball
local EYE = Color3.new(0.05, 0.05, 0.05)

local function leafling(p, color)
	local belly = Color3.fromRGB(225, 240, 160)
	local dark = shade(color, 0.55)
	local torso = p("Body", Vector3.new(3, 2.6, 4.6), Vector3.new(0, 2.6, 0), color)
	p("Belly", Vector3.new(2.4, 1, 3.8), Vector3.new(0, 1.65, 0.1), belly)
	p("Neck", Vector3.new(1.4, 2.2, 1.4), Vector3.new(0, 4.2, -2), color)
	p("Head", Vector3.new(2.4, 2, 2.8), Vector3.new(0, 5.5, -2.7), color)
	p("Snout", Vector3.new(1.6, 1.1, 1.2), Vector3.new(0, 5.2, -4.4), color)
	p("EyeL", Vector3.new(0.5, 0.5, 0.5), Vector3.new(-1.05, 5.9, -3.4), EYE, BALL)
	p("EyeR", Vector3.new(0.5, 0.5, 0.5), Vector3.new(1.05, 5.9, -3.4), EYE, BALL)
	for i = 0, 2 do
		p("Spike" .. i, Vector3.new(0.5, 0.9, 0.9), Vector3.new(0, 4.25, -0.9 + i * 1.3), dark)
	end
	p("Tail1", Vector3.new(1.8, 1.6, 2.6), Vector3.new(0, 2.3, 3.4), color)
	p("Tail2", Vector3.new(1.1, 1.0, 2.4), Vector3.new(0, 2.1, 5.4), color)
	p("TailTip", Vector3.new(0.6, 0.6, 1.4), Vector3.new(0, 2.0, 6.9), dark)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1.4, 1.5 }) do
			p("Leg", Vector3.new(0.9, 1.4, 1.0), Vector3.new(sx * 1.0, 0.7, sz), dark)
		end
	end
	return torso, 7.2
end

local function pebbleback(p, color)
	local dark = shade(color, 0.6)
	local plate = Color3.fromRGB(95, 100, 115)
	local torso = p("Body", Vector3.new(4.6, 3.2, 6.4), Vector3.new(0, 2.9, 0), color)
	p("Belly", Vector3.new(3.8, 1, 5.6), Vector3.new(0, 1.55, 0), shade(color, 1.25))
	p("Head", Vector3.new(2.8, 2.4, 2.8), Vector3.new(0, 2.7, -4.4), color)
	p("Snout", Vector3.new(2, 1.2, 1.2), Vector3.new(0, 2.3, -5.9), color)
	p("EyeL", Vector3.new(0.5, 0.5, 0.5), Vector3.new(-1.1, 3.2, -5.4), EYE, BALL)
	p("EyeR", Vector3.new(0.5, 0.5, 0.5), Vector3.new(1.1, 3.2, -5.4), EYE, BALL)
	for i = 0, 3 do
		p("Plate" .. i, Vector3.new(3.4 - i * 0.3, 0.9, 1.1), Vector3.new(0, 4.8, -2.2 + i * 1.6), plate, nil, Enum.Material.Slate)
	end
	p("Tail1", Vector3.new(2.2, 1.8, 2.6), Vector3.new(0, 2.5, 4.4), color)
	p("Tail2", Vector3.new(1.4, 1.2, 2.2), Vector3.new(0, 2.2, 6.3), dark)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -2.2, 2.2 }) do
			p("Leg", Vector3.new(1.5, 1.8, 1.5), Vector3.new(sx * 1.7, 0.9, sz), dark)
		end
	end
	return torso, 5.6
end

local function embercrest(p, color)
	local crest = Color3.fromRGB(255, 110, 30)
	local dark = shade(color, 0.6)
	local torso = p("Body", Vector3.new(2.2, 2.4, 3.2), Vector3.new(0, 3.3, 0), color)
	p("Belly", Vector3.new(1.7, 1, 2.6), Vector3.new(0, 2.4, -0.1), Color3.fromRGB(255, 232, 190))
	p("Neck", Vector3.new(1.1, 2.2, 1.1), Vector3.new(0, 5, -1.5), color)
	p("Head", Vector3.new(1.8, 1.6, 2.4), Vector3.new(0, 6.3, -2.1), color)
	p("Snout", Vector3.new(1.2, 0.9, 1.1), Vector3.new(0, 6.1, -3.6), color)
	p("EyeL", Vector3.new(0.45, 0.45, 0.45), Vector3.new(-0.85, 6.6, -2.8), Color3.fromRGB(255, 230, 80), BALL)
	p("EyeR", Vector3.new(0.45, 0.45, 0.45), Vector3.new(0.85, 6.6, -2.8), Color3.fromRGB(255, 230, 80), BALL)
	for i = 0, 3 do
		local c = p("Crest" .. i, Vector3.new(0.35, 1.5 - i * 0.2, 0.9), Vector3.new(0, 7.4 - i * 0.55, -1.4 + i * 0.75), crest)
		c.CFrame = c.CFrame * CFrame.Angles(math.rad(-15), 0, 0)
	end
	p("Tail1", Vector3.new(1.2, 1.2, 3), Vector3.new(0, 3, 3.4), color)
	p("Tail2", Vector3.new(0.8, 0.8, 3), Vector3.new(0, 2.8, 6.2), color)
	p("TailTip", Vector3.new(0.5, 0.5, 1.2), Vector3.new(0, 2.7, 8.2), crest)
	for _, sx in ipairs({ -1, 1 }) do
		p("Leg", Vector3.new(0.9, 2.2, 1.1), Vector3.new(sx * 0.9, 1.1, 0.3), dark)
		p("Arm", Vector3.new(0.5, 0.5, 1), Vector3.new(sx * 1.25, 3.3, -1.4), dark)
	end
	return torso, 8.6
end

local builders = { leafling = leafling, pebbleback = pebbleback, embercrest = embercrest }

-- Constrói o modelo da espécie em 'origin' (CFrame no chão). Devolve Model e altura (para a etiqueta).
function M.buildDino(speciesId, origin, parent)
	local sp = Config.Species[speciesId]
	local builder = builders[speciesId]
	if not sp or not builder then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = sp.name
	model:SetAttribute("SpeciesId", speciesId)
	local p = newBuilder(model, origin, sp.scale)
	local primary, height = builder(p, sp.color)
	model.PrimaryPart = primary
	model.Parent = parent
	return model, height * sp.scale
end

-- Decorações cosméticas (origin = CFrame no chão).
local decor = {}

function decor.lamp(p)
	p("Post", Vector3.new(0.6, 7, 0.6), Vector3.new(0, 3.5, 0), Color3.fromRGB(70, 70, 80), nil, Enum.Material.Metal)
	local bulb = p("Bulb", Vector3.new(1.6, 1.6, 1.6), Vector3.new(0, 7.6, 0), Color3.fromRGB(255, 235, 150), BALL, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 1.5
	light.Color = Color3.fromRGB(255, 225, 150)
	light.Parent = bulb
end

function decor.flowers(p)
	p("Bed", Vector3.new(5, 0.6, 3), Vector3.new(0, 0.3, 0), Color3.fromRGB(110, 75, 50), nil, Enum.Material.Wood)
	local colors = { Color3.fromRGB(255, 120, 150), Color3.fromRGB(255, 220, 90), Color3.fromRGB(190, 130, 255) }
	for i = 1, 6 do
		p("Flower" .. i, Vector3.new(0.8, 0.8, 0.8), Vector3.new(-2 + (i - 1) * 0.8, 1.1, ((i % 2) - 0.5) * 1.2), colors[i % 3 + 1], BALL)
	end
end

function decor.banner(p)
	p("PostL", Vector3.new(0.5, 8, 0.5), Vector3.new(-3, 4, 0), Color3.fromRGB(139, 94, 60), nil, Enum.Material.Wood)
	p("PostR", Vector3.new(0.5, 8, 0.5), Vector3.new(3, 4, 0), Color3.fromRGB(139, 94, 60), nil, Enum.Material.Wood)
	local colors = { Color3.fromRGB(240, 90, 90), Color3.fromRGB(250, 200, 70), Color3.fromRGB(90, 190, 240) }
	for i = 1, 3 do
		p("Flag" .. i, Vector3.new(1.6, 1.8, 0.2), Vector3.new(-2 + (i - 1) * 2, 7, 0), colors[i])
	end
end

function decor.balloons(p)
	p("Weight", Vector3.new(1.2, 0.8, 1.2), Vector3.new(0, 0.4, 0), Color3.fromRGB(110, 110, 120))
	local colors = { Color3.fromRGB(250, 90, 110), Color3.fromRGB(90, 190, 250), Color3.fromRGB(255, 215, 80) }
	for i = 1, 3 do
		p("String" .. i, Vector3.new(0.1, 5 + i, 0.1), Vector3.new((i - 2) * 0.9, 2.8 + i / 2, 0), Color3.fromRGB(230, 230, 230))
		p("Balloon" .. i, Vector3.new(2.2, 2.6, 2.2), Vector3.new((i - 2) * 1.2, 6.2 + i, 0), colors[i], BALL)
	end
end

function decor.rocks(p)
	local g = Color3.fromRGB(135, 140, 150)
	p("Rock1", Vector3.new(3, 2, 2.6), Vector3.new(0, 1, 0), g, nil, Enum.Material.Slate)
	p("Rock2", Vector3.new(2, 1.4, 2), Vector3.new(2.4, 0.7, 0.8), shade(g, 0.85), nil, Enum.Material.Slate)
	p("Rock3", Vector3.new(1.4, 1, 1.4), Vector3.new(-2, 0.5, 0.6), shade(g, 1.1), nil, Enum.Material.Slate)
end

function decor.fountain(p)
	p("Basin", Vector3.new(0.4, 6, 6), Vector3.new(0, 0.6, 0), Color3.fromRGB(190, 190, 200), Enum.PartType.Cylinder, Enum.Material.Marble)
	p("Water", Vector3.new(0.2, 5.2, 5.2), Vector3.new(0, 0.9, 0), Color3.fromRGB(90, 180, 235), Enum.PartType.Cylinder, Enum.Material.Glass)
	p("Column", Vector3.new(0.9, 3, 0.9), Vector3.new(0, 2, 0), Color3.fromRGB(200, 200, 210), nil, Enum.Material.Marble)
	p("Top", Vector3.new(1.8, 0.5, 1.8), Vector3.new(0, 3.6, 0), Color3.fromRGB(90, 180, 235), nil, Enum.Material.Glass)
end

function M.buildDecor(id, origin, parent)
	local fn = decor[id]
	if not fn then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Decor_" .. id
	local p = newBuilder(model, origin, 1)
	fn(p)
	-- cilindros precisam girar para ficar deitados (eixo X -> Y)
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("Part") and part.Shape == Enum.PartType.Cylinder then
			part.CFrame = part.CFrame * CFrame.Angles(0, 0, math.rad(90))
		end
	end
	model.Parent = parent
	return model
end

return M
