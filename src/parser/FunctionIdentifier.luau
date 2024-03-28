-- macro for (a << 8 | b)
local function add(a: number, b: number)
	return bit32.bor(bit32.lshift(a, 8), b)
end

export type FunctionIdentifier = {
	prefix: number?,
	intermediates: { number }?,
	final: number,
}

local function identifier(id: FunctionIdentifier, finalRange: { number }?): number
	local res = 0

	if id.prefix then
		res = id.prefix
		if res ~= 0 and (res < 0x3c or res > 0x3f) then
			error("prefix must be in range 0x3c .. 0x3f")
		end
	end

	if id.intermediates then
		for i = 1, #id.intermediates do
			local intermediate = id.intermediates[i]
			if intermediate < 0x20 or intermediate > 0x2f then
				error("intermediate must be in range 0x20 .. 0x2f")
			end
			res = add(res, intermediate)
		end
	end

	local final = id.final
	local final1 = (finalRange and finalRange[1] or 0x40)
	local final2 = (finalRange and finalRange[1] or 0x7e)
	if final < final1 or final > final2 then
		error(`final must be in range {final1} .. {final2}`)
	end
	res = add(res, final)

	return res
end

return {
	identifier = identifier,
}
