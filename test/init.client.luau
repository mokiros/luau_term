local Terminal = require(script.luau_term)
local parseUnifont = require(script.unifont)

local font = script:WaitForChild("GetFont"):InvokeServer()
local parsedFont = parseUnifont(font)
local themes = require(script.colors)
local defaultTheme = themes.Default

local TERM = 'vt100'

local term = Terminal.createTerminal(100, 30, parsedFont, defaultTheme)
local size = Vector2.new(term.currentScreen.canvas.width * 8, term.currentScreen.canvas.height * 16)

local player = game:GetService("Players").LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local gui = Instance.new("ScreenGui")
gui.ResetOnSpawn = false
gui.Parent = PlayerGui
local label = Instance.new("ImageLabel")
label.AnchorPoint = Vector2.new(0.5, 0.5)
label.Size = UDim2.fromOffset(size.X, size.Y)
label.Position = UDim2.fromScale(0.5, 0.5)
label.ResampleMode = Enum.ResamplerMode.Pixelated
label.Parent = gui

local cursor = Instance.new("Frame")
cursor.Size = UDim2.fromOffset(8, 16)
cursor.Parent = label
local image = Instance.new("EditableImage")
image.Parent = label
image:Resize(size)

function render()
	image:WritePixels(Vector2.zero, size, term.currentScreen.canvas.canvas)
	cursor.Position = UDim2.fromOffset(term.currentScreen.cursor.X * 8, term.currentScreen.cursor.Y * 16)
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

local sessionid = newSession:InvokeServer(term.currentScreen.canvas.width, term.currentScreen.canvas.height, TERM)

event.Event:Connect(function(str)
	std:FireServer(sessionid, str)
end)

term.stdin = function(str)
	std:FireServer(sessionid, str)
end

std.OnClientEvent:Connect(function(id, str)
	write(str)
end)
