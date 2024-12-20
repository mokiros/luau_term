local Terminal = require(script.luau_term)

local std = script:WaitForChild("stdio") :: RemoteEvent
local newSession = script:WaitForChild("NewSession") :: RemoteFunction

local font = (script:WaitForChild("GetFont") :: RemoteFunction):InvokeServer()
local parseUnifont = Terminal.parseUnifont
local parsedFont = parseUnifont(font)

local term = Terminal.createTerminal(80, 30, parsedFont)
local sessionid = newSession:InvokeServer(term.currentScreen.canvas.width, term.currentScreen.canvas.height, "xterm-256color")
function term:stdin(str)
	std:FireServer(sessionid, str)
end

local pixelSize = Vector2.new(term.currentScreen.canvas.width * 8, term.currentScreen.canvas.height * 16)

local player = game:GetService("Players").LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local gui = Instance.new("ScreenGui")
gui.ResetOnSpawn = false
gui.Parent = PlayerGui
local label = Instance.new("ImageLabel")
label.AnchorPoint = Vector2.new(0.5, 0.5)
label.Size = UDim2.fromOffset(pixelSize.X - 2, pixelSize.Y - 2)
label.Position = UDim2.fromScale(0.5, 0.5)
label.ResampleMode = Enum.ResamplerMode.Pixelated
label.Parent = gui

local cursor = Instance.new("Frame")
cursor.Size = UDim2.fromOffset(6, 14)
cursor.BackgroundTransparency = 1
cursor.Parent = label
local stroke = Instance.new("UIStroke")
stroke.Thickness = 1
stroke.Color = Color3.new(1, 1, 1)
stroke.Parent = cursor

local image = game:GetService("AssetService"):CreateEditableImage({
	Size = pixelSize,
})

label.ImageContent = Content.fromObject(image)

local function render()
	image:WritePixelsBuffer(Vector2.zero, pixelSize, term.currentScreen.canvas.canvas)
	cursor.Position = UDim2.fromOffset(term.currentScreen.cursor.x * 8 + 1, term.currentScreen.cursor.y * 16 + 1)
end

render()

std.OnClientEvent:Connect(function(id, str)
	Terminal.stdout(term, buffer.fromstring(str))
	render()
end)

local createInput = require(script.input)
local info = createInput()
local inputBox = info.box

inputBox.ZIndex = 999
inputBox.Size = UDim2.fromScale(1, 1)
inputBox.Transparency = 1
inputBox.TextTransparency = 1
inputBox.TextSize = 0
inputBox.Parent = label

function term:changeCursorKeyFormat(mode)
	info.mode = mode
end

function term:changeCursorVisibility(visible)
	cursor.Visible = visible
end

function term:changeBracketedPasteMode(enable)
	info.bracketedPaste = enable
end

info.event.Event:Connect(function(str)
	std:FireServer(sessionid, str)
end)
