// Verificação cruzada: ações pedidas pelo cliente existem no servidor; campos de estado lidos pelo cliente são enviados.
const fs = require("fs"), path = require("path");
const root = path.join(__dirname, "..");
const r = (p) => fs.readFileSync(path.join(root, p), "utf8");
const client = r("src/StarterPlayer/StarterPlayerScripts/DinoParkClient.client.lua");
const game = r("src/ServerScriptService/DinoParkServices/GameService.lua");
let bad = 0;
const actions = new Set([...client.matchAll(/request\(\s*(?:[^"()]*\?\s*)?"(\w+)"/g)].map((m) => m[1]));
for (const m of client.matchAll(/request\(dino\.placed and "(\w+)" or "(\w+)"/g)) { actions.add(m[1]); actions.add(m[2]); }
actions.add("getState");
const handlers = new Set([...game.matchAll(/function handlers\.(\w+)/g)].map((m) => m[1]));
for (const a of actions) if (!handlers.has(a)) { console.log("FALTA handler: " + a); bad++; }
console.log("ações do cliente: " + [...actions].join(", "));
console.log("handlers: " + [...handlers].join(", "));
const sent = new Set([...game.matchAll(/^\t\t(\w+) = /gm)].map((m) => m[1]));
const used = new Set([...client.matchAll(/\bstate\.(\w+)/g)].map((m) => m[1]));
for (const m of client.matchAll(/\bs\.(\w+)/g)) used.add(m[1]);
for (const u of used) if (!sent.has(u)) { console.log("campo de estado não enviado: " + u); bad++; }
const cfg = r("src/ReplicatedStorage/Shared/Config.lua");
for (const m of client.matchAll(/\bConfig\.(\w+)/g)) if (!new RegExp("Config\\." + m[1] + "\\s*=").test(cfg)) { console.log("Config sem campo: " + m[1]); bad++; }
for (const f of ["Logic", "DinoModels"]) {
  const src = r(`src/ReplicatedStorage/Shared/${f}.lua`);
  for (const file of ["src/ServerScriptService/DinoParkServices/GameService.lua", "src/ServerScriptService/DinoParkServices/ParkService.lua", "src/StarterPlayer/StarterPlayerScripts/DinoParkClient.client.lua"]) {
    for (const m of r(file).matchAll(new RegExp(`\\b${f}\\.(\\w+)`, "g"))) {
      if (!new RegExp(`function ${f === "Logic" ? "Logic" : "M"}\\.${m[1]}\\b`).test(src)) { console.log(`${file}: ${f}.${m[1]} não existe`); bad++; }
    }
  }
}
console.log(bad ? bad + " problema(s)" : "xref ok");
process.exit(bad ? 1 : 0);
