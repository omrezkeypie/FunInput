--!strict
local UserInputService = game:GetService("UserInputService")

type Binding = {
	Input : Enum.KeyCode | Enum.UserInputType,
	Toggle : boolean,
	Priority : number?,
}

type MobileBinding = {
	Button : TextButton | ImageButton,
	Toggle : boolean,
	Priority : number,
}

type Action = {
	PC : Binding?,
	Gamepad : Binding?,
	Mobile : MobileBinding?,
}

type ToggledActions = {
	[string] : {
		Mobile : boolean?,
		PC : boolean?,
		Gamepad : boolean?,
	}
}

type Context = {
	Enabled : boolean,
	Actions : {[string] : Action},
	ToggledActionsStates : ToggledActions,
}

type ContextSetup = {
	Enabled: boolean?,
	[string]: Action | boolean?,
}

type ActionBinds = {
	[string] : {(GameProcessed : boolean) -> ()}
} 

type Keybinds = {
	[Enum.UserInputType | Enum.KeyCode] : {
		{
			Priority : number,
			ActionName : string,
		}
	}
}

local Contexts : {[string] : Context} = {}
local Keybinds: Keybinds = {}
local OriginalKeybinds : Keybinds = {}
local ActionActivatedBinds : ActionBinds = {}
local ActionDeactivatedBinds : ActionBinds = {}
local ActivatedBindsID = 0
local DeactivatedBindsID = 0

local function AssertDefined<T>(Value: T?, Message: string?): T
	if Value == nil then
		error(Message or "Expected value to be defined, got nil", 2)
	end
	
	return Value
end

local function GetContextFromActionName(SearchActionName : string) : Context?
	for _,Context in Contexts do
		if Context.Actions[SearchActionName] then
			return Context
		end
	end
	
	return
end

local function GetCurrentDevice(): string
	local inputType = UserInputService:GetLastInputType()
		
	if inputType == Enum.UserInputType.Keyboard or inputType == Enum.UserInputType.MouseMovement then
		return "PC"
	elseif inputType.Name:match("^Gamepad") then
		return "Gamepad"
	elseif inputType == Enum.UserInputType.Touch then
		return "Mobile"
	end

	return "Unknown"
end

local function CallActivatedCallbacks(Context : Context,ActionName : string,GameProcessed : boolean)
	local Device = GetCurrentDevice()
	local Toggle = Context.ToggledActionsStates[ActionName][Device]
	
	if Toggle == nil then
		for _,Callback in ActionActivatedBinds[ActionName] do
			Callback(GameProcessed)
		end
	else
		--false for activated, true for deactivated.
		if Toggle == false then
			for _,Callback in ActionActivatedBinds[ActionName] do
				Callback(GameProcessed)
			end
		else
			for _,Callback in ActionDeactivatedBinds[ActionName] do
				Callback(GameProcessed)
			end
		end

		Context.ToggledActionsStates[ActionName][Device] = not Toggle
	end
end

local function CallDeactivatedCallbacks(Context : Context,ActionName : string,GameProcessed : boolean)
	local Device = GetCurrentDevice()
	local Toggle = Context.ToggledActionsStates[ActionName][Device]
		
	if Toggle == nil then
		for _,Callback in ActionDeactivatedBinds[ActionName] do
			Callback(GameProcessed)
		end
	end
end

local function SetupMobileButton(Button: TextButton | ImageButton, ActionName: string)
	Button.InputBegan:Connect(function(Input)
		if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then return end
		
		local Context = AssertDefined(GetContextFromActionName(ActionName))
		
		CallActivatedCallbacks(Context,ActionName,false)
		
		Button.InputEnded:Once(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				CallDeactivatedCallbacks(Context,ActionName,false)
			end
		end)
	end)
end

local function SetupActions(Actions : {[string] : Action}) : ToggledActions
	local ToggleKeybinds = {}
	
	for ActionName,ActionKeybinds in Actions do	
		ActionActivatedBinds[ActionName] = {}
		ActionDeactivatedBinds[ActionName] = {}
		ToggleKeybinds[ActionName] = {}		
		
		for DeviceName,Binding : Binding in pairs(ActionKeybinds) do
			if not Keybinds[Binding.Input] and DeviceName ~= "Mobile" then
				Keybinds[Binding.Input] = {}
				OriginalKeybinds[Binding.Input] = {}
			end
			
			if DeviceName == "Mobile" then
				if not ActionKeybinds.Mobile then continue end
 
				local MobileBind = AssertDefined(ActionKeybinds.Mobile)

				SetupMobileButton(MobileBind.Button,ActionName)
			else
				local NewKeybind = {
					ActionName = ActionName,
					Priority = Binding.Priority or 1,
				}
				
				table.insert(OriginalKeybinds[Binding.Input],NewKeybind)
				table.insert(Keybinds[Binding.Input],NewKeybind)
			end
			
			if Binding.Toggle then
				ToggleKeybinds[ActionName][DeviceName] = false
			end
		end
	end
	
	return ToggleKeybinds
