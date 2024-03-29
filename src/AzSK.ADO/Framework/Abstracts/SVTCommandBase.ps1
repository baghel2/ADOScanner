﻿<#
.Description
	Base class for SVT classes being called from PS commands
	Provides functionality to fire events/operations at command levels like command started, 
	command completed and perform operation like generate run-identifier, invoke auto module update, 
	open log folder at the end of commmand execution etc
#>
using namespace System.Management.Automation
Set-StrictMode -Version Latest
class SVTCommandBase: CommandBase {

    #Region: Properties 
    [string[]] $ExcludeTags = @();
    [string[]] $ControlIds = @();
	[string[]] $ExcludeControlIds = @();
    [string] $ControlIdString = "";
    [string[]] $Severity = @();
	[string] $ExcludeControlIdString = "";
    [bool] $UsePartialCommits;
    [bool] $UseBaselineControls;
    [bool] $UsePreviewBaselineControls;
    [PSObject] $CentralStorageAccount;
	[string] $PartialScanIdentifier = [string]::Empty;
    hidden [bool] $UserHasStateAccess = $false;
    [bool] $GenerateFixScript = $false;
	[bool] $IncludeUserComments = $false;
    [AttestationOptions] $AttestationOptions;
    hidden [ControlStateExtension] $ControlStateExt;
    
    hidden [string] $AttestationUniqueRunId;
    #EndRegion

    #Region Constructor
    SVTCommandBase([string] $organizationName, [InvocationInfo] $invocationContext):
    Base($organizationName, $invocationContext) {
        
        #Adding below auto update call here bcz this code runs very earlier befor resource fetching.
        $this.CheckModuleVersion();

        [Helpers]::AbstractClass($this, [SVTCommandBase]);
        
    }
    #EndRegion


    hidden [SVTEventContext] CreateSVTEventContextObject() {
        return [SVTEventContext]@{
            OrganizationContext = $this.OrganizationContext;
            PartialScanIdentifier = $this.PartialScanIdentifier
            };
    }

    hidden [void] CommandStarted() {

        [SVTEventContext] $arg = $this.CreateSVTEventContextObject();
        
        #Removing below auto update call bcz this code runs after SVTResourceResolver.       
        #$versionMessage = $this.CheckModuleVersion();
        #if ($versionMessage) {
        #    $arg.Messages += $versionMessage;
        #}

        if ($null -ne $this.AttestationOptions -and $this.AttestationOptions.AttestControls -eq [AttestControls]::NotAttested -and $this.AttestationOptions.IsBulkClearModeOn) {
            throw [SuppressedException] ("The 'BulkClear' option does not apply to 'NotAttested' controls.`n")
        }
        #check to limit multi controlids in the bulk attestation mode
        $ctrlIds = $this.ConvertToStringArray($this.ControlIdString);
        # Block scan if both ControlsIds and UBC/UPBC parameters contain values 
        if($null -ne $ctrlIds -and $ctrlIds.Count -gt 0 -and ($this.UseBaselineControls -or $this.UsePreviewBaselineControls)){
            throw [SuppressedException] ("Both the parameters 'ControlIds' and 'UseBaselineControls/UsePreviewBaselineControls' contain values. `nYou should use only one of these parameters.`n")
        }

        if ($null -ne $this.AttestationOptions -and (-not [string]::IsNullOrWhiteSpace($this.AttestationOptions.JustificationText) -or $this.AttestationOptions.IsBulkClearModeOn) -and ($ctrlIds.Count -gt 1 -or $this.UseBaselineControls)) {
			if($this.UseBaselineControls)
			{
				throw [SuppressedException] ("UseBaselineControls flag should not be passed in case of Bulk attestation. This results in multiple controls. `nBulk attestation mode supports only one controlId at a time.`n")
			}
			else
			{
				throw [SuppressedException] ("Multiple controlIds specified. `nBulk attestation mode supports only one controlId at a time.`n")
			}	
        }
        
        $this.PublishEvent([SVTEvent]::CommandStarted, $arg);
        $this.InvokeExtensionMethod()
    }

    hidden [void] CommandError([System.Management.Automation.ErrorRecord] $exception) {
        [SVTEventContext] $arg = $this.CreateSVTEventContextObject();
        $arg.ExceptionMessage = $exception;

        $this.PublishEvent([SVTEvent]::CommandError, $arg);
        $this.InvokeExtensionMethod($exception)
    }

    hidden [void] CommandCompleted([SVTEventContext[]] $arguments) {
        $this.PublishEvent([SVTEvent]::CommandCompleted, $arguments);
        $this.InvokeExtensionMethod($arguments)
    }

    [string] EvaluateControlStatus() {
        $startScan = ([CommandBase]$this).InvokeFunction($this.RunAllControls);
        if( ([FeatureFlightingManager]::GetFeatureStatus("EnableScanAfterAttestation","*"))) { 
            if ($null -ne $this.AttestationOptions) {
                if (($this.AttestationOptions.AttestControls -eq "NotAttested") -or ($this.AttestationOptions.AttestControls -eq "All")) {
                    if (Get-Variable AttestationValue -Scope Global){
                        if ($Global:AttestationValue) {

                            $this.PublishCustomMessage(([Constants]::DoubleDashLine))
                            $this.PublishCustomMessage(([Constants]::HashLine))
                            $this.PublishCustomMessage(([Constants]::AttestedControlsScanMsg))
                            $this.PublishCustomMessage(([Constants]::DoubleDashLine))

                            ([CommandBase]$this).InvokeFunction($this.ScanAttestedControls,$null);
                        }
                    }
                }
            }
        }
        return $startScan
    }

    # Dummy function declaration to define the function signature
    # Function is supposed to override in derived class
    hidden [SVTEventContext[]] RunAllControls() {
        return @();
    }

    hidden [void] SetSVTBaseProperties([PSObject] $svtObject) {
        $svtObject.FilterTags = $this.ConvertToStringArray($this.FilterTags);
        $svtObject.ExcludeTags = $this.ConvertToStringArray($this.ExcludeTags);
        $svtObject.ControlIds += $this.ControlIds;
        $svtObject.Severity += $this.Severity;
        $svtObject.ControlIds += $this.ConvertToStringArray($this.ControlIdString);
		$svtObject.ExcludeControlIds += $this.ExcludeControlIds;
        $svtObject.ExcludeControlIds += $this.ConvertToStringArray($this.ExcludeControlIdString);
        $svtObject.GenerateFixScript = $this.GenerateFixScript;
        $svtObject.InvocationContext = $this.InvocationContext;
        # ToDo: Assumption: usercomment will only work when storage report feature flag is enable
        $resourceId = $svtObject.ResourceId; 

        #Include Server Side Exclude Tags
        $svtObject.ExcludeTags += [ConfigurationManager]::GetAzSKConfigData().DefaultControlExculdeTags

        #Include Server Side Filter Tags
        $svtObject.FilterTags += [ConfigurationManager]::GetAzSKConfigData().DefaultControlFiltersTags

		#Set Partial Unique Identifier
		if($svtObject.ResourceContext)
		{
			$svtObject.PartialScanIdentifier =$this.PartialScanIdentifier
		}
        
        #$this.InvokeExtensionMethod($svtObject);
        $svtObject.ControlStateExt = $this.ControlStateExt;
        
    }
}
