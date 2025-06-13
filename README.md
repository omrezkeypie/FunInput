# FunInput
FunInput is a module for roblox that handles different inputs from different devices and allows you easily setup different actions for different keybinds while easily making said actions be handled for different devices.
This module was inspired by roblox's new input action system. I disliked how it was completely instance dependent so i decided to make my own.

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
