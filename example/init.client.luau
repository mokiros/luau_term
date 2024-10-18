local Terminal = require(script.luau_term)

local std = script:WaitForChild("stdio") :: RemoteEvent
local newSession = script:WaitForChild("NewSession") :: RemoteFunction
local event = Instance.new("BindableEvent")
event.Name = "InputEvent"
event.Parent = script

local font = script:WaitForChild("GetFont"):InvokeServer()
local parseUnifont = require(script.unifont)
local parsedFont = parseUnifont(font)

-- Since buffers use little endian, the numbers have to be written in ABGR format
local colorTheme = {
	0xff_00_00_00, -- 0, 0, 0
	0xff_00_00_bb, -- 187, 0, 0
	0xff_00_bb_00, -- 0, 187, 0
	0xff_00_bb_bb, -- 187, 187, 0
	0xff_bb_00_00, -- 0, 0, 187
	0xff_bb_00_bb, -- 187, 0, 187
	0xff_bb_bb_00, -- 0, 187, 187
	0xff_bb_bb_bb, -- 187, 187, 187

	-- Bright colors
	0xff_55_55_55, -- 85, 85, 85
	0xff_55_55_ff, -- 255, 85, 85
	0xff_55_ff_55, -- 85, 255, 85
	0xff_55_ff_ff, -- 255, 255, 85
	0xff_ff_55_55, -- 85, 85, 255
	0xff_ff_55_ff, -- 255, 85, 255
	0xff_ff_ff_55, -- 85, 255, 255
	0xff_ff_ff_ff, -- 255, 255, 255
}

local term = Terminal.createTerminal(128, 32, parsedFont, colorTheme)
local sessionid = newSession:InvokeServer(term.currentScreen.canvas.width, term.currentScreen.canvas.height, "xterm-256color")
term.stdin = function(str)
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
label.Size = UDim2.fromOffset(pixelSize.X, pixelSize.Y)
label.Position = UDim2.fromScale(0.5, 0.5)
label.ResampleMode = Enum.ResamplerMode.Pixelated
label.Parent = gui

local cursor = Instance.new("Frame")
cursor.Size = UDim2.fromOffset(8, 16)
cursor.Parent = label
local image = Instance.new("EditableImage")
image.Parent = label
image:Resize(pixelSize)

event.Event:Connect(function(str)
	std:FireServer(sessionid, str)
end)

std.OnClientEvent:Connect(function(id, str)
	Terminal.stdout(term, str)
	image:WritePixelsBuffer(Vector2.zero, pixelSize, term.currentScreen.canvas.canvas)
	cursor.Position = UDim2.fromOffset(term.currentScreen.cursor.X * 8, term.currentScreen.cursor.Y * 16)
end)
