local canvas = require(script.Parent.canvas)

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

export type Params = {
	_length: number,
	_isSubParam: boolean,
	params: { number },
	subParams: { [number]: { number } },
	[number]: never,
}

export type Parser = {
	transitions: buffer,
	initialState: number,
	currentState: number,
	collect: number,
	precedingJoinState: number,
	params: Params,
	stringData: buffer,
	stringDataLength: number,
	oscState: number,
	ident: number,
}

export type Terminal = {
	canvas: canvas.Canvas,
	parser: Parser,
	handlers: Handlers,
	cursor: Vector2,
	font: { buffer },
	fgColor: canvas.RGBA,
	fgIndex: number,
	bgColor: canvas.RGBA,
	bgIndex: number,
}

export type Handlers = {
	csi: { (term: Terminal, params: Params) -> () },
	dcs: { (term: Terminal, data: buffer, dataLength: number, params: Params) -> () },
	osc: { (term: Terminal, data: buffer, dataLength: number) -> () },
	esc: { (term: Terminal) -> () },
	exec: { (term: Terminal) -> () },
	print: (term: Terminal, code: number) -> (),
	error: (term: Terminal, code: number) -> (),
}

local DATA_LIMIT = 1024

local NON_ASCII_PRINTABLE = 0xA0

local TableAccess = table.freeze({
	TRANSITION_ACTION_SHIFT = 4,
	TRANSITION_STATE_MASK = 15,
	INDEX_STATE_SHIFT = 8,
})

return {
	ParserState = ParserState,
	ParserAction = ParserAction,
	OscState = OscState,
	NON_ASCII_PRINTABLE = NON_ASCII_PRINTABLE,
	TableAccess = TableAccess,
	C0 = C0,
	C1 = C1,
	DCS_DATA_LIMIT = DATA_LIMIT,
}
