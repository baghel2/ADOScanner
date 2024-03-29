Set-StrictMode -Version Latest

class CommonSVTResourceResolver {
    [string] $ResourceType = "";
    [ResourceTypeName] $ResourceTypeName = [ResourceTypeName]::All;

    [string] $organizationName
    [string] $organizationId
    [string] $projectId
    [psobject] $feedDefnsObj = $null
    [bool] $UseIncrementalScan = $false
    [bool] $IsAutomatedFixUndoCmd = $false;
    [DateTime] $IncrementalDate = 0
    [PSObject] $organizationContext

    CommonSVTResourceResolver($organizationName, $organizationId, $projectId, $organizationContext, $IsAutomatedFixUndoCmd) {
        $this.organizationName = $organizationName;
        $this.organizationId = $organizationId;
        $this.projectId = $projectId;
        $this.organizationContext = $organizationContext
        $this.IsAutomatedFixUndoCmd = $IsAutomatedFixUndoCmd
        if($PSCmdlet.MyInvocation.BoundParameters["IncrementalScan"]){
            $this.UseIncrementalScan = $true
            if (-not [string]::IsNullOrWhiteSpace($PSCmdlet.MyInvocation.BoundParameters["IncrementalDate"])) 
                {
                    $this.IncrementalDate = $PSCmdlet.MyInvocation.BoundParameters["IncrementalDate"]  
                }
                else 
                {
                    $this.IncrementalDate = [datetime] 0    
                }
            
        }
    }

