-- Afternoon glimpses (horror_entity.gd encounter): twice a run, between 14:00 and 17:30 on the story clock, the
-- entity stands still at the far end of a corridor, facing a player, wearing the possessed teacher's shreds and
-- mark. Everyone can see it. It is gone after 2.5 s, or as soon as anyone comes within 8 m. Harmless: it is a clue.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Characters = require(script.Parent.Parent.Characters)
local EntityModel = require(script.Parent.Parent.EntityModel)

local S = Config.studs
local FIRST, LAST = 14 * 60, 17 * 60 + 30 -- game minutes
local COUNT = 2
local SHOW = 2.5 -- seconds
local NEAR, FAR = 10, 30 -- metres from the player
local VANISH = 8 -- metres: closer than this and it is gone

local Glimpses = {}
Glimpses.__index = Glimpses

export type Run = {
	folder: Instance,
	alive: () -> { Player },
	look: EntityModel.Look,
	minutes: () -> number,
	patrol: { Vector3 },
	sound: (name: string, at: Vector3?) -> (),
}

function Glimpses.new(run: Run)
	local self = setmetatable({}, Glimpses)
	self.run = run
	self.running = true
	self.times = {}
	for i = 1, COUNT do
		self.times[i] = FIRST + math.random() * (LAST - FIRST)
	end
	table.sort(self.times)
	task.spawn(function()
		while self.running do
			task.wait(0.5)
			local due = self.times[1]
			if due and run.minutes() >= due and run.minutes() < LAST + 15 then
				if self:show() then
					table.remove(self.times, 1)
				else
					self.times[1] = due + 10 -- no good spot right now: try again a little later
				end
			end
		end
	end)
	return self
end

-- A patrol point on the player's floor, NEAR-FAR metres away, in clear view of them.
local function spotFor(player: Player, patrol: { Vector3 }): Vector3?
	local root = Characters.root(player)
	if not root then
		return nil
	end
	local eye = root.Position + Vector3.new(0, S(0.6), 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Model }
	local options = {}
	for _, p in patrol do
		local d = (Vector3.new(p.X, 0, p.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
		if math.abs(p.Y - (root.Position.Y - 3)) < S(1.5) and d >= S(NEAR) and d <= S(FAR) then
			local target = p + Vector3.new(0, S(1.6), 0)
			if not workspace:Raycast(eye, target - eye, params) then
				table.insert(options, p)
			end
		end
	end
	return if #options > 0 then options[math.random(#options)] else nil
end

function Glimpses:show(): boolean
	local players = self.run.alive()
	if #players == 0 then
		return false
	end
	local player = players[math.random(#players)]
	local spot = spotFor(player, self.run.patrol)
	local root = Characters.root(player)
	if not spot or not root then
		return false
	end
	local model = EntityModel.build(self.run.look)
	local body = model.PrimaryPart :: BasePart
	body.Anchored = true
	local face = Vector3.new(root.Position.X, spot.Y, root.Position.Z)
	model:PivotTo(CFrame.lookAt(spot + Vector3.new(0, S(1), 0), face + Vector3.new(0, S(1), 0)))
	model.Parent = self.run.folder
	self.run.sound("sting", spot)
	task.spawn(function()
		local started = os.clock()
		while model.Parent and os.clock() - started < SHOW do
			task.wait(0.1)
			for _, p in Players:GetPlayers() do
				local r = Characters.root(p)
				if r and (r.Position - body.Position).Magnitude < S(VANISH) then
					model:Destroy()
					return
				end
			end
		end
		model:Destroy()
	end)
	return true
end

function Glimpses:destroy()
	self.running = false
end

return Glimpses
