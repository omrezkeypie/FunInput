--!strict
--//Services
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

--//Modules
local ComboQueries = require(script.ComboQueries)
local Types = require(script.Types)

--//Export type
export type ComboState = Types.ComboState

--//Constants
local INPUT_TRIM_PERIOD = 2
local DEFAULT_GRACE_PERIOD = 0.45
local JUST_PRESSED_GRACE_PERIOD = 0.02

local Contexts : {[string] : Types.Context} = {}
local Keybinds: Types.Keybinds = {}
local OriginalKeybinds : Types.Keybinds = {}
local ActionActivatedBinds : Types.ActionBinds = {}
local ActionDeactivatedBinds : Types.ActionBinds = {}
local InputQueue : {Types.QueuedInput} = {}
local HeldInputs : {[Types.InputTypes] : boolean?} = {}
local PersistentComboState : {[string] : Types.ComboState} = {}
local ActionActiveStates : {[string] : {[string] : boolean}} = {}
local ButtonConnections : {[string] : {RBXScriptConnection}} = {}
local JustMap : {Pressed : {[string] : boolean},Released : {[string] : boolean}} = {
	Pressed = {},
	Released = {},
}

local PCInputTypes = {
	Enum.UserInputType.Keyboard,
	Enum.UserInputType.MouseButton1,
	Enum.UserInputType.MouseWheel,
	Enum.UserInputType.MouseButton2,
	Enum.UserInputType.MouseMovement,
}

local ActivatedBindsID = 0
local DeactivatedBindsID = 0

--Enums
local TouchEnums = {
	Drag = "Drag",
	Tap = "Tap",
	Swipe = "Swipe",
	LongPress = "LongPress",
	Pinch = "Pinch",
	Rotate = "Rotate",
}

local Devices = {
	Button = "Button",
	Touch = "Touch",
	PC = "PC", 
	Gamepad = "Gamepad",
	Unknown = "Unknown",
}

local ComboStatus = ComboQueries.ComboStatus

local function AssertDefined<T>(Value: T?, Message: string?): T
	if Value == nil then
		error(Message or "Expected value to be defined, got nil", 2)
	end

	return Value
end

local function GetContextFromActionName(SearchActionName : string) : Types.Context?
	for _,Context in Contexts do
		if Context.Actions[SearchActionName] then
			return Context
		end
	end
	
	return
end

local function GetCurrentDevice() : string
	local InputType = UserInputService:GetLastInputType()

	if table.find(PCInputTypes,InputType) then
		return Devices.PC
	elseif InputType.Name:match("^Gamepad") then
		return Devices.Gamepad
	elseif InputType == Enum.UserInputType.Touch then
		return Devices.Touch
	end

	return Devices.Unknown
end

local function CallActivatedCallbacks(Context : Types.Context,ActionName : string,GameProcessed : boolean,Data : Types.CallbackData)
	local Device = GetCurrentDevice()
	local Toggle = Context.ToggledActionsStates[ActionName][Device]
	
	if not Data.Device then
		Data.Device = Device	
	end	
		
	if Toggle == nil then
		for _,Callback in ActionActivatedBinds[ActionName] do
			Callback(GameProcessed,Data)
		end
	else
		if Toggle then
			for _,Callback in ActionActivatedBinds[ActionName] do
				Callback(GameProcessed,Data)
			end
		else
			for _,Callback in ActionDeactivatedBinds[ActionName] do
				Callback(GameProcessed,Data)
			end
		end

		Context.ToggledActionsStates[ActionName][Device] = not Toggle
	end
	
	ActionActiveStates[ActionName][Device] = true
end

local function CallDeactivatedCallbacks(Context : Types.Context,ActionName : string,GameProcessed : boolean,Data : Types.CallbackData)
	local Device = GetCurrentDevice()
	local Toggle = Context.ToggledActionsStates[ActionName][Device]
		
	if Toggle == nil then
		if ActionActiveStates[ActionName] and ActionActiveStates[ActionName][Device] then
			for _, Callback in ActionDeactivatedBinds[ActionName] do
				Callback(GameProcessed, {Device = Device})
			end
			ActionActiveStates[ActionName][Device] = false
		end
	end
