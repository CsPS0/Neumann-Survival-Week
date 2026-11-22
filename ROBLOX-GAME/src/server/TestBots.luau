-- Four test players and the entity's attack, played out in front of you (for checking how it looks; Studio and admins
-- only: the free roam admin panel or ServerStorage.TestHooks.AttackDemo). The test players look like real players
-- (Characters' look) and carry a name and health bar. Three parts, the same rules and visuals as Hide and Seek:
--   1. the entity catches Test 1 and holds it; after 8 s it takes the left arm; Test 2 sneaks behind the entity and
--      hits it (stunned 4 s, Test 1 is free with no arm; Test 2 loses 15 health);
--   2. it catches Test 3; Test 4 pulls Test 3 free (holds 3 s; Test 3 loses 25 health);
--   3. it catches Test 4 and nobody comes: the arm at 8 s, an eye at 16 s, eaten at 25 s.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Characters = require(script.Parent.Characters)
local EntityModel = require(script.Parent.EntityModel)
local Maim = require(script.Parent.Maim)
local Npc = require(script.Parent.Campaign.Npc)
local Grab = require(script.Parent.Grab)

local S = Config.studs
local HOLD = 25 -- seconds a caught survivor lasts (Config.HideSeek.downed)

local TestBots = {}

local running = false
local remotes: Folder

local function banner(text: string, seconds: number?)
	(remotes:FindFirstChild("Banner") :: RemoteEvent):FireAllClients(text, seconds or 4)
end

local function sound(name: string, at: Vector3)
	(remotes:FindFirstChild("Sound") :: RemoteEvent):FireAllClients(name, at)
end

local function root(m: Model): BasePart
	return m:FindFirstChild("HumanoidRootPart") :: BasePart
end

-- A name tag with a health bar over a test player's head.
local function tag(m: Model)
	local head = m:FindFirstChild("Head") :: BasePart
	local gui = Instance.new("BillboardGui")
	gui.Name = "TestTag"
	gui.Size = UDim2.fromOffset(140, 40)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 80
	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0, 20)
	name.BackgroundTransparency = 1
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.3
	name.Font = Enum.Font.GothamBold
	name.TextSize = 15
	name.Text = m.Name
	name.Parent = gui
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Position = UDim2.fromOffset(20, 24)
	back.Size = UDim2.new(1, -40, 0, 8)
	back.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 220, 110)
	fill.BorderSizePixel = 0
	fill.Parent = back
	local state = Instance.new("TextLabel")
	state.Name = "State"
	state.Position = UDim2.fromOffset(0, -18)
	state.Size = UDim2.new(1, 0, 0, 16)
	state.BackgroundTransparency = 1
	state.TextColor3 = Color3.fromRGB(255, 210, 120)
	state.TextStrokeTransparency = 0.3
	state.Font = Enum.Font.GothamMedium
	state.TextSize = 13
	state.Text = ""
	state.Parent = gui
	gui.Parent = head
	local humanoid = m:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid:GetPropertyChangedSignal("Health"):Connect(function()
		local f = humanoid.Health / humanoid.MaxHealth
		TweenService:Create(fill, TweenInfo.new(0.3), { Size = UDim2.fromScale(math.max(f, 0), 1) }):Play()
		fill.BackgroundColor3 = if f > 0.5 then Color3.fromRGB(90, 220, 110) else Color3.fromRGB(230, 120, 60)
	end)
end

local function say(m: Model, text: string)
	local head = m:FindFirstChild("Head")
	local gui = head and head:FindFirstChild("TestTag")
	if gui then
		(gui :: any).State.Text = text
	end
end

local function hurt(m: Model, amount: number)
	local humanoid = m:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.Health = math.max(1, humanoid.Health - amount)
end

local function walk(m: Model, to: Vector3, speed: number?)
	local humanoid = m:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.WalkSpeed = speed or S(2.5)
	humanoid:MoveTo(to)
	local done = false
	local c = humanoid.MoveToFinished:Connect(function()
		done = true
	end)
	local t0 = os.clock()
	while not done and os.clock() - t0 < 8 do
		task.wait(0.1)
	end
	c:Disconnect()
