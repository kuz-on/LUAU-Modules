--!optimize 2

--modules
local remoteNames: {[string]: number} = require("./RemoteNames")
local _: number, buffSize: number = math.frexp(remoteNames.__maxInt)

--script variables
local writeHandler: (b: buffer, offset: number, value: number) -> ()
local readHandler : (b: buffer, offset: number)                -> number

local serializedTable: {[number]: buffer} = {}

do -- find the handler function
	if buffSize <= 8 then
		writeHandler = buffer.writeu8
		readHandler  = buffer.readu8
		
	elseif buffSize <= 16 then
		writeHandler = buffer.writeu16
		readHandler  = buffer.readu16
		
	elseif buffSize <= 32 then
		writeHandler = buffer.writeu32
		readHandler  = buffer.readu32
		
	else
		error(`Can't find a write function for the buffer with the size (in bits): '{tostring(buffSize)}'`, 2)
		
		return {}
	end
end

-- set up the serialized table
for _: string, id: number in pairs(remoteNames) do
	local buff: buffer = buffer.create(buffSize)
	writeHandler(buff, 0, id)
	
	serializedTable[id] = buff
end

return {serializedTable, readHandler}