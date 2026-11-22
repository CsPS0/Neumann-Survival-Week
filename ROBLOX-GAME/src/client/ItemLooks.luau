-- What items look like (in your hand, as slot icons) and the line the bag shows about them. Room keys look like the
-- storage key (Inventory.lookOf).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Inventory = require(ReplicatedStorage.Shared.Inventory)

local ItemLooks = {}

local LOOKS: { [string]: { color: Color3, size: Vector3, material: Enum.Material?, about: string } } = {
	key = { color = Color3.fromRGB(196, 160, 70), size = Vector3.new(0.05, 0.2, 0.02), material = Enum.Material.Metal,
		about = "A brass key from the board at the Porta." },
	vial = { color = Color3.fromRGB(150, 200, 235), size = Vector3.new(0.09, 0.24, 0.09), material = Enum.Material.Glass,
		about = "Holy water in a small glass vial." },
	salt = { color = Color3.fromRGB(235, 235, 235), size = Vector3.new(0.25, 0.3, 0.18),
		about = "A heavy bag of salt from the storage room." },
	fuse = { color = Color3.fromRGB(200, 160, 60), size = Vector3.new(0.09, 0.24, 0.09), material = Enum.Material.Metal,
		about = "A ceramic fuse. Something in the school is missing one." },
	bell = { color = Color3.fromRGB(205, 205, 215), size = Vector3.new(0.2, 0.22, 0.2), material = Enum.Material.Metal,
		about = "A small silver bell." },
	papers = { color = Color3.fromRGB(236, 230, 210), size = Vector3.new(0.21, 0.02, 0.28),
		about = "Notes and clue papers you picked up." },
	battery = { color = Color3.fromRGB(40, 40, 46), size = Vector3.new(0.12, 0.2, 0.04),
		about = "A power bank. Use it to charge the phone." },
	biscuit = { color = Color3.fromRGB(170, 120, 70), size = Vector3.new(0.12, 0.03, 0.08),
		about = "A dog biscuit. Csoki would follow you anywhere for this." },
}

local FALLBACK = { color = Color3.new(0.6, 0.6, 0.6), size = Vector3.new(0.12, 0.12, 0.12), about = "" }

function ItemLooks.of(id: string): { color: Color3, size: Vector3, material: Enum.Material?, about: string }
	return LOOKS[Inventory.lookOf(id)] or FALLBACK
end

function ItemLooks.about(id: string): string
	local room = string.match(id, "^roomkey:(.+)$")
	if room then
		return `The key to room {room}, from the porter. It unlocks the door for good.`
	end
	return ItemLooks.of(id).about
end

-- A ViewportFrame with the item turning slowly in it (a slot icon). `size` in pixels.
function ItemLooks.icon(parent: Instance, id: string?, size: number): ViewportFrame
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Icon"
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromOffset(size, size)
	vp.AnchorPoint = Vector2.new(0.5, 0.5)
	vp.Position = UDim2.fromScale(0.5, 0.5)
	vp.Ambient = Color3.fromRGB(150, 150, 150)
	vp.LightColor = Color3.fromRGB(255, 244, 225)
	vp.LightDirection = Vector3.new(-1, -1.5, -1)
	vp.Parent = parent
	if not id then
		return vp
	end
	local look = ItemLooks.of(id)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = look.size * 6
	p.Color = look.color
	p.Material = look.material or Enum.Material.SmoothPlastic
	p.CFrame = CFrame.Angles(math.rad(-20), math.rad(35), math.rad(10))
	p.Parent = vp
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local extent = p.Size.Magnitude
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, extent * 2.1), Vector3.zero)
	camera.Parent = vp
	vp.CurrentCamera = camera
	return vp
end

return ItemLooks
