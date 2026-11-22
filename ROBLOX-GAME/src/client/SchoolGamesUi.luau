-- Your side of the school's games (src/server/SchoolGames.luau): the ping pong ball drawn from the server's flight
-- (smooth on every screen), the score above the table, and left click (or F) to hit the ball or throw the basketball.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local MouseLock = require(script.Parent.MouseLock)

local player = Players.LocalPlayer
local SchoolGamesUi = {}

local function swingOrThrow(hitRemote: RemoteEvent, throwRemote: RemoteEvent)
	if MouseLock.isFree() then
		return -- a panel is open: the click is for it
	end
	if player:GetAttribute("HoldingBall") then
		throwRemote:FireServer(workspace.CurrentCamera.CFrame.LookVector)
	elseif player:GetAttribute("PingPong") then
		hitRemote:FireServer()
	end
end

function SchoolGamesUi.init(remotes: Folder)
	local hitRemote = remotes:WaitForChild("PingPongHit") :: RemoteEvent
	local throwRemote = remotes:WaitForChild("BallThrow") :: RemoteEvent
	local stateRemote = remotes:WaitForChild("PingPongState") :: RemoteEvent

	-- The ball and the score board (local only).
	local ball = Instance.new("Part")
	ball.Name = "PingPongBall"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(0.15, 0.15, 0.15)
	ball.Color = Color3.fromRGB(255, 240, 220)
	ball.Material = Enum.Material.SmoothPlastic
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.Transparency = 1
	ball.Parent = workspace
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(220, 46)
	board.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
	board.AlwaysOnTop = false
	board.MaxDistance = 60
	board.Enabled = false
	local scoreText = Instance.new("TextLabel")
	scoreText.Size = UDim2.fromScale(1, 1)
	scoreText.BackgroundColor3 = Color3.fromRGB(14, 12, 16)
	scoreText.BackgroundTransparency = 0.3
	scoreText.TextColor3 = Color3.fromRGB(255, 226, 170)
	scoreText.TextScaled = true
	scoreText.Font = Enum.Font.GothamBold
	scoreText.Parent = board
	local state: any = nil
	stateRemote.OnClientEvent:Connect(function(s)
		state = s
		local tableModel = workspace:FindFirstChild("PingPongTable", true)
		local top = tableModel and tableModel:FindFirstChild("TableTop") :: BasePart?
		if top then
			board.Adornee = top
			board.Parent = top
		end
		local anyone = s.names.W ~= "Computer" or s.names.E ~= "Computer"
		board.Enabled = anyone
		scoreText.Text = `{s.names.W} {s.score.W} : {s.score.E} {s.names.E}`
	end)
	RunService.RenderStepped:Connect(function()
		if not state or not state.active then
			ball.Transparency = 1
			return
		end
		local t = (workspace:GetServerTimeNow() - state.t0) / state.dur
		if t < 0 or t > 1.25 then
			ball.Transparency = 1
			return
		end
		-- Over the net in an arc, a bounce on the far half, then up towards the other end.
		local a, b = state.a :: Vector3, state.b :: Vector3
		local pos = a:Lerp(b, math.min(t, 1.25))
		local top = state.top + 0.25
		local height
		if t < 0.7 then
			local u = t / 0.7
			height = (a.Y - top) * (1 - u) + 4 * 1.2 * u * (1 - u)
		else
			local u = (t - 0.7) / 0.3
			height = 3 * 0.9 * u * (1 - u * 0.5) - (if t > 1 then (t - 1) * 3 else 0)
		end
		ball.Position = Vector3.new(pos.X, top + height, pos.Z)
		ball.Transparency = 0
	end)

	-- Left click or F: hit or throw (only while one of the games is yours).
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		swingOrThrow(hitRemote, throwRemote)
	end)
	local function bindF()
		local playing = player:GetAttribute("HoldingBall") or player:GetAttribute("PingPong")
		if playing then
			ContextActionService:BindAction("SchoolGame", function(_, s)
				if s == Enum.UserInputState.Begin then
					swingOrThrow(hitRemote, throwRemote)
				end
				return Enum.ContextActionResult.Sink
			end, true, Enum.KeyCode.ButtonR2)
			ContextActionService:SetTitle("SchoolGame", if player:GetAttribute("HoldingBall") then "Throw" else "Hit")
		else
			ContextActionService:UnbindAction("SchoolGame")
		end
	end
	player:GetAttributeChangedSignal("HoldingBall"):Connect(bindF)
	player:GetAttributeChangedSignal("PingPong"):Connect(bindF)
end

return SchoolGamesUi
