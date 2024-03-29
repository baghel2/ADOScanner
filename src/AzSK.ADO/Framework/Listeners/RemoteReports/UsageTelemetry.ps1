﻿Set-StrictMode -Version Latest

class UsageTelemetry: ListenerBase {
	[Microsoft.ApplicationInsights.TelemetryClient] $TelemetryClient;

    hidden UsageTelemetry() {
		$this.TelemetryClient = [Microsoft.ApplicationInsights.TelemetryClient]::new()
		$this.TelemetryClient.InstrumentationKey = [Constants]::UsageTelemetryKey
    }

    hidden static [UsageTelemetry] $Instance = $null;

    static [UsageTelemetry] GetInstance() {
        if ( $null  -eq [UsageTelemetry]::Instance -or  $null  -eq [UsageTelemetry]::Instance.TelemetryClient) {
            [UsageTelemetry]::Instance = [UsageTelemetry]::new();
        }
        return [UsageTelemetry]::Instance
    }

    [void] RegisterEvents() {
        $this.UnregisterEvents();		
        $this.RegisterEvent([AzSKRootEvent]::GenerateRunIdentifier, {
            $currentInstance = [UsageTelemetry]::GetInstance();
            try
            {
				$runIdentifier = [AzSKRootEventArgument] ($Event.SourceArgs | Select-Object -First 1)
                $currentInstance.SetRunIdentifier($runIdentifier);
            }
            catch
            {
                $currentInstance.PublishException($_);
            }
        });


		$this.RegisterEvent([AzSKRootEvent]::CommandStarted, {
			if(-not [UsageTelemetry]::IsAnonymousTelemetryActive()) { return; }
            $currentInstance = [UsageTelemetry]::GetInstance();
			try
			{
				$Properties = @{ "Command" = $currentInstance.invocationContext.MyCommand.Name }
				[UsageTelemetry]::SetCommandInvocationProperties($currentInstance,$Properties);
				$commandStartedEvents = [System.Collections.ArrayList]::new()
				$telemetryEvent = "" | Select-Object Name, Properties, Metrics
				$telemetryEvent.Name = "Command Started"
				$telemetryEvent.Properties = $Properties
				$telemetryEvent = [UsageTelemetry]::SetCommonProperties($telemetryEvent,$currentInstance);
				$commandStartedEvents.Add($telemetryEvent) 
				[AIOrgTelemetryHelper]::PublishEvent($commandStartedEvents,"Usage")
				#Not using the below helper functions because it is currently unable to gracefully handle properties with null value.
				#[UsageTelemetry]::TrackCommandUsageEvent($currentInstance, "Command Started", $Properties, @{});
			}
			catch{
				#No need to break execution, If any occurs while sending anonymous telemetry
			}
        });

        $this.RegisterEvent([SVTEvent]::ResourceCount, {
            if(-not [UsageTelemetry]::IsAnonymousTelemetryActive()) { return; }
            $currentInstance = [UsageTelemetry]::GetInstance();
            try
            {
                $message = $Event.SourceArgs.Messages | Select-Object -First 1
                if($message -and $message.DataObject)
                {
                    $Properties = @{ "Command" = $currentInstance.invocationContext.MyCommand.Name }
                    [UsageTelemetry]::SetCommandInvocationProperties($currentInstance,$Properties);
                    $resourceCountEvents = [System.Collections.ArrayList]::new()
                    $telemetryEvent = "" | Select-Object Name, Properties, Metrics
                    $telemetryEvent.Name = "Resource Count"
                    $telemetryEvent.Properties = $Properties
                    $telemetryEvent.Metrics = @{"Count" = $message.DataObject}
                    $telemetryEvent = [UsageTelemetry]::SetCommonProperties($telemetryEvent,$currentInstance);
                    $resourceCountEvents.Add($telemetryEvent) 
                    [AIOrgTelemetryHelper]::PublishEvent($resourceCountEvents,"Usage")
                }
            }
            catch{
                #No need to break execution, If any occurs while sending anonymous telemetry
            }
        });



        $this.RegisterEvent([SVTEvent]::CommandStarted, {
			if(-not [UsageTelemetry]::IsAnonymousTelemetryActive()) { return; }
            $currentInstance = [UsageTelemetry]::GetInstance();
			try
			{
				$Properties = @{ "Command" = $currentInstance.invocationContext.MyCommand.Name }
				[UsageTelemetry]::SetCommandInvocationProperties($currentInstance,$Properties);
				$commandStartedEvents = [System.Collections.ArrayList]::new()
				$telemetryEvent = "" | Select-Object Name, Properties, Metrics
				$telemetryEvent.Name = "Command Started"
				$telemetryEvent.Properties = $Properties
				$telemetryEvent = [UsageTelemetry]::SetCommonProperties($telemetryEvent,$currentInstance);
				$commandStartedEvents.Add($telemetryEvent) 
				[AIOrgTelemetryHelper]::PublishEvent($commandStartedEvents,"Usage")
				#Not using the below helper functions because it is currently unable to gracefully handle properties with null value.
				#[UsageTelemetry]::TrackCommandUsageEvent($currentInstance, "Command Started", $Properties, @{});
			}
			catch{
				#No need to break execution, If any occurs while sending anonymous telemetry
			}
        });

		$this.RegisterEvent([AzSKRootEvent]::CommandCompleted, {
			if(-not [UsageTelemetry]::IsAnonymousTelemetryActive()) { return; }
			$currentInstance = [UsageTelemetry]::GetInstance();
            $currentInstance.PushAIEventsfromHandler("UsageTelemetry CommandCompleted"); 
			try
			{
				$Properties = @{ "Command" = $currentInstance.invocationContext.MyCommand.Name }
				[UsageTelemetry]::SetCommandInvocationProperties($currentInstance,$Properties);
				$commandCompletedEvents = [System.Collections.ArrayList]::new()
				$telemetryEvent = "" | Select-Object Name, Properties, Metrics
				$telemetryEvent.Name = "Command Completed"
				$telemetryEvent.Properties = $Properties
				$telemetryEvent = [UsageTelemetry]::SetCommonProperties($telemetryEvent,$currentInstance);
				$commandCompletedEvents.Add($telemetryEvent) 
				[AIOrgTelemetryHelper]::PublishEvent($commandCompletedEvents,"Usage")
				#Not using the below helper functions because it is currently unable to gracefully handle properties with null value.
				#[UsageTelemetry]::TrackCommandUsageEvent($currentInstance, "Command Completed", $Properties, @{});
			}
			catch{
				#No need to break execution, If any occurs while sending anonymous telemetry
			}
        });

		$this.RegisterEvent([SVTEvent]::CommandCompleted, {
			if(-not [UsageTelemetry]::IsAnonymousTelemetryActive()) { return; }
            $currentInstance = [UsageTelemetry]::GetInstance();
			try
			{
				$Properties = @{ "Command" = $currentInstance.invocationContext.MyCommand.Name }
				[UsageTelemetry]::SetCommandInvocationProperties($currentInstance,$Properties);
				$commandCompletedEvents = [System.Collections.ArrayList]::new()
				$telemetryEvent = "" | Select-Object Name, Properties, Metrics
				$telemetryEvent.Name = "Command Completed"
				$telemetryEvent.Properties = $Properties
				$telemetryEvent = [UsageTelemetry]::SetCommonProperties($telemetryEvent,$currentInstance);
				$commandCompletedEvents.Add($telemetryEvent) 
				[AIOrgTelemetryHelper]::PublishEvent($commandCompletedEvents,"Usage")
				#Not using the below helper functions because it is currently unable to gracefully handle properties with null value.
				#[UsageTelemetry]::TrackCommandUsageEvent($currentInstance, "Command Completed", $Properties, @{});
			}
			catch{
				#No need to break execution, If any occurs while sending anonymous telemetry
			}
		});	 
		
		$this.RegisterEvent([SVTEvent]::EvaluationCompleted, {
			if(-not [UsageTelemetry]::IsAnonymousTelemetryActive()) { return; }
			$currentInstance = [UsageTelemetry]::GetInstance();
			try
			{
				$invocationContext = [System.Management.Automation.InvocationInfo] $currentInstance.InvocationContext
				$SVTEventContexts = [SVTEventContext[]] $Event.SourceArgs
				$feature = $SVTEventContexts[0].FeatureName
				#Adding project info telemetry for scanned controls.
				if($feature -eq 'Project'){
					[UsageTelemetry]::PushProjectTelemetry($currentInstance, $SVTEventContexts[0])
				}else{
					#do nothing. Currently, we do not support extracting unique project info (masked) from other feature types.
				}
			}
			catch
			{
				$currentInstance.PublishException($_);
			}
			$currentInstance.TelemetryClient.Flush()
		});


		$this.RegisterEvent([AzSKGenericEvent]::Exception, {
			if(-not [UsageTelemetry]::IsAnonymousTelemetryActive()) { return; }
            $currentInstance = [UsageTelemetry]::GetInstance();
            try
            {
				[System.Management.Automation.ErrorRecord] $er = ($Event.SourceArgs | Select-Object -First 1)	

				[UsageTelemetry]::PushException($currentInstance, @{}, @{}, $er);
            }
            catch
            {
				# Handling error while registration of Exception event.
				# No need to break execution
            }
        });

		$this.RegisterEvent([AzSKRootEvent]::CommandError, {
			if(-not [UsageTelemetry]::IsAnonymousTelemetryActive()) { return; }
            $currentInstance = [UsageTelemetry]::GetInstance();
            try
            {
				[System.Management.Automation.ErrorRecord] $er = [RemoteReportHelper]::Mask($Event.SourceArgs.ExceptionMessage)
				[UsageTelemetry]::PushException($currentInstance, @{}, @{}, $er);
            }
            catch
            {
				# Handling error while registration of CommandError event at AzSKRoot.
				# No need to break execution
            }
        });

		$this.RegisterEvent([SVTEvent]::CommandError, {
			if(-not [UsageTelemetry]::IsAnonymousTelemetryActive()) { return; }
            $currentInstance = [UsageTelemetry]::GetInstance();
            try
            {
				[System.Management.Automation.ErrorRecord] $er = [RemoteReportHelper]::Mask($Event.SourceArgs.ExceptionMessage)
				[UsageTelemetry]::PushException($currentInstance, @{}, @{}, $er);
            }
            catch
            {
				# Handling error while registration of CommandError event at SVT.
				# No need to break execution
            }
        });

		$this.RegisterEvent([SVTEvent]::EvaluationError, {
			if(-not [UsageTelemetry]::IsAnonymousTelemetryActive()) { return; }
            $currentInstance = [UsageTelemetry]::GetInstance();
            try
            {
				[System.Management.Automation.ErrorRecord] $er = [RemoteReportHelper]::Mask($Event.SourceArgs.ExceptionMessage)
				[UsageTelemetry]::PushException($currentInstance, @{}, @{}, $er);
            }
            catch
            {
				# Handling error while registration of EvaluationError event at SVT.
				# No need to break execution
            }
        });

		$this.RegisterEvent([SVTEvent]::ControlError, {
			if(-not [UsageTelemetry]::IsAnonymousTelemetryActive()) { return; }
            $currentInstance = [UsageTelemetry]::GetInstance();
            try
            {
				[System.Management.Automation.ErrorRecord] $er = [RemoteReportHelper]::Mask($Event.SourceArgs.ExceptionMessage)
				[UsageTelemetry]::PushException($currentInstance, @{}, @{}, $er);
            }
            catch
            {
				# Handling error while registration of ControlError event at SVT.
				# No need to break execution
            }
        });

		$this.RegisterEvent([AzSKRootEvent]::PolicyMigrationCommandStarted, {
			if(-not [UsageTelemetry]::IsAnonymousTelemetryActive()) { return; }
            $currentInstance = [UsageTelemetry]::GetInstance();
           	try{
			$Properties = @{			
			"OrgName" = [RemoteReportHelper]::Mask($Event.SourceArgs[0]);			
			}
			[UsageTelemetry]::SetCommonProperties($currentInstance, $Properties);
			$event = [Microsoft.ApplicationInsights.DataContracts.EventTelemetry]::new()
			$event.Name = "Policy Migration Started"
			$Properties.Keys | ForEach-Object {
				try{
					$event.Properties.Add($_, $Properties[$_].ToString());
				}
				catch{
					#Eat the current exception which typically happens when the property already exist in the object and try to add the same property again
					#No need to break execution
				}
			}			
			$currentInstance.TelemetryClient.TrackEvent($event);
		}
		catch{
		}
        });

		$this.RegisterEvent([AzSKRootEvent]::PolicyMigrationCommandCompleted, {
			if(-not [UsageTelemetry]::IsAnonymousTelemetryActive()) { return; }
            $currentInstance = [UsageTelemetry]::GetInstance();
           	try{
			$Properties = @{			
			"OrgName" = [RemoteReportHelper]::Mask($Event.SourceArgs[0]);			
			}
			[UsageTelemetry]::SetCommonProperties($currentInstance, $Properties);
			$event = [Microsoft.ApplicationInsights.DataContracts.EventTelemetry]::new()
			$event.Name = "Policy Migration Completed"
			$Properties.Keys | ForEach-Object {
				try{
					$event.Properties.Add($_, $Properties[$_].ToString());
				}
				catch{
				}
			}			
			$currentInstance.TelemetryClient.TrackEvent($event);
		}
		catch{
		}
        });
    }

