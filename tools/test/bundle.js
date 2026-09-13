// Bundles the pure ReplicatedStorage modules + a fake Roblox `script` tree
// into one Luau chunk, then appends tests.lua. Usage: node bundle.js <srcRoot> <out>
const fs = require("fs");
const path = require("path");

const [srcRoot, outFile] = process.argv.slice(2);
const rsRoot = path.join(srcRoot, "ReplicatedStorage");

const nodes = []; // { path, name, parentPath, file }
function walk(dir, instPath) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      const p = instPath + "/" + entry.name;
      nodes.push({ path: p, name: entry.name, parentPath: instPath });
      walk(full, p);
    } else if (entry.name.endsWith(".lua")) {
      const name = entry.name.replace(/(\.server|\.client)?\.lua$/, "");
      const p = instPath + "/" + name;
      nodes.push({ path: p, name, parentPath: instPath, file: full });
    }
  }
}
walk(rsRoot, "ReplicatedStorage");

let lua = `
Color3 = Color3 or { fromRGB = function(r, g, b) return { r = r, g = g, b = b } end }
local __nodes = {}
local __sources = {}
local __cache = {}
local function __makeNode(p, name, parentPath)
  local node = { __path = p, Name = name, __children = {} }
  node.Parent = parentPath and __nodes[parentPath] or nil
  if node.Parent then node.Parent.__children[name] = node end
  setmetatable(node, { __index = function(t, k)
    local child = rawget(t, "__children")[k]
    if child then return child end
    if k == "WaitForChild" or k == "FindFirstChild" then
      return function(self, n) return rawget(self, "__children")[n] end
    end
    error("fake instance " .. rawget(t, "__path") .. " has no child " .. tostring(k), 2)
  end })
  __nodes[p] = node
  return node
end
__makeNode("ReplicatedStorage", "ReplicatedStorage", nil)
local function require(node)
  local p = node.__path
  if __cache[p] == nil then
    local fn = __sources[p]
    if not fn then error("no module source for " .. p) end
    __cache[p] = fn(node)
  end
  return __cache[p]
end
`;
for (const n of nodes) {
  lua += `__makeNode(${JSON.stringify(n.path)}, ${JSON.stringify(n.name)}, ${JSON.stringify(n.parentPath)})\n`;
}
for (const n of nodes.filter((n) => n.file)) {
  const src = fs.readFileSync(n.file, "utf8");
  lua += `__sources[${JSON.stringify(n.path)}] = function(script)\n${src}\nend\n`;
}
lua += `local RS = __nodes["ReplicatedStorage"]\n`;
lua += fs.readFileSync(path.join(__dirname, "tests.lua"), "utf8");
fs.writeFileSync(outFile, lua);
console.log("bundled " + nodes.filter((n) => n.file).length + " modules");
