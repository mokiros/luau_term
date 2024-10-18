local UIS = game:GetService("UserInputService")

local inputBoxes: { [TextBox]: BindableEvent } = {}

local function modifierBitMask(io: InputObject)
	local ctrl = io:IsModifierKeyDown(Enum.ModifierKey.Ctrl)
	local shift = io:IsModifierKeyDown(Enum.ModifierKey.Shift)

	return bit32.band(ctrl and 0b0011111 or 0b1111111, shift and 0b1011111 or 0b1111111)
end

local function handleInput(io: InputObject, handledByEngine: boolean)
	if io.UserInputState ~= Enum.UserInputState.Begin or not handledByEngine then
		return
	end
	local focusedBox = UIS:GetFocusedTextBox()
	local event = focusedBox and inputBoxes[focusedBox] or nil
	if not event then
		return
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
		return
	elseif code > 127 then
		return
	end
	local mod = modifierBitMask(io)
	local str = string.char(bit32.band(code, mod))
	if str then
		event:Fire(str)
	end
end

UIS.InputBegan:Connect(handleInput)

return function()
	local box = Instance.new("TextBox")
	box.Name = "InputBox"
	box.MultiLine = true
	box.ClearTextOnFocus = true
	local event = Instance.new("BindableEvent")
	event.Name = "InputEvent"
	event.Parent = box
	inputBoxes[box] = event

	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			box:CaptureFocus()
		end
	end)

	return box, event
end
