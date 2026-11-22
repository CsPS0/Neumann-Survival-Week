-- Brings the entity's body to life on your screen (the server only builds it: EntityModel). Every frame the joints of
-- the parts marked "Anim" move from their resting place: it breathes, the head twitches and jerks, the jaw works,
-- the huge arm sways, the tendrils swing, the pustules pulse. While it bites someone (the model's Biting attribute)
-- the head lunges, the jaw snaps and the arm rises. Local only: smooth, and nothing is sent to the server.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local EntityAnimator = {}

type Joint = { weld: Weld, base: CFrame, kind: string, part: BasePart, phase: number }
local bodies: { [Model]: { Joint } } = {}

local function collect(model: Model)
	local list: { Joint } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Anim") then
			local weld = d:FindFirstChild("Joint")
			if weld and weld:IsA("Weld") then
				table.insert(list, { weld = weld, base = weld.C0, kind = d:GetAttribute("Anim"), part = d,
					phase = d:GetAttribute("Phase") or 0 })
			end
		end
	end
	bodies[model] = list
end

-- A rotation of `base` about `pivot` (both in the root's space).
local function about(base: CFrame, pivot: Vector3, rotation: CFrame): CFrame
	local p = CFrame.new(pivot)
	return p * rotation * p:Inverse() * base
end

function EntityAnimator.init()
	local function add(m: Instance)
		if m:IsA("Model") then
			task.defer(collect, m)
		end
	end
	for _, m in CollectionService:GetTagged("EntityBody") do
		add(m)
	end
	CollectionService:GetInstanceAddedSignal("EntityBody"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("EntityBody"):Connect(function(m)
		bodies[m :: Model] = nil
	end)

	local twitchAt, twitch = 0, CFrame.new()
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		if t > twitchAt then
			-- A sudden jerk of the head now and then.
			twitchAt = t + 1.2 + math.random() * 2.5
			twitch = CFrame.Angles((math.random() - 0.5) * 0.5, (math.random() - 0.5) * 0.9, (math.random() - 0.5) * 0.7)
		end
		local jerk = math.max(0, 1 - (twitchAt - t) * 6) -- the jerk eases back in about 0.15 s
		for model, joints in bodies do
			if not model.Parent then
				bodies[model] = nil
				continue
			end
			local biting = model:GetAttribute("Biting") == true
			local arm = model:GetAttribute("ArmPivot") or Vector3.zero
			local neck = model:GetAttribute("HeadPivot") or Vector3.zero
			local hinge = model:GetAttribute("JawPivot") or Vector3.zero
			for _, j in joints do
				local k = j.kind
				local c = j.base
				if k == "breathe" then
					c = c * CFrame.new(0, math.sin(t * 2.2) * 0.05, 0) * CFrame.Angles(math.sin(t * 2.2) * 0.03, 0, 0)
				elseif k == "pulse" then
					local s = math.sin(t * 3.1)
					c = c * CFrame.new(s * 0.03, s * 0.04, 0)
				elseif k == "glow" then
					local s = (math.sin(t * 4 + j.part.Position.Y * 3) + 1) / 2
					j.part.Color = Color3.fromRGB(150, 60, 20):Lerp(Color3.fromRGB(255, 160, 60), s)
				elseif k == "head" then
					local idle = CFrame.Angles(math.sin(t * 1.3) * 0.08, math.sin(t * 0.7) * 0.25, math.sin(t * 1.9) * 0.1)
					local lunge = if biting then CFrame.Angles(0.35 + math.sin(t * 9) * 0.25, 0, 0) else CFrame.new()
					c = about(c, neck, idle * twitch:Lerp(CFrame.new(), 1 - jerk) * lunge)
				elseif k == "jaw" then
					local open = if biting then 0.25 + math.abs(math.sin(t * 9)) * 0.6 else 0.15 + math.sin(t * 1.5) * 0.12
					local head = CFrame.Angles(math.sin(t * 1.3) * 0.08, math.sin(t * 0.7) * 0.25, math.sin(t * 1.9) * 0.1)
					c = about(about(c, hinge, CFrame.Angles(open, 0, 0)), neck, head)
				elseif k == "arm" then
					local swing = if biting then CFrame.Angles(-1.1 + math.sin(t * 9) * 0.3, 0, -0.3)
						else CFrame.Angles(math.sin(t * 1.1) * 0.12, 0, math.sin(t * 0.8) * 0.06)
					c = about(c, arm, swing)
				elseif k == "tendril" then
					local top = (j.base * CFrame.new(0, j.part.Size.Y / 2, 0)).Position
					c = about(c, top, CFrame.Angles(math.sin(t * 1.6 + j.phase) * 0.35, 0, math.sin(t * 1.2 + j.phase * 2) * 0.3))
				end
				j.weld.C0 = c
			end
		end
	end)
end

return EntityAnimator