end

local function SetupButton(Button: TextButton | ImageButton, ActionName: string)
	if ButtonConnections[ActionName] then
		warn(ActionName.." already has a button bound to it!")
		
		return
	end
	
	local Began = Button.InputBegan:Connect(function(Input)
		if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then return end

		local Context = AssertDefined(GetContextFromActionName(ActionName))

		CallActivatedCallbacks(Context,ActionName,false,{Device = "Button"})
	end)
	
	local Ended = Button.InputEnded:Connect(function(Input)
		if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then return end
		
		local Context = AssertDefined(GetContextFromActionName(ActionName))
			
		CallDeactivatedCallbacks(Context,ActionName,false,{Device = "Button"})
	end)
	
	ButtonConnections[ActionName] = {Began,Ended}
end

local function SetupBinding(Binding : Types.Binding,Input : Types.InputTypes,ActionName : string) : boolean?
	if not Keybinds[Input] then
		Keybinds[Input] = {}
		OriginalKeybinds[Input] = {}
	end

	local NewKeybind = {
		ActionName = ActionName,
		Priority = Binding.Priority or 1,
	}

	table.insert(OriginalKeybinds[Input],NewKeybind)
	table.insert(Keybinds[Input],NewKeybind)
		
	return Binding.Toggle == true
end

local function SetupDeviceBinding(Binding : Types.Binding,ActionName : string,ToggleKeybinds : {[string] : {[string] : boolean}},DeviceName : string)
	local Inputs : {Types.InputTypes} = if typeof(Binding.Input) == "table" then Binding.Input else {Binding.Input}
	
	for _, Input in Inputs do
		SetupBinding(Binding, Input, ActionName)
	end
end

local function SetupActions(Actions : {[string] : Types.Action}) : Types.ToggledActions
	local ToggleKeybinds = {}
		
	for ActionName,ActionBindings in Actions do	
		ActionActivatedBinds[ActionName] = {}
		ActionDeactivatedBinds[ActionName] = {}
		ToggleKeybinds[ActionName] = {}
		ActionActiveStates[ActionName] = {}
		
		for DeviceName,Binding : Types.Binding in pairs(ActionBindings) do
			if DeviceName == "Button" then
				local ButtonBinding = ActionBindings.Button
				if not ButtonBinding then continue end		
				
				local Button = ButtonBinding.Button
				if not Button then continue end
				
				SetupButton(Button, ActionName)			
			else
				SetupDeviceBinding(Binding,ActionName,ToggleKeybinds,DeviceName)
			end
			
			ActionActiveStates[ActionName][DeviceName] = false			
			
			if Binding.Toggle then
				ToggleKeybinds[ActionName][DeviceName] = true
			end
		end
	end
		
	return ToggleKeybinds
end

local function GetHighestPriorityAction(Input : Enum.KeyCode | Enum.UserInputType | string) : string?
	local HighestPriority = -math.huge
	local HighestAction

	if not Keybinds[Input] then return end

	for _,Binding in Keybinds[Input] do
		if Binding.Priority <= HighestPriority then continue end

		local Context = GetContextFromActionName(Binding.ActionName)
		if Context and not Context.Enabled then continue end
		if Context and Context.ActionStates[Binding.ActionName] == false then continue end
		
		HighestPriority = Binding.Priority
		HighestAction = Binding.ActionName		
	end

	return HighestAction
end

local function GetContextData(ContextData : {[string] : Types.Action,Enabled : boolean?}) : (boolean,{[string] : Types.Action})	
	local Enabled = if ContextData.Enabled ~= nil then ContextData.Enabled else true
		
	local Actions = {}
	
	for ActionName,Action in ContextData do
		if ActionName == "Enabled" then continue end
		
		Actions[ActionName] = Action
	end
	
	return Enabled,Actions
end

