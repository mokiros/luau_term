local Terminal = require(script.Parent.Parent.terminal)

local ControlCodes = {
	-- ESC - Escape
	[0x1B] = function(term: Terminal.Terminal)
		term.escaping = true

		-- Buffer switching, check Terminal type definition for explanation
		local currentBuffer = term.escapingState
		local previousBuffer = term.escapingState_previousBuffer
		table.clear(previousBuffer)
		term.escapingState = previousBuffer
		term.escapingState_previousBuffer = currentBuffer
		
		term.escapeCodepoint_previous = term.escapeCodepoint
		term.escapeCodepoint = nil
	end,

	-- BS - Backspace
	[0x08] = function(term: Terminal.Terminal)
		Terminal.moveCursor(term, -1, 0, true)
	end,

	-- LF - Line feed
	[0x0A] = function(term: Terminal.Terminal)
		Terminal.moveCursor(term, 0, 1)
	end,

	-- CR - Carriage return
	[0x0D] = function(term: Terminal.Terminal)
		term.cursor = Vector2.new(0, term.cursor.Y)
	end,

	-- BEL - Bell
	[0x07] = function(term: Terminal.Terminal)
		-- TODO: Play sound
	end,

	-- SUB
	[0x1A] = function(term: Terminal.Terminal)
		term.escaping = false
	end,
}

-- FF -> LF
ControlCodes[0x0C] = ControlCodes[0x0A]

-- CAN -> SUB
ControlCodes[0x18] = ControlCodes[0x1A]

return ControlCodes
