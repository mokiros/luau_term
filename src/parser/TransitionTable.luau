local Constants = require(script.Parent.Parent.Constants)

local ParserState = Constants.ParserState
local ParserAction = Constants.ParserAction
local TableAccess = Constants.TableAccess
local NON_ASCII_PRINTABLE = Constants.NON_ASCII_PRINTABLE

local len = 4095
local buf = buffer.create(len)

local function setDefault(action: number, next: number): ()
	local i = bit32.bor(bit32.lshift(action, TableAccess.TRANSITION_ACTION_SHIFT), next)
	buffer.fill(buf, 0, i)
end

local function add(code: number, state: number, action: number, next: number): ()
	local k = bit32.bor(bit32.lshift(state, TableAccess.INDEX_STATE_SHIFT), code)
	local v = bit32.bor(bit32.lshift(action, TableAccess.TRANSITION_ACTION_SHIFT), next)
	if k == 32 then
		print(debug.traceback())
	end
	buffer.writeu8(buf, k, v)
end

local function addRange(from: number, to: number, state: number, action: number, next: number): ()
	local size = to - from
	local k = bit32.bor(bit32.lshift(state, TableAccess.INDEX_STATE_SHIFT), from)
	local v = bit32.bor(bit32.lshift(action, TableAccess.TRANSITION_ACTION_SHIFT), next)
	buffer.fill(buf, k, v, size)
end

local function addMany(codes: { number }, state: number, action: number, next: number): ()
	local v = bit32.bor(bit32.lshift(action, TableAccess.TRANSITION_ACTION_SHIFT), next)
	for _, code in codes do
		local k = bit32.bor(bit32.lshift(state, TableAccess.INDEX_STATE_SHIFT), code)
		buffer.writeu8(buf, k, v)
	end
end

local EXECUTABLES = {}
for i = 0x00, 0x1F do
	if i ~= 0x18 and i ~= 0x1a and i ~= 0x1b then
		table.insert(EXECUTABLES, i)
	end
end

local PRINTABLES_START = 0x20
local PRINTABLES_END = 0x7f