	static [bool] IsAnonymousTelemetryActive()
	{
		$azskSettings = [ConfigurationManager]::GetAzSKSettings();
		if($azskSettings.UsageTelemetryLevel -eq "anonymous") { return $true; }
		else
		{
			return $false;
		}
	}

	static [void] PushOrganizationScanResults(
		[UsageTelemetry] $Publisher, `
		[SVTEventContext[]] $SVTEventContexts)
	{
		$eventData = @{
			[TelemetryKeys]::FeatureGroup = [FeatureGroup]::Organization;
			"ScanKind" = [RemoteReportHelper]::GetOrganizationScanKind(
				$Publisher.InvocationContext.MyCommand.Name,
				$Publisher.InvocationContext.BoundParameters);
		}
        $organizationScanTelemetryEvents = [System.Collections.ArrayList]::new()

		$SVTEventContexts | ForEach-Object {
			$context = $_
			[hashtable] $eventDataClone = $eventData.Clone();
			$eventDataClone.Add("ControlIntId", $context.ControlItem.Id);
			$eventDataClone.Add("ControlId", $context.ControlItem.ControlID);
			$eventDataClone.Add("ControlSeverity", $context.ControlItem.ControlSeverity);
			if ($context.ControlItem.Enabled) {
				$eventDataClone.Add("ActualVerificationResult", $context.ControlResults[0].ActualVerificationResult)
				$eventDataClone.Add("AttestationStatus", $context.ControlResults[0].AttestationStatus)
				$eventDataClone.Add("VerificationResult", $context.ControlResults[0].VerificationResult)
			}
			else {
				$eventDataClone.Add("ActualVerificationResult", [VerificationResult]::Disabled)
				$eventDataClone.Add("AttestationStatus", [AttestationStatus]::None)
				$eventDataClone.Add("VerificationResult", [VerificationResult]::Disabled)
			}
			#[UsageTelemetry]::PushEvent($Publisher, $eventDataClone, @{})
                $telemetryEvent = "" | Select-Object Name, Properties, Metrics
				$telemetryEvent.Name = "Control Scanned"
				$telemetryEvent.Properties = $eventDataClone
				$telemetryEvent = [UsageTelemetry]::SetCommonProperties($telemetryEvent,$Publisher);
				$organizationScanTelemetryEvents.Add($telemetryEvent)
		}
            [AIOrgTelemetryHelper]::PublishEvent($organizationScanTelemetryEvents,"Usage")
	}

	static [void] PushServiceScanResults(
		[UsageTelemetry] $Publisher, `
		[SVTEventContext[]] $SVTEventContexts)
	{
		$NA = "NA"
		$SVTEventContextFirst = $SVTEventContexts[0]
		$eventData = @{
			[TelemetryKeys]::FeatureGroup = [FeatureGroup]::Service;
			"ScanKind" = [RemoteReportHelper]::GetServiceScanKind(
				$Publisher.InvocationContext.MyCommand.Name,
				$Publisher.InvocationContext.BoundParameters);
			"Feature" = $SVTEventContextFirst.FeatureName;
			"ResourceGroup" = [RemoteReportHelper]::Mask($SVTEventContextFirst.ResourceContext.ResourceGroupName);
			"ResourceName" = [RemoteReportHelper]::Mask($SVTEventContextFirst.ResourceContext.ResourceName);
			"ResourceId" = [RemoteReportHelper]::Mask($SVTEventContextFirst.ResourceContext.ResourceId);
		}
        $servicescantelemetryEvents = [System.Collections.ArrayList]::new()

		$SVTEventContexts | ForEach-Object {
			$SVTEventContext = $_
			[hashtable] $eventDataClone = $eventData.Clone()
			$eventDataClone.Add("ControlIntId", $SVTEventContext.ControlItem.Id);
			$eventDataClone.Add("ControlId", $SVTEventContext.ControlItem.ControlID);
			$eventDataClone.Add("ControlSeverity", $SVTEventContext.ControlItem.ControlSeverity);
			if (!$SVTEventContext.ControlItem.Enabled) {
				$eventDataClone.Add("ActualVerificationResult", [VerificationResult]::Disabled)
				$eventDataClone.Add("AttestationStatus", [AttestationStatus]::None)
				$eventDataClone.Add("VerificationResult", [VerificationResult]::Disabled)
				#[UsageTelemetry]::PushEvent($Publisher, $eventDataClone, @{})

                $telemetryEvent = "" | Select-Object Name, Properties, Metrics
				$telemetryEvent.Name = "Control Scanned"
				$telemetryEvent.Properties = $eventDataClone
				$telemetryEvent = [UsageTelemetry]::SetCommonProperties($telemetryEvent,$Publisher);
				$servicescantelemetryEvents.Add($telemetryEvent) 

			}
			elseif ($SVTEventContext.ControlResults.Count -eq 1 -and `
				($SVTEventContextFirst.ResourceContext.ResourceName -eq $SVTEventContext.ControlResults[0].ChildResourceName -or `
					[string]::IsNullOrWhiteSpace($SVTEventContext.ControlResults[0].ChildResourceName)))
			{
				$eventDataClone.Add("ActualVerificationResult", $SVTEventContext.ControlResults[0].ActualVerificationResult)
				$eventDataClone.Add("AttestationStatus", $SVTEventContext.ControlResults[0].AttestationStatus)
				$eventDataClone.Add("VerificationResult", $SVTEventContext.ControlResults[0].VerificationResult)
				$eventDataClone.Add("IsNestedResource", 'No')
				$eventDataClone.Add("NestedResourceName", $NA)
				#[UsageTelemetry]::PushEvent($Publisher, $eventDataClone, @{})

                $telemetryEvent = "" | Select-Object Name, Properties, Metrics
				$telemetryEvent.Name = "Control Scanned"
				$telemetryEvent.Properties = $eventDataClone
				$telemetryEvent = [UsageTelemetry]::SetCommonProperties($telemetryEvent,$Publisher);
				$servicescantelemetryEvents.Add($telemetryEvent) 
			}
			elseif ($SVTEventContext.ControlResults.Count -eq 1 -and `
				$SVTEventContextFirst.ResourceContext.ResourceName -ne $SVTEventContext.ControlResults[0].ChildResourceName)
			{
				$eventDataClone.Add("ActualVerificationResult", $SVTEventContext.ControlResults[0].ActualVerificationResult)
				$eventDataClone.Add("AttestationStatus", $SVTEventContext.ControlResults[0].AttestationStatus)
				$eventDataClone.Add("VerificationResult", $SVTEventContext.ControlResults[0].VerificationResult)
				$eventDataClone.Add("IsNestedResource", 'Yes')
				$eventDataClone.Add("NestedResourceName", [RemoteReportHelper]::Mask($SVTEventContext.ControlResults[0].ChildResourceName))
				#[UsageTelemetry]::PushEvent($Publisher, $eventDataClone, @{})

                $telemetryEvent = "" | Select-Object Name, Properties, Metrics
				$telemetryEvent.Name = "Control Scanned"
				$telemetryEvent.Properties = $eventDataClone
				$telemetryEvent = [UsageTelemetry]::SetCommonProperties($telemetryEvent,$Publisher);
				$servicescantelemetryEvents.Add($telemetryEvent) 
			}
			elseif ($SVTEventContext.ControlResults.Count -gt 1)
			{
				$eventDataClone.Add("IsNestedResource", 'Yes')
				$SVTEventContext.ControlResults | Foreach-Object {
					[hashtable] $eventDataCloneL2 = $eventDataClone.Clone()
					$eventDataCloneL2.Add("ActualVerificationResult", $_.ActualVerificationResult)
					$eventDataCloneL2.Add("AttestationStatus", $_.AttestationStatus)
					$eventDataCloneL2.Add("VerificationResult", $_.VerificationResult)
					$eventDataCloneL2.Add("NestedResourceName", [RemoteReportHelper]::Mask($_.ChildResourceName))
					#[UsageTelemetry]::PushEvent($Publisher, $eventDataCloneL2, @{})

                    $telemetryEvent = "" | Select-Object Name, Properties, Metrics
				    $telemetryEvent.Name = "Control Scanned"
				    $telemetryEvent.Properties = $eventDataCloneL2
					$telemetryEvent = [UsageTelemetry]::SetCommonProperties($telemetryEvent,$Publisher);
                    $servicescantelemetryEvents.Add($telemetryEvent) 
				}
			}
		}
        [AIOrgTelemetryHelper]::PublishEvent($servicescantelemetryEvents,"Usage")
	}

	static [void] PushProjectTelemetry(
		[UsageTelemetry] $Publisher, `
		[SVTEventContext] $SVTEventContexts)
	{
		$NA = "NA"
		#Note we are pushing only one event for each unique project resource scanned. We are not duplicatig efforts by sending project info for each project control scanned.
		$eventData = @{
			"Feature" = $SVTEventContexts.FeatureName;
			"ResourceGroup" = [RemoteReportHelper]::Mask($SVTEventContexts.ResourceContext.ResourceGroupName);
			"ResourceName" = [RemoteReportHelper]::Mask($SVTEventContexts.ResourceContext.ResourceName);
			"ResourceId" = [RemoteReportHelper]::Mask($SVTEventContexts.ResourceContext.ResourceId);
		}
		$projectTelemetryEvents = [System.Collections.ArrayList]::new()
        $telemetryEvent = "" | Select-Object Name, Properties, Metrics
		$telemetryEvent.Name = "Project Info"
		$telemetryEvent.Properties = $eventData
		$telemetryEvent = [UsageTelemetry]::SetCommonProperties($telemetryEvent,$Publisher);
		$projectTelemetryEvents.Add($telemetryEvent) 
        [AIOrgTelemetryHelper]::PublishEvent($projectTelemetryEvents,"Usage")
	}

	static [void] PushEvent([UsageTelemetry] $Publisher, `
							[hashtable] $Properties, [hashtable] $Metrics)
	{
		try{
			[UsageTelemetry]::SetCommonProperties($Publisher, $Properties);
			$event = [Microsoft.ApplicationInsights.DataContracts.EventTelemetry]::new()
			$event.Name = "Control Scanned"
			$Properties.Keys | ForEach-Object {
				try{
					$event.Properties.Add($_, $Properties[$_].ToString());
				}
				catch{
					# Eat the current exception which typically happens when the property already exist in the object and try to add the same property again
					# No need to break execution
				}
			}
			$Metrics.Keys | ForEach-Object {
				try{
					$event.Metrics.Add($_, $Metrics[$_]);
				}
				catch{
					# Eat the current exception which typically happens when the property already exist in the object and try to add the same property again
					# No need to break execution
				}
			}
			$Publisher.TelemetryClient.TrackEvent($event);
		}
		catch{
				# Eat the current exception which typically happens when network or other API issue while sending telemetry events 
				# No need to break execution
		}
	}

	static [void] PushException([UsageTelemetry] $Publisher, `
							[hashtable] $Properties, [hashtable] $Metrics, `
							[System.Management.Automation.ErrorRecord] $ErrorRecord)
	{
		try{
			[UsageTelemetry]::SetCommonProperties($Publisher, $Properties);
			$ex = [Microsoft.ApplicationInsights.DataContracts.ExceptionTelemetry]::new()
			$ex.Exception = [System.Exception]::new( [RemoteReportHelper]::Mask($ErrorRecord.Exception.ToString()))
			try{
				$ex.Properties.Add("ScriptStackTrace", [UsageTelemetry]::AnonScriptStackTrace($ErrorRecord.ScriptStackTrace))
			}
			catch
			{
				# Eat the current exception which typically happens when the property already exist in the object and try to add the same property again
				# No need to break execution
			}
			$Properties.Keys | ForEach-Object {
				try{
					$ex.Properties.Add($_, $Properties[$_].ToString());
				}
				catch
				{
					# Eat the current exception which typically happens when the property already exist in the object and try to add the same property again
					# No need to break execution
				}
			}
			$Metrics.Keys | ForEach-Object {
				try{
					$ex.Metrics.Add($_, $Metrics[$_]);
				}
				catch
				{
					# Eat the current exception which typically happens when the property already exist in the object and try to add the same property again
					# No need to break execution
				}
			}
			$Publisher.TelemetryClient.TrackException($ex)
			$Publisher.TelemetryClient.Flush()
		}
		catch{
			# Handled exception occurred while publishing exception
			# No need to break execution
		}
	}

	hidden static [void] SetCommonProperties([UsageTelemetry] $Publisher, [hashtable] $Properties)
	{
		try{
			$NA = "NA";
			$Properties.Add("InfoVersion", "V1");
			try{
				$Properties.Add("ScanSource", [RemoteReportHelper]::GetScanSource());
			}
			catch
			{
				# Eat the current exception which typically happens when the property already exist in the object and try to add the same property again
				# No need to break execution
			}
			try{
				$Properties.Add("ScannerVersion", $Publisher.GetCurrentModuleVersion());
			}
			catch
			{
				# Eat the current exception which typically happens when the property already exist in the object and try to add the same property again
				# No need to break execution
			}
			try{
				$Properties.Add("ControlVersion", $Publisher.GetCurrentModuleVersion());
			}
			catch
			{
				# Eat the current exception which typically happens when the property already exist in the object and try to add the same property again
				# No need to break execution
			}
			try{
				$organizationContext = [ContextHelper]::GetCurrentContext()
				try{
					$Properties.Add([TelemetryKeys]::OrganizationId, [RemoteReportHelper]::Mask($organizationContext.Organization.Id))
				}
				catch {
					# Eat the current exception which typically happens when the property already exist in the object and try to add the same property again
					# No need to break execution
				}
				try{
					$Properties.Add([TelemetryKeys]::OrganizationName, [RemoteReportHelper]::Mask($organizationContext.Organization.Name))
				}
				catch {
					# Eat the current exception which typically happens when the property already exist in the object and try to add the same property again
					# No need to break execution
				}
				try{
					$Properties.Add("ADOEnv", $organizationContext.Environment.Name)
				} 
				catch {
					# Eat the current exception which typically happens when the property already exist in the object and try to add the same property again
					# No need to break execution
				}
				try{
					$Properties.Add("TenantId", [RemoteReportHelper]::Mask($organizationContext.Tenant.Id))
				}
				catch {
					# Eat the current exception which typically happens when the property already exist in the object and try to add the same property again
					# No need to break execution
				}
				try{
					$Properties.Add("AccountId", [RemoteReportHelper]::Mask($organizationContext.Account.Id))
				}
				catch {
					# Eat the current exception which typically happens when the property already exist in the object and try to add the same property again
					# No need to break execution
				}
				try{
					$Properties.Add("RunIdentifier",  [RemoteReportHelper]::Mask($organizationContext.Account.Id + '##' + $Publisher.RunIdentifier));
				}
				catch
				{
					$Properties.Add("RunIdentifier",  $Publisher.RunIdentifier);
				}
				try{
					$Properties.Add("AccountType", $organizationContext.Account.Type)
				}
				catch {
					# Eat the current exception which typically happens when the property already exist in the object and try to add the same property again
					# No need to break execution
				}
				try{
					$OrgName = [ConfigurationManager]::GetAzSKConfigData().PolicyOrgName
					$Properties.Add("OrgName", [RemoteReportHelper]::Mask($OrgName))
				}
				catch {
					# Eat the current exception which typically happens when the property already exist in the object and try to add the same property again
					# No need to break execution
				}
			}
			catch{
				# Eat the current exception which typically happens when the property already exist in the object and try to add the same property again
				# No need to break execution
			}
		}
		catch{
			# Eat the current exception which typically happens when the property already exist in the object and try to add the same property again
			# No need to break execution
		}
	}

	hidden static [void] SetCommandInvocationProperties([UsageTelemetry] $CurrentInstance, [hashtable] $Properties)
	{
		try{
			$params = @{}
			$CurrentInstance.invocationContext.BoundParameters.Keys | ForEach-Object {
				$value = "MASKED"
				$params.Add($_, $value)
			}
			$Properties.Add("Params", [JsonHelper]::ConvertToJsonCustomCompressed($params))
		}
		catch{
			# Eat the current exception which typically happens when the property already exist in the object and try to add the same property again
			# No need to break execution
		}
	}

	hidden static [string] AnonScriptStackTrace([string] $ScriptStackTrace)
	{
		try{
			$ScriptStackTrace = $ScriptStackTrace.Replace($env:USERNAME, "USERNAME")
			$lines = $ScriptStackTrace.Split([System.Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)
			$newLines = $lines | ForEach-Object {
				$line = $_
				$lineSplit = $line.Split(@(", "), [System.StringSplitOptions]::RemoveEmptyEntries);
				if($lineSplit.Count -eq 2){
					$filePath = $lineSplit[1];
					$startMarker = $filePath.IndexOf("AzSK")
					if($startMarker -gt 0){
						$anonFilePath = $filePath.Substring($startMarker, $filePath.Length - $startMarker)
						$newLine = $lineSplit[0] + ", " + $anonFilePath
						$newLine
					}
					else{
						$line
					}
				}
				else{
					$line
				}
			}
			return ($newLines | Out-String)
		}
		catch{
			return $ScriptStackTrace
		}
	}

	static [psobject] SetCommonProperties([psobject] $EventObj,[UsageTelemetry] $Publisher)
	{
		try{
			$NA = "NA";
			$eventObj.properties.Add("InfoVersion", "V1");
			try{
				$eventObj.properties.Add("ScanSource", [RemoteReportHelper]::GetScanSource());
			}
			catch{
				# Eat the current exception which typically happens when the property already exist in the object and try to add the same property again
				# No need to break execution
			}
			try{
				$eventObj.properties.Add("ScannerModuleName", $Publisher.GetModuleName());
			}
			catch{
				# Eat the current exception which typically happens when the property already exist in the object and try to add the same property again
				# No need to break execution
			}
			try{
				$eventObj.properties.Add("ScannerVersion", $Publisher.GetCurrentModuleVersion());
			}
			catch{
				# Eat the current exception which typically happens when the property already exist in the object and try to add the same property again
				# No need to break execution
			}
			try{
				$eventObj.properties.Add("ControlVersion", $Publisher.GetCurrentModuleVersion());
			}
			catch{
				# Eat the current exception which typically happens when the property already exist in the object and try to add the same property again
				# No need to break execution
			}
			try{
				$organizationContext = [ContextHelper]::GetCurrentContext()
				try{
					$eventObj.properties.Add([TelemetryKeys]::OrganizationId, [RemoteReportHelper]::Mask($organizationContext.Organization.Id))
				}
				catch{
					# Eat the current exception which typically happens when the property already exist in the object and try to add the same property again
					# No need to break execution
				}
				try{
					$eventObj.properties.Add([TelemetryKeys]::OrganizationName, [RemoteReportHelper]::Mask($organizationContext.Organization.Name))
				}
				catch{
					# Eat the current exception which typically happens when the property already exist in the object and try to add the same property again
					# No need to break execution
				}
				try{
					$eventObj.properties.Add("ADOEnv", $organizationContext.Environment.Name)
				}
				catch{
					# Eat the current exception which typically happens when the property already exist in the object and try to add the same property again
					# No need to break execution
				}
				try{
					$eventObj.properties.Add("TenantId", [RemoteReportHelper]::Mask($organizationContext.Tenant.Id))
				}
				catch{
					# Eat the current exception which typically happens when the property already exist in the object and try to add the same property again
					# No need to break execution
				}
				try{
					$eventObj.properties.Add("AccountId", [RemoteReportHelper]::Mask($organizationContext.Account.Id))
				}
				catch{
					# Eat the current exception which typically happens when the property already exist in the object and try to add the same property again
					# No need to break execution
				}
				try{
					$eventObj.properties.Add("RunIdentifier",  [RemoteReportHelper]::Mask($organizationContext.Account.Id + '##' + $Publisher.RunIdentifier));
				}
				catch{
					$eventObj.properties.Add("RunIdentifier",  $Publisher.RunIdentifier);
				}
				try{
					$eventObj.properties.Add("AccountType", $organizationContext.Account.Type)
				}
				catch{
					# Eat the current exception which typically happens when the property already exist in the object and try to add the same property again
					# No need to break execution
				}
				try{
					$OrgName = [ConfigurationManager]::GetAzSKConfigData().PolicyOrgName
					$eventObj.properties.Add("OrgName", [RemoteReportHelper]::Mask($OrgName))
				}
				catch {
					# Eat the current exception which typically happens when the property already exist in the object and try to add the same property again
					# No need to break execution
				}
			}
			catch{
				# Eat the current exception which typically happens when the property already exist in the object and try to add the same property again
				# No need to break execution
			}
		}
		catch{
			# Eat the current exception which typically happens when the property already exist in the object and try to add the same property again
			# No need to break execution
		}

		return $eventObj;
	}
	hidden static [void] TrackCommandUsageEvent([UsageTelemetry] $currentInstance, [string] $Name, [hashtable] $Properties, [hashtable] $Metrics) {
        [UsageTelemetry]::SetCommonProperties($currentInstance, $Properties);
        try {
            $event = [Microsoft.ApplicationInsights.DataContracts.EventTelemetry]::new()
            $event.Name = $Name
            $Properties.Keys | ForEach-Object {
				if(-not $event.Properties.ContainsKey($_)){
					$event.Properties[$_] = $Properties[$_].ToString();
				}
            }
            $Metrics.Keys | ForEach-Object {
				if(-not $event.Properties.ContainsKey($_)){
					$event.Metrics[$_] = $Metrics[$_].ToString();
				}
			}

            $currentInstance.TelemetryClient.TrackEvent($event);
        }
        catch{ 
				# No need to break execution, if any occurs while sending telemetry
		}
    }
}

