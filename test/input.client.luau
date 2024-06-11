local CAS = game:GetService("ContextActionService")
local StarterGui = game:GetService("StarterGui")

local InputMap = require(script.Parent.inputMap)

local event = script.Parent:WaitForChild("InputEvent") :: BindableEvent

local toggle = false

local function modifierBitMask(io: InputObject)
	return ((io:IsModifierKeyDown(Enum.ModifierKey.Alt) and 1 or 0) * 2 ^ 3)
		+ ((io:IsModifierKeyDown(Enum.ModifierKey.Ctrl) and 1 or 0) * 2 ^ 2)
		+ ((io:IsModifierKeyDown(Enum.ModifierKey.Shift) and 1 or 0) * 2 ^ 1)
		+ ((io:IsModifierKeyDown(Enum.ModifierKey.Meta) and 1 or 0) * 2 ^ 0)
end

local function handleInput(_, state: Enum.UserInputState, io: InputObject)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if io.KeyCode == Enum.KeyCode.RightAlt then
		toggle = not toggle
		StarterGui:SetCore("ChatBarDisabled", toggle)
	end
	if not toggle then
		return Enum.ContextActionResult.Pass
	end
	local mod = modifierBitMask(io)
	local code = io.KeyCode.Value
	local str = InputMap[mod] and InputMap[mod][code] or InputMap[0][code]
	if not str then
		return Enum.ContextActionResult.Pass
	end
	event:Fire(str)
	return Enum.ContextActionResult.Sink
end

CAS:BindActionAtPriority(
	"TerminalInput",
	handleInput,
	false,
	Enum.ContextActionPriority.High.Value + 10,
	Enum.UserInputType.Keyboard
)
