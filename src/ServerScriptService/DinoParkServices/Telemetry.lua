--!nonstrict
-- Camada fina sobre o AnalyticsService: nunca quebra o jogo (tudo em pcall), sem dados pessoais
-- (só nome do evento, números e ids de itens). Config.Analytics.Enabled=false desliga o envio.
local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Telemetry = {}
Telemetry.counts = {} -- contadores locais por evento (depuração; não persistem)

-- Tipo de transação do AnalyticsService por motivo de entrada/saída de moedas.
local TX_TYPE = {
	income = "Gameplay", mission = "Onboarding", quest = "Gameplay", goal = "Gameplay",
	daily = "TimedReward", offline = "TimedReward", egg = "Shop", upgrade = "Shop", shop = "Shop",
}

-- Até 3 campos extras, valores em texto curto.
local function fieldsOf(fields)
	if type(fields) ~= "table" then
		return nil
	end
	local keys = {}
	for k in pairs(fields) do
		keys[#keys + 1] = k
	end
	table.sort(keys)
	local out = {}
	for i = 1, math.min(3, #keys) do
		out[keys[i]] = string.sub(tostring(fields[keys[i]]), 1, 40)
	end
	return out
end

local function bump(name)
	Telemetry.counts[name] = (Telemetry.counts[name] or 0) + 1
end

function Telemetry.event(player, name, value, fields)
	bump(name)
	if Config.Analytics.Debug then
		print("[Telemetry]", name, value, fields)
	end
	if not Config.Analytics.Enabled then
		return
	end
	local ok, err = pcall(function()
		AnalyticsService:LogCustomEvent(player, name, value or 1, fieldsOf(fields))
	end)
	if not ok and Config.Analytics.Debug then
		warn("[Telemetry] LogCustomEvent falhou: " .. tostring(err))
	end
end

function Telemetry.economy(player, flow, reason, amount, balance)
	bump("economy_" .. flow .. "_" .. reason)
	if Config.Analytics.Debug then
		print("[Telemetry] economia", flow, reason, amount, balance)
	end
	if not Config.Analytics.Enabled then
		return
	end
	local ok, err = pcall(function()
		local flowType = flow == "source" and Enum.AnalyticsEconomyFlowType.Source or Enum.AnalyticsEconomyFlowType.Sink
		local txType = Enum.AnalyticsEconomyTransactionType[TX_TYPE[reason] or "Gameplay"]
		AnalyticsService:LogEconomyEvent(player, flowType, "Coins", balance, amount, txType, reason)
	end)
	if not ok and Config.Analytics.Debug then
		warn("[Telemetry] LogEconomyEvent falhou: " .. tostring(err))
	end
end

function Telemetry.funnel(player, funnelName, funnelSessionId, step, stepName)
	bump("funnel_" .. funnelName .. "_" .. stepName)
	if Config.Analytics.Debug then
		print("[Telemetry] funil", funnelName, step, stepName)
	end
	if not Config.Analytics.Enabled then
		return
	end
	local ok, err = pcall(function()
		AnalyticsService:LogFunnelStepEvent(player, funnelName, funnelSessionId, step, stepName)
	end)
	if not ok and Config.Analytics.Debug then
		warn("[Telemetry] LogFunnelStepEvent falhou: " .. tostring(err))
	end
end

return Telemetry
