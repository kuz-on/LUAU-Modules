--!optimize 2
--!strict
--!native

-- thank you for using my module
-- if you have any issues just dm me
-- my discord is __kuzon_

--caches
local floor: (x: number) -> (number) = math.floor
local round: (x: number) -> (number) = math.round
local ceil:  (x: number) -> (number) = math.ceil

local frexp: (x: number)            -> (number, number) = math.frexp
local sqrt: (x: number)             -> (number)         = math.sqrt
local abs:   (x: number)            -> (number)         = math.abs
local pow:   (x: number, y: number) -> (number)         = math.pow

local POW10: {number} = {
	[1]  = 0.000000000000001,  -- was -15
	[2]  = 0.00000000000001,   -- was -14
	[3]  = 0.0000000000001,    -- was -13
	[4]  = 0.000000000001,     -- was -12
	[5]  = 0.00000000001,      -- was -11
	[6]  = 0.0000000001,       -- was -10
	[7]  = 0.000000001,        -- was -9
	[8]  = 0.00000001,         -- was -8
	[9]  = 0.0000001,          -- was -7
	[10] = 0.000001,           -- was -6
	[11] = 0.00001,            -- was -5
	[12] = 0.0001,             -- was -4
	[13] = 0.001,              -- was -3
	[14] = 0.01,               -- was -2
	[15] = 0.1,                -- was -1
	[16] = 1,                  -- was  0
	[17] = 10,                 -- was  1
	[18] = 100,                -- was  2
	[19] = 1000,               -- was  3
	[20] = 10000,              -- was  4
	[21] = 100000,             -- was  5
	[22] = 1000000,            -- was  6
	[23] = 10000000,           -- was  7
	[24] = 100000000,          -- was  8
	[25] = 1000000000,         -- was  9
	[26] = 10000000000,        -- was 10
	[27] = 100000000000,       -- was 11
	[28] = 1000000000000,      -- was 12
	[29] = 10000000000000,     -- was 13
	[30] = 100000000000000,    -- was 14
	[31] = 1000000000000000    -- was 15
}

local prefixes: {[number]: string} = {
	'K'   , 'M'   , 'B'   , 'T'   , 'Qd'  , 'Qn'  ,
	'Sx'  , 'Sp'  , 'Oc'  , 'No'  , 'De'  , 'UDe' ,
	'DDe' , 'TDe' , 'QdDe', 'QnQe', 'SxDe', 'SpDe',
	'OcDe', 'NoDe', 'Vt'  , 'UVt' , 'DVt' , 'TVt' 
}

local oppLog2_10: number = 0.3010299956639812 -- 1 / math.log(10, 2)
local log2_10   : number = 3.321928094887362  -- math.log(10, 2)
local sqrt10    : number = 3.1622776601683795 -- math.sqrt(10)

--script variables
local Bignum = {}

--Returns a Bignum with the value of 1.
function Bignum.one(): buffer
	
	-- never do this at home kids
	local buff: buffer = buffer.create(12)
	buffer.writef64(buff, 0, 1)
	
	return buff
end

--Adds 'a' to 'b' and stores the result in 'a'.
function Bignum.Add(a: buffer, b: buffer): ()
	local am: number, ae: number = buffer.readf64(a, 0), buffer.readi32(a, 8)
	local bm: number, be: number = buffer.readf64(b, 0), buffer.readi32(b, 8)
	
	-- swap the values so 'a' is the biggest (wolf)
	local diff: number = ae - be
	if diff < 0 then
		ae, be = be, ae
		am, bm = bm, am
		
		if diff <= -15 then
			buffer.writef64(a, 0, am)
			buffer.writei32(a, 8, ae)
			
			return
		end
		
		diff *= -1
	elseif diff >= 15 then
		return
	end
	
	--[[ a + b = am * 10^ae + bm * 10^be; take ae >= be
		 a + b = 10^be * (am * 10^(ae - be) + bm)
		 
		 let c = a + b and x a natural number
		 exponent_c = ae - be + x
		 mantissa_c = (am * 10^be + bm) / 10^x
		 
		 observation: to have abs(mantissa_c) < 10, we divide it by
		  10^x and add x to the exponent; so, x = floor(log10(am * 10^(ae - be) + bm))
		  
		  BUT math.frexp(n) - 1 = floor(log2(n)) and log10(n) = log2(n) / log2(10)
		  hence log10(am * 10^(ae - be) + bm) = (math.frexp(am * 10^(ae - be) + bm) - 1) / log2(10)
	]]
	
	local m: number = am * (POW10[diff + 16] or pow(10, diff)) + bm
	if m == 0 then
		
		-- zero
		buffer.writef64(a, 0, 0)
		buffer.writei32(a, 8, 0)
	
	else
		local _, log2: number = frexp(abs(m))
		local e: number = floor((log2 - 1) * oppLog2_10)

		buffer.writef64(a, 0, m / (POW10[e + 16] or pow(10, e)))
		buffer.writei32(a, 8, be + e)
	end
