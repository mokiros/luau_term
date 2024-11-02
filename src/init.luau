local Types = require(script.Types)
local Terminal = require(script.terminal)
local parser = require(script.parser)

local function stdout(term: Types.Terminal, str: string): ()
	for i, codepoint in utf8.codes(str) do
		parser.parse(term, codepoint)
	end
end

return {
	stdout = stdout,
	createTerminal = Terminal.createTerminal,
}
