local ParserState = table.freeze({
	GROUND = 0,
	ESCAPE = 1,
	ESCAPE_INTERMEDIATE = 2,
	CSI_ENTRY = 3,
	CSI_PARAM = 4,
	CSI_INTERMEDIATE = 5,
	CSI_IGNORE = 6,
	SOS_PM_APC_STRING = 7,
	OSC_STRING = 8,
	DCS_ENTRY = 9,
	DCS_PARAM = 10,
	DCS_IGNORE = 11,
	DCS_INTERMEDIATE = 12,
	DCS_PASSTHROUGH = 13,
})

local ParserAction = table.freeze({
	IGNORE = 0,
	ERROR = 1,
	PRINT = 2,
	EXECUTE = 3,
	OSC_START = 4,
	OSC_PUT = 5,
	OSC_END = 6,
	CSI_DISPATCH = 7,
	PARAM = 8,
	COLLECT = 9,
	ESC_DISPATCH = 10,
	CLEAR = 11,
	DCS_HOOK = 12,
	DCS_PUT = 13,
	DCS_UNHOOK = 14,
})

local OscState = table.freeze({
	START = 0,
	ID = 1,
	PAYLOAD = 2,
	ABORT = 3,
})

-- C0 control codes
-- See = https://en.wikipedia.org/wiki/C0_and_C1_control_codes
local C0 = table.freeze({
	--  Null (Caret = ^@, C = \0)
	NUL = 0x00,
	--  Start of Heading (Caret = ^A)
	SOH = 0x01,
	--  Start of Text (Caret = ^B)
	STX = 0x02,
	--  End of Text (Caret = ^C)
	ETX = 0x03,
	--  End of Transmission (Caret = ^D)
	EOT = 0x04,
	--  Enquiry (Caret = ^E)
	ENQ = 0x05,
	--  Acknowledge (Caret = ^F)
	ACK = 0x06,
	--  Bell (Caret = ^G, C = \a)
	BEL = 0x07,
	--  Backspace (Caret = ^H, C = \b)
	BS = 0x08,
	--  Character Tabulation, Horizontal Tabulation (Caret = ^I, C = \t)
	HT = 0x09,
	--  Line Feed (Caret = ^J, C = \n)
	LF = 0x0a,
	--  Line Tabulation, Vertical Tabulation (Caret = ^K, C = \v)
	VT = 0x0b,
	--  Form Feed (Caret = ^L, C = \f)
	FF = 0x0c,
	--  Carriage Return (Caret = ^M, C = \r)
	CR = 0x0d,
	--  Shift Out (Caret = ^N)
	SO = 0x0e,
	--  Shift In (Caret = ^O)
	SI = 0x0f,
	--  Data Link Escape (Caret = ^P)
	DLE = 0x10,
	--  Device Control One (XON) (Caret = ^Q)
	DC1 = 0x11,
	--  Device Control Two (Caret = ^R)
	DC2 = 0x12,
	--  Device Control Three (XOFF) (Caret = ^S)
	DC3 = 0x13,
	--  Device Control Four (Caret = ^T)
	DC4 = 0x14,
	--  Negative Acknowledge (Caret = ^U)
	NAK = 0x15,
	--  Synchronous Idle (Caret = ^V)
	SYN = 0x16,
	--  End of Transmission Block (Caret = ^W)
	ETB = 0x17,
	--  Cancel (Caret = ^X)
	CAN = 0x18,
	--  End of Medium (Caret = ^Y)
	EM = 0x19,
	--  Substitute (Caret = ^Z)
	SUB = 0x1a,
	--  Escape (Caret = ^[, C = \e)
	ESC = 0x1b,
	--  File Separator (Caret = ^\)
	FS = 0x1c,
	--  Group Separator (Caret = ^])
	GS = 0x1d,
	--  Record Separator (Caret = ^^)
	RS = 0x1e,
	--  Unit Separator (Caret = ^_)
	US = 0x1f,
	--  Space
	SP = 0x20,
	--  Delete (Caret = ^?)
	DEL = 0x7f,
})