    [SVTResource[]] LoadResourcesForScan($projectName, $repoNames, $secureFileNames, $feedNames, $environmentNames, $ResourceTypeName, $MaxObjectsToScan, $isServiceIdBasedScan) {
        #Get resources  

        [System.Collections.Generic.List[SVTResource]] $SVTResources = @();
        if ($repoNames.Count -gt 0 -or ($ResourceTypeName -in ([ResourceTypeName]::Repository, [ResourceTypeName]::All,[ResourceTypeName]::Build_Release_SvcConn_AgentPool_VarGroup_User_CommonSVTResources, [ResourceTypeName]::SvcConn_AgentPool_VarGroup_CommonSVTResources) -and !$isServiceIdBasedScan) ) {

            #Write-Host "Getting repository configurations..." -ForegroundColor cyan
            if ($ResourceTypeName -in([ResourceTypeName]::Repository, [ResourceTypeName]::SvcConn_AgentPool_VarGroup_CommonSVTResources) -and $repoNames.Count -eq 0) {
                $repoNames += "*";
            }
            $repoObjList = @();
            #if rtn Build_Release_SvcConn_AgentPool_VarGroup_User_CommonSVTResources and resource name not provided (neither * nor any name) no need to fetch this resource
            if($repoNames.Count -ne 0){
                $repoObjList += $this.FetchRepositories($projectName, $repoNames);
            }            
            if ($repoObjList.count -gt 0 -and [Helpers]::CheckMember($repoObjList[0], "Id")) {
                $maxObjScan = $MaxObjectsToScan
                foreach ($repo in $repoObjList) {
                    $resourceId = "organization/{0}/project/{1}/repository/{2}" -f $this.organizationId, $this.projectId, $repo.id;
                    $SVTResources.Add($this.AddSVTResource($repo.name, $projectName, "ADO.Repository", $resourceId, $repo, $repo.webUrl));
                    if (--$maxObjScan -eq 0) { break; }
                }

                $repoObjList = $null;
            }
        }
        
        ##Get SecureFiles
        if ($secureFileNames.Count -gt 0 -or ($ResourceTypeName -in ([ResourceTypeName]::SecureFile, [ResourceTypeName]::All,[ResourceTypeName]::Build_Release_SvcConn_AgentPool_VarGroup_User_CommonSVTResources, [ResourceTypeName]::SvcConn_AgentPool_VarGroup_CommonSVTResources) -and !$isServiceIdBasedScan) ) {
            if ($ResourceTypeName -in([ResourceTypeName]::SecureFile, [ResourceTypeName]::SvcConn_AgentPool_VarGroup_CommonSVTResources) -and $secureFileNames.Count -eq 0) {
                $secureFileNames += "*"
            }            
            # Here we are fetching all the secure files in the project.
            $secureFileObjList = @();
            #if rtn Build_Release_SvcConn_AgentPool_VarGroup_User_CommonSVTResources and resource name not provided (neither * nor any name) no need to fetch this resource
            if($secureFileNames.Count -ne 0){
                $secureFileObjList += $this.FetchSecureFiles($projectName, $secureFileNames);
            }            
            if ($secureFileObjList.count -gt 0 -and [Helpers]::CheckMember($secureFileObjList[0], "Id")) {
                $maxObjScan = $MaxObjectsToScan
                foreach ($securefile in $secureFileObjList) {
                    $resourceId = "organization/{0}/project/{1}/securefile/{2}" -f $this.organizationId, $this.projectId, $securefile.Id;
                    $secureFileLink = "https://dev.azure.com/{0}/{1}/_library?itemType=SecureFiles&view=SecureFileView&secureFileId={2}&path={3}" -f $this.organizationName, $projectName, $securefile.Id, $securefile.Name;
                    $SVTResources.Add($this.AddSVTResource($securefile.Name, $projectName, "ADO.SecureFile", $resourceId, $securefile, $secureFileLink));
                    if (--$maxObjScan -eq 0) { break; }
                }

                $secureFileObjList = $null;
            }
        }

        #Get feeds
        if ($feedNames.Count -gt 0 -or ($ResourceTypeName -in ([ResourceTypeName]::Feed, [ResourceTypeName]::All,[ResourceTypeName]::Build_Release_SvcConn_AgentPool_VarGroup_User_CommonSVTResources, [ResourceTypeName]::SvcConn_AgentPool_VarGroup_CommonSVTResources) -and !$isServiceIdBasedScan) ) {
            #Write-Host "Getting feed configurations..." -ForegroundColor cyan
            if ($ResourceTypeName -in([ResourceTypeName]::Feed, [ResourceTypeName]::SvcConn_AgentPool_VarGroup_CommonSVTResources) -and $feedNames.Count -eq 0) {
                $feedNames += "*"
            }

            $feedObjList = @();
            #if rtn Build_Release_SvcConn_AgentPool_VarGroup_User_CommonSVTResources and resource name not provided (neither * nor any name) no need to fetch this resource
            if($feedNames.Count -ne 0){
                $feedObjList += $this.FetchFeeds($projectName, $feedNames);
            }            
            if ($feedObjList.count -gt 0 -and [Helpers]::CheckMember($feedObjList[0], "Id")) {
                $maxObjScan = $MaxObjectsToScan
                foreach ($feed in $feedObjList) {
                    $resourceId = "organization/{0}/project/{1}/feed/{2}" -f $this.organizationId, $this.projectId, $feed.id;
                    $resourceLink = "https://dev.azure.com/{0}/{1}/_packaging?_a=feed&feed={2}" -f $this.organizationName, $projectName, $feed.name;
                    $SVTResources.Add($this.AddSVTResource($feed.name, $projectName, "ADO.Feed", $resourceId, $feed, $resourceLink));
                    if (--$maxObjScan -eq 0) { break; }
                }

                $feedObjList = $null;
            }
        }

        #Get $EnvironmentNames
        if ($environmentNames.Count -gt 0 -or ($ResourceTypeName -in ([ResourceTypeName]::Environment, [ResourceTypeName]::All, [ResourceTypeName]::Build_Release_SvcConn_AgentPool_VarGroup_User_CommonSVTResources, [ResourceTypeName]::SvcConn_AgentPool_VarGroup_CommonSVTResources) -and !$isServiceIdBasedScan)) {
            #Write-Host "Getting feed configurations..." -ForegroundColor cyan
            if ($ResourceTypeName -in([ResourceTypeName]::Environment, [ResourceTypeName]::SvcConn_AgentPool_VarGroup_CommonSVTResources) -and $environmentNames.Count -eq 0) {
                $environmentNames += "*"
            }

            $environmentObjList = @();
            #if rtn Build_Release_SvcConn_AgentPool_VarGroup_User_CommonSVTResources and resource name not provided (neither * nor any name) no need to fetch this resource
            if($environmentNames.Count -ne 0){
                $environmentObjList += $this.FetchEnvironments($projectName, $environmentNames, $MaxObjectsToScan);
            }            
            if ($environmentObjList.count -gt 0 -and [Helpers]::CheckMember($environmentObjList[0], "Id")) {
                $maxObjScan = $MaxObjectsToScan
                foreach ($environment in $environmentObjList) {
                    $resourceId = "organization/{0}/project/{1}/environment/{2}" -f $this.organizationId, $this.projectId, $environment.id;
                    $resourceLink = "https://dev.azure.com/{0}/{1}/_environments/{2}?view=resources" -f $this.organizationName, $environment.project.id, $environment.id;
                    $SVTResources.Add($this.AddSVTResource($environment.name, $projectName, "ADO.Environment", $resourceId, $environment, $resourceLink));
                    if (--$maxObjScan -eq 0) { break; }
                }

                $environmentObjList = $null;
            }
        }

        return $SVTResources;
    }