end

local function GetHighestPriorityAction(Input : Enum.KeyCode | Enum.UserInputType,Type : number) : string?
	local HighestPriority = 0
	local HighestAction
	
	if not Keybinds[Input] then return end
	
	for _,Binding in Keybinds[Input] do
		if Binding.Priority <= HighestPriority then continue end
		
		local Context = GetContextFromActionName(Binding.ActionName)
		if Context and not Context.Enabled then continue end
		
		HighestPriority = Binding.Priority
		HighestAction = Binding.ActionName		
	end
	
	return HighestAction
end

--Public functions

local function CreateContexts(SetupContexts : {[string] : {[string] : Action}}) : true
	for ContextName,Actions in SetupContexts do
		local ActionStates = SetupActions(Actions)
				
		Contexts[ContextName] = {
			Enabled = true,
			Actions = Actions,
			ToggledActionsStates = ActionStates,
		}
	end
	
	return true
end

local function ToggleContext(ContextName : string,State : boolean)
	local Context = Contexts[ContextName]
	if not Context then print(ContextName.." Doesn't exist.") return end
	
	Context.Enabled = State
end

local function BindToActionActivated(ActionName : string,Callback : (GameProcessed : boolean) -> ()) : () -> ()
	if not ActionActivatedBinds[ActionName] then
		error(ActionName.." Doesn't exist!")
	end
	
	ActivatedBindsID += 1
	
	local CallbackID = ActivatedBindsID
	
	ActionActivatedBinds[ActionName][CallbackID] = Callback
	
	return function()
		ActionActivatedBinds[ActionName][CallbackID] = nil
	end
end

local function BindToActionDeactivated(ActionName : string,Callback : (GameProcessed : boolean) -> ()) : () -> ()
	if not ActionDeactivatedBinds[ActionName] then
		error(ActionName.." Doesn't exist!")
	end
	
	DeactivatedBindsID += 1
	
	local CallbackID = DeactivatedBindsID
	
	ActionDeactivatedBinds[ActionName][CallbackID] = Callback
	
	return function()
		ActionDeactivatedBinds[ActionName][CallbackID] = nil
	end
end

local function GetActionKeybind(ActionName : string) : Enum.KeyCode? | Enum.UserInputType?
	for Binding,Keybind in Keybinds do
		for _,ActionData in Keybind do
			if ActionData.ActionName ~= ActionName then continue end

			return Binding
		end
	end
	
	return
end

local function SetActionKeybind(ActionName : string,NewBinding : Enum.KeyCode | Enum.UserInputType)
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

local function GetCustomKeybinds() : {[string] : Enum.KeyCode | Enum.UserInputType}
	local CustomKeybinds = {}
	
	for KeyCode,Bindings in Keybinds do
		for _,Binding in Bindings do
			CustomKeybinds[Binding.ActionName] = KeyCode
		end
	end
	
	return CustomKeybinds
end

local function LoadCustomKeybinds(CustomKeybinds : {[string] : Enum.KeyCode | Enum.UserInputType})
	for ActionName,KeyCode in CustomKeybinds do
		SetActionKeybind(ActionName,KeyCode)
	end
end

UserInputService.InputBegan:Connect(function(Input,GameProcessed)
	local InputType = Input.KeyCode ~= Enum.KeyCode.Unknown and Input.KeyCode or Input.UserInputType
	
	local ActionName = GetHighestPriorityAction(InputType,1)
	
	if ActionName then 
		local Context = AssertDefined(GetContextFromActionName(ActionName))

		if not Context then return end
		if not Context.Enabled then print("context is disabled") return end

		CallActivatedCallbacks(Context,ActionName,GameProcessed)
	end
end)

UserInputService.InputEnded:Connect(function(Input,GameProcessed)
	local InputType = Input.KeyCode ~= Enum.KeyCode.Unknown and Input.KeyCode or Input.UserInputType

	local ActionName = GetHighestPriorityAction(InputType,2)

	if ActionName then 
		local Context = AssertDefined(GetContextFromActionName(ActionName))

		if not Context then return end
		if not Context.Enabled then print("context is disabled") return end

		CallDeactivatedCallbacks(Context,ActionName,GameProcessed)
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
}