end

local function face(m: Model, at: Vector3)
	local r = root(m)
	r.CFrame = CFrame.lookAt(r.Position, Vector3.new(at.X, r.Position.Y, at.Z))
end

-- The entity grabs a survivor: it lies on the floor in front of the entity, which bends over it and bites.
local holding: { [Model]: boolean } = {}
local function catch(entity: Model, victim: Model)
	walk(entity, root(victim).Position, S(4.2))
	local e, v = root(entity), root(victim)
	local front = e.Position + e.CFrame.LookVector * S(1.1)
	v.Anchored = true
	v.CFrame = CFrame.new(front.X, e.Position.Y - 1.6, front.Z) * CFrame.Angles(math.rad(-90), 0, 0)
	e.Anchored = true
	face(entity, front)
	sound("sting", v.Position)
	say(victim, "CAUGHT")
	holding[entity] = true
	entity:SetAttribute("Biting", true)
	-- The bite: the entity leans in and back while it holds someone.
	task.spawn(function()
		local base = e.CFrame
		while holding[entity] and entity.Parent do
			TweenService:Create(e, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { CFrame = base * CFrame.Angles(math.rad(-25), 0, 0)
				* CFrame.new(0, -0.6, -0.4) }):Play()
			task.wait(0.5)
			TweenService:Create(e, TweenInfo.new(0.5), { CFrame = base }):Play()
			task.wait(0.9)
		end
		e.CFrame = base
	end)
end

local function release(entity: Model, victim: Model)
	holding[entity] = false
	entity:SetAttribute("Biting", nil)
	task.wait(0.2)
	root(entity).Anchored = false
	local v = root(victim)
	v.CFrame = CFrame.new(v.Position + Vector3.new(0, 1.8, 0)) * CFrame.Angles(0, math.rad(math.random(0, 359)), 0)
	v.Anchored = false
	say(victim, "")
end

local function stun(entity: Model)
	local e = root(entity)
	e.Anchored = true
	local base = e.CFrame
	TweenService:Create(e, TweenInfo.new(0.25), { CFrame = base * CFrame.new(0, 0, 1.5) * CFrame.Angles(math.rad(15), 0,
		math.rad(12)) }):Play()
	sound("bump", e.Position)
	task.wait(4)
	e.CFrame = base
	e.Anchored = false
end

local function maim(victim: Model, part: string)
	Maim.apply(victim, part)
	sound("scream", root(victim).Position)
	banner(if part == "LostArm" then `{victim.Name}: the entity took the left arm.` else `{victim.Name}: an eye is gone.`, 3)
end

