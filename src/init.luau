local Types = require(script.Types)
local Terminal = require(script.terminal)
local parser = require(script.parser)
local Constants = require(script.Constants)
local Canvas = require(script.canvas)
local Util = require(script.terminal.Util)
local parseUnifont = require(script.unifont)

local UNIFONT_ASCII = require(script.UnifontAscii)


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
