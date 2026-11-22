-- Spawning and moving player characters. Every player spawns as the same plain default character (no own avatar,
-- no accessories, fixed colours), so nobody is a giant block and Social Deduction needs no extra uniform.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local S = Config.studs
local SKIN = Color3.fromRGB(234, 184, 146)
local JACKET = Color3.fromRGB(38, 52, 86)
local TROUSERS = Color3.fromRGB(70, 68, 74)
local JUMP_POWER = 50 -- Roblox's default jump

local Characters = {}

local function defaultDescription(): HumanoidDescription
	local d = Instance.new("HumanoidDescription")
	d.HeadColor = SKIN
	d.LeftArmColor = SKIN
	d.RightArmColor = SKIN
	d.TorsoColor = JACKET
	d.LeftLegColor = TROUSERS
	d.RightLegColor = TROUSERS
	-- A slim build: narrower shoulders and a shallower chest, so the body does not fill a first-person view and the
	-- school's 1.5 m doors feel wide. Height stays (eye level 1.6 m).
	d.HeightScale = 1
	d.WidthScale = 0.8
	d.DepthScale = 0.8
	d.HeadScale = 0.95
	d.BodyTypeScale = 0
	d.ProportionScale = 0
	return d
end

-- The look every player gets (the test players use it too: TestBots).
Characters.SKIN, Characters.JACKET, Characters.TROUSERS = SKIN, JACKET, TROUSERS

-- Yields while the character loads. Returns nil (never errors) when the player left or loading failed.
function Characters.spawn(player: Player, at: CFrame): Model?
	if not player.Parent then
		return nil
	end
	local ok, err = pcall(function()
		player:LoadCharacterWithHumanoidDescriptionAsync(defaultDescription())
	end)
	if not ok then
		warn(`[characters] could not spawn {player.Name}: {err}`)
		return nil
	end
	local character = player.Character
	if not character or not player.Parent then
		return nil
	end
	character:PivotTo(at)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = S(Config.Player.walk)
		humanoid.UseJumpPower = true
		humanoid.JumpPower = JUMP_POWER
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	end
	player:SetAttribute("SpeedLock", nil)
	player:SetAttribute("LostArm", nil) -- a new body is whole again (Hide and Seek's entity)
	player:SetAttribute("LostEye", nil)
	return character
end

-- A fixed speed (metres per second) the client's sprint cannot change; nil gives control back.
function Characters.setSpeed(player: Player, metresPerSecond: number?)
	player:SetAttribute("SpeedLock", if metresPerSecond then S(metresPerSecond) else nil)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = S(metresPerSecond or Config.Player.walk)
		humanoid.JumpPower = if metresPerSecond == 0 then 0 else JUMP_POWER -- Downed or stunned: no jumping.
	end
end

function Characters.freeze(player: Player, on: boolean)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = on
	end
end

function Characters.place(player: Player, at: CFrame)
	if player.Character then
		player.Character:PivotTo(at)
	end
end

function Characters.despawn(player: Player)
	if player.Character then
		player.Character:Destroy()
		player.Character = nil
	end
end

function Characters.humanoid(player: Player): Humanoid?
	return player.Character and player.Character:FindFirstChildOfClass("Humanoid")
end

function Characters.root(player: Player): BasePart?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

return Characters