local function TrimInputQueue()
	for i = #InputQueue,1,-1 do
		local QueuedInput = InputQueue[i]

		local PassedTime = (os.clock() - QueuedInput.StartTime)

		if PassedTime < INPUT_TRIM_PERIOD then break end

		InputQueue[i] = nil
	end
end

local function RegisterInput(InputType : Types.InputTypes)
	TrimInputQueue()
	
	local QueuedInput : Types.QueuedInput = {
		StartTime = os.clock(),
		Input = InputType,
		Consumed = false,
	}
	
	table.insert(InputQueue,1,QueuedInput)
end

local function CleanupComboState(ActionName : string)
	PersistentComboState[ActionName] = nil	
end

local function GetComboState(ActionName : string,GracePeriod : number) : Types.ComboState
	if not PersistentComboState[ActionName] then
		PersistentComboState[ActionName] = {
			MatchedInputs = {},
			LoopAmount = 0,
			ConsumedInputs = {},
		}
		
		task.delay(GracePeriod,function()
			CleanupComboState(ActionName)
		end)
	end
	
	return PersistentComboState[ActionName]
end

local function CheckCombo(Context : Types.Context,ActionName : string,InputType : Types.InputTypes) : boolean
	local DeviceName = GetCurrentDevice()
	local Binding : Types.Binding = Context.Actions[ActionName][DeviceName]
		
	if not Binding then return false end
	if not Binding.Combo then return true end
	
	local ExpectedInputs = Binding.Input	
	assert(typeof(ExpectedInputs) == "table")
	
	local ExpectedInputsIndex = #ExpectedInputs
	local GracePeriod = Binding.Combo.GracePeriod or DEFAULT_GRACE_PERIOD
	
	if Binding.Combo.HoldInputs then
		for _,ExpectedHeldInput in Binding.Combo.HoldInputs do
			if HeldInputs[ExpectedHeldInput] then continue end

			return false
		end
	end	
	
	if #InputQueue < #ExpectedInputs then
		return false
	end	
	
	for i = 1,#InputQueue do
		local QueuedInput = InputQueue[i]
		local TimePassed = os.clock() - QueuedInput.StartTime
				
		if TimePassed > GracePeriod then break end	
		if QueuedInput.Consumed then break end
		
		local Input = QueuedInput.Input
		local ExpectedInput = ExpectedInputs[ExpectedInputsIndex]
				
		local ComboState = GetComboState(ActionName,GracePeriod)
		
		--I tried to use ternarny but the type checking didn't like it for some reason
		local Status
		
		if Binding.Combo then
			Status = Binding.Combo.Query(ExpectedInputs,Input,ExpectedInput,ComboState)
		else
			Status = ComboQueries.StrictOrdered(ExpectedInputs,Input,ExpectedInput,ComboState)
		end
				
		if Status == ComboStatus.Fail then
			break
		elseif Status == ComboStatus.Succeed then
			ExpectedInputsIndex -= 1
			
			table.insert(ComboState.ConsumedInputs,QueuedInput)
			
			if ExpectedInputsIndex == 0 then				
				for _,Input in ComboState.ConsumedInputs do
					Input.Consumed = true
				end
				
				CleanupComboState(ActionName)
				
				return true
			end
		else
			--Ignore status			
			continue
		end
	end
	
	CleanupComboState(ActionName)
	
	return false
end

local function QueueAction(InputType : Types.InputTypes,GameProcessed : boolean,CallbackType : "Activate" | "Deactivate",CallbackData : Types.CallbackData)	
	if CallbackType == "Activate" then
		RegisterInput(InputType)
		
		HeldInputs[InputType] = true
	else
		HeldInputs[InputType] = false
	end
		
	local ActionName = GetHighestPriorityAction(InputType)
	if not ActionName then return end
		
	local Context = AssertDefined(GetContextFromActionName(ActionName))

	if not Context then return end
	if not Context.Enabled then return end
		
	if CallbackType == "Activate" then
		local ComboSuccess = CheckCombo(Context,ActionName,InputType)
		
		if not ComboSuccess then return end
	end
		
	if CallbackType == "Activate" then
		JustMap.Pressed[ActionName] = true
		CallActivatedCallbacks(Context,ActionName,GameProcessed,CallbackData)
	else
		JustMap.Released[ActionName] = true
		CallDeactivatedCallbacks(Context,ActionName,GameProcessed,CallbackData)
	end