function TestBots.run(near: CFrame, parent: Instance)
	if running then
		return false
	end
	running = true
	local folder = Instance.new("Folder")
	folder.Name = "TestPlayers"
	folder.Parent = parent
	local bots: { Model } = {}
	for i = 1, 4 do
		local at = near * CFrame.new(S(-3 + (i - 1) * 2), 0, -S(6))
		local m = Npc.build(`Test {i}`, Characters.JACKET, Characters.TROUSERS, at, folder, {
			skin = Characters.SKIN, width = 0.8, nameless = true })
		m:SetAttribute("TestPlayer", true)
		tag(m)
		table.insert(bots, m)
	end
	local entity = EntityModel.build()
	entity.Parent = folder
	entity:PivotTo(near * CFrame.new(0, 0, -S(18)) * CFrame.Angles(0, math.pi, 0))
	for _, b in bots do
		face(b, entity:GetPivot().Position)
	end
	local t1, t2, t3, t4 = bots[1], bots[2], bots[3], bots[4]

	task.spawn(function()
		banner("Attack demo: four test players and the entity.", 4)
		task.wait(3)
		-- 1. Caught; the arm goes; a friend hits it from behind.
		banner("1. The entity catches Test 1 and holds it.", 4)
		catch(entity, t1)
		task.wait(8)
		maim(t1, "LostArm")
		banner("Test 2 sneaks behind the entity...", 3)
		local behind = root(entity).Position - root(entity).CFrame.LookVector * S(1.4)
		walk(t2, behind, S(2.2))
		face(t2, root(entity).Position)
		say(t2, "HIT!")
		local r2 = root(t2)
		TweenService:Create(r2, TweenInfo.new(0.15), { CFrame = r2.CFrame * CFrame.new(0, 0, -1) }):Play()
		hurt(t2, 15)
		release(entity, t1)
		banner("Test 2 hit it from behind: Test 1 is free (no left arm). The entity lashed out: Test 2 -15 health.", 5)
		task.spawn(function()
			walk(t1, (near * CFrame.new(-S(7), 0, -S(5))).Position) -- aside, out of your view's middle
		end)
		stun(entity)
		say(t2, "")
		task.wait(2)

		-- 2. Pulled free.
		banner("2. The entity catches Test 3. Test 4 pulls...", 4)
		catch(entity, t3)
		task.wait(1.5)
		local side = root(t3).Position + root(entity).CFrame.RightVector * S(1.3)
		walk(t4, side, S(2.5))
		face(t4, root(t3).Position)
		for k = 3, 1, -1 do
			say(t4, `PULLING {k}...`)
			task.wait(1)
		end
		say(t4, "")
		hurt(t3, 25)
		release(entity, t3)
		banner("Test 4 pulled Test 3 free: Test 3 -25 health.", 5)
		task.spawn(function()
			walk(t3, (near * CFrame.new(S(7), 0, -S(5))).Position)
		end)
		task.wait(3)

		-- 3. Nobody comes.
		banner("3. The entity catches Test 4. Nobody comes this time.", 4)
		catch(entity, t4)
		task.wait(HOLD / 3)
		maim(t4, "LostArm")
		task.wait(HOLD / 3)
		maim(t4, "LostEye")
		task.wait(HOLD / 3)
		holding[entity] = false
		sound("scream", root(t4).Position)
		for _, d in t4:GetDescendants() do
			if d:IsA("BasePart") then
				TweenService:Create(d, TweenInfo.new(1.5), { Transparency = 1 }):Play()
			end
		end
		banner("Nobody came: the entity ate Test 4.", 5)
		task.wait(2)
		t4:Destroy()
		task.wait(8)
		banner("Attack demo over. The test players leave.", 3)
		task.wait(3)
		folder:Destroy()
		running = false
	end)
	return true
end

-- The entity attacks you (your own view): it comes out of the dark 9 m ahead, grabs you, and you have to mash the
-- defend key (X) before it eats you. Being eaten here only resets your character.
local attacking = false
function TestBots.attackMe(player: Player, parent: Instance): boolean
	local r = Characters.root(player)
	if attacking or not r then
		return false
	end
	attacking = true
	local entity = EntityModel.build()
	entity.Parent = parent
	local start = r.CFrame * CFrame.new(0, 0, -S(9))
	entity:PivotTo(CFrame.lookAt(start.Position, r.Position))
	task.spawn(function()
		banner("Something is coming...", 3)
		sound("sting", entity:GetPivot().Position)
		task.wait(1.5)
		walk(entity, r.Position, S(4.5))
		Grab.start({
			victim = player,
			entity = entity,
			hold = HOLD,
			remotes = remotes,
			onMaim = function(part)
				player:SetAttribute(part, true)
				if player.Character then
					Maim.apply(player.Character, part)
				end
			end,
			onEaten = function()
				local humanoid = Characters.humanoid(player)
				task.delay(2.5, function()
					if humanoid then
						humanoid.Health = 0 -- respawns (lobby / free roam)
					end
					entity:Destroy()
					attacking = false
				end)
			end,
			onFree = function()
				banner(`{player.DisplayName} threw the entity off!`, 4)
				task.spawn(function()
					task.wait(1.5)
					local away = entity:GetPivot() * CFrame.new(0, 0, -S(12))
					walk(entity, away.Position, S(3))
					entity:Destroy()
					attacking = false
				end)
			end,
		})
	end)
	return true
end

function TestBots.init(remoteFolder: Folder)
	remotes = remoteFolder
end

return TestBots
