local Session = require(script.Parent.pty_proxy)

local event = Instance.new("RemoteEvent")
event.Name = "stdio"
event.Parent = script.Parent

local newSession = Instance.new("RemoteFunction")
newSession.Name = "NewSession"
newSession.Parent = script.Parent

local sessions = {}

local sessionThread = function(session)
	while true do
		task.wait(1 / 10)
		session.requesting = true
		local input = session.inputBuffer
		session.inputBuffer = ""
		local data = Session.update(session, input)
		event:FireClient(session.player, session.id, data)
		session.lastRequest = tick()
		session.requesting = false
	end
end

event.OnServerEvent:Connect(function(plr, id, str)
	local session = sessions[id]
	if not session or session.player ~= plr then
		return
	end
	session.inputBuffer ..= str
end)

newSession.OnServerInvoke = function(player, w, h)
	local session = Session.newSession(w, h)
	sessions[session.id] = session
	session.player = player
	session.inputBuffer = ""
	session.requesting = false
	session.lastRequest = 0
	session.thread = task.spawn(sessionThread, session)
	return session.id
end
