# FunInput

**FunInput** is a modular input handling system for Roblox that simplifies the process of binding gameplay actions to inputs from multiple device types—keyboard, gamepad,mobile and mouse.

Features in the module:
- **Action priority**, allowing fine-grained control over which input gets handled when multiple actions share the same key.
- **Toggle settings per device type**, enabling different behavior for inputs depending on the device. For example, a "Run" action can be toggleable on mobile (tap to start/stop running) and hold-based on PC (hold Shift to run).
- **Context-based activation**, so you can enable or disable entire sets of actions depending on the current game state (e.g., menu vs gameplay).
  
FunInput was inspired by Roblox's new user action system.

---

## Example Usage

A basic script showing how to set up actions for multiple input types:

```lua
local FunInput = require(script.FunInput)
local CreateContexts = FunInput.CreateContexts

local Player = game.Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local Button = PlayerGui:WaitForChild("MobileButtons")
    :WaitForChild("Frame")
    :WaitForChild("PlaceTower")

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

-- Bind to action callbacks
local disconnectActivate = FunInput.BindToActionActivated("PlaceTower", function()
    print("Place tower action activated!")
end)

local disconnectDeactivate = FunInput.BindToActionDeactivated("PlaceTower", function()
    print("Place tower action deactivated!")
end)
```
