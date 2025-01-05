local Types = require("./types")

type TextLabelCanvas = {
	frame: Frame,
	font: {
		Regular: Font,
		Bold: Font,
		Italic: Font,
		BoldItalic: Font,
	},
	lines: { Frame },
	labels: { TextLabel },
}

local TextLabelCanvas = {} :: Types.CanvasModule<TextLabelCanvas, string>

local function abgrToColor3(abgr: number): Color3
	local r = bit32.band(abgr, 0xff)
	local g = bit32.band(bit32.rshift(abgr, 8), 0xff)
	local b = bit32.band(bit32.rshift(abgr, 16), 0xff)

	return Color3.fromRGB(r, g, b)
end

local function copyLabel(targetLabel: TextLabel, sourceLabel: TextLabel): ()
	targetLabel.RichText = sourceLabel.RichText
	targetLabel.Text = sourceLabel.Text
	targetLabel.TextColor3 = sourceLabel.TextColor3
	targetLabel.BackgroundColor3 = sourceLabel.BackgroundColor3
	targetLabel.FontFace = sourceLabel.FontFace
end

local function clearLabel(label: TextLabel, clr: Color3): ()
	label.Text = ""
	label.BackgroundColor3 = clr
end

function TextLabelCanvas.draw(canvas, x, y, char, att, fg, bg)
	local label = canvas.canvas.labels[y * canvas.width + x + 1]
	label.TextColor3 = abgrToColor3(fg)
	if bg then
		label.BackgroundColor3 = abgrToColor3(bg)
	end
	if att.underline then
		label.RichText = true
		label.Text = "<u>" .. char .. "</u>"
	else
		label.RichText = false
		label.Text = char
	end
	local fonts = canvas.canvas.font
	if att.bold and att.italic then
		label.FontFace = fonts.BoldItalic
	elseif att.bold then
		label.FontFace = fonts.Bold
	elseif att.italic then
		label.FontFace = fonts.Italic
	else
		label.FontFace = fonts.Regular
	end
end

function TextLabelCanvas.fillCell(canvas, x, y, bg)
	clearLabel(canvas.canvas.labels[y * canvas.width + x + 1], abgrToColor3(bg))
end

function TextLabelCanvas.fillLines(canvas, startY, count, bg)
	local clr = abgrToColor3(bg)
	local labels = canvas.canvas.labels
	for i = startY * canvas.width + 1, (startY + count) * canvas.width do
		clearLabel(labels[i], clr)
	end
end

function TextLabelCanvas.fillScreen(canvas, bg)
	TextLabelCanvas.fillLines(canvas, 0, canvas.height, bg)
end

function TextLabelCanvas.shiftDown(canvas, lines, topMargin, bottomMargin, bg)
	local availableLines = canvas.height - topMargin - bottomMargin

	if availableLines < 1 then
		warn("Margins exceed canvas height, not shifting")
		return
	end

	local labels = canvas.canvas.labels

	local clampedLines = math.clamp(lines, 1, availableLines)
	local startOffset = canvas.width * topMargin + 1
	local emptyLinesOffset = canvas.width * clampedLines
	local midOffset = startOffset + emptyLinesOffset
	local endOffset = canvas.width * (canvas.height - bottomMargin)

	for i = endOffset, midOffset, -1 do
		copyLabel(labels[i], labels[i - emptyLinesOffset])
	end

	local clr = abgrToColor3(bg)

	for i = startOffset, midOffset - 1 do
		clearLabel(labels[i], clr)
	end
end

function TextLabelCanvas.shiftUp(canvas, lines, topMargin, bottomMargin, bg)
	local availableLines = canvas.height - topMargin - bottomMargin

	if availableLines < 1 then
		warn("Margins exceed canvas height, not shifting")
		return
	end

	local labels = canvas.canvas.labels

	local clampedLines = math.clamp(lines, 1, availableLines)
	local startOffset = canvas.width * topMargin + 1
	local endOffset = canvas.width * (canvas.height - bottomMargin)
	local emptyLinesOffset = canvas.width * clampedLines
	local midOffset = endOffset - emptyLinesOffset + 1

	for i = startOffset, midOffset - 1 do
		copyLabel(labels[i], labels[i + emptyLinesOffset])
	end

	local clr = abgrToColor3(bg)

	for i = midOffset, endOffset do
		clearLabel(labels[i], clr)
	end
end

function TextLabelCanvas.shiftRight(canvas, y, startX, endX, emptyCellCount, bg)
	local clr = abgrToColor3(bg)
	local labels = canvas.canvas.labels

	local lineOffset = canvas.width * y + 1
	local width = endX - startX
	local cellsToCopy = width - emptyCellCount

	for x = 0, cellsToCopy do
		local i = lineOffset + endX - x
		copyLabel(labels[i], labels[i - emptyCellCount])
	end

	for x = 0, emptyCellCount - 1 do
		clearLabel(labels[lineOffset + startX + x], clr)
	end
end

function TextLabelCanvas.shiftLeft(canvas, y, startX, endX, emptyCellCount, bg)
	local clr = abgrToColor3(bg)
	local labels = canvas.canvas.labels

	local lineOffset = canvas.width * y + 1
	local width = endX - startX
	local cellsToCopy = width - emptyCellCount

	for x = 0, cellsToCopy do
		local i = lineOffset + startX + x
		copyLabel(labels[i], labels[i + emptyCellCount])
	end

	for x = 0, emptyCellCount - 1 do
		clearLabel(labels[lineOffset + endX - x], clr)
	end
end

function TextLabelCanvas.createCanvas(w, h, cellSize)
	assert(Instance, "TextLabelCanvas can only be used in Roblox environment!")

	local cs = cellSize or 8
	local len = w * h

	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)

	local fonts = {
		Regular = Font.new("rbxasset://fonts/families/Inconsolata.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
		Bold = Font.new("rbxasset://fonts/families/Inconsolata.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
		Italic = Font.new("rbxasset://fonts/families/Inconsolata.json", Enum.FontWeight.Regular, Enum.FontStyle.Italic),
		BoldItalic = Font.new("rbxasset://fonts/families/Inconsolata.json", Enum.FontWeight.Bold, Enum.FontStyle.Italic),
	}

	local lines = table.create(h)
	local labels = table.create(len)
	for line = 1, h do
		local lineFrame = Instance.new("Frame")
		lineFrame.BackgroundTransparency = 1
		lineFrame.Size = UDim2.fromScale(1 / w, 1 / h)
		lineFrame.Position = UDim2.fromScale(0, (line - 1) / h)
		lineFrame.Parent = frame

		lines[line] = lineFrame

		for char = 1, w do
			local label = Instance.new("TextLabel")
			label.BorderSizePixel = 0
			label.BackgroundColor3 = Color3.new(0, 0, 0)
			label.TextColor3 = Color3.new(1, 1, 1)
			label.Size = UDim2.fromScale(1, 1)
			label.Position = UDim2.fromScale(char - 1, 0)
			label.FontFace = fonts.Regular
			label.TextSize = cs * 2
			label.TextScaled = false
			label.TextWrapped = false
			label.TextXAlignment = Enum.TextXAlignment.Center
			label.TextYAlignment = Enum.TextYAlignment.Center
			label.AutoLocalize = false
			label.Parent = lineFrame

			labels[(line - 1) * w + char] = label
		end
	end

	local canvas: Types.Canvas<TextLabelCanvas> = {
		canvas = {
			frame = frame,
			font = fonts,
			lines = lines,
			labels = labels,
		},
		length = len,
		width = w,
		height = h,
		cellSize = cs,
	}

	return canvas
end

return table.freeze(TextLabelCanvas)
