local getFont = Instance.new("RemoteFunction")
getFont.Name = "GetFont"
getFont.Parent = script.Parent

local cached: string? = nil

getFont.OnServerInvoke = function(plr)
	if cached then
		return cached
	end

	local font = game:GetService("HttpService"):GetAsync(
		"https://gist.githubusercontent.com/mokiros/b55a8a64ac100fe737450343f5ef3d85/raw/6835baa97d7cbb7431fb05faa6d41269c3c929b8/unifont-15.1.04.hex"
	)
	cached = font

	return font
end
