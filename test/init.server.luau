local Terminal = require(script.luau_term)
local Renderer = require(script.luau_term.renderer)

local term = Terminal.createTerminal(64, 40)
local size = Vector2.new(term.canvas.canvasWidth, term.canvas.canvasHeight)

local part = workspace:WaitForChild("terminal") :: Part
part.Size = Vector3.new(term.canvas.width / 4, term.canvas.height / 2)
local gui = part:WaitForChild("SurfaceGui") :: SurfaceGui
local label = gui:WaitForChild("ImageLabel") :: ImageLabel
local cursor = gui:WaitForChild("cursor") :: Frame
local image = Instance.new("EditableImage")
image.Parent = label
image:Resize(size)
gui.CanvasSize = size

function render()
	image:WritePixels(Vector2.zero, size, term.canvas.buffer)
	cursor.Position = UDim2.fromOffset(term.cursor.X * 8, term.cursor.Y * 16)
end

function write(str: string)
	Terminal.stdout(term, str)
	render()
end

local castle = game:GetService("HttpService"):GetAsync(
	"https://raw.githubusercontent.com/imsnif/terminal-anatomy-code-examples/main/raw_castle_ansi/castle"
)

write(castle)
