local Terminal = require(script.Parent.terminal)
local ControlCodes = require(script.controlCodes)
local ProcessEscapeCodepoint = require(script.escapeSequences)

local function processCodepoint(term: Terminal.Terminal, codepoint: number): boolean
	if codepoint < 0x20 then -- Control characters
		local handler = ControlCodes[codepoint] :: ((term: Terminal.Terminal) -> boolean?)?
		if not handler then
			warn(`Unknown control character codepoint: {codepoint}`)
			return false
		end
		local result = handler(term)
		if result == false then
			return false
		end
		return true
	end

	if term.escaping then
		return ProcessEscapeCodepoint(term, codepoint)
	end

	return false
end

return processCodepoint
