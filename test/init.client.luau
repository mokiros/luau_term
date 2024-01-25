local Terminal = require(script.luau_term)
local Renderer = require(script.luau_term.renderer)

local parseUnifont = require(script.unifont)

local font = script:WaitForChild("GetFont"):InvokeServer()
local parsedFont = parseUnifont(font)

local term = Terminal.createTerminal(40, 20, { normal = parsedFont })
local size = Vector2.new(term.canvas.canvasWidth, term.canvas.canvasHeight)

local part = workspace:WaitForChild("terminal") :: Part
part.Size = Vector3.new(term.canvas.width / 8, term.canvas.height / 4)
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

local std = script:WaitForChild("stdio") :: RemoteEvent
local newSession = script:WaitForChild("NewSession") :: RemoteFunction
local event = Instance.new("BindableEvent")
event.Name = "InputEvent"
event.Parent = script

local inputBuffer = ""

term.stdin = function(str: string)
	inputBuffer ..= str
end

local sessionid = newSession:InvokeServer(term.canvas.width, term.canvas.height)

event.Event:Connect(function(str)
	std:FireServer(sessionid, str)
end)

term.stdin = function(str)
	std:FireServer(sessionid, str)
end

std.OnClientEvent:Connect(function(id, str)
	write(str)
end)
