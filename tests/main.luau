local fs = require("@lune/fs")
local net = require("@lune/net")
local encodeBMP = require("./bmp.luau")

local fontFileName = "unifont-15.1.04.hex"
local fontFile
if fs.isFile(fontFileName) then
	print("Using cached font...")
	fontFile = fs.readFile(fontFileName)
else
	print("Downloading font...")
	local fontUrl =
		"https://gist.githubusercontent.com/mokiros/b55a8a64ac100fe737450343f5ef3d85/raw/6835baa97d7cbb7431fb05faa6d41269c3c929b8/unifont-15.1.04.hex"
	local response = net.request({
		url = fontUrl,
		method = "GET",
	})
	assert(response.ok, "Failed to download font")
	fontFile = response.body
	fs.writeFile(fontFileName, fontFile)
end

print("Loading source files...")
local Terminal = require("../src/init.luau")

local font = Terminal.parseUnifont(fontFile)

local width, height = 10, 4
local term = Terminal.createTerminal(width, height, font)

print("Sending stdout...")
Terminal.stdout(term, buffer.fromstring("test"))

print("Saving image...")
local bmpBuffer = encodeBMP(term.currentScreen.canvas.canvas, width * 8, height * 16)
fs.writeFile("./output.bmp", bmpBuffer)
