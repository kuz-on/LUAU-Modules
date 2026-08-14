--!optimize 2
--!strict

-- must use consecutive positive integers,
-- make sure to update the __maxInt field
-- at the end of the table when you're done

return {
	["Test"] = 1,
	
	["__maxInt"] = 1
} :: {[string]: number}