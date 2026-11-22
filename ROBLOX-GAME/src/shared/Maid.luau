--!strict
-- Collects things to clean up (connections, instances, functions) and cleans them all at once, e.g. when a character
-- dies. A task is anything with Disconnect or Destroy, or a function. A failing task does not stop the others.

local Maid = {}
Maid.__index = Maid

export type Maid = typeof(setmetatable({} :: { tasks: { any } }, Maid))

function Maid.new(): Maid
	return setmetatable({ tasks = {} }, Maid)
end

function Maid.give<T>(self: Maid, item: T): T
	table.insert(self.tasks, item)
	return item
end

function Maid.clean(self: Maid)
	local tasks = self.tasks
	self.tasks = {}
	for i = #tasks, 1, -1 do
		local item: any = tasks[i]
		local ok, err = pcall(function()
			if type(item) == "function" then
				item()
			elseif item.Disconnect then -- RBXScriptConnection
				item:Disconnect()
			elseif item.Destroy then -- Instance, Tween, Maid-like
				item:Destroy()
			end
		end)
		if not ok then
			print("[maid] cleanup failed: " .. tostring(err))
		end
	end
end

return Maid
