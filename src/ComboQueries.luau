--!strict
local Types = require(script.Parent.Types)

type ComboState = Types.ComboState

local ComboStatus = {
	Fail = "Fail",
	Ignore = "Ignore",
	Succeed = "Succeed",
}

return {
	ComboStatus = ComboStatus,
	
	--i genuintly have no clue why in the functions it only lets me reference InputTypes from the Types module
	StrictOrdered = function(ComboInputs : {Types.InputTypes},QueuedInput : Types.InputTypes,ExpectedInput : Types.InputTypes,ComboState : ComboState) : string
		if QueuedInput == ExpectedInput then
			return ComboStatus.Succeed
		else
			return ComboStatus.Fail
		end
	end,
	
	StrictUnordered = function(ComboInputs : {Types.InputTypes},QueuedInput : Types.InputTypes,ExpectedInput : Types.InputTypes,ComboState : ComboState) : string
		for Index,Input in ComboInputs do
			if Input == QueuedInput and not ComboState.MatchedInputs[Index] then
				ComboState.MatchedInputs[Index] = true
				
				return ComboStatus.Succeed
			end
		end
		
		return ComboStatus.Fail
	end,
	
	LooseOrdered = function(ComboInputs : {Types.InputTypes},QueuedInput : Types.InputTypes,ExpectedInput : Types.InputTypes,ComboState : ComboState) : string
		if QueuedInput == ExpectedInput then
			return ComboStatus.Succeed
		end

		return ComboStatus.Ignore
	end,
	
	LooseUnordered = function(ComboInputs : {Types.InputTypes},QueuedInput : Types.InputTypes,ExpectedInput : Types.InputTypes,ComboState : ComboState) : string
		for Index,Input in ComboInputs do
			if Input == QueuedInput and not ComboState.MatchedInputs[Index] then
				ComboState.MatchedInputs[Index] = true

				return ComboStatus.Succeed
			end
		end

		return ComboStatus.Ignore
	end,
}
