local luau = require("@lune/luau")
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local PathModule = require("./luau-path/src/init.lua")
local Path = PathModule.Path

local function discoverAndReadScript(filePath: string): (string, string)
	local scriptContents: string

	if fs.isFile(filePath) then
		scriptContents = fs.readFile(filePath)
		return scriptContents, filePath
	end

	if fs.isDir(filePath) then
		if fs.isFile(filePath .. "/init.luau") then
			filePath ..= "/init.luau"
			scriptContents = fs.readFile(filePath)
		end
	end

	if scriptContents == nil then
		local filePathExt = filePath .. ".luau"
		if fs.isFile(filePathExt) then
			filePath ..= ".luau"
			scriptContents = fs.readFile(filePathExt)
		end

		if scriptContents == nil then
			error(`No such file or directory \`{filePath}\``)
		end
	end

	return scriptContents, filePath
end

local fakeScriptMT = {
	__index = function(self, key)
		local t = table.clone(self)
		table.insert(t, key)
		return t
	end,

	__tostring = function(self)
		return "script." .. table.concat(self, ".")
	end,
}

local cache = {}

local loadScript
loadScript = function(stringPath: string)
	if cache[stringPath] then
		return cache[stringPath]
	end

	print("Loading", stringPath)
	local fakeScript = setmetatable({}, fakeScriptMT)
	local scriptContents, filePath = discoverAndReadScript(stringPath)

	local module_env = {
		debugName = filePath,
		environment = {
			Vector2 = (roblox :: any).Vector2,
			print = print,
			warn = warn,
			script = fakeScript,
			require = function(scriptPath: typeof(fakeScript))
				local path = Path.new(filePath)
				local isInit = path:filePrefix() == "init"
				local firstParent = scriptPath[1] == "Parent"
				if not isInit and not firstParent then
					error("Invalid path: " .. tostring(scriptPath))
				elseif isInit then
					path = path:parent() :: typeof(path)
				end
				for _, name in pairs(scriptPath) do
					if name == "Parent" then
						path = path:parent() :: typeof(path)
					else
						path:push(name)
					end
				end

				print(`Resolved {scriptPath} to {path}`)

				return loadScript(path:toString())
			end,
		},
	}

	local v = luau.load(scriptContents, table.freeze(module_env))()

	cache[stringPath] = v
	return v
end

return loadScript
