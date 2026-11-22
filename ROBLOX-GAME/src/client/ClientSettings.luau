-- The player's current menu settings, shared by the menu (which edits them) and the camera (which reads the base
-- field of view). Mouse sensitivity and volume are applied here; the field of view is applied by CameraController.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local Keybinds = require(ReplicatedStorage.Shared.Keybinds)
local Settings = require(ReplicatedStorage.Shared.Settings)
Settings.useKeybinds(Keybinds)

local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")

local ClientSettings = {
	values = Settings.clean(nil),
}

local changedEvent = Instance.new("BindableEvent")
ClientSettings.changed = changedEvent.Event

function ClientSettings.group(): SoundGroup
	local group = SoundService:FindFirstChild("GameSounds")
	if not group then
		group = Instance.new("SoundGroup")
		group.Name = "GameSounds"
		group.Parent = SoundService
	end
	return group :: SoundGroup
end

function ClientSettings.set(raw: any)
	ClientSettings.values = Settings.clean(raw)
	UserInputService.MouseDeltaSensitivity = ClientSettings.values.sensitivity
	ClientSettings.group().Volume = ClientSettings.values.volume
	-- Graphics (local only; the server never changes these): shadows and the screen effects.
	local g = ClientSettings.values.graphics
	Lighting.GlobalShadows = g ~= "low"
	for _, name in { "Bloom", "SunRays", "Depth" } do
		local effect = Lighting:FindFirstChild(name) :: PostEffect?
		if effect then
			effect.Enabled = g == "high" or (g == "medium" and name == "Bloom")
		end
	end
	changedEvent:Fire()
end

-- The key chosen for an action (src/shared/Keybinds.luau).
function ClientSettings.key(id: string): Enum.KeyCode
	local name = ClientSettings.values.keys[id] or Keybinds.default(id)
	return (Enum.KeyCode :: any)[name]
end

-- ContextActionService:BindAction with the action's chosen key (plus fixed extras such as gamepad buttons), bound
-- again whenever the key changes in the settings. `when` (optional) decides whether the binding should exist now;
-- call the returned function to re-check it.
function ClientSettings.bind(name: string, id: string, handler: (string, Enum.UserInputState, InputObject) -> any,
	touchButton: boolean, extras: { Enum.KeyCode }?, when: (() -> boolean)?): () -> ()
	local bound = false
	local function apply()
		local want = when == nil or when()
		if bound then
			ContextActionService:UnbindAction(name)
			bound = false
		end
		if want then
			ContextActionService:BindAction(name, handler, touchButton, ClientSettings.key(id),
				table.unpack(extras or {}))
			bound = true
		end
	end
	apply()
	changedEvent.Event:Connect(apply)
	return apply
end

return ClientSettings
