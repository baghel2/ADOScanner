using namespace System.Management.Automation
Set-StrictMode -Version Latest

# Class for providing capability to fire events,
# also includes support to fire AzSKGenericEvent and holds InvocationContext
class EventBase
{
    [string] $RunIdentifier = "default";
    [InvocationInfo] $InvocationContext;

	EventBase()
	{
		
	}
	EventBase($Id)
	{

	}
	[string] GenerateRunIdentifier()
	{
        return $(Get-Date -format "yyyyMMdd_HHmmss");
    }

    hidden [void] PublishEvent([string] $eventType, [PSObject] $eventArgument)
    {
		New-Event -SourceIdentifier $eventType  `
			-Sender $this `
			-EventArguments $eventArgument | Out-Null
    }

	[void] PublishException([ErrorRecord] $eventArgument)
	{
        $this.PublishEvent([AzSKGenericEvent]::Exception, $eventArgument);
    }

    [MessageData[]] PublishCustomMessage([MessageData[]] $messageData)
    {
		if($messageData)
		{
			$this.PublishEvent([AzSKGenericEvent]::CustomMessage, $messageData);
			return $messageData;
		}
		return @();
    }

    [MessageData[]] PublishCustomMessage([string] $message, [MessageType] $messageType)
    {
        return $this.PublishCustomMessage([MessageData]::new($message, $messageType));
    }

    [MessageData[]] PublishCustomMessage([string] $message, [PSObject] $dataObject)
    {
        return $this.PublishCustomMessage([MessageData]::new($message, $dataObject));
    }

    [MessageData[]] PublishCustomMessage([string] $message)
    {
        return $this.PublishCustomMessage($message, [MessageType]::Info);
    }

    [string] GetModuleName()
    {
        if($this.InvocationContext)
		{
			return $this.InvocationContext.MyCommand.Module.Name;
		}

		throw [System.ArgumentException] "The parameter 'InvocationContext' is not set"
    }

	[CommandDetails] GetCommandMetadata()
    {
        if($this.InvocationContext)
		{
			$commandNoun = $this.InvocationContext.MyCommand.Noun
			if(-not [string]::IsNullOrWhiteSpace($this.InvocationContext.MyCommand.Module.Prefix))
			{
				# Remove the module prefix from command name
				$commandNoun = $commandNoun.TrimStart($this.InvocationContext.MyCommand.Module.Prefix);
			}

			#if this is a batch scan we need to add the folder name where results will be stored in the command meta data which can be used be file output base file
			if($this.InvocationContext.BoundParameters.ContainsKey('BatchScan')){
				$commandMetadata = [CommandHelper]::Mapping | 
						Where-Object { $_.Noun -eq $commandNoun -and $_.Verb -eq $this.InvocationContext.MyCommand.Verb } | 
						Select-Object -First 1 
				$commandMetadata | Add-Member -NotePropertyName BatchScan -NotePropertyValue ($this.InvocationContext.BoundParameters.FolderName)
						
				return $commandMetaData
			}
			
			return [CommandHelper]::Mapping | 
								Where-Object { $_.Noun -eq $commandNoun -and $_.Verb -eq $this.InvocationContext.MyCommand.Verb } | 
								Select-Object -First 1;
		}

		throw [System.ArgumentException] "The parameter 'InvocationContext' is not set"
    }

	[bool] IsLatestVersionRequired()
    {
        if($this.InvocationContext)
		{
			$commandNoun = $this.InvocationContext.MyCommand.Noun
			if(-not [string]::IsNullOrWhiteSpace($this.InvocationContext.MyCommand.Module.Prefix))
			{
				# Remove the module prefix from command name
				$commandNoun = $commandNoun.TrimStart($this.InvocationContext.MyCommand.Module.Prefix);
			}

			$mapping = [CommandHelper]::Mapping | 
								Where-Object { $_.Noun -eq $commandNoun -and $_.Verb -eq $this.InvocationContext.MyCommand.Verb } | 
								Select-Object -First 1;
			return $mapping.IsLatestRequired;
		}

		throw [System.ArgumentException] "The parameter 'InvocationContext' is not set"
    }

	[System.Version] GetCurrentModuleVersion()
    {
        if($this.InvocationContext)
		{
			return [System.Version] ($this.InvocationContext.MyCommand.Version);
		}

		# Return default version which is 0.0.
		return [System.Version]::new();
    }

	[string[]] ConvertToStringArray([string] $stringArray)
	{
		$result = @();
		if(-not [string]::IsNullOrWhiteSpace($stringArray))
		{
			$result += $stringArray.Split(',', [StringSplitOptions]::RemoveEmptyEntries) | 
							Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
							ForEach-Object { $_.Trim() } |
							Select-Object -Unique;
		}
		return $result;
	}

	# Static Methods
	static [void] PublishGenericException([ErrorRecord] $eventArgument)
	{
		[EventBase]::new().PublishException($eventArgument);
    }

	static [void] PublishGenericCustomMessage([string] $message)
	{
		[EventBase]::PublishGenericCustomMessage($message, [MessageType]::Info);
    }

    static [void] PublishGenericCustomMessage([string] $message, [MessageType] $messageType)
	{
		[EventBase]::new().PublishCustomMessage($message, $messageType);
	}
	
	#Function to invoke extension method for base classes
	[void] InvokeExtensionMethod([PSObject] $arguments)
	{
		#Get calling method name using PSCallStack
		$stack= (Get-PSCallStack)
		if($stack.Count -gt 0)
		{
			$callingMethodName = $stack[1].FunctionName
			if($callingMethodName)
			{
				$extensionMethodName = $callingMethodName + "Ext"
				if(($this.PSobject.Methods.Match($extensionMethodName) | Measure-Object).Count)
				{
					$this.$extensionMethodName($arguments)					
				}
			}
		}
	}

	#Function to invoke extension method for base classes
	[void] InvokeExtensionMethod()
	{
		#Get calling method name using PSCallStack
		$stack= (Get-PSCallStack)
		if($stack.Count -gt 0)
		{
			$callingMethodName = $stack[1].FunctionName
			if($callingMethodName)
			{
				$extensionMethodName = $callingMethodName + "Ext"
				if(($this.PSobject.Methods.Match($extensionMethodName) | Measure-Object).Count)
				{
					$this.$extensionMethodName()					
				}
			}
		}
	}
}
