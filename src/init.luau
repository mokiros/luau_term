local Types = require("./types")
local Terminal = require("./terminal")
local parser = require("./parser")
local Constants = require("./constants")
local Canvas = require("./canvas")
local Util = require("./terminal/util")
local parseUnifont = require("./unifont")

local UNIFONT_ASCII = require("./unifont_ascii")

local function stdout(term: Types.Terminal, str: string): ()
	for i, codepoint in utf8.codes(str) do
		parser.parse(term, codepoint)
	end
end

return {
	stdout = stdout,
	createTerminal = Terminal.createTerminal,
	parseUnifont = parseUnifont,
	Constants = Constants,
	Types = Types,
	Canvas = Canvas,
	Util = Util,
	Parser = parser,
	UNIFONT_ASCII = UNIFONT_ASCII,
}
