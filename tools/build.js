// Gera os instaladores da Command Bar a partir de src/ e scene/.
// Uso: node tools/build.js   (saída em installer/)
const fs = require("fs");
const path = require("path");
const root = path.join(__dirname, "..");
const read = (p) => fs.readFileSync(path.join(root, p), "utf8");

// [classe, nome, caminho-do-arquivo]
const shared = [
  ["ModuleScript", "Config", "src/ReplicatedStorage/Shared/Config.lua"],
  ["ModuleScript", "Logic", "src/ReplicatedStorage/Shared/Logic.lua"],
  ["ModuleScript", "DinoModels", "src/ReplicatedStorage/Shared/DinoModels.lua"],
];
const services = [
  ["ModuleScript", "DataService", "src/ServerScriptService/DinoParkServices/DataService.lua"],
  ["ModuleScript", "ParkService", "src/ServerScriptService/DinoParkServices/ParkService.lua"],
  ["ModuleScript", "GameService", "src/ServerScriptService/DinoParkServices/GameService.lua"],
];
const main = ["Script", "DinoParkMain", "src/ServerScriptService/DinoParkMain.server.lua"];
const client = ["LocalScript", "DinoParkClient", "src/StarterPlayer/StarterPlayerScripts/DinoParkClient.client.lua"];

function lit(src, file) {
  for (let level = 2; level < 8; level++) {
    const eq = "=".repeat(level);
    if (!src.includes("]" + eq + "]")) return `[${eq}[\n${src}]${eq}]`;
  }
  throw new Error("sem delimitador livre em " + file);
}
const entry = (cls, name, file) => `{ "${cls}", "${name}", ${lit(read(file), file)} }`;

const out = `--!nonstrict
-- Dino Park Tycoon — Parte 2: scripts do jogo (GERADO por tools/build.js — não edite à mão).
-- Cole na Command Bar do Roblox Studio. Cria: ReplicatedStorage.Shared, ServerScriptService.DinoParkServices,
-- ServerScriptService.DinoParkMain e StarterPlayerScripts.DinoParkClient.
-- Seguro para repetir: se já existir, PARA sem alterar nada (REPLACE_EXISTING = true recria SÓ esses objetos).
local REPLACE_EXISTING = false

local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local SPS = StarterPlayer:FindFirstChild("StarterPlayerScripts") or StarterPlayer:WaitForChild("StarterPlayerScripts", 5)
assert(SPS, "[DinoPark] StarterPlayerScripts não encontrado")

local targets = {
	{ RS, "Shared" }, { SSS, "DinoParkServices" }, { SSS, "DinoParkMain" }, { SPS, "DinoParkClient" },
}
for _, t in ipairs(targets) do
	local found = t[1]:FindFirstChild(t[2])
	if found then
		if not REPLACE_EXISTING then
			warn("[DinoPark] " .. t[1].Name .. "." .. t[2] .. " já existe. Nada foi alterado. Mude REPLACE_EXISTING para true para recriar.")
			return
		end
		found:Destroy()
	end
end

local function make(class, name, source, parent)
	local inst = Instance.new(class)
	inst.Name = name
	inst.Source = source
	inst.Parent = parent
	return inst
end

local sharedFolder = Instance.new("Folder")
sharedFolder.Name = "Shared"
local sharedFiles = {
${shared.map((e) => "\t" + entry(...e)).join(",\n")},
}
for _, f in ipairs(sharedFiles) do make(f[1], f[2], f[3], sharedFolder) end
sharedFolder.Parent = RS

local servicesFolder = Instance.new("Folder")
servicesFolder.Name = "DinoParkServices"
local serviceFiles = {
${services.map((e) => "\t" + entry(...e)).join(",\n")},
}
for _, f in ipairs(serviceFiles) do make(f[1], f[2], f[3], servicesFolder) end
servicesFolder.Parent = SSS

local m = ${entry(...main)}
make(m[1], m[2], m[3], SSS)

local c = ${entry(...client)}
make(c[1], c[2], c[3], SPS)

print("[DinoPark] Parte 2 (scripts) instalada. Salve o lugar e pressione Play (F5).")
`;

fs.mkdirSync(path.join(root, "installer"), { recursive: true });
fs.writeFileSync(path.join(root, "installer/Parte2_Scripts.lua"), out);
fs.writeFileSync(path.join(root, "installer/Parte1_Cenario.lua"), read("scene/SceneBuilder.lua"));
console.log("OK: installer/Parte1_Cenario.lua e installer/Parte2_Scripts.lua gerados.");
