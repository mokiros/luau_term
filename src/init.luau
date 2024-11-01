local Types = require(script.Types)
local Terminal = require(script.terminal)
local parser = require(script.parser)

local v = Instance.new("StringValue")
v.Parent = script
v.Value = ""

local function stdout(term: Types.Terminal, str: string): ()
	-- local s = ""
	-- for i = 1, #str do
	-- 	s ..= string.format("%02X", string.byte(str, i))
	-- end
	-- v.Value ..= s
	-- debug.profilebegin("stdout")
	for i, codepoint in utf8.codes(str) do
		parser.parse(term, codepoint)
	end
	-- debug.profileend()
end

return {
	stdout = stdout,
	createTerminal = Terminal.createTerminal,
}
