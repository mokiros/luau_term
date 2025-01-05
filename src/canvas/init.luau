local Types = require("./types")
local BitmapCanvas = require("./bitmap")
local TextLabelCanvas = require("./textlabel")

export type BitmapCanvasType = "Bitmap"
export type TextLabelCanvasType = "TextLabel"
export type CanvasType = BitmapCanvasType | TextLabelCanvasType
export type RGBA = Types.RGBA
export type Canvas<CanvasType> = Types.Canvas<CanvasType>
export type CanvasModule<CanvasType, CharacterData> = Types.CanvasModule<CanvasType, CharacterData>

local CanvasType = table.freeze({
	Bitmap = "Bitmap" :: BitmapCanvasType,
	TextLabel = "TextLabel" :: TextLabelCanvasType,
})

return table.freeze({
	CanvasType = CanvasType,
	Bitmap = BitmapCanvas,
	TextLabel = TextLabelCanvas,
} :: { CanvasType: typeof(CanvasType), [CanvasType]: CanvasModule<any, any> })
