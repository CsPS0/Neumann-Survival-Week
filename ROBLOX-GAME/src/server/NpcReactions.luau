-- People react to you. Players and people bump into each other (they collide; people still pass through each
-- other so a crowd never jams). Running into someone makes them stagger and say something; sprinting near a teacher
-- gets you told off ("No running in the corridor!"). Speech is a small bubble over their head, seen by everyone.
-- NPC models carry the "Npc" tag (Npc.build) and teachers also "Teacher" (People, Teachers).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local S = Config.studs
local BUMP = 3.6 -- studs between roots that count as a bump
local BUMP_SPEED = S(2) -- you must be moving at least this fast (studs/s)
local YELL_RANGE = S(10)
local YELL_EVERY = 12 -- seconds per player
local SAY_EVERY = 4 -- seconds per NPC

local BUMPED = { "Hey!", "Watch it!", "Ouch, look where you're going!", "Excuse you!", "Careful!", "Oi!" }
local BUMPED_TEACHER = { "Watch where you're going, young one!", "Slow down!", "Careful! This is a school." }
local RUNNING = { "No running in the corridor!", "Walk, don't run!", "Slow down! This isn't the gym!",
	"Running again? Walk!" }

local NpcReactions = {}

local lastSaid: { [Model]: number } = {}
local lastYell: { [Player]: number } = {}
local lastFast: { [Player]: number } = {} -- when the player last moved fast (a collision stops you at once)

local function pick(list: { string }): string
	return list[math.random(#list)]
end

-- A speech bubble over an NPC's head for a few seconds.
function NpcReactions.say(model: Model, text: string)
	local head = model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local old = head:FindFirstChild("Speech")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Speech"
	gui.Size = UDim2.fromOffset(220, 46)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.MaxDistance = 45
	gui.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(250, 248, 240)
	label.BackgroundTransparency = 0.05
	label.TextColor3 = Color3.fromRGB(25, 25, 30)
	label.TextWrapped = true
	label.TextScaled = true
	label.Font = Enum.Font.GothamMedium
	label.Text = text
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4)
	pad.Parent = label
	gui.Parent = head
	task.delay(2.8, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

local function canSay(model: Model): boolean
	local now = os.clock()
	if now - (lastSaid[model] or 0) < SAY_EVERY then
		return false
	end
	lastSaid[model] = now
	return true
end

local function bumped(model: Model, root: BasePart, by: BasePart)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Sit then
		return
	end
	if not canSay(model) then
		return
	end
	NpcReactions.say(model, pick(if CollectionService:HasTag(model, "Teacher") then BUMPED_TEACHER else BUMPED))
	-- A stagger: a small shove away from you, and a look back at you.
	local away = Vector3.new(root.Position.X - by.Position.X, 0, root.Position.Z - by.Position.Z)
	if away.Magnitude > 0.1 then
		root.AssemblyLinearVelocity = away.Unit * S(4) + Vector3.new(0, S(1), 0)
	end
	humanoid:Move(Vector3.zero)
end

function NpcReactions.init()
	task.spawn(function()
		while true do
			task.wait(0.1)
			local npcs = CollectionService:GetTagged("Npc")
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and character then
					local v = root.AssemblyLinearVelocity
					local speed = Vector3.new(v.X, 0, v.Z).Magnitude
					local sprinting = player:GetAttribute("Sprinting") == true
					if speed > BUMP_SPEED then
						lastFast[player] = os.clock()
					end
					local fast = os.clock() - (lastFast[player] or 0) < 0.6
					for _, model in npcs do
						local npcRoot = (model :: Model).PrimaryPart or model:FindFirstChild("HumanoidRootPart") :: BasePart?
						if npcRoot and model:IsDescendantOf(workspace) then
							local d = (npcRoot.Position - root.Position).Magnitude
							if d < BUMP and fast then
								bumped(model :: Model, npcRoot, root)
							elseif sprinting and d < YELL_RANGE and CollectionService:HasTag(model, "Teacher")
								and os.clock() - (lastYell[player] or 0) > YELL_EVERY then
								lastYell[player] = os.clock()
								lastSaid[model :: Model] = os.clock()
								NpcReactions.say(model :: Model, pick(RUNNING))
							end
						end
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastYell[player] = nil
		lastFast[player] = nil
	end)
end

return NpcReactions
