# OmrezKeyBind

**OmrezKeyBind** is a modular input handling library for Roblox that simplifies the process of binding gameplay actions to inputs from multiple device types—keyboard, gamepad, mobile and mouse.

It's inspired by Roblox's beta input action system.

Wally:

```
OmrezKeyBind = "omrezkeypie/omrezkeybind@0.1.3"
``` 

# Example Usage

A basic script showing how to setup and use OmrezKeyBind.

```lua
local OmrezKeyBind = require(script.OmrezKeyBind)
local CreateContexts = OmrezKeyBind.CreateContexts

local Player = game.Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local Button = PlayerGui:WaitForChild("MobileButtons")
    :WaitForChild("Frame")
    :WaitForChild("Button")

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
                Toggle = true,
                Priority = 99999,
            },
            Button = {
                Button = Button,
                Toggle = false,
                Priority = 2,
            },
            Touch = {
               Input = OmrezKeyBind.Touch.Tap,
               Toggle = true,
               Priority = 3,
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

For every action you can define if it supports a combo. This field is optional.

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

You pass a table to the action's Combo key which has 3 fields.

* Query - The query function which interprets the input queue to try to detect if a combo was successful. If omitted the system will use StrictOrdered.
* HoldInputs - Which inputs need to be held down for the combo to succeed. Can be omitted if no inputs need to be held down.
  
   Warning: If an input is in both the Input key of the action and HoldInputs it will conflict and cause unpredictable behavior.
  
* GracePeriod - In what time frame the inputs should be accepted. Any input older then the grace period will be ignored. Default value is 0.45 seconds.

**Query functions:**

To access built-in query functions you can find them in `OmrezKeyBind.Combos`

For the explanation assume the actions combo inputs are A + B.

OmrezKeyBind provides 4 default query functions. these being:
* StrictOrdered:
  Inputs must be in order and one after another exactly as declared in the Input key of the action.
  
  A + B -> Success
  
  B + A -> Fail
  
  A + [Any] + B -> Fail
  
  B + [Any] + A -> Fail
  
* StrictUnordered:
  Inputs must be one after another but order does not matter.
  
  A + B -> Success
  
  B + A -> Success
  
  A + [Any] + B -> Fail
  
  B + [Any] + A -> Fail
  
* LooseOrdered:
  Inputs must be in order as declared in the Input key of the action but other inputs can be in between them.
  
  A + B -> Success
  
  B + A -> Fail
  
  A + [Any] + B -> Success
  
  B + [Any] + A -> Fail
  
* LooseUnordered:
  Input order does not matter and there can be inputs in between them. as long as the inputs declared in the action are in the input queue the combo will succeed.
  
  A + B -> Success
  
  B + A -> Success
  
  A + [Any] + B -> Success
  
  B + [Any] + A -> Success

**Custom query functions**

For users who want more complex input queue interpreting you can pass your own custom functions instead of using the ones OmrezKeyBind provides.

```lua
Combo = {
	--In this example the combo will always succeed no matter the input.
	Query = function(ComboInputs,QueuedInput,ExpectedInput,ComboState)
		return OmrezKeyBind.ComboStatus.Succeed
	end,
}
```

The query function takes in 4 parameters:

* ComboInputs - A table which contains the combo's inputs.

* QueuedInput - The input in the input queue we wish to check.

* ExpectedInput - The input the combo expects in the current check.

* ComboState - A table which persists throughout the entire query process. Gets cleaned up when the combo querying finishes. Use this for any state that needs to stick around throughout the entire query process.

The combo query functions use a state machine to traverse the input queue and try to detect if a combo was successful. The query functions return 3 statuses to handle the logic.

* Succeed - Input was as expected. Continue to the next input in the input queue and to the next input in the combo's inputs.
  
* Fail - Input contradicts the query conditions. Stop traversing the input queue and return that the combo has failed.
  
* Ignore - Input doesn't matter for the logic. Ignore this input and move to the next queued input.

To access these statuses you can find them in `OmrezKeyBind.ComboStatus`.

For query function examples you can check out the ComboQueries module.
  
Note: Inputs in the input queue get trimmed after 2 seconds.

---

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
BindToActionActivated(ActionName : string,Callback : (GameProcessed : boolean,Data : CallbackData) -> ()) : () -> ()
```

Adds a callback function to the provided action. When the action's inputs are activated, all callbacks under that action get called. Callbacks receive `GameProcessed`. Returns a disconnect function that removes that specific callback.

```lua
BindToActionDeactivated(ActionName : string,Callback : (GameProcessed : boolean,Data : CallbackData) -> ()) : () -> ()
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

```lua
BindButtonToAction(ActionName : string,Button : TextButton | ImageButton)
```

Binds a UI button to an action.

```lua
UnbindActionButton(ActionName : string)
```

Unbinds the actions UI button if it has one bound to it.

```lua
ToggleAction(ActionName : string,Toggle : boolean)
```

Toggle an action. enabling or disabling it.

```lua
ActionJustPressed(ActionName : string) : boolean
```

Returns if the given action was activated that frame.

```lua
ActionJustReleased(ActionName : string) : boolean
```

Returns if the given action was deactivated that frame.
