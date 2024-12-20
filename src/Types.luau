local canvas = require(script.Parent.canvas)
local Charsets = require(script.Parent.Charsets)

export type Cursor = Vector2

export type Params = {
	_length: number,
	_isSubParam: boolean,
	params: { number },
	subParams: { [number]: { number } },
	[number]: never,
}

export type Parser = {
	currentState: number,
	collect: number,
	params: Params,
	stringData: buffer,
	stringDataLength: number,
	oscState: number,
	ident: number,
}

export type TerminalScreen = {
	canvas: canvas.Canvas,
	cursor: Cursor,
	savedCursor: Cursor,
	tabs: { number },
}

export type Terminal = {
	currentScreen: TerminalScreen,
	screens: {
		normal: TerminalScreen,
		alternate: TerminalScreen,
	},
	parser: Parser,
	handlers: Handlers,
	font: { buffer },
	charset: Charsets.Charset,
	attributes: {
		bold: boolean,
		underline: boolean,
		inverted: boolean,
	},
	topMargin: number,
	bottomMargin: number,
	lastPrintedCodepoint: number,
	cursorHidden: boolean,
	modes: {
		insert: boolean,
	},
	options: {
		convertEol: boolean,
		cursorBlink: boolean,
	},
	decPrivateModes: {
		applicationCursorKeys: boolean,
		applicationKeypad: boolean,
		bracketedPasteMode: boolean,
		origin: boolean,
		reverseWraparound: boolean,
		sendFocus: boolean,
		wraparound: boolean,
	},
	theme: { canvas.RGBA },
	fgColor: canvas.RGBA,
	fgIndex: number,
	bgColor: canvas.RGBA,
	bgIndex: number,

	-- externally supplied functions
	stdin: (self: Terminal, str: string) -> (),
	bell: (self: Terminal) -> (),
	changeCursorKeyFormat: (self: Terminal, mode: boolean) -> (),
	changeCursorVisibility: (self: Terminal, visible: boolean) -> (),
	changeBracketedPasteMode: (self: Terminal, enable: boolean) -> (),
}

export type Handlers = {
	csi: { (term: Terminal, params: Params) -> () },
	csiFallback: (term: Terminal, ident: number, params: Params) -> (),
	dcs: { (term: Terminal, data: buffer, dataLength: number, params: Params) -> () },
	dcsFallback: (term: Terminal, ident: number, data: buffer, dataLength: number, params: Params) -> (),
	osc: { (term: Terminal, data: buffer, dataLength: number) -> () },
	oscFallback: (term: Terminal, ident: number, data: buffer, dataLength: number) -> (),
	esc: { (term: Terminal) -> () },
	escFallback: (term: Terminal, code: number) -> (),
	exec: { (term: Terminal) -> () },
	execFallback: (term: Terminal, code: number) -> (),
	print: (term: Terminal, code: number) -> (),
	error: (term: Terminal, code: number) -> (),
}

return table.freeze({})
