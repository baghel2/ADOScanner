Set-StrictMode -Version Latest 

class IncrementalScanHelper
{
    hidden [string] $OrganizationName = $null;
    hidden [string] $ProjectName = $null;
    hidden [string] $ProjectId = $null;
    hidden $OrganizationContext = $null;
    [PSObject] $ControlSettings;
    hidden [string] $AzSKTempStatePath = (Join-Path $([Constants]::AzSKAppFolderPath) "IncrementalScan");
    hidden [string] $CAScanProgressSnapshotsContainerName = [Constants]::CAScanProgressSnapshotsContainerName;
    hidden [string] $ScanSource = $null;
    $StorageContext = $null;
	$ControlStateBlob = $null;
    $ContainerObject = $null;
    hidden [string] $IncrementalScanTimestampFile=$null;
    hidden [string] $CATempFile = $null;
    hidden [string] $MasterFilePath;
    hidden [PSObject] $ResourceTimestamps = $null;
    hidden [bool] $FirstScan = $false;
    hidden [datetime] $IncrementalDate = 0;
    hidden [datetime] $LastFullScan = 0;
    hidden [bool] $ShouldDiscardOldScan = $false;
    [bool] $UpdateTime = $true;
    hidden [datetime] $Timestamp = 0; 
    [bool] $isPartialScanActive = $false;
    [bool] $IsFullScanInProgress = $false;
    static [PSObject] $auditSchema = $null
    [bool] $isIncFileAlreadyAvailable = $false;
    