end

--Adds 'a' to (number) 'b' and stores the result in 'a'.
function Bignum.AddNumber(a: buffer, b: number): ()
	local am: number, ae: number = buffer.readf64(a, 0), buffer.readi32(a, 8)

	local _, log2_b: number = frexp(abs(b))
	local be: number = floor((log2_b - 1) * oppLog2_10)
	local bm: number = b / (POW10[be + 16] or pow(10, be))
	
	local diff: number = ae - be
	if diff < 0 then
		ae, be = be, ae
		am, bm = bm, am

		if diff <= -15 then
			buffer.writef64(a, 0, am)
			buffer.writei32(a, 8, ae)

			return
		end

		diff *= -1
	elseif diff >= 15 then
		return
	end
	
	local m: number = am * (POW10[diff + 16] or pow(10, diff)) + bm
	if m == 0 then

		-- zero
		buffer.writef64(a, 0, 0)
		buffer.writei32(a, 8, 0)

	else
		local _, log2: number = frexp(abs(m))
		local e: number = floor((log2 - 1) * oppLog2_10)

		buffer.writef64(a, 0, m / (POW10[e + 16] or pow(10, e)))
		buffer.writei32(a, 8, be + e)
	end
end

--Subtracts 'a' from 'b' and stores the result in 'a'.
function Bignum.Subtract(a: buffer, b: buffer): ()
	local am: number, ae: number = buffer.readf64(a, 0), buffer.readi32(a, 8)
	local bm: number, be: number = buffer.readf64(b, 0), buffer.readi32(b, 8)

	-- swap the values so 'a' is the biggest (wolf)
	local diff: number = ae - be
	if diff < 0 then
		ae, be = be, ae
		am, bm = bm, am

		if diff <= -15 then
			buffer.writef64(a, 0, am)
			buffer.writei32(a, 8, ae)

			return
		end

		diff *= -1
	elseif diff >= 15 then
		return
	end

	--[[ follow the same logic from :Add,
	except b is negative]]

	local m: number = am * (POW10[diff + 16] or pow(10, diff)) - bm
	if m == 0 then

		-- zero
		buffer.writef64(a, 0, 0)
		buffer.writei32(a, 8, 0)

	else
		local _, log2: number = frexp(abs(m))
		local e: number = floor((log2 - 1) * oppLog2_10)

		buffer.writef64(a, 0, m / (POW10[e + 16] or pow(10, e)))
		buffer.writei32(a, 8, be + e)
	end
end

--Subtracts 'a' to (number) 'b' and stores the result in 'a'.
function Bignum.SubtractNumber(a: buffer, b: number): ()
	local am: number, ae: number = buffer.readf64(a, 0), buffer.readi32(a, 8)

	local _, log2_b: number = frexp(abs(b))
	local be: number = floor((log2_b - 1) * oppLog2_10)
	local bm: number = b / (POW10[be + 16] or pow(10, be))

	local diff: number = ae - be
	if diff < 0 then
		ae, be = be, ae
		am, bm = bm, am

		if diff <= -15 then
			buffer.writef64(a, 0, am)
			buffer.writei32(a, 8, ae)

			return
		end

		diff *= -1
	elseif diff >= 15 then
		return
	end

	local m: number = am * (POW10[diff + 16] or pow(10, diff)) - bm
	if m == 0 then

		-- zero
		buffer.writef64(a, 0, 0)
		buffer.writei32(a, 8, 0)

	else
		local _, log2: number = frexp(abs(m))
		local e: number = floor((log2 - 1) * oppLog2_10)

		buffer.writef64(a, 0, m / (POW10[e + 16] or pow(10, e)))
		buffer.writei32(a, 8, be + e)
	end