end

--Public functions

local function CreateContexts(SetupContexts : {[string] : {[string] : Types.Action,Enabled : boolean?}}) : true
	for ContextName,ContextData in SetupContexts do
		local Enabled,Actions = GetContextData(ContextData)
		
		local ActionStates = SetupActions(Actions)
				
		Contexts[ContextName] = {
			Enabled = Enabled,
			Actions = Actions,
			ToggledActionsStates = ActionStates,
			ActionStates = {},
		}
	end

	return true
end

local function ToggleContext(ContextName : string,State : boolean)
	local Context = Contexts[ContextName]
	if not Context then return end

	Context.Enabled = State
end

local function BindToActionActivated(ActionName : string,Callback : Types.Callback) : () -> ()
	if not ActionActivatedBinds[ActionName] then
		error(ActionName.." Doesn't exist!")
	end

	ActivatedBindsID += 1

	ActionActivatedBinds[ActionName][ActivatedBindsID] = Callback

	return function()
		ActionActivatedBinds[ActionName][ActivatedBindsID] = nil
	end
end

local function BindToActionDeactivated(ActionName : string,Callback : Types.Callback) : () -> ()
	if not ActionDeactivatedBinds[ActionName] then
		error(ActionName.." Doesn't exist!")
	end
	
	DeactivatedBindsID += 1

	ActionDeactivatedBinds[ActionName][DeactivatedBindsID] = Callback

	return function()
		ActionDeactivatedBinds[ActionName][DeactivatedBindsID] = nil
	end
end

local function GetActionKeybind(ActionName : string) : Types.InputTypes?
	for Binding,Keybind in Keybinds do
		for _,ActionData in Keybind do
			if ActionData.ActionName ~= ActionName then continue end

			return Binding
		end
	end

	return
end

local function SetActionKeybind(ActionName : string,NewBinding : Types.InputTypes)
	local CurrentBinding = AssertDefined(GetActionKeybind(ActionName))
	if not CurrentBinding then return end

	local RemoveIndex

	for Index,Keybind in Keybinds[CurrentBinding] do
		if Keybind.ActionName == ActionName then
			RemoveIndex = Index

			break
		end
	end

	local Binding = Keybinds[CurrentBinding][RemoveIndex]

	table.remove(Keybinds[CurrentBinding],RemoveIndex)

	if not Keybinds[NewBinding] then
		Keybinds[NewBinding] = {}
	end

	table.insert(Keybinds[NewBinding],Binding)
end

local function ResetActionKeybinds()
	Keybinds = table.clone(OriginalKeybinds)
end

local function GetCustomKeybinds() : {[string] : Types.InputTypes}
	local CustomKeybinds = {}

	for KeyCode,Bindings in Keybinds do
		for _,Binding in Bindings do
			CustomKeybinds[Binding.ActionName] = KeyCode
		end
	end

	return CustomKeybinds
end

local function LoadCustomKeybinds(CustomKeybinds : {[string] : Types.InputTypes})
	for ActionName,KeyCode in CustomKeybinds do
		SetActionKeybind(ActionName,KeyCode)
	end
end

local function BindButtonToAction(ActionName : string,Button : TextButton | ImageButton)
	local Context = GetContextFromActionName(ActionName)
	if not Context then warn(ActionName.." doesn't exist!") return end
	
	SetupButton(Button,ActionName)
end

local function UnbindActionButton(ActionName : string)
	if not ButtonConnections[ActionName] then
		warn(ActionName.." doesn't have a UI button connected to it!")
		
		return
	end
	
	for _,Connection in ButtonConnections[ActionName] do
		Connection:Disconnect()
	end
	
	ButtonConnections[ActionName] = nil
