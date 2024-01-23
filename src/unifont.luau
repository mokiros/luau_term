-- trim12 taken from http://lua-users.org/wiki/StringTrim
local function trim(s: string): string
	local from = s:match("^%s*()")
	return from > #s and "" or s:match(".*%S", from)
end

local function parseUnifont(data: string)
	local lines = string.split(data, "\n")
	-- Each codepoint will have a buffer containing 4 (or 8 for 16x16 characters) 32-bit unsigned integers
	local parsed: { [number]: buffer } = {}

	for i, line in lines do
		-- Trimming unnecessary whitespace
		line = trim(line)

		if line == "" then
			continue
		end

		-- Assuming our codepoint is within BMP, the colon will always be the fifth character
		-- Not sure if it needs support for surrogate pair UTF-16 codepoint (which has 8 hex characters instead of 4)
		if string.sub(line, 5, 5) ~= ":" then
			error(`Invalid format on line {i}: no colon on 5th position`)
		end

		-- First 4 hex characters are a simple utf8 codepoint
		local codepoint = tonumber(string.sub(line, 1, 4), 16) or error(`Invalid codepoint on line {i}`)
		local len = #line - 5
		if len ~= 32 and len ~= 64 then
			error(`Invalid hex length ({len}) at line {i}`)
		end

		-- We read 8 hex characters, and write it as a 32-bit unsigned integer
		local buf = buffer.create(len // 2)
		for i = 1, len, 8 do
			local num = tonumber(string.sub(line, i + 5, i + 5 + 7), 16) or error(`Could not parse hex on line {i}`)
			buffer.writeu32(buf, i // 2, num)
		end

		parsed[codepoint] = buf
	end

	return parsed
end

return parseUnifont
