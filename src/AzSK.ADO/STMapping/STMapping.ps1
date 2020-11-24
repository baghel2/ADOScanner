Set-StrictMode -Version Latest
function Get-AzSKADOServiceMapping
{
    <#
    .SYNOPSIS
        This command would help users to get service tree mappings of various components of AzSK.ADO.
    .DESCRIPTION
        This command will fetch service tree mappings of AzSK.ADO components and help user to provide details of different component using single command. Refer https://aka.ms/adoscanner/docs for more information 
    .PARAMETER OrganizationName
        Organization name for which the service mapping evaluation has to be performed.
    .PARAMETER ProjectName
        Project name for which the service mapping evaluation has to be performed.
    .PARAMETER BuildMappingsFilePath
        File Path for build mappings in json format.
    .PARAMETER ReleaseMappingsFilePath
        File Path for release mappings in json format.

    .LINK
    https://aka.ms/ADOScanner 

    #>
    Param(
        [string]
        [Parameter(Mandatory = $true)]
        [Alias("oz")]
        $OrganizationName,

        [string]
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("pns", "ProjectNames", "pn")]
        $ProjectName,

        [string]
        [Parameter(Mandatory = $true)]
        [Alias("bfp")]
        $BuildMappingsFilePath,

        [string]
        [Parameter(Mandatory = $true)]
        [Alias("rfp")]
        $ReleaseMappingsFilePath
    )
    Begin
    {
        [CommandHelper]::BeginCommand($PSCmdlet.MyInvocation);
        [ListenerHelper]::RegisterListeners();
    }

    Process
    {
        try 
        {
            $resolver = [Resolver]::new($OrganizationName)
            $mapping = [AzSKADOServiceMapping]::new($OrganizationName, $ProjectName, $BuildMappingsFilePath, $ReleaseMappingsFilePath, $PSCmdlet.MyInvocation);

            return $mapping.InvokeFunction($mapping.GetSTmapping);
        }
        catch 
        {
            [EventBase]::PublishGenericException($_);
        }  
    }

    End
    {
        [ListenerHelper]::UnregisterListeners();
    }
}
