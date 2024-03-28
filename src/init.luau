local Constants = require(script.Constants)
local Terminal = require(script.terminal)
local parser = require(script.parser)

local function stdout(term: Constants.Terminal, str: string): ()
	for i = 1, #str do
		local code = string.byte(str, i, i)
		parser.parse(term, code)
	end
end

return {
	stdout = stdout,
	createTerminal = Terminal.createTerminal,
}
