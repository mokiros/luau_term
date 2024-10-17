local endpoint = "http://localhost:3000"
local endpoint_newSession = endpoint .. "/session?w=%s&h=%s"
local endpoint_updateSession = endpoint .. "/session/%s"

local HS = game:GetService("HttpService")

local stdioEvent = Instance.new("RemoteEvent")
stdioEvent.Name = "stdio"
stdioEvent.Parent = script.Parent

local NewSessionEvent = Instance.new("RemoteFunction")
NewSessionEvent.Name = "NewSession"
NewSessionEvent.Parent = script.Parent

local getUnifont = Instance.new("RemoteFunction")
getUnifont.Name = "GetFont"
getUnifont.Parent = script.Parent

export type Session = {
	id: string,
	w: number,
	h: number,
	player: Player,
	inputBuffer: string,
	requesting: boolean,
	lastRequest: number,
	thread: thread?,
}

local sessions = {}

local sessionThread = function(session)
	while true do
		task.wait(1 / 10)
		session.requesting = true
		local input = session.inputBuffer
		session.inputBuffer = ""
		local data = HS:PostAsync(
			string.format(endpoint_updateSession, session.id),
			HS:JSONEncode({ body = input or "" }),
			Enum.HttpContentType.ApplicationJson
		)
		if #data > 0 then
			stdioEvent:FireClient(session.player, session.id, data)
		end
		session.lastRequest = tick()
		session.requesting = false
	end
end

stdioEvent.OnServerEvent:Connect(function(plr, id, str)
	local session = sessions[id]
	if not session or session.player ~= plr then
		return
	end
	session.inputBuffer ..= str
end)

NewSessionEvent.OnServerInvoke = function(player, w, h, name)
	local url = string.format(endpoint_newSession, w, h)
	if name ~= nil then
		url ..= "&name=" .. name
	end
	local response = HS:GetAsync(url)
	local data = HS:JSONDecode(response)
	local id = data.session
	local session = {
		id = id,
		w = data.w,
		h = data.h,
		player = player,
		inputBuffer = "",
		requesting = false,
		lastRequest = 0,
	}
	session.thread = task.spawn(sessionThread, session)
	sessions[session.id] = session
	return session.id
end

local cachedUnifont: string? = nil

getUnifont.OnServerInvoke = function(plr)
	if cachedUnifont then
		return cachedUnifont
	end

	local unifont = game:GetService("HttpService"):GetAsync(
		"https://gist.githubusercontent.com/mokiros/b55a8a64ac100fe737450343f5ef3d85/raw/6835baa97d7cbb7431fb05faa6d41269c3c929b8/unifont-15.1.04.hex"
	)
	cachedUnifont = unifont

	return unifont
end
