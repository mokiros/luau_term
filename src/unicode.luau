local CONTINUATION_START = 0x80
local CONTINUATION_END = 0xBF
local INVALID_CODEPOINT = 0xFFFD

local function process(code: number, joinState: number): (boolean, number?)
	if joinState > 0 then
		if code < CONTINUATION_START or code > CONTINUATION_END then
			return true, nil
		end

		local bytesRemaining = bit32.band(joinState, 0b11)
		local codeBits = bit32.band(code, 0b00111111)

		local newState = bit32.bor(joinState, bit32.lshift(codeBits, bytesRemaining * 6))
		if bytesRemaining ~= 0 then
			return false, newState - 1
		end
		return true, newState
	end

	if code < CONTINUATION_START then
		return true, code
	elseif code < 0xC2 then
		return true, nil
	elseif code < 0xE0 then
		return false, bit32.lshift(bit32.band(code, 0b00011111), 6)
	elseif code < 0xF0 then
		return false, bit32.lshift(bit32.band(code, 0b00001111), 12) + 1
	elseif code < 0xF5 then
		return false, bit32.lshift(bit32.band(code, 0b00000111), 18) + 2
	end

	return true, nil
end

return {
	process = process,
	INVALID_CODEPOINT = INVALID_CODEPOINT,
}
