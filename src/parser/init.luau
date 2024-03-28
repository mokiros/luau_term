local Constants = require(script.Parent.Constants)
local Handlers = require(script.Handlers)
local TransitionTable = require(script.TransitionTable)

local ParserState = Constants.ParserState
local ParserAction = Constants.ParserAction
local OscState = Constants.OscState
local TableAccess = Constants.TableAccess

-- macro for (a << 8 | b)
local function add(a: number, b: number)
	return bit32.bor(bit32.lshift(a, 8), b)
end

local function resetParams(params: Constants.Params)
	table.clear(params.params)
	table.clear(params.subParams)
	params._length = 0
	params._isSubParam = false
end

local function addParam(params: Constants.Params)
	local len = params._length + 1
	params._isSubParam = false
	params.params[len] = 0
	params._length = len
end

local function addSubParam(params: Constants.Params)
	local len = params._length
	params._isSubParam = true
	local t = params.subParams[len]
	if not t then
		params.subParams[len] = { 0 }
	else
		table.insert(t, 0)
	end
end

local function reset(parser: Constants.Parser)
	resetParams(parser.params)
	addParam(parser.params)
	parser.collect = 0
	parser.precedingJoinState = 0
	parser.stringDataLength = 0
end

local function addDigit(params: Constants.Params, digit: number)
	local len = params._length
	if params._isSubParam then
		local t = params.subParams[len]
		if #t == 0 then
			table.insert(t, 0)
		end
		local num = t[#t]
		t[#t] = num * 10 + digit
	else
		if len == 0 then
			len = 1
			params._length = 1
		end
		local num = params.params[len] or 0
		params.params[len] = num * 10 + digit
	end
end

local function parse(term: Constants.Terminal, code: number): ()
	local parser = term.parser
	local handlers = term.handlers
	local idx = bit32.bor(
		bit32.lshift(parser.currentState, TableAccess.INDEX_STATE_SHIFT),
		if code < 0xa0 then code else Constants.NON_ASCII_PRINTABLE
	)
	local transition = buffer.readu8(parser.transitions, idx)
	local a = bit32.rshift(transition, TableAccess.TRANSITION_ACTION_SHIFT)
	if a == ParserAction.PRINT then
		handlers.print(term, code)
	elseif a == ParserAction.EXECUTE then
		local handler = handlers.exec[code]
		if handler then
			handler(term)
		else
			warn(`Unhandled EXECUTE command: {code}`)
		end
	elseif a == ParserAction.IGNORE then
		-- ignore
	elseif a == ParserAction.ERROR then
		handlers.error(term, code)
	elseif a == ParserAction.CSI_DISPATCH then
		local ident = add(parser.collect, code)
		local handler = handlers.csi[ident]
		if handler then
			handler(term, parser.params)
		else
			warn(
				`Unhandled CSI command: {ident}, params: {parser.params._length}, \{{table.concat(parser.params.params, ", ")}\}`
			)
		end
		parser.precedingJoinState = 0
	elseif a == ParserAction.PARAM then
		-- digits (0x30 - 0x39) and ; (0x3b) and : (0x3a)
		if code == 0x3b then
			addParam(parser.params)
		elseif code == 0x3a then
			addSubParam(parser.params)
		else
			addDigit(parser.params, code - 0x30)
		end
	elseif a == ParserAction.COLLECT then
		parser.collect = add(parser.collect, code)
	elseif a == ParserAction.ESC_DISPATCH then
		local ident = add(parser.collect, code)
		local handler = handlers.esc[ident]
		if handler then
			handler(term)
		else
			warn(`Unhandled ESC command: {ident}`)
		end
	elseif a == ParserAction.CLEAR then
		reset(parser)
	elseif a == ParserAction.DCS_HOOK then
		parser.ident = add(parser.collect, code)
		parser.stringDataLength = 0
	elseif a == ParserAction.DCS_PUT or a == ParserAction.OSC_PUT then
		if parser.stringDataLength < Constants.DCS_DATA_LIMIT then
			buffer.writeu8(parser.stringData, parser.stringDataLength, code)
			parser.stringDataLength += 1
		end
	elseif a == ParserAction.DCS_UNHOOK then
		local success = code ~= 0x18 and code ~= 0x1a
		if success then
			local handler = handlers.dcs[parser.ident]
			if handler then
				handler(term, parser.stringData, parser.stringDataLength, parser.params)
			else
				warn(`Unhandled DCS command: {parser.ident}, params: {parser.params._length}, \{{table.concat(parser.params.params, ", ")}\}`)
			end
		end
		if code == 0x1b then
			transition = bit32.bor(transition, ParserState.ESCAPE)
		end
		reset(parser)
	elseif a == ParserAction.OSC_START then
		parser.oscState = OscState.ID
	elseif a == ParserAction.OSC_END then
		local success = code ~= 0x18 and code ~= 0x1a
		if success then
			local handler = handlers.osc[parser.ident]
			if handler then
				handler(term, parser.stringData, parser.stringDataLength)
			else
				warn(`Unhandled OSC command: {parser.ident}`)
			end
		end
		reset(parser)
	end
	parser.currentState = bit32.band(transition, TableAccess.TRANSITION_STATE_MASK)
end

local function createParser(): Constants.Parser
	local parser: Constants.Parser = {
		collect = 0,
		precedingJoinState = 0,
		currentState = 0,
		initialState = 0,
		transitions = TransitionTable,
		params = {
			_isSubParam = false,
			_length = 0,
			params = {},
			subParams = {},
		},
		stringData = buffer.create(Constants.DCS_DATA_LIMIT),
		stringDataLength = 0,
		ident = 0,
		oscState = OscState.START,
	}

	reset(parser)

	return parser
end

return {
	createParser = createParser,
	parse = parse,
}
