# FunInput
FunInput is a module for roblox that allows to easily setup actions that correspond to different keybinds from seperate devices for user input handling. 

Action priority allows for fine grained control of action behavior with same the same keybinds.

Toggle setting for actions per device type. for example a run button on mobile that when pressed initially starts a run state and when pressed again stops the run state meanwhile on PC you hold shift to stay on the run state and when releasing the shift button stop the run state.

Disabling and enabling context to easily control which actions should be active at what time.

This module was inspired by roblox's new input action system.

# Example usage

A simple script showing the basic setup and usage of the module.

```luau
local FunInput = require(script.FunInput)
local CreateContexts = FunInput.CreateContexts

local Player = game.Players.LocalPlayer
local PlayerGui = Player.PlayerGui

local Button = PlayerGui:WaitForChild("MobileButtons"):WaitForChild("Frame"):WaitForChild("PlaceTower")

CreateContexts {
	Gameplay = {
		PlaceTower = {
			PC = {
				Input = Enum.KeyCode.X,
				Toggle = false,
				Priority = 5,
			},
			Gamepad = {
				Input = Enum.KeyCode.DPadDown,
				Toggle = false,
				Priority = 99999,
			},
			Mobile = {
				Button = Button,
				Toggle = false,
				Priority = 2,
			}
		},
	}
} 

local Disconnect = FunInput.BindToActionActivated("PlaceTower",function()
	print("Place tower action activated!")
end)

local Disconnect = FunInput.BindToActionDeactivated("PlaceTower",function()
	print("Place tower action deactivated!!")
end)
```

Anytime one of the keybinds of the action is used (PC, Gamepad or Mobile) any binded functions to that action will be called.
If there's multiple actions with the same keybind the action with the higher priority will be called.