-- C1 control codes
-- See = https://en.wikipedia.org/wiki/C0_and_C1_control_codes
local C1 = table.freeze({
	--  padding character
	PAD = 0x80,
	--  High Octet Preset
	HOP = 0x81,
	--  Break Permitted Here
	BPH = 0x82,
	--  No Break Here
	NBH = 0x83,
	--  Index
	IND = 0x84,
	--  Next Line
	NEL = 0x85,
	--  Start of Selected Area
	SSA = 0x86,
	--  End of Selected Area
	ESA = 0x87,
	--  Horizontal Tabulation Set
	HTS = 0x88,
	--  Horizontal Tabulation With Justification
	HTJ = 0x89,
	--  Vertical Tabulation Set
	VTS = 0x8a,
	--  Partial Line Down
	PLD = 0x8b,
	--  Partial Line Up
	PLU = 0x8c,
	--  Reverse Index
	RI = 0x8d,
	--  Single-Shift 2
	SS2 = 0x8e,
	--  Single-Shift 3
	SS3 = 0x8f,
	--  Device Control String
	DCS = 0x90,
	--  Private Use 1
	PU1 = 0x91,
	--  Private Use 2
	PU2 = 0x92,
	--  Set Transmit State
	STS = 0x93,
	--  Destructive backspace, intended to eliminate ambiguity about meaning of BS.
	CCH = 0x94,
	--  Message Waiting
	MW = 0x95,
	--  Start of Protected Area
	SPA = 0x96,
	--  End of Protected Area
	EPA = 0x97,
	--  Start of String
	SOS = 0x98,
	--  Single Graphic Character Introducer
	SGCI = 0x99,
	--  Single Character Introducer
	SCI = 0x9a,
	--  Control Sequence Introducer
	CSI = 0x9b,
	--  String Terminator
	ST = 0x9c,
	--  Operating System Command
	OSC = 0x9d,
	--  Privacy Message
	PM = 0x9e,
	--  Application Program Command
	APC = 0x9f,
})

local DATA_LIMIT = 1024

local NON_ASCII_PRINTABLE = 0xA0

local DEFAULT_TAB_WIDTH = 8

local TableAccess = table.freeze({
	TRANSITION_ACTION_SHIFT = 4,
	TRANSITION_STATE_MASK = 15,
	INDEX_STATE_SHIFT = 8,
})

-- Since buffers use little endian, the numbers have to be written in ABGR format
local ANSI_COLORS = {
	0xff_00_00_00, -- 0, 0, 0
	0xff_00_00_bb, -- 187, 0, 0
	0xff_00_bb_00, -- 0, 187, 0
	0xff_00_bb_bb, -- 187, 187, 0
	0xff_bb_00_00, -- 0, 0, 187
	0xff_bb_00_bb, -- 187, 0, 187
	0xff_bb_bb_00, -- 0, 187, 187
	0xff_bb_bb_bb, -- 187, 187, 187

	-- Bright colors
	0xff_55_55_55, -- 85, 85, 85
	0xff_55_55_ff, -- 255, 85, 85
	0xff_55_ff_55, -- 85, 255, 85
	0xff_55_ff_ff, -- 255, 255, 85
	0xff_ff_55_55, -- 85, 85, 255
	0xff_ff_55_ff, -- 255, 85, 255
	0xff_ff_ff_55, -- 85, 255, 255
	0xff_ff_ff_ff, -- 255, 255, 255
}

-- generate remaining 240 ANSI colors
do
	local v = { 0x00, 0x5f, 0x87, 0xaf, 0xd7, 0xff }
	for i = 0, 215 do
		local r = v[(i // 36) % 6 + 1]
		local g = v[(i // 6) % 6 + 1]
		local b = v[i % 6 + 1]

		ANSI_COLORS[i + 17] = 0xff_00_00_00 + b * 0x10000 + g * 0x100 + r
	end

	for i = 0, 23 do
		local c = 8 + i * 10

		ANSI_COLORS[i + 233] = 0xff_00_00_00 + c * 0x10000 + c * 0x100 + c
	end
end

local Constants = table.freeze({
	ParserState = ParserState,
	ParserAction = ParserAction,
	OscState = OscState,
	NON_ASCII_PRINTABLE = NON_ASCII_PRINTABLE,
	TableAccess = TableAccess,
	C0 = C0,
	C1 = C1,
	DCS_DATA_LIMIT = DATA_LIMIT,
	DEFAULT_TAB_WIDTH = DEFAULT_TAB_WIDTH,
	ANSI_COLORS = ANSI_COLORS,
})

return Constants
