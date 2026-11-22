-- The porter at the Porta desk (porter.gd), simplified: he stands behind the desk all day and night. He lends the
-- room keys and, at night, hands the team the storage key for the red room (his prompt is Keys.luau's).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FloorData = require(ReplicatedStorage.Shared.FloorData)
local Npc = require(script.Parent.Npc)

local Porter = {}

function Porter.build(folder: Instance): Model?
	local at = Npc.roomPoint(FloorData, 0, "Porta")
	if not at then
		return nil
	end
	local model = Npc.build("Porter", Color3.fromRGB(50, 66, 90), Color3.fromRGB(44, 44, 48),
		CFrame.lookAt(at, at + Vector3.new(0, 0, -1)), folder)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	root.Anchored = true
	return model
end

return Porter
