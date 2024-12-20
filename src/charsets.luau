-- The code below has been adapted from xterm.js source code
-- https://github.com/xtermjs/xterm.js/blob/f701d073d15f7b312a9d051e719f748665701cef/src/common/data/Charsets.ts
-- xterm.js is licensed under the MIT license: https://github.com/xtermjs/xterm.js/blob/f701d073d15f7b312a9d051e719f748665701cef/LICENSE

export type Charset = { [number]: number }

local Charsets: { [number]: Charset } = {}

local b = string.byte

--[[
	DEC Special Character and Line Drawing Set.
	Reference: http://vt100.net/docs/vt102-ug/table5-13.html
	A lot of curses apps use this if they see TERM=xterm.
	Testing: echo -e '\e(0a\e(B'
	The xterm output sometimes seems to conflict with the
	reference above. xterm seems in line with the reference
	when running vttest however.
	The table below now uses xterm's output from vttest.
]]
Charsets[b("0")] = table.freeze({
	[b("`")] = 0x25c6, -- '◆'
	[b("a")] = 0x2592, -- '▒'
	[b("b")] = 0x2409, -- '␉' (HT)
	[b("c")] = 0x240c, -- '␌' (FF)
	[b("d")] = 0x240d, -- '␍' (CR)
	[b("e")] = 0x240a, -- '␊' (LF)
	[b("f")] = 0x00b0, -- '°'
	[b("g")] = 0x00b1, -- '±'
	[b("h")] = 0x2424, -- '␤' (NL)
	[b("i")] = 0x240b, -- '␋' (VT)
	[b("j")] = 0x2518, -- '┘'
	[b("k")] = 0x2510, -- '┐'
	[b("l")] = 0x250c, -- '┌'
	[b("m")] = 0x2514, -- '└'
	[b("n")] = 0x253c, -- '┼'
	[b("o")] = 0x23ba, -- '⎺'
	[b("p")] = 0x23bb, -- '⎻'
	[b("q")] = 0x2500, -- '─'
	[b("r")] = 0x23bc, -- '⎼'
	[b("s")] = 0x23bd, -- '⎽'
	[b("t")] = 0x251c, -- '├'
	[b("u")] = 0x2524, -- '┤'
	[b("v")] = 0x2534, -- '┴'
	[b("w")] = 0x252c, -- '┬'
	[b("x")] = 0x2502, -- '│'
	[b("y")] = 0x2264, -- '≤'
	[b("z")] = 0x2265, -- '≥'
	[b("{")] = 0x03c0, -- 'π'
	[b("|")] = 0x2260, -- '≠'
	[b("}")] = 0x00a3, -- '£'
	[b("~")] = 0x00b7, -- '·'
})