    hidden [PSObject] FetchRepositories($projectName, $repoNames) {
        try {
            # Here we are fetching all the repositories in the project and then filtering out.
            $repoDefnURL = "";
            $repoDefnURL = "https://dev.azure.com/$($this.organizationName)/$projectName/_apis/git/repositories?api-version=6.1-preview.1"
            $repoDefnsObj = [WebRequestHelper]::InvokeGetWebRequest($repoDefnURL);
            if ($repoNames -ne "*") {
                $repoDefnsObj = $repoDefnsObj | Where-Object { $repoNames -contains $_.name }
            }
            else{
                if($this.UseIncrementalScan){                                    
                    $timestamp = (Get-Date)
                    $incrementalScanHelperObj = [IncrementalScanHelper]::new($this.organizationName, $projectName, $this.IncrementalDate, $true, $timestamp)
                    $incrementalScanHelperObj.SetContext($this.projectId, $this.organizationContext)
                    $repoDefnsObj = $incrementalScanHelperObj.GetModifiedCommonSvtFromAudit("GitRepositories",$repoDefnsObj)
                }
            }

            return $repoDefnsObj;
        }
        catch {
            return $null;
        }
    }

    hidden [PSObject] FetchFeeds($projectName, $feedNames) {
        try {
            #Fetching project and org scoped feeds
            if($null -eq $this.feedDefnsObj)
            {
                #When controls undo fix is called, resources need to be fetched from deleted list (only for controls ids in RevertDeletedResourcesControlList)
                if($this.IsAutomatedFixUndoCmd){
                    $feedDefnURL = 'https://feeds.dev.azure.com/{0}/_apis/Packaging/FeedRecycleBin?api-version=6.0-preview.1&includeUrls=false' -f $this.organizationName
                }
                elseif($PSCmdlet.MyInvocation.BoundParameters["CheckOwnerAccess"]){
                    $feedDefnURL = 'https://feeds.dev.azure.com/{0}/_apis/packaging/feeds?feedRole=administrator&api-version=6.0-preview.1&includeUrls=false' -f $this.organizationName
                }
                else{
                    $feedDefnURL = 'https://feeds.dev.azure.com/{0}/_apis/packaging/feeds?api-version=6.0-preview.1&includeUrls=false' -f $this.organizationName
                }                
                $this.feedDefnsObj = [WebRequestHelper]::InvokeGetWebRequest($feedDefnURL);
            }
            $feedsList = @()
            #current project scoped feeds
            $projectScopedFeeds = $this.feedDefnsObj | where-object {"Project" -in $_.PSobject.Properties.name}
            $feedsList += $projectScopedFeeds | where-object {$_.Project.id -eq $this.projectId}

            #org scoped feeds - Project property does not exist of org scoped feeds
            $feedsList +=  $this.feedDefnsObj | where-object {"Project" -notin $_.PSobject.Properties.name}

            if ($feedNames -ne "*") {
                $feedsList = $feedsList | Where-Object { $feedNames -contains $_.name }
            }            
            else{
                if($this.UseIncrementalScan){                                    
                    $timestamp = (Get-Date)
                    $incrementalScanHelperObj = [IncrementalScanHelper]::new($this.organizationName, $projectName, $this.IncrementalDate, $true, $timestamp)
                    $incrementalScanHelperObj.SetContext($this.projectId, $this.organizationContext)
                    $feedsList = $incrementalScanHelperObj.GetModifiedCommonSvtFromAudit("Feed",$feedsList)
                }
            }
            #Following piece of code is to get a list of all feeds that wont be scanned due to insufficient privileges, will be used only for control fix
            if($PSCmdlet.MyInvocation.BoundParameters["CheckOwnerAccess"]){
                $totalFeedsURL = 'https://feeds.dev.azure.com/{0}/_apis/packaging/feeds?api-version=6.0-preview.1&includeUrls=false' -f $this.organizationName
                $totalFeedsObj = [WebRequestHelper]::InvokeGetWebRequest($totalFeedsURL);
                $totalFeeds=@();
                $totalFeeds += $totalFeedsObj | where-object {"Project" -in $_.PSobject.Properties.name -and $_.Project.id -eq $this.projectId}
                $totalFeeds +=  $totalFeedsObj | where-object {"Project" -notin $_.PSobject.Properties.name}
                $nonScannedResources = @();
                #get all feeds not being scanned
                $nonScannedResources += ((Compare-Object $totalFeeds $feedsList -Property name,id) | select -ExpandProperty name)
                #update the list with the corresponding resource links
                $nonScannedResources = $nonScannedResources | foreach{
                    $_ =  "https://dev.azure.com/{0}/{1}/_packaging?_a=feed&feed={2}" -f $this.organizationName, $projectName, $_;
                    $_;
                }
                try{
                    #saving this in an env variable as we have to access it while saving a list of these resources in logs.
                    $env:nonScannedResources +=$nonScannedResources
                }
                catch{
                    #TODO: in case of higher number of feeds, this env variable may not be stored
                    #in such cases the scan should work properly with owner access feeds even if nonscannedresources.json cannot be formed
                    if($_ -like "Environment variable name or value is too long"){
                        $env:nonScannedResources = $null;
                    }
                }
                if([Helpers]::CheckMember($feedsList[0],"id")){
                    $feedCntWithOwnerAccess = $feedsList.Count
                }
                else{
                    $feedCntWithOwnerAccess=0 
                }
                Write-Host "Found $($totalFeeds.Count) feeds. Current user has owner access on $($feedCntWithOwnerAccess) feeds. $($totalFeeds.Count - $feedCntWithOwnerAccess) feeds will not be scanned due to insufficient permissions." -ForegroundColor Yellow
            }
            return $feedsList
        }
        catch {
            return $null;
        }
    }

