local Terminal = require(script.luau_term)
local TERMINAL_WIDTH = 80
local TERMINAL_HEIGHT = 30
local TERMINAL_CANVAS_TYPE: "Bitmap" = "Bitmap"

local std = script:WaitForChild("stdio") :: RemoteEvent
local newSession = script:WaitForChild("NewSession") :: RemoteFunction

local parsedFont
if TERMINAL_CANVAS_TYPE == "Bitmap" then
	local font = (script:WaitForChild("GetFont") :: RemoteFunction):InvokeServer()
	local parseUnifont = Terminal.parseUnifont
	parsedFont = parseUnifont(font)
end

local term = Terminal.createTerminal(TERMINAL_CANVAS_TYPE, TERMINAL_WIDTH, TERMINAL_HEIGHT, parsedFont)

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

local container = Instance.new("Frame")
container.AnchorPoint = Vector2.new(0.5, 0.5)
container.Size = UDim2.fromOffset(pixelSize.X, pixelSize.Y)
container.Position = UDim2.fromScale(0.5, 0.5)
container.Parent = gui

local _renderCanvas

if TERMINAL_CANVAS_TYPE == "Bitmap" then
	local label = Instance.new("ImageLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.ResampleMode = Enum.ResamplerMode.Pixelated
	label.Parent = container

	local image = game:GetService("AssetService"):CreateEditableImage({
		Size = pixelSize,
	})

	label.ImageContent = Content.fromObject(image)

	_renderCanvas = function()
		image:WritePixelsBuffer(Vector2.zero, pixelSize, term.currentScreen.canvas.canvas)
	end
elseif TERMINAL_CANVAS_TYPE == "TextLabel" then
	local normalScreen = term.screens.normal
	local normalScreenFrame = normalScreen.canvas.canvas.frame
	local alternateScreen = term.screens.alternate
	local alternateScreenFrame = alternateScreen.canvas.canvas.frame

	normalScreenFrame.Parent = container
	alternateScreenFrame.Parent = container

	_renderCanvas = function()
		local currentScreen = term.currentScreen
		if currentScreen == term.screens.normal then
			normalScreenFrame.Visible = true
			alternateScreenFrame.Visible = false
		else
			normalScreenFrame.Visible = false
			alternateScreenFrame.Visible = true
		end
	end
end

local cursor = Instance.new("Frame")
cursor.Size = UDim2.fromOffset(6, 14)
cursor.BackgroundTransparency = 1
cursor.Parent = container
local stroke = Instance.new("UIStroke")
stroke.Thickness = 1
stroke.Color = Color3.new(1, 1, 1)
stroke.Parent = cursor

local function render()
	_renderCanvas()
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
inputBox.Parent = container

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
