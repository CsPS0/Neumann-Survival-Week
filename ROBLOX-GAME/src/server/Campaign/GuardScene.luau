-- Nightfall in the Aula (docs/2026-11-22-campaign-story-design.md): the security guard stands by the altar with his
-- torch. A scream rings through the school; when someone walks into the Aula (or after a minute), the entity has
-- him: it lifts him, shakes him and eats him while his torch flickers, then the torch drops and rolls across the
-- floor and the entity turns on the nearest student. Moderate 13+: a scream, a shadow, a dropped torch; no blood.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Characters = require(script.Parent.Parent.Characters)
local Caretaker = require(script.Parent.Caretaker)
local Npc = require(script.Parent.Npc)

local S = Config.studs
local SCREAM_AFTER = 8 -- seconds after nightfall
local WAIT_LIMIT = 60 -- seconds the scene waits for a witness
local WITNESS = 20 -- metres from the guard that count as "in the Aula"
local EAT = 3.6 -- seconds of the scene

local GuardScene = {}
GuardScene.__index = GuardScene

export type Opts = {
	folder: Instance,
	at: Vector3, -- where the guard stands (feet, studs)
	entity: Model,
	alive: () -> { Player },
	sound: (name: string, at: Vector3?) -> (),
	banner: (text: string, seconds: number, player: Player?) -> (),
	timeScale: number,
	onScream: () -> (),
	onDone: (nearest: Player?) -> (), -- the entity attacks
}

local function nearest(opts: Opts, at: Vector3, within: number): Player?
	local best, bestD = nil, within
	for _, p in opts.alive() do
		local root = Characters.root(p)
		if root then
			local d = (root.Position - at).Magnitude
			if d < bestD then
				best, bestD = p, d
			end
		end
	end
	return best
end

function GuardScene.start(opts: Opts)
	local self = setmetatable({}, GuardScene)
	self.stopped = false
	self.opts = opts
	local guard = Npc.build("Guard", Color3.fromRGB(34, 44, 70), Color3.fromRGB(28, 30, 40),
		CFrame.lookAt(opts.at + Vector3.new(0, 3, 0), opts.at + Vector3.new(0, 3, S(3))), opts.folder)
	self.guard = guard
	self.torch = Caretaker.giveTorch(guard)
	task.spawn(function()
		self:run()
	end)
	return self
end

function GuardScene:run()
	local opts = self.opts
	task.wait(SCREAM_AFTER * opts.timeScale)
	if self.stopped then
		return
	end
	-- Everyone hears it, wherever they hide.
	opts.sound("scream", opts.at)
	opts.sound("sting")
	opts.banner("A scream from the Aula!", 5)
	opts.onScream()
	local waited = 0
	while waited < WAIT_LIMIT * opts.timeScale and not self.stopped do
		if nearest(opts, opts.at, S(WITNESS)) then
			break
		end
		task.wait(0.25)
		waited += 0.25
	end
	if self.stopped then
		return
	end
	self:eat()
end

function GuardScene:eat()
	local opts = self.opts
	local guard = self.guard
	local groot = guard:FindFirstChild("HumanoidRootPart") :: BasePart?
	local eroot = opts.entity:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = guard:FindFirstChildOfClass("Humanoid")
	if not groot or not eroot then
		opts.onDone(nearest(opts, opts.at, math.huge))
		return
	end
	Npc.stop(guard)
	-- It comes out of the dark right in front of him, both face to face.
	local base = groot.CFrame
	local front = base.Position + base.LookVector * 3.4
	-- Stand it on the Aula floor (it waits far below the school until now): its root as high above its feet as
	-- it is in its own model.
	local box, size = opts.entity:GetBoundingBox()
	local rootAboveFeet = eroot.Position.Y - (box.Position.Y - size.Y / 2)
	local y = opts.at.Y + rootAboveFeet
	local rootAt = CFrame.lookAt(Vector3.new(front.X, y, front.Z), Vector3.new(base.Position.X, y, base.Position.Z))
	opts.entity:PivotTo(rootAt * eroot.CFrame:ToObjectSpace(opts.entity:GetPivot()))
	eroot.Anchored = true
	groot.Anchored = true
	if humanoid then
		humanoid.PlatformStand = true
	end
	local body = opts.entity:FindFirstChild("EntityLook") or opts.entity
	body:SetAttribute("Biting", true)
	opts.sound("scream", opts.at)
	local light = self.torch and self.torch:FindFirstChildOfClass("SpotLight")
	local started = os.clock()
	local nextBump = 0
	while os.clock() - started < EAT and not self.stopped do
		local t = (os.clock() - started) / EAT
		local lift = math.min(1, t * 2.5) * 1.6
		local shake = CFrame.Angles((math.random() - 0.5) * 0.5, (math.random() - 0.5) * 0.4, (math.random() - 0.5) * 0.6)
		groot.CFrame = base * CFrame.new(0, lift, -t * 1.2) * shake
		if light then
			light.Enabled = math.random() > 0.35
		end
		if os.clock() > nextBump then
			nextBump = os.clock() + 0.9
			opts.sound("bump", opts.at)
		end
		task.wait(0.06)
	end
	body:SetAttribute("Biting", nil)
	-- The torch falls and rolls away, still on; the guard is gone.
	if self.torch then
		local weld = self.torch:FindFirstChildOfClass("WeldConstraint")
		if weld then
			weld:Destroy()
		end
		self.torch.Parent = opts.folder
		self.torch.CanCollide = true
		self.torch.Massless = false
		self.torch.AssemblyLinearVelocity = base.RightVector * 6 + Vector3.new(0, 4, 0)
		self.torch.AssemblyAngularVelocity = Vector3.new(0, 0, 8)
		if light then
			light.Enabled = true
		end
	end
	if guard.Parent then
		guard:Destroy()
	end
	eroot.Anchored = false
	if not self.stopped then
		opts.onDone(nearest(opts, opts.at, math.huge))
	end
end

function GuardScene:stop()
	self.stopped = true
	if self.guard.Parent then
		self.guard:Destroy()
	end
end

return GuardScene