end

--Multiplies 'a' and 'b' and stores the result in 'a'.
function Bignum.Multiply(a: buffer, b: buffer): ()
	local am: number, ae: number = buffer.readf64(a, 0), buffer.readi32(a, 8)
	local bm: number, be: number = buffer.readf64(b, 0), buffer.readi32(b, 8)
	
	local m: number = am * bm
	if abs(m) >= 10 then
		buffer.writef64(a, 0, m / 10)
		buffer.writei32(a, 8, ae + be + 1)
	
	elseif abs(m) < 1 then
		buffer.writef64(a, 0, m * 10)
		buffer.writei32(a, 8, ae + be - 1)
		
	else -- if it's less than 10
		buffer.writef64(a, 0, m)
		buffer.writei32(a, 8, ae + be)
	end
end

--Multiplies 'a' and (number) 'b' and stores the result in 'a'.
function Bignum.MultiplyNumber(a: buffer, b: number): ()
	local am: number, ae: number = buffer.readf64(a, 0), buffer.readi32(a, 8)
	
	local _, log2_b: number = frexp(abs(b))
	local be: number = floor((log2_b - 1) * oppLog2_10)
	-- unused local bm: number = b / (POW10[be + 16] or pow(10, be))
	
	local m: number = am * b
	if abs(m) >= 10 then
		buffer.writef64(a, 0, m / 10)
		buffer.writei32(a, 8, ae + be + 1)

	elseif abs(m) < 1 then
		buffer.writef64(a, 0, m * 10)
		buffer.writei32(a, 8, ae + be - 1)

	else -- if it's less than 10
		buffer.writef64(a, 0, m)
		buffer.writei32(a, 8, ae + be)
	end
end

--Divides 'a' to 'b' and stores the result in 'a'.
function Bignum.Divide(a: buffer, b: buffer): ()
	local am: number, ae: number = buffer.readf64(a, 0), buffer.readi32(a, 8)
	local bm: number, be: number = buffer.readf64(b, 0), buffer.readi32(b, 8)
	assert(bm ~= 0, "Can't divide by 0")
	
	local m: number = am / bm
	if abs(m) >= 10 then
		buffer.writef64(a, 0, m / 10)
		buffer.writei32(a, 8, ae + be + 1)
	
	elseif abs(m) < 1 then
		buffer.writef64(a, 0, m * 10)
		buffer.writei32(a, 8, ae - be - 1)
		
	else -- if it's less than 10
		buffer.writef64(a, 0, m)
		buffer.writei32(a, 8, ae - be)
	end
end

--Divides 'a' to (number) 'b' and stores the result in 'a'.
function Bignum.DivideNumber(a: buffer, b: number): ()
	local am: number, ae: number = buffer.readf64(a, 0), buffer.readi32(a, 8)
	assert(b ~= 0, "Can't divide by 0")
	
	local _, log2_b: number = frexp(abs(b))
	local be: number = floor((log2_b - 1) * oppLog2_10)
	local bm: number = b / (POW10[be + 16] or pow(10, be))
	
	local m: number = am / bm
	if abs(m) >= 10 then
		buffer.writef64(a, 0, m / 10)
		buffer.writei32(a, 8, ae + be + 1)

	elseif abs(m) < 1 then
		buffer.writef64(a, 0, m * 10)
		buffer.writei32(a, 8, ae - be - 1)

	else -- if it's less than 10
		buffer.writef64(a, 0, m)
		buffer.writei32(a, 8, ae - be)
	end
end

--Raises 'a' to the power (number) 'b' and stores the result in 'a'. (b must be an integer)
function Bignum.PowNumber(a: buffer, b: number): ()
	local am: number, ae: number = buffer.readf64(a, 0), buffer.readi32(a, 8)
	if am == 0 then return end; assert(floor(b) == b, "Can't raise to float")
	
	local m: number = pow(am, b)

	-- just cloned from :Add
	local _, log2: number = frexp(abs(m))
	local e: number = floor((log2 - 1) * oppLog2_10)

	buffer.writef64(a, 0, m / (POW10[e + 16] or pow(10, e)))
	buffer.writei32(a, 8, ae * b + e)
end

