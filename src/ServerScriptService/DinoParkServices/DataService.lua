--!nonstrict
-- Persistência com DataStoreService: carrega com tentativas, nunca sobrescreve dados válidos com
-- padrões após falha de carga (canSave=false), salva com UpdateAsync e limite de frequência.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Logic = require(Shared:WaitForChild("Logic"))

local DataService = {}
local sessions = {} -- [Player] = { data=, canSave=, dirty=, lastSave=, loadFailed= }

local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[DinoPark] DataStore indisponível: " .. tostring(result))
	end
end

local function keyFor(player)
	return "u_" .. tostring(player.UserId)
end

-- Carrega (yield). Sempre devolve uma sessão; canSave=false se o carregamento falhou.
function DataService.load(player)
	local now = os.time()
	local raw, loaded = nil, false
	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return store:GetAsync(keyFor(player))
			end)
			if ok then
				raw, loaded = result, true
				break
			end
			warn(("[DinoPark] Falha ao carregar %s (tentativa %d): %s"):format(player.Name, attempt, tostring(result)))
			task.wait(1.5 * attempt)
		end
	end
	local session = {
		data = Logic.migrate(raw, Config, now),
		canSave = loaded, -- se não carregou, NÃO salvamos (evita apagar progresso real)
		dirty = false,
		lastSave = 0,
		isNew = loaded and raw == nil,
	}
	sessions[player] = session
	return session
end

function DataService.get(player)
	return sessions[player]
end

function DataService.markDirty(player)
	local s = sessions[player]
	if s then
		s.dirty = true
	end
end

-- Salva se necessário. force=true ignora o intervalo mínimo (saída do jogador / desligamento).
function DataService.save(player, force)
	local s = sessions[player]
	if not s or not s.canSave or not store then
		return false
	end
	if not force and (not s.dirty or os.clock() - s.lastSave < Config.MinSaveGap) then
		return false
	end
	s.data.lastSeen = os.time()
	local snapshot = s.data
	local ok, err = pcall(function()
		store:UpdateAsync(keyFor(player), function()
			return snapshot
		end)
	end)
	if ok then
		s.dirty = false
		s.lastSave = os.clock()
		return true
	end
	warn(("[DinoPark] Falha ao salvar %s: %s"):format(player.Name, tostring(err)))
	return false
end

function DataService.release(player)
	DataService.save(player, true)
	sessions[player] = nil
end

function DataService.sessions()
	return sessions
end

return DataService