--[[
	British character set
	ESC (A
	Reference: http://vt100.net/docs/vt220-rm/table2-5.html
]]
Charsets[b("A")] = table.freeze({
	[b("#")] = b("£"),
})

--[[
	United States character set
	ESC (B
]]
Charsets[b("B")] = nil

--[[
	Dutch character set
	ESC (4
	Reference: http://vt100.net/docs/vt220-rm/table2-6.html
]]
Charsets[b("4")] = table.freeze({
	[b("#")] = b("£"),
	[b("@")] = b("¾"),
	[b("[")] = b("ij"), -- NOTE: This will only output "i", but it's too obscure to fix
	[b("\\")] = b("½"),
	[b("]")] = b("|"),
	[b("{")] = b("¨"),
	[b("|")] = b("f"),
	[b("}")] = b("¼"),
	[b("~")] = b("´"),
})

--[[
	Finnish character set
	ESC (C or ESC (5
	Reference: http://vt100.net/docs/vt220-rm/table2-7.html
]]
Charsets[b("C")] = table.freeze({
	[b("[")] = b("Ä"),
	[b("\\")] = b("Ö"),
	[b("]")] = b("Å"),
	[b("^")] = b("Ü"),
	[b("`")] = b("é"),
	[b("{")] = b("ä"),
	[b("|")] = b("ö"),
	[b("}")] = b("å"),
	[b("~")] = b("ü"),
})
Charsets[b("5")] = Charsets[b("C")]

--[[
	French character set
	ESC (R
	Reference: http://vt100.net/docs/vt220-rm/table2-8.html
]]
Charsets[b("R")] = table.freeze({
	[b("#")] = b("£"),
	[b("@")] = b("à"),
	[b("[")] = b("°"),
	[b("\\")] = b("ç"),
	[b("]")] = b("§"),
	[b("{")] = b("é"),
	[b("|")] = b("ù"),
	[b("}")] = b("è"),
	[b("~")] = b("¨"),
})

--[[
	French Canadian character set
	ESC (Q
	Reference: http://vt100.net/docs/vt220-rm/table2-9.html
]]
Charsets[b("Q")] = table.freeze({
	[b("@")] = b("à"),
	[b("[")] = b("â"),
	[b("\\")] = b("ç"),
	[b("]")] = b("ê"),
	[b("^")] = b("î"),
	[b("`")] = b("ô"),
	[b("{")] = b("é"),
	[b("|")] = b("ù"),
	[b("}")] = b("è"),
	[b("~")] = b("û"),
})

--[[
	German character set
	ESC (K
	Reference: http://vt100.net/docs/vt220-rm/table2-10.html
]]
Charsets[b("K")] = table.freeze({
	[b("@")] = b("§"),
	[b("[")] = b("Ä"),
	[b("\\")] = b("Ö"),
	[b("]")] = b("Ü"),
	[b("{")] = b("ä"),
	[b("|")] = b("ö"),
	[b("}")] = b("ü"),
	[b("~")] = b("ß"),
})

--[[
	Italian character set
	ESC (Y
	Reference: http://vt100.net/docs/vt220-rm/table2-11.html
]]
Charsets[b("Y")] = table.freeze({
	[b("#")] = b("£"),
	[b("@")] = b("§"),
	[b("[")] = b("°"),
	[b("\\")] = b("ç"),
	[b("]")] = b("é"),
	[b("`")] = b("ù"),
	[b("{")] = b("à"),
	[b("|")] = b("ò"),
	[b("}")] = b("è"),
	[b("~")] = b("ì"),
})

--[[
	Norwegian/Danish character set
	ESC (E or ESC (6
	Reference: http://vt100.net/docs/vt220-rm/table2-12.html
]]
Charsets[b("E")] = table.freeze({
	[b("@")] = b("Ä"),
	[b("[")] = b("Æ"),
	[b("\\")] = b("Ø"),
	[b("]")] = b("Å"),
	[b("^")] = b("Ü"),
	[b("`")] = b("ä"),
	[b("{")] = b("æ"),
	[b("|")] = b("ø"),
	[b("}")] = b("å"),
	[b("~")] = b("ü"),
})
Charsets[b("6")] = Charsets[b("E")]

--[[
	Spanish character set
	ESC (Z
	Reference: http://vt100.net/docs/vt220-rm/table2-13.html
]]
Charsets[b("Z")] = table.freeze({
	[b("#")] = b("£"),
	[b("@")] = b("§"),
	[b("[")] = b("¡"),
	[b("\\")] = b("Ñ"),
	[b("]")] = b("¿"),
	[b("{")] = b("°"),
	[b("|")] = b("ñ"),
	[b("}")] = b("ç"),
})

--[[
	Swedish character set
	ESC (H or ESC (7
	Reference: http://vt100.net/docs/vt220-rm/table2-14.html
]]
Charsets[b("H")] = table.freeze({
	[b("@")] = b("É"),
	[b("[")] = b("Ä"),
	[b("\\")] = b("Ö"),
	[b("]")] = b("Å"),
	[b("^")] = b("Ü"),
	[b("`")] = b("é"),
	[b("{")] = b("ä"),
	[b("|")] = b("ö"),
	[b("}")] = b("å"),
	[b("~")] = b("ü"),
})
Charsets[b("7")] = Charsets[b("H")]

--[[
	Swiss character set
	ESC (=
	Reference: http://vt100.net/docs/vt220-rm/table2-15.html
]]
Charsets[b("=")] = table.freeze({
	[b("#")] = b("ù"),
	[b("@")] = b("à"),
	[b("[")] = b("é"),
	[b("\\")] = b("ç"),
	[b("]")] = b("ê"),
	[b("^")] = b("î"),
	[b("_")] = b("è"),
	[b("`")] = b("ô"),
	[b("{")] = b("ä"),
	[b("|")] = b("ö"),
	[b("}")] = b("ü"),
	[b("~")] = b("û"),
})

-- Default charset
Charsets[0] = Charsets[b("B")]

return table.freeze(Charsets)
