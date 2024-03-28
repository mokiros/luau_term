local Constants = require(script.Parent.Parent.Constants)

local function createHandlers(): Constants.Handlers
	local Handlers: Constants.Handlers = {
		csi = {},
		dcs = {},
		osc = {},
		esc = {},
		exec = {},
		print = function() end,
		error = function() end,
	}
	return Handlers
end

return {
	createHandlers = createHandlers,
}
