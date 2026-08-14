--!optimize 2

--services
local RunService = game:GetService("RunService")

--modules
local remoteSerialized: {[number]: buffer}, readHandler: (b: buffer, offset: number) -> number = table.unpack(require("@self/RemoteSerialized"))
local remoteNames: {[string]: number} = require("@self/RemoteNames")

--instances
local remote: RemoteEvent = script:WaitForChild("RemoteEvent")

--types
export type RemoteService = {
	["id"]: (name: string) -> (number),
	
	["FireClient"]    : (self: RemoteService, id: number, player: Player, ...any) -> (),
	["FireAllClients"]: (self: RemoteService, id: number,                 ...any) -> (),
	
	["FireServer"]: (self: RemoteService, id: number, ...any) -> (),
	
	["OnServer"]: (self: RemoteService, id: number, func: (                ...any) -> ()) -> (),
	["OnClient"]: (self: RemoteService, id: number, func: (player: Player, ...any) -> ()) -> ()
}

--script variables
local RemoteService: RemoteService = {}

local serverHandlers: {[number]: (player: Player, ...any) -> ()} = {}
local clientHandlers: {[number]: (                ...any) -> ()} = {}

--Returns the ID associated with that remote event.
function RemoteService.id(name: string): number
	return assert(remoteNames[name])
end

--Sends a message (...) to the player 'player' via the remote event with the ID 'id'.
function RemoteService:FireClient(id: number, player: Player, ...: any): ()
	local buff: buffer = assert(RunService:IsServer() and remoteSerialized[id])
	
	remote:FireClient(player, buff, ...)
end

--Sends a message (...) to all players via the remote event with the ID 'id'.
function RemoteService:FireAllClients(id: number, ...: any): ()
	local buff: buffer = assert(RunService:IsServer() and remoteSerialized[id])
	
	remote:FireAllClients(buff, ...)
end


--Sends a message (...) to the server via the remote event with the ID 'id'.
function RemoteService:FireServer(id: number, ...: any): ()
	local buff: buffer = assert(RunService:IsClient() and remoteSerialized[id])
	
	remote:FireServer(buff, ...)
end


--Defines what should happen when the server receives a message from the player 'player' via the remote with the ID 'id'.
function RemoteService:OnClient(id: number, func: (player: Player, ...any) -> ()): ()
	assert(RunService:IsServer() and remoteSerialized[id])
	
	serverHandlers[id] = func
end

--Defines what should happen when the player receives a message from the server via the remote with the ID 'id'.
function RemoteService:OnServer(id: number, func: (...any) -> ()): ()
	assert(RunService:IsClient() and remoteSerialized[id])
	
	clientHandlers[id] = func
end

function RemoteService.init(): ()
	if RunService:IsClient() then
		remote.OnClientEvent:Connect(function(buff: buffer, ...: any)
			(clientHandlers[assert(readHandler(buff, 0))] or function() end)(...)
		end)
	end
	
	if RunService:IsServer() then
		remote.OnServerEvent:Connect(function(player: Player, buff: buffer, ...: any)
			(serverHandlers[assert(readHandler(buff, 0))] or function() end)(player, ...)
		end)
	end
end

return RemoteService
