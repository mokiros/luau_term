local Constants = require("../constants")
local Types = require("../types")
local TransitionTable = require("./transition_table")
local Unicode = require('../unicode')

local ParserState = Constants.ParserState
local ParserAction = Constants.ParserAction
local OscState = Constants.OscState
local TableAccess = Constants.TableAccess

-- macro for (a << 8 | b)
local function add(a: number, b: number)
	return bit32.bor(bit32.lshift(a, 8), b)
end

local function resetParams(params: Types.Params)
	table.clear(params.params)
	table.clear(params.subParams)
	params._length = 0
	params._isSubParam = false
end

local function addParam(params: Types.Params)
	local len = params._length + 1
	params._isSubParam = false
	params.params[len] = 0
	params._length = len
end

local function addSubParam(params: Types.Params)
	local len = params._length
	params._isSubParam = true
	local t = params.subParams[len]
	if not t then
		params.subParams[len] = { 0 }
	else
		table.insert(t, 0)
	end
end

local function reset(parser: Types.Parser)
	resetParams(parser.params)
	parser.collect = 0
	parser.stringDataLength = 0
	parser.ident = 0
	parser.joinState = 0
end

local function addDigit(params: Types.Params, digit: number)
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

local function parse(term: Types.Terminal, code: number): ()
	local parser = term.parser
	local handlers = term.handlers

	if parser.joinState ~= 0 then
		local isReady, newState = Unicode.process(code, parser.joinState)
		if not isReady then
			parser.joinState = newState or 0
			return
		end
		parser.joinState = 0
		if newState then
			handlers.print(term, newState)
			return
		else
			handlers.print(term, Unicode.INVALID_CODEPOINT)
		end
	end

	local idx =
		bit32.bor(bit32.lshift(parser.currentState, TableAccess.INDEX_STATE_SHIFT), math.min(code, Constants.NON_ASCII_PRINTABLE))
	local transition = buffer.readu8(TransitionTable, idx)
	local a = bit32.rshift(transition, TableAccess.TRANSITION_ACTION_SHIFT)
	if a == ParserAction.PRINT then
		local isReady, newState = Unicode.process(code, 0)
		if not isReady then
			parser.joinState = newState or 0
			return
		end
		handlers.print(term, newState or Unicode.INVALID_CODEPOINT)
	elseif a == ParserAction.EXECUTE then
		local handler = handlers.exec[code]
		if handler then
			handler(term)
		else
			handlers.execFallback(term, code)
		end
		parser.joinState = 0
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
			handlers.csiFallback(term, ident, parser.params)
		end
		parser.joinState = 0
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
			handlers.escFallback(term, ident)
		end
		parser.joinState = 0
	elseif a == ParserAction.CLEAR then
		reset(parser)
	elseif a == ParserAction.DCS_HOOK then
		parser.ident = add(parser.collect, code)
		parser.stringDataLength = 0
	elseif a == ParserAction.DCS_PUT then
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
				handlers.dcsFallback(term, parser.ident, parser.stringData, parser.stringDataLength, parser.params)
			end
		end
		if code == 0x1b then
			transition = bit32.bor(transition, ParserState.ESCAPE)
		end
		reset(parser)
	elseif a == ParserAction.OSC_START then
		parser.oscState = OscState.ID
	elseif a == ParserAction.OSC_PUT then
		if parser.oscState == OscState.ID then
			if code == 0x3b then
				parser.oscState = OscState.PAYLOAD
			elseif code < 0x30 or code > 0x39 then
				parser.oscState = OscState.ABORT
			else
				parser.ident = parser.ident * 10 + (code - 0x30)
			end
		elseif parser.oscState == OscState.PAYLOAD and parser.stringDataLength < Constants.DCS_DATA_LIMIT then
			buffer.writeu8(parser.stringData, parser.stringDataLength, code)
			parser.stringDataLength += 1
		end
	elseif a == ParserAction.OSC_END then
		local success = code ~= 0x18 and code ~= 0x1a
		if success then
			local handler = handlers.osc[parser.ident]
			if handler then
				handler(term, parser.stringData, parser.stringDataLength)
			else
				handlers.oscFallback(term, parser.ident, parser.stringData, parser.stringDataLength)
			end
		end
		if code == 0x1b then
			transition = bit32.bor(transition, ParserState.ESCAPE)
		end
		reset(parser)
	end
	parser.currentState = bit32.band(transition, TableAccess.TRANSITION_STATE_MASK)
end

local function createParser(): Types.Parser
	local parser: Types.Parser = {
		currentState = 0,
		collect = 0,
		params = {
			_isSubParam = false,
			_length = 0,
			params = {},
			subParams = {},
		},
		stringData = buffer.create(Constants.DCS_DATA_LIMIT),
		stringDataLength = 0,
		oscState = OscState.START,
		ident = 0,
		joinState = 0,
	}

	reset(parser)

	return parser
end

return {
	createParser = createParser,
	parse = parse,
}
