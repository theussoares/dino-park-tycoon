--!nonstrict
-- Compras com Robux: DESLIGADO por padrão (Config.Monetization.Enabled=false). Com a flag desligada este módulo
-- não toca em MarketplaceService, não registra ProcessReceipt e não vende nada.
-- NÃO TESTADO no Studio. Só ligue depois de o loop estar validado com DataStore real e multiplayer.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Logic = require(Shared:WaitForChild("Logic"))

local MonetizationService = {}
MonetizationService.enabled = false

local function productKeyById(productId)
	for key, p in pairs(Config.Monetization.Products) do
		if p.productId ~= 0 and p.productId == productId then
			return key
		end
	end
	return nil
end

local function passKeyById(passId)
	for key, p in pairs(Config.Monetization.Passes) do
		if p.gamePassId ~= 0 and p.gamePassId == passId then
			return key
		end
	end
	return nil
end

-- deps: { DataService, Telemetry, push }
function MonetizationService.init(deps)
	if not Config.Monetization.Enabled then
		return false
	end
	local MarketplaceService = game:GetService("MarketplaceService")
	MonetizationService.enabled = true

	-- Idempotente: o mesmo PurchaseId nunca concede duas vezes (data.receipts, salvo junto com o inventário).
	-- Só devolve PurchaseGranted depois de o dado estar SALVO; qualquer dúvida => NotProcessedYet (o Roblox repete).
	MarketplaceService.ProcessReceipt = function(info)
		local player = Players:GetPlayerByUserId(info.PlayerId)
		local session = player and deps.DataService.get(player)
		if not player or not session or not session.canSave then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local key = productKeyById(info.ProductId)
		local result = Logic.processReceipt(session.data, Config, tostring(info.PurchaseId), key, os.time())
		if result == "unknown" or result == "invalid" then
			warn("[DinoPark] recibo desconhecido: produto " .. tostring(info.ProductId))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if result == "granted" then
			deps.DataService.markDirty(player)
			deps.Telemetry.event(player, "purchase_granted", info.CurrencySpent or 0, { product = key })
		end
		if session.dirty and not deps.DataService.save(player, true) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		deps.push(player)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		local key = passKeyById(passId)
		local session = deps.DataService.get(player)
		if wasPurchased and key and session and Logic.grantPass(session.data, Config, key) then
			deps.DataService.markDirty(player)
			deps.Telemetry.event(player, "purchase_granted", 1, { pass = key })
			deps.DataService.save(player, true)
			deps.push(player)
		end
	end)
	return true
end

-- Abre a janela de compra do Roblox (a UI só chama isto por ação explícita do jogador).
function MonetizationService.prompt(player, kind, key)
	if not MonetizationService.enabled then
		return false
	end
	local MarketplaceService = game:GetService("MarketplaceService")
	if kind == "product" and Config.Monetization.Products[key] and Config.Monetization.Products[key].productId ~= 0 then
		MarketplaceService:PromptProductPurchase(player, Config.Monetization.Products[key].productId)
		return true
	elseif kind == "pass" and Config.Monetization.Passes[key] and Config.Monetization.Passes[key].gamePassId ~= 0 then
		MarketplaceService:PromptGamePassPurchase(player, Config.Monetization.Passes[key].gamePassId)
		return true
	end
	return false
end

return MonetizationService
