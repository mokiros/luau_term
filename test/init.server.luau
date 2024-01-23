local term = require(script.luau_term)
local Renderer = require(script.luau_term.renderer)

local terminal = term.createTerminal(40, 15)
local size = Vector2.new(terminal.canvas.canvasWidth, terminal.canvas.canvasHeight)

local part = workspace:WaitForChild("terminal")
local label = part:WaitForChild("SurfaceGui"):WaitForChild("ImageLabel")
local image = Instance.new("EditableImage")
image.Parent = label
image:Resize(size)

function render()
	image:WritePixels(Vector2.zero, size, terminal.canvas.buffer)
end

function write(str: string)
	term.stdout(terminal, str)
	render()
end

while task.wait() do
	write("a")
	task.wait()
	write("s")
	task.wait()
	write("d")
end
