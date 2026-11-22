-- What the entity takes from someone it holds (Hide and Seek, and the test players' attack demo): the left arm, or
-- the left eye (a dark patch). Only on the body; nothing graphic (the game is Moderate 13+).
local Maim = {}

function Maim.apply(character: Model, part: string)
	if character:GetAttribute(part) then
		return
	end
	character:SetAttribute(part, true)
	if part == "LostArm" then
		for _, name in { "LeftUpperArm", "LeftLowerArm", "LeftHand" } do
			local p = character:FindFirstChild(name) :: BasePart?
			if p then
				p.Transparency = 1
			end
		end
		-- A dark sleeve end at the shoulder.
		local shoulder = character:FindFirstChild("UpperTorso") :: BasePart?
		if shoulder then
			local stump = Instance.new("Part")
			stump.Name = "Stump"
			stump.Size = Vector3.new(0.35, 0.3, 0.6)
			stump.Color = Color3.fromRGB(40, 30, 34)
			stump.Material = Enum.Material.Fabric
			stump.CanCollide = false
			stump.Massless = true
			stump.CFrame = shoulder.CFrame * CFrame.new(-shoulder.Size.X / 2 - 0.12, shoulder.Size.Y / 2 - 0.35, 0)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = shoulder
			weld.Part1 = stump
			weld.Parent = stump
			stump.Parent = character
		end
	elseif part == "LostEye" then
		local head = character:FindFirstChild("Head") :: BasePart?
		if head then
			local patch = Instance.new("Part")
			patch.Name = "EyePatch"
			patch.Size = Vector3.new(0.32, 0.26, 0.05)
			patch.Color = Color3.fromRGB(20, 16, 16)
			patch.Material = Enum.Material.Fabric
			patch.CanCollide = false
			patch.Massless = true
			patch.CFrame = head.CFrame * CFrame.new(-0.22, 0.12, -head.Size.Z / 2 - 0.02)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = head
			weld.Part1 = patch
			weld.Parent = patch
			patch.Parent = character
		end
	end
end

return Maim