end

local function ToggleAction(ActionName : string,Toggle : boolean)
	local Context = GetContextFromActionName(ActionName)
	if not Context then warn(ActionName.." doesn't exist!") return end
	
	Context.ActionStates[ActionName] = Toggle
end

local function ActionJustPressed(ActionName : string) : boolean
	return JustMap.Pressed[ActionName] == true
end

local function ActionJustReleased(ActionName : string) : boolean
	return JustMap.Released[ActionName] == true
end

UserInputService.InputBegan:Connect(function(Input,GameProcessed)
	local InputType = Input.KeyCode ~= Enum.KeyCode.Unknown and Input.KeyCode or Input.UserInputType
		
	QueueAction(InputType,GameProcessed,"Activate",{InputType = InputType})
end)

UserInputService.InputEnded:Connect(function(Input,GameProcessed)
	local InputType = Input.KeyCode ~= Enum.KeyCode.Unknown and Input.KeyCode or Input.UserInputType

	QueueAction(InputType,GameProcessed,"Deactivate",{InputType = InputType})
end)

UserInputService.TouchTap:Connect(function(TouchPositions,GameProcessed)
	QueueAction(TouchEnums.Tap,GameProcessed,"Activate",{TouchPositions = TouchPositions})
end)   

UserInputService.TouchPan:Connect(function(TouchPositions,TotalTranslation,Velocity,GameProcessed)
	QueueAction(TouchEnums.Drag,GameProcessed,"Activate",{
		TouchPositions = TouchPositions,
		TotalTranslation = TotalTranslation,
		Velocity = Velocity
	})
end)

UserInputService.TouchLongPress:Connect(function(TouchPositions,State,GameProcessed)
	QueueAction(TouchEnums.LongPress,GameProcessed,"Activate",{
		TouchPositions = TouchPositions,
		State = State
	})
end)

UserInputService.TouchSwipe:Connect(function(SwipeDirection,NumberOfTouches,GameProcessed)
	QueueAction(TouchEnums.Swipe,GameProcessed,"Activate",{
		SwipeDirection = SwipeDirection,
		NumberOfTouches = NumberOfTouches
	})
end)

UserInputService.TouchPinch:Connect(function(TouchPositions,Scale,Velocity,State,GameProcessed)
	QueueAction(TouchEnums.Pinch,GameProcessed,"Activate",{
		TouchPositions = TouchPositions,
		Scale = Scale,
		NumberVelocity = Velocity,
		State = State,
	})
end)

UserInputService.TouchRotate:Connect(function(TouchPositions,Rotation : number,Velocity,State,GameProcessed)
	QueueAction(TouchEnums.Rotate,GameProcessed,"Activate",{
		TouchPositions = TouchPositions,
		Rotation = Rotation,
		NumberVelocity = Velocity,
		State = State,
	})
end)

RunService.Heartbeat:Connect(function()
	for ActionName,_ in JustMap.Pressed do
		JustMap.Pressed[ActionName] = false
	end
	
	for ActionName,_ in JustMap.Released do
		JustMap.Released[ActionName] = false
	end
end)

return {
	CreateContexts = CreateContexts,
	ToggleContext = ToggleContext,
	BindToActionActivated = BindToActionActivated,
	BindToActionDeactivated = BindToActionDeactivated,
	SetActionKeybind = SetActionKeybind,
	ResetActionKeybinds = ResetActionKeybinds,
	GetCustomKeybinds = GetCustomKeybinds,
	LoadCustomKeybinds = LoadCustomKeybinds,
	GetActionKeybind = GetActionKeybind,
	BindActionToButton = BindButtonToAction,
	UnbindActionButton = UnbindActionButton,
	ToggleAction = ToggleAction,
	ActionJustPressed = ActionJustPressed,
	ActionJustReleased = ActionJustReleased,
	
	Touch = TouchEnums,
	Devices = Devices,
	Combos = ComboQueries,
	ComboStatus = ComboStatus,
}
