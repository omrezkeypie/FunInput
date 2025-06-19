export type Binding = {
	Input : InputTypes | {InputTypes},
	Toggle : boolean?,
	Combo : {
		GracePeriod : number,
		HoldInputs : {InputTypes},
		Query : (ComboInputs : {InputTypes},QueuedInput : InputTypes,ExpectedInput : InputTypes,ComboState : ComboState) -> string
	}?,
	Priority : number?,
}

export type ComboState = {
	MatchedInputs : {[number] : boolean},
	LoopAmount : number,
	ConsumedInputs : {QueuedInput},
}

export type Button = TextButton | ImageButton

export type ButtonBinding = {
	Button : Button?,
	Toggle : boolean,
	Priority : number,
}

export type Action = {
	PC : Binding?,
	Gamepad : Binding?,
	Touch : Binding?,
	Button : ButtonBinding?,
}

export type ToggledActions = {
	[string] : {
		Button : boolean?,
		PC : boolean?,
		Gamepad : boolean?,
	}
}

export type Context = {
	Enabled : boolean,
	Actions : {[string] : Action},
	ActionStates : {[string] : boolean?},
	ToggledActionsStates : ToggledActions,
}

export type ContextSetup = {
	Enabled: boolean?,
	[string]: Action | boolean?,
}

export type CallbackData = {
	InputType : InputTypes?,
	Device : string?,
	TouchPositions : {Vector2}?,
	TotalTranslation : Vector2?,
	Velocity : Vector2?,
	NumberVelocity : number?,
	State : Enum.UserInputType?,
	SwipeDirection : Vector2?,
	NumberOfTouches : number?,
	Scale : number?,
	Rotation : number?,
}

export type Callback = (GameProcessed : boolean,Data : CallbackData) -> ()

export type ActionBinds = {
	[string] : {Callback}
} 

export type InputTypes = Enum.UserInputType | Enum.KeyCode | string

export type Keybinds = {
	[InputTypes] : {
		{
			Priority : number,
			ActionName : string,
		}
	}
}

export type QueuedInput = {
	StartTime : number,
	Input : InputTypes,
	Consumed : boolean,
}

return true