--Takes the logarithm with the base 'b' of 'a' and stores the result in 'a'.
function Bignum.Log(a: buffer, b: buffer): ()
	local am: number, ae: number = buffer.readf64(a, 0), buffer.readi32(a, 8)
	local bm: number, be: number = buffer.readf64(b, 0), buffer.readi32(b, 8)
	
	--[[ log_a(b) = log_10(b) / log_10(a)
	
	 > log_10(b) = log_10(bm * 10^be) = be + log_10(bm) = be + log_2(bm) * oppLog2_10
	 > log_10(a) = log_10(am * 10^ae) = ae + log_10(am) = ae + log_2(am) * oppLog2_10
	]]
	
	local _, log2_bm: number = frexp(abs(bm))
	local _, log2_am: number = frexp(abs(am))
	
	local m: number = (be + (log2_bm - 1) * oppLog2_10) / (ae + (log2_am - 1) * oppLog2_10)
	
	-- another copy/paste
	local _, log2: number = frexp(abs(m))
	local e: number = floor((log2 - 1) * oppLog2_10)

	buffer.writef64(a, 0, m / (POW10[e + 16] or pow(10, e)))
	buffer.writei32(a, 8, e)
end

--Takes the logarithm with the base (number) 'b' of 'a' and stores the result in 'a'.
function Bignum.LogNumber(a: buffer, b: number): ()
	local am: number, ae: number = buffer.readf64(a, 0), buffer.readi32(a, 8)

	--[[ im NOT explaining the maths
	     for this one like i did in :Log]]

	local _, log2_b : number = frexp(abs(b))
	local _, log2_am: number = frexp(abs(am))

	local m: number = (ae * log2_10 + (log2_am - 1)) / (log2_b - 1)

	-- another copy/paste
	local _, log2: number = frexp(abs(m))
	local e: number = floor((log2 - 1) * oppLog2_10)

	buffer.writef64(a, 0, m / (POW10[e + 16] or pow(10, e)))
	buffer.writei32(a, 8, e)
end

--Stores the square root of 'a' in 'a'.
function Bignum.Sqrt(a: buffer): ()
	local am: number, ae: number = buffer.readf64(a, 0), buffer.readi32(a, 8)
	assert(am >= 0, "Can't square root a negative number")
	
	buffer.writef64(a, 0, sqrt(am) * ((abs(ae) % 2 == 0) and 1 or sqrt10))
	buffer.writei32(a, 8, floor(ae / 2))
end

--Finds and stores the minimum value between 'a' and 'b' in 'a'.
function Bignum.min(a: buffer, b: buffer): ()
	local am: number, ae: number = buffer.readf64(a, 0), buffer.readi32(a, 8)
	local bm: number, be: number = buffer.readf64(b, 0), buffer.readi32(b, 8)
	
	if (ae < be) or ((ae == be) and (am < bm)) then
		return
	end
	
	buffer.writef64(a, 0, bm)
	buffer.writei32(a, 8, be)
end

--Finds and stores the minimum value between 'a' and 1 in 'a'.
function Bignum.min1(a: buffer): ()
	local am: number, ae: number = buffer.readf64(a, 0), buffer.readi32(a, 8)

	if (am == 0) or (ae < 0) then
		return
	end
	
	buffer.writef64(a, 0, 1)
	buffer.writei32(a, 8, 1)
end

--Finds and stores the maximum value between 'a' and 'b' in 'a'.
function Bignum.max(a: buffer, b: buffer): ()
	local am: number, ae: number = buffer.readf64(a, 0), buffer.readi32(a, 8)
	local bm: number, be: number = buffer.readf64(b, 0), buffer.readi32(b, 8)

	if (ae >= be) or ((ae == be) and (am >= bm)) then
		return
	end

	buffer.writef64(a, 0, bm)
	buffer.writei32(a, 8, be)
end

--Turns a Bignum to a string and returns it.
function Bignum.tostring(a: buffer): string
	local am: number, ae: number = buffer.readf64(a, 0), buffer.readi32(a, 8)
	if ae < 0 then return "" end
	
	local r : number = ae % 3
	
	return tostring(floor(am * POW10[r + 16] * 100) / 100) .. (prefixes[(ae - r) / 3] or "")
end

return table.freeze(Bignum) :: typeof(Bignum)
