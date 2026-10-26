// Lista identificadores GLOBAIS usados (detecta typos/variáveis não declaradas). Revisão manual contra a API do Roblox.
const fs = require("fs"), path = require("path"), luaparse = require("luaparse");
const root = path.join(__dirname, "..");
const files = process.argv.slice(2);
const allowed = new Set("game workspace script Instance Vector3 Vector2 CFrame Color3 UDim UDim2 Enum Random task os math string table pairs ipairs type tostring tonumber pcall assert warn print require next select error setmetatable unpack Workspace".split(" "));
let bad = 0;
for (const f of files) {
  const ast = luaparse.parse(fs.readFileSync(path.join(root, f), "utf8"), { luaVersion: "5.1", scope: true });
  const names = new Set((ast.globals || []).map((g) => g.name));
  const odd = [...names].filter((n) => !allowed.has(n));
  if (odd.length) bad++;
  console.log(f + ": " + (odd.length ? "GLOBAIS NÃO LISTADOS -> " + odd.join(", ") : "ok (" + names.size + " globais permitidos)"));
}
process.exit(bad ? 1 : 0);
