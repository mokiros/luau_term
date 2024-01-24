local Terminal = require(script.terminal)
local ProcessCodepoint = require(script.ansi)

local function stdout(term: Terminal.Terminal, str: string)
	for i, codepoint in utf8.codes(str) do
		local result = ProcessCodepoint(term, codepoint)
		if result == true then
			continue
		end
		Terminal.writeCodepoint(term, codepoint)
	end
end

return {
	createTerminal = Terminal.createTerminal,
	stdout = stdout,
}
