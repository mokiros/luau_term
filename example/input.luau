local UIS = game:GetService("UserInputService")

local inputBoxes: { [TextBox]: { box: TextBox, event: BindableEvent, mode: boolean } } = {}

local InputMap: { [number]: { [number]: number | string } } = {
	-- No modifier keys
	[0b00] = {},

	-- Only shift
	[0b01] = {},

	-- Only ctrl
	[0b10] = {},

	-- Both shift and ctrl
	[0b11] = {},
}

-- Generating the input map based on US keyboard layout:
do
	-- A-Z keycodes:
	-- Shift sets 6th bit to 0
	-- Ctrl sets 6th and 7th bits to 0
	-- Example: a = 0b1100001
	--          A = 0b1000001
	for code = Enum.KeyCode.A.Value, Enum.KeyCode.Z.Value do
		InputMap[0b00][code] = code
		InputMap[0b01][code] = bit32.bor(code, 0b1011111)
		InputMap[0b10][code] = bit32.bor(code, 0b0011111)
	end

	-- Rest of the regular keys, hardcoded to not do crazy math
	local lookup = "`1234567890-=[];'\\,./"
	local lookupShift = '~!@#$%^&*()_+{}:"|<>?'
	for i = 1, #lookup do
		local code = string.byte(lookup, i, i)
		InputMap[0b00][code] = code
		InputMap[0b01][code] = string.byte(lookupShift, i, i)
		InputMap[0b10][code] = string.byte(lookupShift, i, i)
	end

	-- Function keys
	InputMap[0b00][Enum.KeyCode.F1.Value] = "\x1bOP"
	InputMap[0b00][Enum.KeyCode.F2.Value] = "\x1bOQ"
	InputMap[0b00][Enum.KeyCode.F3.Value] = "\x1bOR"
	InputMap[0b00][Enum.KeyCode.F4.Value] = "\x1bOS"
	InputMap[0b00][Enum.KeyCode.F5.Value] = "\x1b[15~"
	InputMap[0b00][Enum.KeyCode.F6.Value] = "\x1b[17~"
	InputMap[0b00][Enum.KeyCode.F7.Value] = "\x1b[18~"
	InputMap[0b00][Enum.KeyCode.F8.Value] = "\x1b[19~"
	InputMap[0b00][Enum.KeyCode.F9.Value] = "\x1b[20~"
	InputMap[0b00][Enum.KeyCode.F10.Value] = "\x1b[21~"
	InputMap[0b00][Enum.KeyCode.F11.Value] = "\x1b[23~"
	InputMap[0b00][Enum.KeyCode.F12.Value] = "\x1b[24~"

	-- Special keys
	InputMap[0b00][Enum.KeyCode.Backspace.Value] = 0x7f
	InputMap[0b10][Enum.KeyCode.Backspace.Value] = 0x08
	InputMap[0b00][Enum.KeyCode.Tab.Value] = 0x09
	InputMap[0b00][Enum.KeyCode.Return.Value] = 0x0D
	InputMap[0b00][Enum.KeyCode.Space.Value] = 0x20

	table.freeze(InputMap[0b00])
	table.freeze(InputMap[0b01])
	table.freeze(InputMap[0b10])
	table.freeze(InputMap[0b11])

	table.freeze(InputMap)
end

local keysThatDontRepeat = {
	[Enum.KeyCode.Backspace.Value] = true,
	[Enum.KeyCode.Left.Value] = true,
	[Enum.KeyCode.Right.Value] = true,
	[Enum.KeyCode.Up.Value] = true,
	[Enum.KeyCode.Down.Value] = true,
	[Enum.KeyCode.F1.Value] = true,
	[Enum.KeyCode.F2.Value] = true,
	[Enum.KeyCode.F3.Value] = true,
	[Enum.KeyCode.F4.Value] = true,
	[Enum.KeyCode.F5.Value] = true,
	[Enum.KeyCode.F6.Value] = true,
	[Enum.KeyCode.F7.Value] = true,
	[Enum.KeyCode.F8.Value] = true,
	[Enum.KeyCode.F9.Value] = true,
	[Enum.KeyCode.F10.Value] = true,
	[Enum.KeyCode.F11.Value] = true,
	[Enum.KeyCode.F12.Value] = true,
}
local lastKeyCode: Enum.KeyCode = Enum.KeyCode.Unknown

local function handleInput(io: InputObject, handledByEngine: boolean)
	if not handledByEngine then
		return
	end

	if keysThatDontRepeat[io.KeyCode.Value] and io.UserInputState == Enum.UserInputState.Begin then
		lastKeyCode = io.KeyCode
	else
		if
			io.UserInputState == Enum.UserInputState.Begin
			and io.UserInputType == Enum.UserInputType.Keyboard
			and io.KeyCode ~= Enum.KeyCode.Unknown
		then
			lastKeyCode = io.KeyCode
			return
		elseif
			io.UserInputState ~= Enum.UserInputState.Change
			or io.UserInputType ~= Enum.UserInputType.TextInput
			or not lastKeyCode
		then
			return
		end
	end
	local focusedBox = UIS:GetFocusedTextBox()
	local inputInfo = focusedBox and inputBoxes[focusedBox] or nil
	if not inputInfo then
		return
	end
	local shift = io:IsModifierKeyDown(Enum.ModifierKey.Shift)
	local ctrl = io:IsModifierKeyDown(Enum.ModifierKey.Ctrl)
	local alt = io:IsModifierKeyDown(Enum.ModifierKey.Alt)

	local event = inputInfo.event
	local code = lastKeyCode.Value

	-- Special case for arrow keys
	if code > 0b100010000 and code < 0b100010101 then
		local mode = inputInfo.mode
		local shiftMod = shift and 0b100 or 0
		local ctrlMod = ctrl and 0b010 or 0
		local altMod = alt and 0b001 or 0
		local t = { "", "1;3", "1;5", "1;7", "", "1;4", "1;6", "1;8" }
		local mod = shiftMod + ctrlMod + altMod
		local str = string.format(
			"\27%s%s%s",
			(mode and mod == 0) and "O" or "[",
			t[mod + 1],
			string.char(bit32.band(code, 0b111) + 0b1000000)
		)
		event:Fire(str)
		return
	end

	local shiftMod = shift and 0b01 or 0
	local ctrlMod = ctrl and 0b10 or 0
	local charcode = InputMap[shiftMod + ctrlMod][code]
	if charcode then
		event:Fire(type(charcode) == "number" and utf8.char(charcode) or charcode)
	end
end

UIS.InputBegan:Connect(handleInput)
UIS.InputChanged:Connect(handleInput)

return function()
	local box = Instance.new("TextBox")
	box.Name = "InputBox"
	box.MultiLine = true
	box.ClearTextOnFocus = true
	local event = Instance.new("BindableEvent")
	event.Name = "InputEvent"
	event.Parent = box

	local info = {
		box = box,
		event = event,
		mode = false,
	}
	inputBoxes[box] = info

	box:GetPropertyChangedSignal("Text"):Connect(function()
		box.Text = ""
	end)
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			box:CaptureFocus()
		end
	end)

	return info
end
