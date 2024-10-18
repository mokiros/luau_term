local CAS = game:GetService("ContextActionService")
local StarterGui = game:GetService("StarterGui")

local event = Instance.new("BindableEvent")
event.Name = "InputEvent"
event.Parent = script

local toggle = false

local function modifierBitMask(io: InputObject)
	local ctrl = io:IsModifierKeyDown(Enum.ModifierKey.Ctrl)
	local shift = io:IsModifierKeyDown(Enum.ModifierKey.Shift)

	return bit32.band(ctrl and 0b0011111 or 0b1111111, shift and 0b1011111 or 0b1111111)
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
	local code = io.KeyCode.Value
	if code > 0b100010000 and code < 0b100010101 then
		-- Special case for arrow keys
		local shift = io:IsModifierKeyDown(Enum.ModifierKey.Shift) and 0b100 or 0
		local ctrl = io:IsModifierKeyDown(Enum.ModifierKey.Ctrl) and 0b010 or 0
		local alt = io:IsModifierKeyDown(Enum.ModifierKey.Alt) and 0b001 or 0
		local t = { "", "1;3", "1;5", "1;7", "", "1;4", "1;6", "1;8" }
		local str = string.format("\27[%s%s", t[shift + ctrl + alt + 1], string.char(bit32.band(code, 0b111) + 0b1000000))
		event:Fire(str)
		return Enum.ContextActionResult.Sink
	elseif code > 127 then
		return Enum.ContextActionResult.Pass
	end
	local mod = modifierBitMask(io)
	local str = string.char(bit32.band(code, mod))
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

return event
