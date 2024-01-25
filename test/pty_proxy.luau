local endpoint = "http://localhost:3000"
local endpoint_newSession = endpoint .. "/session?w=%s&h=%s"
local endpoint_updateSession = endpoint .. "/session/%s"

local HS = game:GetService("HttpService")

export type Session = {
	id: string,
	w: number,
	h: number,
}

local function newSession(w: number, h: number)
	local data = HS:JSONDecode(HS:GetAsync(string.format(endpoint_newSession, w, h)))
	local id = data.session
	local w, h = data.w, data.h
	return {
		id = id,
		w = w,
		h = h,
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