do -- Setting up the table
	setDefault(ParserAction.ERROR, ParserState.GROUND)

	-- Printables
	addRange(PRINTABLES_START, PRINTABLES_END, ParserState.GROUND, ParserAction.PRINT, ParserState.GROUND)

	-- Global anywhere rules
	for state = ParserState.GROUND, ParserState.DCS_PASSTHROUGH, 1 do
		addMany({ 0x18, 0x1a, 0x99, 0x9a }, state, ParserAction.EXECUTE, ParserState.GROUND)
		addRange(0x80, 0x90, state, ParserAction.EXECUTE, ParserState.GROUND)
		addRange(0x90, 0x98, state, ParserAction.EXECUTE, ParserState.GROUND)
		add(0x9c, state, ParserAction.IGNORE, ParserState.GROUND) -- ST as terminator
		add(0x1b, state, ParserAction.CLEAR, ParserState.ESCAPE) -- ESC
		add(0x9d, state, ParserAction.OSC_START, ParserState.OSC_STRING) -- OSC
		addMany({ 0x98, 0x9e, 0x9f }, state, ParserAction.IGNORE, ParserState.SOS_PM_APC_STRING)
		add(0x9b, state, ParserAction.CLEAR, ParserState.CSI_ENTRY) -- CSI
		add(0x90, state, ParserAction.CLEAR, ParserState.DCS_ENTRY) -- DCS
	end

	-- Rules for executables and 7f
	addMany(EXECUTABLES, ParserState.GROUND, ParserAction.EXECUTE, ParserState.GROUND)
	addMany(EXECUTABLES, ParserState.ESCAPE, ParserAction.EXECUTE, ParserState.ESCAPE)
	add(0x7f, ParserState.ESCAPE, ParserAction.IGNORE, ParserState.ESCAPE)
	addMany(EXECUTABLES, ParserState.OSC_STRING, ParserAction.IGNORE, ParserState.OSC_STRING)
	addMany(EXECUTABLES, ParserState.CSI_ENTRY, ParserAction.EXECUTE, ParserState.CSI_ENTRY)
	add(0x7f, ParserState.CSI_ENTRY, ParserAction.IGNORE, ParserState.CSI_ENTRY)
	addMany(EXECUTABLES, ParserState.CSI_PARAM, ParserAction.EXECUTE, ParserState.CSI_PARAM)
	add(0x7f, ParserState.CSI_PARAM, ParserAction.IGNORE, ParserState.CSI_PARAM)
	addMany(EXECUTABLES, ParserState.CSI_IGNORE, ParserAction.EXECUTE, ParserState.CSI_IGNORE)
	addMany(EXECUTABLES, ParserState.CSI_INTERMEDIATE, ParserAction.EXECUTE, ParserState.CSI_INTERMEDIATE)
	add(0x7f, ParserState.CSI_INTERMEDIATE, ParserAction.IGNORE, ParserState.CSI_INTERMEDIATE)
	addMany(EXECUTABLES, ParserState.ESCAPE_INTERMEDIATE, ParserAction.EXECUTE, ParserState.ESCAPE_INTERMEDIATE)
	add(0x7f, ParserState.ESCAPE_INTERMEDIATE, ParserAction.IGNORE, ParserState.ESCAPE_INTERMEDIATE)

	-- OSC
	add(0x5d, ParserState.ESCAPE, ParserAction.OSC_START, ParserState.OSC_STRING)
	addRange(PRINTABLES_START, PRINTABLES_END, ParserState.OSC_STRING, ParserAction.OSC_PUT, ParserState.OSC_STRING)
	add(0x7f, ParserState.OSC_STRING, ParserAction.OSC_PUT, ParserState.OSC_STRING)
	addMany({ 0x9c, 0x1b, 0x18, 0x1a, 0x07 }, ParserState.OSC_STRING, ParserAction.OSC_END, ParserState.GROUND)
	addRange(0x1c, 0x20, ParserState.OSC_STRING, ParserAction.IGNORE, ParserState.OSC_STRING)

	-- sos/pm/apc does nothing
	addMany({ 0x58, 0x5e, 0x5f }, ParserState.ESCAPE, ParserAction.IGNORE, ParserState.SOS_PM_APC_STRING)
	addRange(PRINTABLES_START, PRINTABLES_END, ParserState.SOS_PM_APC_STRING, ParserAction.IGNORE, ParserState.SOS_PM_APC_STRING)
	addMany(EXECUTABLES, ParserState.SOS_PM_APC_STRING, ParserAction.IGNORE, ParserState.SOS_PM_APC_STRING)
	add(0x9c, ParserState.SOS_PM_APC_STRING, ParserAction.IGNORE, ParserState.GROUND)
	add(0x7f, ParserState.SOS_PM_APC_STRING, ParserAction.IGNORE, ParserState.SOS_PM_APC_STRING)

	-- csi entries
	add(0x5b, ParserState.ESCAPE, ParserAction.CLEAR, ParserState.CSI_ENTRY)
	addRange(0x40, 0x7f, ParserState.CSI_ENTRY, ParserAction.CSI_DISPATCH, ParserState.GROUND)
	addRange(0x30, 0x3c, ParserState.CSI_ENTRY, ParserAction.PARAM, ParserState.CSI_PARAM)
	addMany({ 0x3c, 0x3d, 0x3e, 0x3f }, ParserState.CSI_ENTRY, ParserAction.COLLECT, ParserState.CSI_PARAM)
	addRange(0x30, 0x3c, ParserState.CSI_PARAM, ParserAction.PARAM, ParserState.CSI_PARAM)
	addRange(0x40, 0x7f, ParserState.CSI_PARAM, ParserAction.CSI_DISPATCH, ParserState.GROUND)
	addMany({ 0x3c, 0x3d, 0x3e, 0x3f }, ParserState.CSI_PARAM, ParserAction.IGNORE, ParserState.CSI_IGNORE)
	addRange(0x20, 0x40, ParserState.CSI_IGNORE, ParserAction.IGNORE, ParserState.CSI_IGNORE)
	add(0x7f, ParserState.CSI_IGNORE, ParserAction.IGNORE, ParserState.CSI_IGNORE)
	addRange(0x40, 0x7f, ParserState.CSI_IGNORE, ParserAction.IGNORE, ParserState.GROUND)
	addRange(0x20, 0x30, ParserState.CSI_ENTRY, ParserAction.COLLECT, ParserState.CSI_INTERMEDIATE)
	addRange(0x20, 0x30, ParserState.CSI_INTERMEDIATE, ParserAction.COLLECT, ParserState.CSI_INTERMEDIATE)
	addRange(0x30, 0x40, ParserState.CSI_INTERMEDIATE, ParserAction.IGNORE, ParserState.CSI_IGNORE)
	addRange(0x40, 0x7f, ParserState.CSI_INTERMEDIATE, ParserAction.CSI_DISPATCH, ParserState.GROUND)
	addRange(0x20, 0x30, ParserState.CSI_PARAM, ParserAction.COLLECT, ParserState.CSI_INTERMEDIATE)

	-- esc_intermediate
	addRange(0x20, 0x30, ParserState.ESCAPE, ParserAction.COLLECT, ParserState.ESCAPE_INTERMEDIATE)
	addRange(0x20, 0x30, ParserState.ESCAPE_INTERMEDIATE, ParserAction.COLLECT, ParserState.ESCAPE_INTERMEDIATE)
	addRange(0x30, 0x7f, ParserState.ESCAPE_INTERMEDIATE, ParserAction.ESC_DISPATCH, ParserState.GROUND)
	addRange(0x30, 0x50, ParserState.ESCAPE, ParserAction.ESC_DISPATCH, ParserState.GROUND)
	addRange(0x51, 0x58, ParserState.ESCAPE, ParserAction.ESC_DISPATCH, ParserState.GROUND)
	addMany({ 0x59, 0x5a, 0x5c }, ParserState.ESCAPE, ParserAction.ESC_DISPATCH, ParserState.GROUND)
	addRange(0x60, 0x7f, ParserState.ESCAPE, ParserAction.ESC_DISPATCH, ParserState.GROUND)

	-- dcs entry
	add(0x50, ParserState.ESCAPE, ParserAction.CLEAR, ParserState.DCS_ENTRY)
	addMany(EXECUTABLES, ParserState.DCS_ENTRY, ParserAction.IGNORE, ParserState.DCS_ENTRY)
	add(0x7f, ParserState.DCS_ENTRY, ParserAction.IGNORE, ParserState.DCS_ENTRY)
	addRange(0x1c, 0x20, ParserState.DCS_ENTRY, ParserAction.IGNORE, ParserState.DCS_ENTRY)
	addRange(0x20, 0x30, ParserState.DCS_ENTRY, ParserAction.COLLECT, ParserState.DCS_INTERMEDIATE)
	addRange(0x30, 0x3c, ParserState.DCS_ENTRY, ParserAction.PARAM, ParserState.DCS_PARAM)
	addMany({ 0x3c, 0x3d, 0x3e, 0x3f }, ParserState.DCS_ENTRY, ParserAction.COLLECT, ParserState.DCS_PARAM)
	addMany(EXECUTABLES, ParserState.DCS_IGNORE, ParserAction.IGNORE, ParserState.DCS_IGNORE)
	addRange(0x20, 0x80, ParserState.DCS_IGNORE, ParserAction.IGNORE, ParserState.DCS_IGNORE)
	addRange(0x1c, 0x20, ParserState.DCS_IGNORE, ParserAction.IGNORE, ParserState.DCS_IGNORE)
	addMany(EXECUTABLES, ParserState.DCS_PARAM, ParserAction.IGNORE, ParserState.DCS_PARAM)
	add(0x7f, ParserState.DCS_PARAM, ParserAction.IGNORE, ParserState.DCS_PARAM)
	addRange(0x1c, 0x20, ParserState.DCS_PARAM, ParserAction.IGNORE, ParserState.DCS_PARAM)
	addRange(0x30, 0x3c, ParserState.DCS_PARAM, ParserAction.PARAM, ParserState.DCS_PARAM)
	addMany({ 0x3c, 0x3d, 0x3e, 0x3f }, ParserState.DCS_PARAM, ParserAction.IGNORE, ParserState.DCS_IGNORE)
	addRange(0x20, 0x30, ParserState.DCS_PARAM, ParserAction.COLLECT, ParserState.DCS_INTERMEDIATE)
	addMany(EXECUTABLES, ParserState.DCS_INTERMEDIATE, ParserAction.IGNORE, ParserState.DCS_INTERMEDIATE)
	add(0x7f, ParserState.DCS_INTERMEDIATE, ParserAction.IGNORE, ParserState.DCS_INTERMEDIATE)
	addRange(0x1c, 0x20, ParserState.DCS_INTERMEDIATE, ParserAction.IGNORE, ParserState.DCS_INTERMEDIATE)
	addRange(0x20, 0x30, ParserState.DCS_INTERMEDIATE, ParserAction.COLLECT, ParserState.DCS_INTERMEDIATE)
	addRange(0x30, 0x40, ParserState.DCS_INTERMEDIATE, ParserAction.IGNORE, ParserState.DCS_IGNORE)
	addRange(0x40, 0x7f, ParserState.DCS_INTERMEDIATE, ParserAction.DCS_HOOK, ParserState.DCS_PASSTHROUGH)
	addRange(0x40, 0x7f, ParserState.DCS_PARAM, ParserAction.DCS_HOOK, ParserState.DCS_PASSTHROUGH)
	addRange(0x40, 0x7f, ParserState.DCS_ENTRY, ParserAction.DCS_HOOK, ParserState.DCS_PASSTHROUGH)
	addMany(EXECUTABLES, ParserState.DCS_PASSTHROUGH, ParserAction.DCS_PUT, ParserState.DCS_PASSTHROUGH)
	addRange(PRINTABLES_START, PRINTABLES_END, ParserState.DCS_PASSTHROUGH, ParserAction.DCS_PUT, ParserState.DCS_PASSTHROUGH)
	add(0x7f, ParserState.DCS_PASSTHROUGH, ParserAction.IGNORE, ParserState.DCS_PASSTHROUGH)
	addMany({ 0x1b, 0x9c, 0x18, 0x1a }, ParserState.DCS_PASSTHROUGH, ParserAction.DCS_UNHOOK, ParserState.GROUND)

	-- special handling of unicode chars
	add(NON_ASCII_PRINTABLE, ParserState.GROUND, ParserAction.PRINT, ParserState.GROUND)
	add(NON_ASCII_PRINTABLE, ParserState.OSC_STRING, ParserAction.OSC_PUT, ParserState.OSC_STRING)
	add(NON_ASCII_PRINTABLE, ParserState.CSI_IGNORE, ParserAction.IGNORE, ParserState.CSI_IGNORE)
	add(NON_ASCII_PRINTABLE, ParserState.DCS_IGNORE, ParserAction.IGNORE, ParserState.DCS_IGNORE)
	add(NON_ASCII_PRINTABLE, ParserState.DCS_PASSTHROUGH, ParserAction.DCS_PUT, ParserState.DCS_PASSTHROUGH)
end

local VT500_TRANSITION_TABLE = buf

return VT500_TRANSITION_TABLE
