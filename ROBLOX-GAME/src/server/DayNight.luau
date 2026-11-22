-- Time of day for the lighting: the lobby is a sunny school morning, the story follows its clock (the
-- CampaignMinutes attribute: sun by day, an orange dusk around 18:00, night after), Hide and Seek and Social
-- Deduction are always at night. The look moves smoothly between the night preset (the project file's Lighting)
-- and a day preset by how high the sun is.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Daylight = require(ReplicatedStorage.Shared.Daylight)

local DayNight = {}

local LOBBY_TIME = 10.5
local NIGHT_TIME = 0.5

-- (night, day) values; dusk colours sit in between.
local NIGHT = {
	Brightness = 0.3,
	Ambient = Color3.new(0.1, 0.1, 0.13),
	OutdoorAmbient = Color3.new(0.09, 0.09, 0.12),
	ExposureCompensation = 0.2,
	AtmosphereDensity = 0.32,
	AtmosphereColor = Color3.new(0.11, 0.12, 0.16),
	AtmosphereDecay = Color3.new(0.05, 0.05, 0.08),
	Haze = 1.2,
	Saturation = -0.18,
	Contrast = 0.16,
	Tint = Color3.new(0.92, 0.96, 1.0),
	Glare = 0,
	SunRays = 0,
	Specular = 0.7,
}
local DAY = {
	Brightness = 2.6,
	Ambient = Color3.new(0.32, 0.32, 0.34),
	OutdoorAmbient = Color3.new(0.55, 0.56, 0.6),
	ExposureCompensation = 0,
	AtmosphereDensity = 0.22,
	AtmosphereColor = Color3.new(0.78, 0.84, 0.92),
	AtmosphereDecay = Color3.new(0.62, 0.7, 0.82),
	Haze = 0.8,
	Saturation = 0.05,
	Contrast = 0.08,
	Tint = Color3.new(1.0, 0.98, 0.95),
	Glare = 0.3,
	SunRays = 0.07,
	Specular = 1,
}
local DUSK_TINT = Color3.new(1, 0.62, 0.38)

local daylight = Daylight.at

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function targetClock(): number
	local mode = ReplicatedStorage:GetAttribute("Mode")
	if mode == "campaign" then
		local minutes = ReplicatedStorage:GetAttribute("CampaignMinutes")
		if minutes then
			return (minutes / 60) % 24
		end
		return 6.5
	elseif mode == "hideseek" or mode == "deduction" then
		return NIGHT_TIME
	elseif mode == "freeroam" then
		local set = ReplicatedStorage:GetAttribute("FreeRoamClock")
		return if type(set) == "number" then set else LOBBY_TIME
	end
	return LOBBY_TIME
end

function DayNight.init()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local grade = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	local roomLightsOn: boolean? = nil
	if not Lighting:FindFirstChildOfClass("Sky") then
		local sky = Instance.new("Sky") -- Roblox's default sky, sun and moon
		sky.StarCount = 3000
		sky.Parent = Lighting
	end
	local clock = targetClock()
	RunService.Heartbeat:Connect(function(dt)
		-- Glide to the target time (fast jumps, like a new round, take a second or two).
		local goal = targetClock()
		local diff = (goal - clock + 12) % 24 - 12
		clock = (clock + math.clamp(diff, -dt * 6, dt * 6)) % 24
		Lighting.ClockTime = clock
		local t = daylight(clock)
		local dusk = if clock > 16 and clock < 20 then math.clamp(1 - math.abs(clock - 18) / 2, 0, 1) else 0
		Lighting.Brightness = lerp(NIGHT.Brightness, DAY.Brightness, t)
		Lighting.Ambient = NIGHT.Ambient:Lerp(DAY.Ambient, t)
		Lighting.OutdoorAmbient = NIGHT.OutdoorAmbient:Lerp(DAY.OutdoorAmbient, t):Lerp(DUSK_TINT, dusk * 0.35)
		Lighting.ExposureCompensation = lerp(NIGHT.ExposureCompensation, DAY.ExposureCompensation, t)
		if atmosphere then
			atmosphere.Density = lerp(NIGHT.AtmosphereDensity, DAY.AtmosphereDensity, t)
			atmosphere.Color = NIGHT.AtmosphereColor:Lerp(DAY.AtmosphereColor, t):Lerp(DUSK_TINT, dusk * 0.5)
			atmosphere.Decay = NIGHT.AtmosphereDecay:Lerp(DAY.AtmosphereDecay, t):Lerp(DUSK_TINT, dusk * 0.4)
			atmosphere.Haze = lerp(NIGHT.Haze, DAY.Haze, t)
			atmosphere.Glare = lerp(NIGHT.Glare, DAY.Glare, t)
		end
		if grade then
			grade.Saturation = lerp(NIGHT.Saturation, DAY.Saturation, t)
			grade.Contrast = lerp(NIGHT.Contrast, DAY.Contrast, t)
			grade.TintColor = NIGHT.Tint:Lerp(DAY.Tint, t)
		end
		if rays then
			rays.Intensity = lerp(NIGHT.SunRays, DAY.SunRays, t)
		end
		Lighting.EnvironmentSpecularScale = lerp(NIGHT.Specular, DAY.Specular, t)
		-- Classroom lights: on while the school is open (from dawn to dusk), off at night.
		local on = t > 0.2 and not ReplicatedStorage:GetAttribute("RoomLightsOff")
		if on ~= roomLightsOn then
			roomLightsOn = on
			for _, light in CollectionService:GetTagged("RoomLight") do
				(light :: SpotLight).Enabled = on
			end
			for _, tube in CollectionService:GetTagged("RoomTube") do
				(tube :: BasePart).Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
			end
		end
	end)
end

DayNight.daylight = daylight

return DayNight