    hidden [PSObject] FetchSecureFiles($projectName, $secureFileNames)
    {
        $secureFileDefnURL = "https://dev.azure.com/$($this.organizationName)/$projectName/_apis/distributedtask/securefiles?api-version=6.1-preview.1"
        try {
            $secureFileDefnObj = [WebRequestHelper]::InvokeGetWebRequest($secureFileDefnURL);
            if ($secureFileNames -ne "*") {
                $secureFileDefnObj = $secureFileDefnObj | Where-Object { $secureFileNames -contains $_.name }
            }
            else{
                if($this.UseIncrementalScan){                                    
                    $timestamp = (Get-Date)
                    $incrementalScanHelperObj = [IncrementalScanHelper]::new($this.organizationName, $projectName, $this.IncrementalDate, $true, $timestamp)
                    $incrementalScanHelperObj.SetContext($this.projectId, $this.organizationContext)
                    $secureFileDefnObj = $incrementalScanHelperObj.GetModifiedCommonSvtFromAudit("SecureFile",$secureFileDefnObj)
                }
            }
            return $secureFileDefnObj;
        }
        catch 
        {
            return $null;
        }
    }

    hidden [PSObject] FetchEnvironments($projectName, $environmentNames, $MaxObjectsToScan) {
        try {
            if ($MaxObjectsToScan -eq 0) {
                $topNQueryString = '&$top=10000'
            }
            else {
                $topNQueryString = '&$top={0}' -f $MaxObjectsToScan
            }
            # Here we are fetching all the environments in the project.
            $environmentDefnURL = ("https://dev.azure.com/{0}/{1}/_apis/distributedtask/environments?api-version=6.0-preview.1" + $topNQueryString) -f $this.organizationName, $projectName;
            $environmentDefnsObj = [WebRequestHelper]::InvokeGetWebRequest($environmentDefnURL);

            if ($environmentNames -ne "*") {
                $environmentDefnsObj = $environmentDefnsObj | Where-Object { $environmentNames -contains $_.name }
            }
            else{
                if($this.UseIncrementalScan){                                    
                    $timestamp = (Get-Date)
                    $incrementalScanHelperObj = [IncrementalScanHelper]::new($this.organizationName, $projectName, $this.IncrementalDate, $true, $timestamp)
                    $incrementalScanHelperObj.SetContext($this.projectId, $this.organizationContext)
                    $environmentDefnsObj = $incrementalScanHelperObj.GetModifiedCommonSvtFromAudit("Environment",$environmentDefnsObj)
                }
            }

            return $environmentDefnsObj;
        }
        catch {
            return $null;
        }
    }

    [SVTResource] AddSVTResource([string] $name, [string] $resourceGroupName, [string] $resourceType, [string] $resourceId, [PSObject] $resourceDetailsObj, $resourceLink)
    {
        $svtResource = [SVTResource]::new();
        $svtResource.ResourceName = $name;
        if ($resourceGroupName) {
            $svtResource.ResourceGroupName = $resourceGroupName;
        }
        $svtResource.ResourceType = $resourceType;
        $svtResource.ResourceId = $resourceId;
        $svtResource.ResourceTypeMapping = ([SVTMapping]::AzSKADOResourceMapping | Where-Object { $_.ResourceType -eq $resourceType } | Select-Object -First 1)

        if ($resourceDetailsObj) {
            $svtResource.ResourceDetails = $resourceDetailsObj;
            $svtResource.ResourceDetails | Add-Member -Name 'ResourceLink' -Type NoteProperty -Value $resourceLink;
        }
        else {
            $svtResource.ResourceDetails = New-Object -TypeName psobject -Property @{ ResourceLink = $resourceLink }
        }                         
                                        
        return $svtResource;
    }
}
