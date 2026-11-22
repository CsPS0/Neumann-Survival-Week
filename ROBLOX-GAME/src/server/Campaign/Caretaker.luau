-- The caretaker (caretaker.gd): patrols the empty school after the explosion. Seeing a student, he walks to them;
-- catching one calls onCatch. The story uses him as the security guard (a name, a uniform, a torch and a sight in
-- metres in the options), who walks the students he catches out of the school.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Characters = require(script.Parent.Parent.Characters)
local Npc = require(script.Parent.Npc)

local S = Config.studs
local SIGHT = 12
local CATCH = 2.2

local Caretaker = {}
Caretaker.__index = Caretaker

export type Run = {
	folder: Instance,
	patrol: { Vector3 },
	alive: () -> { Player },
	onCatch: (Player) -> (),
	speed: number,
	name: string?, -- "Caretaker" when not given
	jacket: Color3?,
	trousers: Color3?,
	sight: number?, -- metres (12 when not given)
	torch: boolean?, -- carries a torch (a spotlight from the hand)
}

-- A torch in the NPC's right hand, shining ahead (the guard). Returns the torch part.
function Caretaker.giveTorch(model: Model): BasePart?
	local hand = model:FindFirstChild("RightHand") :: BasePart?
	if not hand then
		return nil
	end
	local torch = Instance.new("Part")
	torch.Name = "Torch"
	torch.Size = Vector3.new(0.35, 0.35, 1.3)
	torch.Color = Color3.fromRGB(30, 30, 34)
	torch.Material = Enum.Material.Metal
	torch.CanCollide = false
	torch.Massless = true
	torch.CFrame = hand.CFrame * CFrame.new(0, -0.3, -0.5)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = torch
	weld.Parent = torch
	local beam = Instance.new("SpotLight")
	beam.Face = Enum.NormalId.Front
	beam.Angle = 50
	beam.Range = S(14)
	beam.Brightness = 3
	beam.Color = Color3.fromRGB(255, 240, 210)
	beam.Shadows = true
	beam.Parent = torch
	torch.Parent = model
	return torch
end

function Caretaker.new(run: Run, at: Vector3)
	local self = setmetatable({}, Caretaker)
	self.run = run
	self.model = Npc.build(run.name or "Caretaker", run.jacket or Color3.fromRGB(70, 84, 60),
		run.trousers or Color3.fromRGB(60, 60, 56), CFrame.new(at), run.folder)
	self.sight = run.sight or SIGHT
	if run.torch then
		Caretaker.giveTorch(self.model)
	end
	self.running = true
	self.paused = false -- during a team vote
	self.chasing = nil :: Player?
	self.rayParams = RaycastParams.new()
	self.rayParams.FilterType = Enum.RaycastFilterType.Exclude
	self.rayParams.FilterDescendantsInstances = { self.model }
	task.spawn(function()
		while self.running and self.model.Parent do
			if not self.chasing and not self.paused then
				local goal = run.patrol[math.random(#run.patrol)]
				Npc.walkTo(self.model, goal + Vector3.new(0, 3, 0), 1.5)
			end
			task.wait(0.5)
		end
	end)
	task.spawn(function()
		while self.running and self.model.Parent do
			self:look()
			task.wait(0.25)
		end
	end)
	return self
end

function Caretaker:setPaused(paused: boolean)
	self.paused = paused
	self.chasing = nil
	if paused and self.model.Parent then
		Npc.stop(self.model)
	end
end

function Caretaker:look()
	if self.paused then
		return
	end
	local root = self.model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local best, bestDist = nil, math.huge
	for _, player in self.run.alive() do
		local target = Characters.root(player)
		if target and not player:GetAttribute("Hidden") then
			local to = target.Position - root.Position
			if to.Magnitude < S(self.sight) and math.abs(to.Y) < S(2) then
				local hit = workspace:Raycast(root.Position, to, self.rayParams)
				if hit and hit.Instance:IsDescendantOf(player.Character :: Model) and to.Magnitude < bestDist then
					best, bestDist = player, to.Magnitude
				end
			end
		end
	end
	if best then
		if bestDist < S(CATCH) then
			self.chasing = nil
			self.run.onCatch(best)
			return
		end
		self.chasing = best
		local target = Characters.root(best) :: BasePart
		Npc.goTo(self.model, target.Position, self.run.speed)
	elseif self.chasing then
		self.chasing = nil
	end
end

function Caretaker:destroy()
	self.running = false
	if self.model.Parent then
		Npc.remove(self.model)
	end
end

return Caretaker
