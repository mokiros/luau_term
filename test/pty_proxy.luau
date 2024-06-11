local endpoint = "http://localhost:3000"
local endpoint_newSession = endpoint .. "/session?w=%s&h=%s"
local endpoint_updateSession = endpoint .. "/session/%s"

local HS = game:GetService("HttpService")

export type Session = {
	id: string,
	w: number,
	h: number,
}

local function newSession(w: number, h: number, name: string?)
	local url = string.format(endpoint_newSession, w, h)
	if name ~= nil then
		url ..= "&name=" .. name
	end
	local data = HS:JSONDecode(HS:GetAsync(url))
	local id = data.session
	return {
		id = id,
		w = data.w,
		h = data.h,
	}
end

local function update(session: Session, input: string?)
	local output = HS:PostAsync(
		string.format(endpoint_updateSession, session.id),
		HS:JSONEncode({ body = input or "" }),
		Enum.HttpContentType.ApplicationJson
	)
	return output
end

return {
	newSession = newSession,
	update = update,
}
