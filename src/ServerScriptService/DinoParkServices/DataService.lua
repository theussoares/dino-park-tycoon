--!nonstrict
-- Persistência com DataStoreService: trava de sessão (UpdateAsync), carga com tentativas, nunca sobrescreve
-- dados válidos com padrões após falha de carga (canSave=false), salvamento com retry/backoff e limite de frequência.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Logic = require(Shared:WaitForChild("Logic"))

local DataService = {}
local sessions = {} -- [Player] = { data=, canSave=, dirty=, lastSave=, isNew=, locked= }

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

-- Tenta reservar o perfil. Devolve "ok", raw | "locked" | "error".
local function claim(player)
	local status, raw = "error", nil
	local ok, err = pcall(function()
		store:UpdateAsync(keyFor(player), function(old)
			local now = os.time()
			if Logic.lockedByOther(old, game.JobId, now, Config.LockSeconds) then
				status = "locked"
				return nil -- cancela a escrita
			end
			status = "ok"
			raw = old
			return Logic.record(old, game.JobId, now, false)
		end)
	end)
	if not ok then
		warn("[DinoPark] erro ao reservar perfil de " .. player.Name .. ": " .. tostring(err))
		return "error"
	end
	return status, raw
end

-- Carrega (yield). Sempre devolve uma sessão. canSave=false se não foi possível ler (nunca salvamos por cima).
-- session.locked=true: dados em uso em outro servidor (o GameService remove o jogador).
function DataService.load(player)
	local now = os.time()
	local raw, status = nil, "error"
	if store then
		for attempt = 1, Config.LockRetries do
			status, raw = claim(player)
			if status == "ok" then
				break
			end
			warn(("[DinoPark] perfil de %s: %s (tentativa %d)"):format(player.Name, status, attempt))
			task.wait(Config.LockRetryWait)
		end
	end
	local loaded = status == "ok"
	local session = {
		data = Logic.migrate(raw, Config, now),
		canSave = loaded,
		dirty = false,
		lastSave = os.clock(),
		isNew = loaded and (raw == nil or raw.schemaVersion == nil),
		locked = status == "locked",
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

-- Uma tentativa de gravação. release=true remove a trava. Cancela se outro servidor assumiu o perfil.
local function writeOnce(player, session, release)
	local lostLock = false
	local ok, err = pcall(function()
		store:UpdateAsync(keyFor(player), function(old)
			local now = os.time()
			if Logic.lockedByOther(old, game.JobId, now, Config.LockSeconds) then
				lostLock = true
				return nil
			end
			session.data.lastSeen = now
			return Logic.record(session.data, game.JobId, now, release)
		end)
	end)
	if not ok then
		return false, tostring(err)
	end
	if lostLock then
		session.canSave = false -- outro servidor tem o perfil: parar de salvar para não duplicar
		return false, "perfil em uso por outro servidor"
	end
	return true
end

-- Salva se necessário. force=true ignora o intervalo mínimo e tenta de novo com backoff.
-- touch=true grava mesmo sem mudanças (renova a trava). release=true libera a trava.
function DataService.save(player, force, touch, release)
	local s = sessions[player]
	if not s or not s.canSave or not store then
		return false
	end
	if not force and not touch and (not s.dirty or os.clock() - s.lastSave < Config.MinSaveGap) then
		return false
	end
	local attempts = force and Config.SaveRetries or 1
	for attempt = 1, attempts do
		local ok, err = writeOnce(player, s, release)
		if ok then
			s.dirty = false
			s.lastSave = os.clock()
			return true
		end
		warn(("[DinoPark] Falha ao salvar %s (tentativa %d): %s"):format(player.Name, attempt, tostring(err)))
		if not s.canSave then
			return false
		end
		if attempt < attempts then
			task.wait(attempt * 1.5)
		end
	end
	return false
end

function DataService.release(player)
	DataService.save(player, true, true, true)
	sessions[player] = nil
end

function DataService.sessions()
	return sessions
end

return DataService
