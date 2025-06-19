# OmrezKeyBind

**OmrezKeyBind** is a modular input handling system for Roblox that simplifies the process of binding gameplay actions to inputs from multiple device types—keyboard, gamepad, mobile and mouse.

It's inspired by Roblox's beta input action system.

Wally:

```
OmrezKeyBind = "omrezkeypie/omrezkeybind@0.1.3"
``` 

# Features

### **Action priority**, allowing fine-grained control over which input gets handled when multiple actions share the same keybind.

```lua
CreateContexts {
	Gameplay = {
		Jump = {
			PC = {
				Input = Enum.KeyCode.Space,
				Toggle = false,
				Priority = 1,
			},
		},
	},
	Interaction = {
		Interact = {
			PC = {
				Input = Enum.KeyCode.Space,
				Toggle = false,
				Priority = 2,
			}
		}
	}
} 
```
In this case, when the spacebar is pressed, the `Interact` action activates instead of `Jump` because it has a higher priority (2 vs 1). The system always activates the action with the highest priority for a given input.

If the `Priority` key is omitted for an action on a device, it defaults to 1.

### **Toggle property per device type**, enabling toggle behavior for actions depending on the device.
```lua
CreateContexts {
	Gameplay = {
		Run = {
			PC = {
				Input = Enum.KeyCode.LeftShift,
				Toggle = false,
				Priority = 1,
			},
			Gamepad = {
				Input = Enum.KeyCode.ButtonL3,
				Toggle = true,
				Priority = 1,
			},
		},
	},
} 
```

In this example, the `Run` action behaves differently depending on the device:

- PC - the player must hold the Shift key to stay in the run state. Releasing the key deactivates the action.

- Gamepad - pressing the left joystick toggles the run state: the first press activates it, the second deactivates it, and so on. Releasing the joystick has no effect.

### **Context-based action grouping**

Actions are grouped under contexts. You can disable and enable contexts whenever allowing you to control when actions are enabled or disabled depending on the current game state.

```lua
CreateContexts {
	Gameplay = {
		Run = {
			PC = {
				Input = Enum.KeyCode.LeftShift,
				Toggle = false,
				Priority = 1,
			},
		},
	},
	Menu = {
		CloseMenu = {
			PC = {
				Input = Enum.KeyCode.Escape,
				Toggle = false,
				Priority = 1,
			},
		},
	},
} 

--When in menu
OmrezKeyBind.ToggleContext("Gameplay",false)
OmrezKeyBind.ToggleContext("Menu",true)
```

### **Combo support with customizable query logic**

For every action you can define if it's a Combo.

```lua
CreateContexts {
	Gameplay = {
		EpicCombo = {
			PC = {
				Input = {Enum.KeyCode.E,Enum.KeyCode.Q},
				Toggle = false,
				Priority = 1,
				
				Combo = {
					Query = OmrezKeyBind.Combos.StrictOrdered,
					HoldInputs = {},
					GracePeriod = 0.45,
				}
			},
		},
	},
} 
```

You pass a table to the action's Combo key which has 3 keys.

* Query - The query function which interprets the input queue to try to detect if a combo was successful. OmrezKeyBind provides 4 default query functions but users can make their own custom ones. Default one is StrictOrdered.
* HoldInputs - Which inputs need to be held down for the combo to succeed. Can be omitted if no inputs need to be held down.
  
   Warning: If an input is in both the Input key of the action and HoldInputs it will conflict and cause unpredictable behavior.
  
* GracePeriod - In what time frame the inputs should be accepted. Any input older then the grace period will be ignored. Default value is 0.45 seconds.

**Query functions:**

For the explanation assume the actions combo inputs are A + B.

OmrezKeyBind provides 4 default query functions. these being:
* StrictOrdered:
  Inputs must be in order and one after another exactly as shown in the Input key of the action.
  
  A + B -> Success
  
  B + A -> Fail
  
  A + [Any] + B -> Fail
  
  B + [Any] + A -> Fail
  
* StrictUnordered
* 
  Inputs must be one after another but order does not matter.
  
  A + B -> Success
  
  B + A -> Success
  
  A + [Any] + B -> Fail
  
  B + [Any] + A -> Fail
  
* LooseOrdered
* 
  Inputs must be in order as shown in the Input key of the action but other inputs can be in between them.
  
  A + B -> Success
  
  B + A -> Fail
  
  A + [Any] + B -> Success
  
  B + [Any] + A -> Fail
  
* LooseUnordered
* 
  Input order does not matter and there can be inputs in between them. as long as the inputs declared in the action are in the input queue the combo will succeed.
  
  A + B -> Success
  
  B + A -> Success
  
  A + [Any] + B -> Success
  
  B + [Any] + A -> Success

Most of these are pretty useless but i made them just to test out the combo query system and logic.

Note: Inputs in the input queue get trimmed after 2 seconds.

---

# Example Usage

A basic script showing how to setup and use OmrezKeyBind.

```lua
local OmrezKeyBind = require(script.OmrezKeyBind)
local CreateContexts = OmrezKeyBind.CreateContexts

local Player = game.Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local Button = PlayerGui:WaitForChild("MobileButtons")
    :WaitForChild("Frame")
    :WaitForChild("PlaceTower")

CreateContexts {
    Gameplay = {
        DoSomethingCool = {
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

local DisconnectActivate = OmrezKeyBind.BindToActionActivated("DoSomethingCool", function()
    print("Did something cool!")
end)

local DisconnectDeactivate = OmrezKeyBind.BindToActionDeactivated("DoSomethingCool", function()
    print("Stopped doing something cool!")
end)
```

# API

```lua
CreateContexts(SetupContexts : {[string] : {[string] : Action}}) : true
```

Look at example code for usage.

Gets passed a table where each key corresponds to the ContextName and the value is another table where all the contexts actions are defined.

```lua
ToggleContext(ContextName : string,State : boolean)
```

Toggles a context on and off, enabling or disabling all the actions declared on it.

```lua
BindToActionActivated(ActionName : string,Callback : (GameProcessed : boolean) -> ()) : () -> ()
```

Adds a callback function to the provided action. When the action's inputs are activated, all callbacks under that action get called. Callbacks receive `GameProcessed`. Returns a disconnect function that removes that specific callback.

```lua
BindToActionDeactivated(ActionName : string,Callback : (GameProcessed : boolean) -> ()) : () -> ()
```

Adds a callback function to the provided action. When the action's inputs are deactivated, all callbacks under that action get called. Callbacks receive `GameProcessed`. Returns a disconnect function that removes that specific callback.

```lua
SetActionKeybind(ActionName : string,NewBinding : Enum.KeyCode | Enum.UserInputType)
```

Sets a specific actions input keybind.

```lua
ResetActionKeybinds()
```

Resets all actions keybinds to default. to what is defined in the CreateContexts function call.

```lua
GetCustomKeybinds() : {[string] : Enum.KeyCode | Enum.UserInputType}
```

Returns a table where the key is the action name and the value is the keybind it corresponds to.

```lua
LoadCustomKeybinds(CustomKeybinds : {[string] : Enum.KeyCode | Enum.UserInputType})
```

Gets passed a table in the format that GetCustomKeybinds returns and sets all actions keybind to what is specified in the table.

```lua
GetActionKeybind(ActionName : string) : Enum.KeyCode? | Enum.UserInputType?
```

Returns what keybind a specific action has.