    IncrementalScanHelper([string] $organizationName, [string] $projectName, [datetime] $incrementalDate, [bool] $updateTimestamp, [datetime] $timestamp)
    {
        $this.OrganizationName = $organizationName
        $this.ProjectName = $projectName
        $this.IncrementalScanTimestampFile = $([Constants]::IncrementalScanTimeStampFile)
        $this.ScanSource = [AzSKSettings]::GetInstance().GetScanSource()
        $this.CATempFile = "CATempLocal.json" # temporary file to store Json Data to upload to container (in CA)
        $this.IncrementalDate = $incrementalDate
        $this.MasterFilePath = (Join-Path (Join-Path (Join-Path $this.AzSKTempStatePath $this.OrganizationName) $this.projectName) $this.IncrementalScanTimestampFile)
        $this.UpdateTime = $updateTimestamp
        $this.Timestamp = $timestamp
        $this.ControlSettings = [ConfigurationManager]::LoadServerConfigFile("ControlSettings.json");
        if($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("UsePartialCommits")){
            [PartialScanManager] $partialScanMngr = [PartialScanManager]::GetInstance();
            if(($partialScanMngr.IsPartialScanInProgress($this.OrganizationName, $false) -eq [ActiveStatus]::Yes)){
                $this.isPartialScanActive = $true
            }
        }  
        if($null -eq [IncrementalScanHelper]::auditSchema){
            [IncrementalScanHelper]::auditSchema = [ConfigurationManager]::LoadServerConfigFile("IncrementalScanAudits.json")
        }      
    }
    IncrementalScanHelper($organizationContext, [string] $projectId,[string] $projectName, [datetime] $incrementalDate)
    {
        $this.OrganizationName = $organizationContext.OrganizationName
        $this.OrganizationContext = $organizationContext
        $this.ProjectId = $projectId
        $this.IncrementalScanTimestampFile = $([Constants]::IncrementalScanTimeStampFile)
        $this.ScanSource = [AzSKSettings]::GetInstance().GetScanSource()
        $this.CATempFile = "CATempLocal.json" # temporary file to store Json Data to upload to container (in CA)
        $this.IncrementalDate = $incrementalDate
        $this.ProjectName = $projectName 
        $this.MasterFilePath = (Join-Path (Join-Path (Join-Path $this.AzSKTempStatePath $this.OrganizationName) $this.projectName) $this.IncrementalScanTimestampFile)
        $this.ControlSettings = [ConfigurationManager]::LoadServerConfigFile("ControlSettings.json");
        if($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("UsePartialCommits")){
            [PartialScanManager] $partialScanMngr = [PartialScanManager]::GetInstance();
            if(($partialScanMngr.IsPartialScanInProgress($this.OrganizationName, $false) -eq [ActiveStatus]::Yes)){
                $this.isPartialScanActive = $true
            }
        } 
               
    }
    hidden [datetime] GetThresholdTime([string] $resourceType)
    {
        # function to retrieve threshold time from storage, based on scan source.
        $latestScan = 0
        if($this.ScanSource -ne "CA" -and $this.ScanSource -ne "CICD")
        {
            if(![string]::isnullorwhitespace($this.OrganizationName))
            {
                if(Test-Path $this.MasterFilePath)	
                {
                    # File exists. Retrieve last timestamp.
                    $this.ResourceTimestamps = Get-Content $this.MasterFilePath | ConvertFrom-Json

                    if(-not ([Helpers]::CheckMember($this.ResourceTimestamps, $resourceType)) -or $null -eq $this.ResourceTimestamps.$resourceType -or [datetime]$this.ResourceTimestamps.$resourceType.LastScanTime -eq 0)
                    {
                        # Previous timestamp does not exist for this resource in the existing file.
                        $this.FirstScan = $true
                    }
                }
                else 
                {
                    #file does not exist
                    $this.FirstScan = $true
                }
            }
        }
        elseif ($this.ScanSource -eq 'CA') 
        {
            $this.MasterFilePath = (Join-Path (Join-Path (Join-Path $this.AzSKTempStatePath $this.OrganizationName) $this.ProjectName) $this.IncrementalScanTimestampFile)
            $tempPath = Join-Path $([Constants]::AzSKAppFolderPath) $this.CATempFile
            $blobPath = Join-Path (Join-Path (Join-Path "IncrementalScan" $this.OrganizationName) $this.ProjectName) $this.IncrementalScanTimestampFile
            try 
            {
				#Validate if Storage is found 
				$keys = Get-AzStorageAccountKey -ResourceGroupName $env:StorageRG -Name $env:StorageName
				$this.StorageContext = New-AzStorageContext -StorageAccountName $env:StorageName -StorageAccountKey $keys[0].Value -Protocol Https
				$this.ContainerObject = Get-AzStorageContainer -Context $this.StorageContext -Name $this.CAScanProgressSnapshotsContainerName -ErrorAction SilentlyContinue 

                if($null -ne $this.ContainerObject)
				{
                    #container exists
					$this.ControlStateBlob = Get-AzStorageBlob -Container $this.CAScanProgressSnapshotsContainerName -Context $this.StorageContext -Blob $blobPath -ErrorAction SilentlyContinue 
                    if($null -ne $this.ControlStateBlob)
                    {
                        # File exists. Copy existing timestamp file locally 
						Get-AzStorageBlobContent -CloudBlob $this.ControlStateBlob.ICloudBlob -Context $this.StorageContext -Destination $tempPath -Force                
						$this.ResourceTimestamps  = Get-ChildItem -Path $tempPath -Force | Get-Content | ConvertFrom-Json
						#Delete the local file
						Remove-Item -Path $tempPath
                        if(-not ([Helpers]::CheckMember($this.ResourceTimestamps, $resourceType)) -or $null -eq $this.ResourceTimestamps.$resourceType -or [datetime]$this.ResourceTimestamps.$resourceType.LastScanTime -eq 0)
                        {
                            # Previous timestamp does not exist for current resource in existing file.
                            $this.FirstScan = $true
                        }
                    }
                    else 
                    {
                        # File does not exist. 
                        $this.FirstScan = $true
                    }
                }
                else 
                {
                    # Container does not exist
                    $this.FirstScan = $true
                }
            }
            catch
            {
                write-host "Exception when trying to find/create incremental scan container: $_."
            }
        }
        elseif($this.ScanSource -eq 'CICD'){
            if (Test-Path env:incrementalScanURI)
            {
                #Uri is created in cicd task based on jobid
                $uri = $env:incrementalScanURI
            }
            else {
                $uri = [Constants]::StorageUri -f $this.OrgName, $this.OrgName, "IncrementalScanFile"
            }
            try {
                #check if file already in extension sotrage
                $webRequestResult = [WebRequestHelper]::InvokeGetWebRequest($uri)
                if($null -ne $webRequestResult){
                    $this.ResourceTimestamps = $webRequestResult | ConvertFrom-Json
                    if(-not ([Helpers]::CheckMember($this.ResourceTimestamps, $resourceType)) -or $null -eq $this.ResourceTimestamps.$resourceType -or [datetime]$this.ResourceTimestamps.$resourceType.LastScanTime -eq 0)
                    {
                        # Previous timestamp does not exist for this resource in the existing file.
                        $this.FirstScan = $true
                        $this.isIncFileAlreadyAvailable = $true;
                    }
                }
                else{
                    $this.FirstScan = $true
                    $this.isIncFileAlreadyAvailable = $false;
                }                
            }
            catch
            {
                $this.FirstScan = $true
                $this.isIncFileAlreadyAvailable = $false;
            }
        }
        if(-not $this.FirstScan)
        {
            if($this.isPartialScanActive){
                $latestScan = [datetime]$this.ResourceTimestamps.$resourceType.LastPartialTime
                #to check if full scan is currently in progress, if we dont check this and give -dt switch full scan wont work
                if($this.ResourceTimestamps.$resourceType.IsFullScanInProgress){
                    $this.IsFullScanInProgress = $true
                }
                else{
                    $this.IsFullScanInProgress = $false 
                }
            }
            else {
                $latestScan = [datetime]$this.ResourceTimestamps.$resourceType.LastScanTime  
                $this.IsFullScanInProgress = $false      
                
            }
            $this.LastFullScan = [datetime]$this.ResourceTimestamps.$resourceType.LastFullScanTime
            
        }
        if($this.IncrementalDate -ne 0)
        {
            # user input of incremental date to be used for scanning incrementally.
            $latestScan = $this.IncrementalDate
            if($this.ScanSource -eq 'CA'){
                $FromTimeZone = [System.TimeZoneInfo]::FindSystemTimeZoneById("Asia/Kolkata")
                $latestScan = [DateTime]::SpecifyKind((Get-Date $latestScan), [DateTimeKind]::Unspecified)
                $latestScan = [System.TimeZoneInfo]::ConvertTimeToUtc($latestScan, $FromTimeZone)

            }
        }
        return $latestScan
    }
    
