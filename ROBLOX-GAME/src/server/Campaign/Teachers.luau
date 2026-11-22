-- The 8 invented teachers: each walks to its room before its lesson, the rest wait in the staff room (33). E talks:
-- small talk, and the culprit lets one strange line slip per break so far. They leave at the explosion.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CampaignData = require(ReplicatedStorage.Shared.CampaignData)
local FloorData = require(ReplicatedStorage.Shared.FloorData)
local Npc = require(script.Parent.Npc)

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local Teachers = {}
Teachers.__index = Teachers

export type Run = {
	row: number,
	culprit: string,
	breaks: () -> number,
	dialogue: RemoteEvent,
	isAlive: (Player) -> boolean,
}

function Teachers.new(parent: Instance, run: Run)
	local self = setmetatable({}, Teachers)
	self.run = run
	self.models = {} :: { [string]: Model }
	self.staffRoom = Npc.roomPoint(FloorData, 0, CampaignData.STORY.staffClue.room) :: Vector3
	for i, id in CampaignData.SUSPECTS do
		local name = CampaignData.TEACHERS[id]
		local look = CampaignData.LOOKS[id]
		local spot = self.staffRoom + Vector3.new(((i - 1) % 4 - 1.5) * 4, 0, ((i - 1) // 4 - 0.5) * 4)
		local model = Npc.build(name, rgb(look.jacket), rgb(look.trousers), CFrame.new(spot), parent)
		game:GetService("CollectionService"):AddTag(model, "Teacher")
		model:SetAttribute("TeacherId", id)
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Talk"
		prompt.ActionText = "Talk"
		prompt.ObjectText = name
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 10
		prompt:SetAttribute("For", "living")
		prompt.Triggered:Connect(function(player)
			if run.isAlive(player) then
				run.dialogue:FireClient(player, { name = name, lines = self:lines(id) })
			end
		end)
		prompt.Parent = root
		self.models[id] = model
	end
	return self
end

function Teachers:lines(id: string): { string }
	local lines = { CampaignData.CHAT[id] }
	local breaks = self.run.breaks()
	if id == self.run.culprit and breaks >= 1 then
		table.insert(lines, CampaignData.STRANGE[math.min(breaks, #CampaignData.STRANGE)])
	end
	return lines
end

-- Before lesson `subject`: its teacher goes to the room, the others to the staff room.
function Teachers:sendFor(subject: string)
	local teacherId = CampaignData.teacherOf(subject, self.run.row)
	local info = CampaignData.SUBJECTS[subject]
	local room = Npc.roomPoint(FloorData, info.floor, info.room)
	local i = 0
	for id, model in self.models do
		if id == teacherId and room then
			Npc.goTo(model, room, 1.6)
		else
			i += 1
			Npc.goTo(model, self.staffRoom + Vector3.new((i % 4 - 1.5) * 4, 0, (i // 4 - 0.5) * 4), 1.3)
		end
	end
end

-- Everyone leaves the building (the explosion): walk to the entrance, then gone.
function Teachers:dismiss(exit: Vector3)
	for _, model in self.models do
		Npc.goTo(model, exit, 2.2, function()
			if model.Parent then
				Npc.remove(model)
			end
		end)
		task.delay(40, function()
			if model.Parent then
				Npc.remove(model)
			end
		end)
	end
	self.models = {}
end

function Teachers:model(id: string): Model?
	return self.models[id]
end

function Teachers:destroy()
	for _, model in self.models do
		Npc.remove(model)
	end
	self.models = {}
end

return Teachers
