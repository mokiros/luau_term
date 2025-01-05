export type RGBA = number

export type Canvas<CanvasType> = {
	canvas: CanvasType,
	length: number,
	width: number,
	height: number,
	cellSize: number,
}

export type Attributes = {
	underline: boolean,
	bold: boolean,
	italic: boolean,
}

export type CanvasModule<CanvasType, CharacterData> = {
	draw: (canvas: Canvas<CanvasType>, x: number, y: number, data: CharacterData, att: Attributes, fg: RGBA, bg: RGBA?) -> (),
	fillCell: (canvas: Canvas<CanvasType>, x: number, y: number, bg: RGBA) -> (),
	fillLines: (canvas: Canvas<CanvasType>, y: number, count: number, bg: RGBA) -> (),
	fillScreen: (canvas: Canvas<CanvasType>, bg: RGBA) -> (),
	shiftDown: (canvas: Canvas<CanvasType>, count: number, topMargin: number, bottomMargin: number, bg: RGBA) -> (),
	shiftUp: (canvas: Canvas<CanvasType>, count: number, topMargin: number, bottomMargin: number, bg: RGBA) -> (),
	shiftRight: (canvas: Canvas<CanvasType>, y: number, x1: number, x2: number, count: number, bg: RGBA) -> (),
	shiftLeft: (canvas: Canvas<CanvasType>, y: number, x1: number, x2: number, count: number, bg: RGBA) -> (),
	createCanvas: (w: number, h: number, cellSize: number?) -> Canvas<CanvasType>,
}

return {}
