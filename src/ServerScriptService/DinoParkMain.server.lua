--!nonstrict
-- Ponto de entrada do servidor do Dino Park Tycoon.
local services = script.Parent:WaitForChild("DinoParkServices")
local ParkService = require(services:WaitForChild("ParkService"))
local GameService = require(services:WaitForChild("GameService"))

ParkService.init()
GameService.start()
print("[DinoPark] Servidor iniciado.")