    UpdateTimeStamp([string] $resourceType)
    {
        # Updates timestamp of current scan to storage, based on scan source.
        if($this.UpdateTime -ne $true)
        {
            return;
        }
        if($this.isPartialScanActive){
            return;
        }
        if($this.ScanSource -ne "CA" -and $this.ScanSource -ne "CICD")
        {
            if($this.FirstScan -eq $true)
            {
                # Check if file exists 
                if((-not (Test-Path ($this.AzSKTempStatePath))) -or (-not (Test-Path (Join-Path $this.AzSKTempStatePath $this.OrganizationName))) -or (-not (Test-Path $this.MasterFilePath)))
                {
                    # Incremental Scan happening first time locally OR Incremental Scan happening first time for Org OR first time for current Project
                    New-Item -Type Directory -Path (Join-Path (Join-Path $this.AzSKTempStatePath $this.OrganizationName) $this.ProjectName) -ErrorAction Stop | Out-Null
                    $this.ResourceTimestamps = [IncrementalScanTimestamps]::new()
                    $resourceScanTimes = [IncrementalTimeStampsResources]@{
                        LastScanTime = $this.Timestamp;
                        LastFullScanTime = $this.Timestamp;
                        LastPartialTime = "0001-01-01T00:00:00.0000000";
                        IsFullScanInProgress = $false
                    }
                    $this.ResourceTimestamps.$resourceType = $resourceScanTimes                 
                    [JsonHelper]::ConvertToJsonCustom($this.ResourceTimestamps) | Out-File $this.MasterFilePath -Force
                }
                else 
                {
                    # File exists for Organization and Project but first time scan for current resource type
                    $this.ResourceTimestamps = Get-ChildItem -Path $this.MasterFilePath -Force | Get-Content | ConvertFrom-Json
                    $resourceScanTimes = [IncrementalTimeStampsResources]@{
                        LastScanTime = $this.Timestamp;
                        LastFullScanTime = $this.Timestamp;
                        LastPartialTime = "0001-01-01T00:00:00.0000000";
                        IsFullScanInProgress = $false
                    }
                    $this.ResourceTimestamps.$resourceType = $resourceScanTimes
                                       
                    [JsonHelper]::ConvertToJsonCustom($this.ResourceTimestamps) | Out-File $this.MasterFilePath -Force    
                }
            }
            else 
            {
                # Not a first time scan for the current resource
                $this.ResourceTimestamps = Get-ChildItem -Path $this.MasterFilePath -Force | Get-Content | ConvertFrom-Json
                $previousScanTime = $this.ResourceTimestamps.$resourceType.LastScanTime;
                $this.ResourceTimestamps.$resourceType.LastPartialTime= $previousScanTime
                if($this.IsFullScanInProgress -eq $false){
                    $this.ResourceTimestamps.$resourceType.IsFullScanInProgress = $false
                }
                #if old scan, we trigger full scan, store full scan value, also reset upc scan time
                if($this.ShouldDiscardOldScan){
                    $this.ResourceTimestamps.$resourceType.LastFullScanTime = $this.Timestamp
                    $this.ResourceTimestamps.$resourceType.LastPartialTime = "0001-01-01T00:00:00.0000000";
                    $this.ResourceTimestamps.$resourceType.IsFullScanInProgress = $true
                }   
                $this.ResourceTimestamps.$resourceType.LastScanTime = $this.Timestamp
                [JsonHelper]::ConvertToJsonCustom($this.ResourceTimestamps) | Out-File $this.MasterFilePath -Force
            }
        }
        elseif ($this.ScanSource -eq 'CA') 
        {
            $tempPath = Join-Path $([Constants]::AzSKAppFolderPath) $this.CATempFile
            $blobPath = Join-Path (Join-Path (Join-Path "IncrementalScan" $this.OrganizationName) $this.ProjectName) $this.IncrementalScanTimestampFile
            if ($this.FirstScan -eq $true) 
            {
                # Check if container object does not exist 
                if($null -eq $this.ContainerObject)
                {
                    # Container does not exist, create container.
                    $this.ContainerObject = New-AzStorageContainer -Name $this.CAScanProgressSnapshotsContainerName -Context $this.StorageContext -ErrorAction SilentlyContinue
					if ($null -eq $this.ContainerObject )
					{
                    	$this.PublishCustomMessage("Could not find/create partial scan container in storage.", [MessageType]::Warning);
					}
                    $this.ResourceTimestamps = [IncrementalScanTimestamps]::new()
				}
                if($null -eq $this.ControlStateBlob)
                {
                    $this.ResourceTimestamps = [IncrementalScanTimestamps]::new()
                }
                else 
                {
                    Get-AzStorageBlobContent -CloudBlob $this.ControlStateBlob.ICloudBlob -Context $this.StorageContext -Destination $tempPath -Force                
					$this.ResourceTimestamps  = Get-ChildItem -Path $tempPath -Force | Get-Content | ConvertFrom-Json
					#Delete the local file
                    Remove-Item -Path $tempPath

                }
                $resourceScanTimes = [IncrementalTimeStampsResources]@{
                    LastScanTime = $this.Timestamp;
                    LastFullScanTime = $this.Timestamp;
                    LastPartialTime = "0001-01-01T00:00:00.0000000";
                    IsFullScanInProgress = $false
                }
                $this.ResourceTimestamps.$resourceType = $resourceScanTimes             
                                 
                [JsonHelper]::ConvertToJsonCustom($this.ResourceTimestamps) | Out-File $tempPath -Force
                Set-AzStorageBlobContent -File $tempPath -Container $this.ContainerObject.Name -Blob $blobPath -Context $this.StorageContext -Force
                Remove-Item -Path $tempPath
            }
            else 
            {
                Get-AzStorageBlobContent -CloudBlob $this.ControlStateBlob.ICloudBlob -Context $this.StorageContext -Destination $tempPath -Force                
				$this.ResourceTimestamps  = Get-ChildItem -Path $tempPath -Force | Get-Content | ConvertFrom-Json
                $previousScanTime = $this.ResourceTimestamps.$resourceType.LastScanTime;
                $this.ResourceTimestamps.$resourceType.LastPartialTime = $previousScanTime
                if($this.IsFullScanInProgress -eq $false){
                    $this.ResourceTimestamps.$resourceType.IsFullScanInProgress = $false
                }            
                if($this.ShouldDiscardOldScan){
                    $this.ResourceTimestamps.$resourceType.LastFullScanTime = $this.Timestamp
                    $this.ResourceTimestamps.$resourceType.LastPartialTime  = "0001-01-01T00:00:00.0000000";
                    $this.ResourceTimestamps.$resourceType.IsFullScanInProgress = $true
                }
                
				# Delete the local file
                Remove-Item -Path $tempPath
                $this.ResourceTimestamps.$resourceType.LastScanTime = $this.Timestamp
                [JsonHelper]::ConvertToJsonCustom($this.ResourceTimestamps) | Out-File $tempPath -Force
                Set-AzStorageBlobContent -File $tempPath -Container $this.ContainerObject.Name -Blob $blobPath -Context $this.StorageContext -Force
                Remove-Item -Path $tempPath
            }
        }
        elseif($this.ScanSource -eq 'CICD'){
            $incrementalScanPayload = $null
            if($this.FirstScan -eq $true){
                #first scan for the pipeline for all resources
                if($this.isIncFileAlreadyAvailable -eq $false){
                    $this.ResourceTimestamps = [IncrementalScanTimestamps]::new()                  
                }           
                #will be called for both scenarios: first scan for the resource as well as for the entire pipeline
                $resourceScanTimes = [IncrementalTimeStampsResources]@{
                        LastScanTime = $this.Timestamp;
                        LastFullScanTime = $this.Timestamp;
                        LastPartialTime = "0001-01-01T00:00:00.0000000";
                        IsFullScanInProgress = $false
                    }
                $this.ResourceTimestamps.$resourceType = $resourceScanTimes                 
                $incrementalScanPayload = [JsonHelper]::ConvertToJsonCustom($this.ResourceTimestamps)
            }
            #not a first scan
            else{
                $previousScanTime = $this.ResourceTimestamps.$resourceType.LastScanTime;
                $this.ResourceTimestamps.$resourceType.LastPartialTime= $previousScanTime
                if($this.IsFullScanInProgress -eq $false){
                    $this.ResourceTimestamps.$resourceType.IsFullScanInProgress = $false
                }
                #if old scan, we trigger full scan, store full scan value, also reset upc scan time
                if($this.ShouldDiscardOldScan){
                    $this.ResourceTimestamps.$resourceType.LastFullScanTime = $this.Timestamp
                    $this.ResourceTimestamps.$resourceType.LastPartialTime = "0001-01-01T00:00:00.0000000";
                    $this.ResourceTimestamps.$resourceType.IsFullScanInProgress = $true
                }   
                $this.ResourceTimestamps.$resourceType.LastScanTime = $this.Timestamp
                $incrementalScanPayload = [JsonHelper]::ConvertToJsonCustom($this.ResourceTimestamps)
            }
            try{
                $rmContext = [ContextHelper]::GetCurrentContext();
                $user = "";
                $uri = "";
                $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$rmContext.AccessToken)))               
                $body = "";
                if (Test-Path env:incrementalScanURI)
                {
                    $uri = $env:incrementalScanURI
                    $JobId ="";
                    $JobId = $uri.Replace('?','/').Split('/')[$JobId.Length -2]
                    #if the incremental scan is already present need to update the existing file
                    if ($this.FirstScan -eq $false -or $this.isIncFileAlreadyAvailable -eq $true){
                        $body = @{"id" = $Jobid; "__etag"=-1; "value"= $incrementalScanPayload;} | ConvertTo-Json
                    }
                    else{
                        $body = @{"id" = $Jobid; "value"= $incrementalScanPayload;} | ConvertTo-Json
                    }
                }
                else {
                    $uri = [Constants]::StorageUri -f $this.OrgName, $this.OrgName, "IncrementalScanFile"
                    if ($this.FirstScan -eq $false -or $this.isIncFileAlreadyAvailable -eq $true){
                        $body = @{"id" = "IncrementalScanFile";"__etag"=-1; "value"= $incrementalScanPayload;} | ConvertTo-Json
                    }
                    else{
                        $body = @{"id" = "IncrementalScanFile"; "value"= $incrementalScanPayload;} | ConvertTo-Json
                    }
                }
                $webRequestResult = Invoke-WebRequest -Uri $uri -Method Put -ContentType "application/json" -Headers @{Authorization = ("Basic {0}" -f $base64AuthInfo) } -Body $body 
                        
            }
            catch{  
                Write-Host "Error updating Incremental Scan file: $($_)"
            }
        }
    }

    [bool] IsIncScanOld($resourceType){
        $this.GetThresholdTime($resourceType)
        if($this.FirstScan){
            return $false;
        }        
        if($this.LastFullScan.AddDays($this.ControlSettings.IncrementalScan.IncrementalScanValidForDays) -lt [DateTime]::UtcNow){
            return $true;
        }     
     
        return $false;
    }

    [bool] ShouldDiscardOldIncScan($resourceType){
        $this.ShouldDiscardOldScan = $false
        if($this.IsIncScanOld($resourceType)){
            if($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Force')){
                $this.ShouldDiscardOldScan = $false
            }
            else{
                $this.ShouldDiscardOldScan = $true
            }
            
        }
        return $this.ShouldDiscardOldScan;
    }
    [System.Object[]] GetModifiedBuilds($buildDefnsObj)
    {       
        # Function to filter builds that have been modified after threshold time
        $latestBuildScan = $this.GetThresholdTime("Build")        
        if($this.FirstScan -eq $true -and $this.IncrementalDate -eq 0)
        {
            $this.UpdateTimeStamp("Build")
            return $buildDefnsObj
        }
        #if inc scan last time is 0 or if this is a full scan partial checkpoint, return all builds
        if($this.isPartialScanActive -and ($latestBuildScan -eq 0 -or $this.IsFullScanInProgress)){
            return $buildDefnsObj
        }
        #if scan is old and no upc file found, simply return all builds, update scan time for full scans and last scan
        if($this.ShouldDiscardOldIncScan('Build') -and -not($this.isPartialScanActive)){            
            $this.UpdateTimeStamp("Build")
            return $buildDefnsObj
        }

        $newBuildDefns = @()
        if ([datetime] $buildDefnsObj[0].createdDate -lt $latestBuildScan) 
        {
            # first resource is modified before the threshold time => all consequent are also modified before threshold
            # return empty list
            $this.UpdateTimeStamp("Build")
            return $newBuildDefns
        }
        #Binary search 
        [int] $low = 0 # start index of array
        [int] $high = $buildDefnsObj.length - 1 # last index of array
        [int] $size = $buildDefnsObj.length # total length of array 
        [int] $breakIndex = 0
        while($low -le $high)
        {
            [int] $mid = ($low + $high)/2 # seeking the middle of the array 
            [datetime] $modifiedDate = [datetime]($buildDefnsObj[$mid].createdDate)
            if($modifiedDate -ge $latestBuildScan)
            {
                # modified date is after the threshold time
                if(($mid + 1) -eq $size)
                {
                    # all fetched build defs are modified after threshold time
                    # return unmodified
                    $this.UpdateTimeStamp("Build")
                    return $buildDefnsObj
                }
                else 
                {
                    # mid point is not the last build defn
                    if([datetime]($buildDefnsObj[$mid+1].createdDate) -lt $latestBuildScan)
                    {
                        # changing point found
                        $breakIndex = $mid
                        break
                    }
                    else 
                    {
                        # search on right half
                        $low = $mid + 1
                    }
                }
            }
            elseif ($modifiedDate -lt $latestBuildScan) 
            {
                if($mid -eq 0)
                {
                    # All fetched builds have been modified before the threshold
                    return $newBuildDefns
                }
                else 
                {
                    if([datetime]($buildDefnsObj[$mid - 1].createdDate)  -ge $latestBuildScan)
                    {
                        # changing point found
                        $breakIndex = $mid - 1
                        break
                    }    
                    else 
                    {
                        # search on left half
                        $high = $mid - 1
                    }
                }
            }
        }
        $newBuildDefns = @($buildDefnsObj[0..$breakIndex])
        $this.UpdateTimeStamp("Build")
        return $newBuildDefns
    }
    [System.Object[]] GetModifiedReleases($releaseDefnsObj)
    {
        $latestReleaseScan = $this.GetThresholdTime("Release")
        if($this.FirstScan -eq $true -and $this.IncrementalDate -eq 0)
        {
            $this.UpdateTimeStamp("Release")
            return $releaseDefnsObj
        }
        if($this.isPartialScanActive -and ($latestReleaseScan -eq 0 -or $this.IsFullScanInProgress)){
            return $releaseDefnsObj
        }
        
        if($this.ShouldDiscardOldIncScan('Release')){
            $this.UpdateTimeStamp("Release")
            return $releaseDefnsObj
        }
        $newReleaseDefns = @()
        # Searching Linearly
        foreach ($releaseDefn in $releaseDefnsObj)
        {
            if ([datetime]($releaseDefn.modifiedOn) -ge $latestReleaseScan) 
            {
                $newReleaseDefns += @($releaseDefn)    
            }
        }
        $this.UpdateTimeStamp("Release")
        return $newReleaseDefns                
    }

    #Get all resources attested after the latest scan
    [System.Object[]] GetAttestationAfterInc($projectName, $resourceType){
        $resourceIds = @();
        #if parameter not specified, wont be fetching these resources
        if(-not($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('ScanAttestedResources'))){
            return $resourceIds
        }
        $latestResourceScan = $this.GetThresholdTime($resourceType)
        if($this.ScanSource -ne 'CA'){
            $latestResourceScan=$latestResourceScan.ToUniversalTime();
        }
        $latestResourceScan =Get-Date $latestResourceScan -Format s        
        if($this.FirstScan -eq $true -and $this.IncrementalDate -eq 0){
            return $resourceIds;   
        }
        [ControlStateExtension] $ControlStateExt = [ControlStateExtension]::new($this.OrganizationContext, $PSCmdlet.MyInvocation);
        $output = $ControlStateExt.RescanComputeControlStateIndexer($projectName, 'ADO.'+$resourceType);
        $output | ForEach-Object {
			if($_.AttestedDate -gt $latestResourceScan){
                try {                    
                    $resourceIds += ($_.ResourceId -split ($resourceType.ToLower() + "/"))[1]                  				
				
                }
				catch {

				}
			}
		}
        return $resourceIds
    }


    [System.Object[]] GetAuditTrailsForBuilds(){
        $latestBuildScan = $this.GetThresholdTime("Build")
        if($this.ScanSource -ne 'CA'){
            $latestBuildScan=$latestBuildScan.ToUniversalTime();
        }        
        $latestBuildScan =Get-Date $latestBuildScan -Format s
        $buildIds = @();
        if($this.FirstScan -eq $true -and $this.IncrementalDate -eq 0){
            return $buildIds;   
        }
        $auditUrl = "https://auditservice.dev.azure.com/{0}/_apis/audit/auditlog?startTime={1}&api-version=6.0-preview.1" -f $this.OrganizationName, $latestBuildScan
        try {
            $response = [WebRequestHelper]::InvokeGetWebRequest($auditUrl);
            $auditTrails = $response.decoratedAuditLogEntries;
            $modifiedBuilds = $auditTrails | Where-Object {$_.actionId  -eq 'Security.ModifyPermission' -and $_.data.NamespaceName -eq 'Build' -and $_.data.Token -match $this.ProjectId+"/" }
            $restrictedBroaderGroups = @{}
            $broaderGroups = $this.ControlSettings.Build.RestrictedBroaderGroupsForBuild
            $broaderGroups.psobject.properties | foreach { $restrictedBroaderGroups[$_.Name] = $_.Value }
            $modifiedBuilds | foreach {
                $group = ($_.data.SubjectDisplayName -split("\\"))[1]
                if($group -in $restrictedBroaderGroups.keys ){
                    if($_.data.ChangedPermission -in $restrictedBroaderGroups[$group]){
                        $buildIds += (($_.data.Token -split("/"))[-1])
                    }
                }
            }
            $buildIds = $buildIds | Select -Unique
        }
        catch {

        }
        return $buildIds;
    }
    
    [System.Object[]] GetModifiedBuildsFromAudit($buildIds, $projectName){
        $totalBuilds = $buildIds.Count
        $buildDefnObj =@()
        $newBuildDefns = @();
        $queryIdCount = 0;
        $currentbuildIds = ""
        $buildIds | foreach {
            
            if($totalBuilds -lt 100){
                $queryIdCount++;
                $currentbuildIds=$currentbuildIds+$_+","
                if($queryIdCount -eq $totalBuilds){
                    $buildDefnURL = "https://{0}.visualstudio.com/{1}/_apis/build/definitions?definitionIds={2}&api-version=6.0" -f $($this.OrganizationName), $projectName, $currentbuildIds;
                    try {
                        $buildDefnObj += ([WebRequestHelper]::InvokeGetWebRequest($buildDefnURL));
                    }
                    catch {

                    }
                }
            }
            else {
                $queryIdCount++;
                $currentbuildIds=$currentbuildIds+$_+",";
                if($queryIdCount -eq 100){
                    $buildDefnURL = "https://{0}.visualstudio.com/{1}/_apis/build/definitions?definitionIds={2}&api-version=6.0" -f $($this.OrganizationName), $projectName, $currentbuildIds;
                    try {
                        $buildDefnObj += ([WebRequestHelper]::InvokeGetWebRequest($buildDefnURL));
                        $queryIdCount =0;
                        $currentbuildIds="";
                        $totalBuilds -=100;                        
                    }
                    catch {

                    }
                }

            }
        }
        $latestBuildScan = $this.GetThresholdTime("Build");             
        foreach ($buildDefn in $buildDefnObj)
        {
            if ([Helpers]::CheckMember($buildDefn,'CreatedDate') -and [datetime]($buildDefn.CreatedDate) -lt $latestBuildScan) 
            {
                $newBuildDefns += @($buildDefn)    
            }
        }
     
        return $newBuildDefns;
    }

    [System.Object[]] GetAuditTrailsForReleases(){
        $latestReleaseScan = $this.GetThresholdTime("Release");
        if($this.ScanSource -ne 'CA'){
            $latestReleaseScan=$latestReleaseScan.ToUniversalTime();
        }
        $latestReleaseScan = Get-Date $latestReleaseScan -Format s
        $releaseIds = @();
        if($this.FirstScan -eq $true -and $this.IncrementalDate -eq 0){
            return $releaseIds;   
        }
        $auditUrl = "https://auditservice.dev.azure.com/{0}/_apis/audit/auditlog?startTime={1}&api-version=6.0-preview.1" -f $this.OrganizationName, $latestReleaseScan
        try {
            $response = [WebRequestHelper]::InvokeGetWebRequest($auditUrl);
            $auditTrails = $response.decoratedAuditLogEntries;
            $modifiedReleases = $auditTrails | Where-Object {$_.actionId  -eq 'Security.ModifyPermission' -and $_.data.NamespaceName -eq 'ReleaseManagement' -and $_.data.Token -match $this.ProjectId+"/" }
            $restrictedBroaderGroups = @{}
            $broaderGroups = $this.ControlSettings.Release.RestrictedBroaderGroupsForRelease
            $broaderGroups.psobject.properties | foreach { $restrictedBroaderGroups[$_.Name] = $_.Value }
            $modifiedReleases| foreach {
                $group = ($_.data.SubjectDisplayName -split("\\"))[1]
                if($group -in $restrictedBroaderGroups.keys ){
                    if($_.data.ChangedPermission -in $restrictedBroaderGroups[$group]){
                        $releaseIds += (($_.data.Token -split("/"))[-1])
                    }
                }
            }
            $releaseIds = $releaseIds | Select -Unique
        }
        catch {

        }
        return $releaseIds;
    }
    
    [System.Object[]] GetModifiedReleasesFromAudit($releaseIds, $projectName){
        $totalReleases = $releaseIds.Count
        $newReleaseDefns = @();
        $releaseDefnObj =@()
        $queryIdCount = 0;
        $currentReleaseIds = ""
        $releaseIds | foreach {
            
            if($totalReleases -lt 100){
                $queryIdCount++;
                $currentReleaseIds=$currentReleaseIds+$_+","
                if($queryIdCount -eq $totalReleases){
                    $releaseDefnURL = "https://vsrm.dev.azure.com/{0}/{1}/_apis/release/definitions?definitionIdFilter={2}&api-version=6.0" -f $($this.OrganizationName), $projectName, $currentReleaseIds;
                    try {
                        $releaseDefnObj += ([WebRequestHelper]::InvokeGetWebRequest($releaseDefnURL));
                    }
                    catch {

                    }
                }
            }
            else {
                $queryIdCount++;
                $currentReleaseIds=$currentReleaseIds+$_+",";
                if($queryIdCount -eq 100){
                    $releaseDefnURL = "https://vsrm.dev.azure.com/{0}/{1}/_apis/release/definitions?definitionIdFilter={2}&api-version=6.0" -f $($this.OrganizationName), $projectName, $currentReleaseIds;
                    try {
                        $releaseDefnObj += ([WebRequestHelper]::InvokeGetWebRequest($releaseDefnURL));
                        $queryIdCount =0;
                        $currentReleaseIds="";
                        $totalReleases -=100;                        
                    }
                    catch {

                    }
                }

            }
        }   
        $latestReleaseScan = $this.GetThresholdTime("Release");          
        foreach ($releaseDefn in $releaseDefnObj)
        {
            if ([Helpers]::CheckMember($releaseDefn,'modifiedOn') -and [datetime]($releaseDefn.modifiedOn) -lt $latestReleaseScan) 
            {
                $newReleaseDefns += @($releaseDefn)    
            }
        }       
      
        return $newReleaseDefns;
    }

    
    #common function to get modified resource ids from audits for common svts and variable group
    [System.Object[]] GetModifiedCommonSvtAuditTrails($resourceType){
        $resourceIds = @()
        #get last scan of the resources
        $latestScan = $this.GetThresholdTime($resourceType)
        if($this.ScanSource -ne 'CA'){
            $latestScan=$latestScan.ToUniversalTime();
        }        
        $latestScan = Get-Date $latestScan -Format s
        
        $auditUrl = "https://auditservice.dev.azure.com/{0}/_apis/audit/auditlog?startTime={1}&api-version=6.0-preview.1" -f $this.OrganizationName, $latestScan
        try {
            $response = [WebRequestHelper]::InvokeGetWebRequest($auditUrl);
            $auditTrails = $response.decoratedAuditLogEntries;
            #get modified resources from filter
            $modifiedResources = $this.GetModifiedResourcesFilter($resourceType,$auditTrails)                        
            $modifiedResources | foreach {
                #extract resource ids from modified resources
                $resourceIds+=($_.data.([IncrementalScanHelper]::auditSchema.$resourceType.AuditEvents.($_.actionId)[1]) -split("/"))[-1]
                if($resourceType -eq "GitRepositories"){
                    #to handle events of permission changes on branches
                    $resourceIds+=(($_.data.([IncrementalScanHelper]::auditSchema.$resourceType.AuditEvents.($_.actionId)[1]) -split("/refs"))[0]) -split("/")[-1]
                    #to handle events of new repository creation
                    $resourceIds+=($_.data.([IncrementalScanHelper]::auditSchema.$resourceType.AuditEvents.($_.actionId)[1]) -split("\."))[-1]
                }
            }
            $resourceIds = $resourceIds | Select -Unique
        }
        catch {

        }
        return $resourceIds
    }

    #function to filter audits according to resource type
    [System.Object[]] GetModifiedResourcesFilter($resourceType,$auditTrails){
        $resourceTypeInFilter = $resourceType
        #in case of secure file and variable group the resource type in audits is library, for other resources the name is same
        if($resourceType -eq "SecureFile" -or $resourceType -eq "VariableGroup"){
            $resourceTypeInFilter = "Library"
        }
        if($resourceType -eq "GitRepositories"){
                $resourceTypeInFilter = "Git Repositories"
        }
        $modifiedResources = $auditTrails | Where-Object {$_.actionId  -in [IncrementalScanHelper]::auditSchema.$resourceType.AuditEvents.PSObject.Properties.Name -and  ([IncrementalScanHelper]::auditSchema.$resourceType.AuditEvents.($_.actionId)[0] -eq $true -or( $_.Data.([IncrementalScanHelper]::auditSchema.$resourceType.AuditEvents.($_.actionId)[0]) -eq $resourceTypeInFilter -or $_.Data.([IncrementalScanHelper]::auditSchema.$resourceType.AuditEvents.($_.actionId)[0]) -eq "repository" -or $_.Data.([IncrementalScanHelper]::auditSchema.$resourceType.AuditEvents.($_.actionId)[0]) -eq $resourceType))}
        
        return $modifiedResources

    }

    #function to get modified resources 
    [System.Object[]] GetModifiedCommonSvtFromAudit($resourceType,$response){
        $latestScan = $this.GetThresholdTime($resourceType)      
        $latestScan =Get-Date $latestScan -Format s
        #$response = [WebRequestHelper]::InvokeGetWebRequest($url);
        #if this a first scan return all resources
        if($this.FirstScan -eq $true -and $this.IncrementalDate -eq 0){    
            $this.UpdateTimeStamp($resourceType)        
            return $response   
        }
        #if partial scan is active and last scan is 0 or this is a full scan in progress return all resources
        if($this.isPartialScanActive -and ($latestScan -eq 0 -or $this.IsFullScanInProgress)){
            return $response
        }
        #if this is a old scan return all resources
        if($this.ShouldDiscardOldIncScan($resourceType)){
            $this.UpdateTimeStamp($resourceType)
            return $response
        }
        #get ids from above functions
        $modifiedResourceIds = @($this.GetModifiedCommonSvtAuditTrails($resourceType)); 
        if($resourceType -eq "GitRepositories"){
            $modifiedResourceIdsFromAttestation = @($this.GetAttestationAfterInc($this.ProjectName,"Repository"))
        }
        else{
            $modifiedResourceIdsFromAttestation = @($this.GetAttestationAfterInc($this.ProjectName,$resourceType))
        }
        $modifiedResourceIds = @($modifiedResourceIds + $modifiedResourceIdsFromAttestation | select -uniq)
        
        $modifiedResources = @()
        #if we get some ids from audit trails add them to modified resource obj
        if($modifiedResourceIds.Count -gt 0 -and $null -ne $modifiedResourceIds[0]){
            #filter all ids from audit trails in the api response
            $modifiedResources = @($response | Where-Object{$modifiedResourceIds -contains $_.id})
            #to capture events that dont come in audits but is reflected in api responses such as new resource created, properties of resources edited etc.
            if([Helpers]::CheckMember([IncrementalScanHelper]::auditSchema.$resourceType, "ApiResponseFilter")){
                $modifiedResources +=$response | Where-Object{$modifiedResourceIds -notcontains $_.id -and [datetime]($_.([IncrementalScanHelper]::auditSchema.$resourceType.ApiResponseFilter)) -gt $latestScan}
                
            }
        }
        #in case no ids were obtained from audits check from response for corresponding api response filtee if present
        else{
            if([Helpers]::CheckMember([IncrementalScanHelper]::auditSchema.$resourceType, "ApiResponseFilter")){
                $modifiedResources += $response | Where-Object{[datetime]($_.([IncrementalScanHelper]::auditSchema.$resourceType.ApiResponseFilter)) -gt $latestScan}
            }
        }
        $this.UpdateTimeStamp($resourceType)
        return $modifiedResources
    }

    [void] SetContext($projectId,$organizationContext){
        $this.ProjectId = $projectId
        $this.OrganizationContext = $organizationContext
    }

}