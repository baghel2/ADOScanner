Set-StrictMode -Version Latest
class BugMetaInfoProvider {

    hidden [PSObject] $ControlSettingsBugLog
    hidden [string] $ServiceId
    hidden static [PSObject] $ServiceTreeInfo
    hidden [PSObject] $InvocationContext
    hidden [bool] $BugLogUsingCSV = $false;
    hidden [string] $STMappingFilePath = $null
    hidden static $OrgMappingObj = @{}

    BugMetaInfoProvider() {

    }

    BugMetaInfoProvider($bugLogUsingCSV, $stMappingFilePath) {
        $this.BugLogUsingCSV = $bugLogUsingCSV;
        $this.STMappingFilePath = $stMappingFilePath;
    }

    hidden [string] GetAssignee([SVTEventContext[]] $ControlResult, $controlSettingsBugLog, $isBugLogCustomFlow, $serviceIdPassedInCMD, $invocationContext) {
        $this.ControlSettingsBugLog = $controlSettingsBugLog;
        #flag to check if pluggable bug logging interface (service tree)
        if ($isBugLogCustomFlow) {
            $this.InvocationContext = $invocationContext;	
            return $this.BugLogCustomFlow($ControlResult, $serviceIdPassedInCMD)
        }
        else {
            return $this.GetAssigneeFallback($ControlResult);
        }
    }

    hidden [string] GetAssignee([SVTEventContext[]] $ControlResult, $invocationContext) {
        $this.InvocationContext = $invocationContext;	
        return $this.BugLogCustomFlow($ControlResult, "")
    }

    hidden [string] BugLogCustomFlow($ControlResult, $serviceIdPassedInCMD)
    {
        $resourceType = $ControlResult.ResourceContext.ResourceTypeName
        $projectName = $ControlResult[0].ResourceContext.ResourceGroupName;
        $assignee = "";
        try 
         {
            #assign to the person running the scan, as to reach at this point of code, it is ensured the user is PCA/PA and only they or other PCA
            #PA members can fix the control
            if($ResourceType -eq 'Organization' -or $ResourceType -eq 'Project') {
                $assignee = [ContextHelper]::GetCurrentSessionUser();
            }
            else {
                $rscId = ($ControlResult.ResourceContext.ResourceId -split "$resourceType/")[-1];
                $assignee = $this.CalculateAssignee($rscId, $projectName, $resourceType, $serviceIdPassedInCMD);
                if (!$assignee -and (!$this.BugLogUsingCSV)) {
                    $assignee = $this.GetAssigneeFallback($ControlResult)
                }
            }            
        }
        catch {
            return "";
        }
        return $assignee;
    }

    hidden [string] CalculateAssignee($rscId, $projectName, $resourceType, $serviceIdPassedInCMD) 
    {
        $metaInfo = [MetaInfoProvider]::Instance;
        $assignee = "";
        try {
            #If serviceid based scan then get servicetreeinfo details only once.
            #First condition if not serviceid based scan then go inside every time.
            #Second condition if serviceid based scan and [BugMetaInfoProvider]::ServiceTreeInfo not null then only go inside.
            if (!$serviceIdPassedInCMD -or ($serviceIdPassedInCMD -and ![BugMetaInfoProvider]::ServiceTreeInfo)) {
                [BugMetaInfoProvider]::ServiceTreeInfo = $metaInfo.FetchResourceMappingWithServiceData($rscId, $projectName, $resourceType, $this.STMappingFilePath);
            }
            if([BugMetaInfoProvider]::ServiceTreeInfo)
            {
                #Filter based on area path match project name and take first items (if duplicate service tree entry found).
                #Split areapath to match with projectname
                if (!$this.BugLogUsingCSV) {
                    [BugMetaInfoProvider]::ServiceTreeInfo = ([BugMetaInfoProvider]::ServiceTreeInfo | Where {($_.areaPath).Split('\')[0] -eq $projectName})[0]
                }
                $this.ServiceId = [BugMetaInfoProvider]::ServiceTreeInfo.serviceId;
                #Check if area path is not supplied in command parameter then only set from service tree.
                if (!$this.InvocationContext.BoundParameters["AreaPath"]) {
                    [BugLogPathManager]::AreaPath = [BugMetaInfoProvider]::ServiceTreeInfo.areaPath.Replace("\", "\\");
                }
                $domainNameForAssignee = ""
                if([Helpers]::CheckMember($this.ControlSettingsBugLog, "DomainName"))
                {
                    $domainNameForAssignee = $this.ControlSettingsBugLog.DomainName;
                }
                elseif ($this.BugLogUsingCSV) {
                    $domainNameForAssignee = "microsoft.com";
                }
                $assignee = [BugMetaInfoProvider]::ServiceTreeInfo.devOwner.Split(";")[0] + "@"+ $domainNameForAssignee
            }
        }
        catch {
            Write-Host "Could not find service tree data file." -ForegroundColor Yellow
        }
        return $assignee;	
    }

    hidden [string] GetAssigneeFallback([SVTEventContext[]] $ControlResult) {
        $ResourceType = $ControlResult.ResourceContext.ResourceTypeName
        $ResourceName = $ControlResult.ResourceContext.ResourceName
        $organizationName = $ControlResult.OrganizationContext.OrganizationName;
        switch -regex ($ResourceType) {
            #assign to the creator of service connection
            'ServiceConnection' {
                return $ControlResult.ResourceContext.ResourceDetails.createdBy.uniqueName
            }
            #assign to the creator of agent pool
            'AgentPool' {
                $apiurl = "https://dev.azure.com/{0}/_apis/distributedtask/pools?poolName={1}&api-version=6.0" -f $organizationName, $ResourceName
                try {
                    $response = [WebRequestHelper]::InvokeGetWebRequest($apiurl)
                    return $response.createdBy.uniqueName
                }
                catch {
                    return "";
                }
            }
            #assign to the creator of variable group
            'VariableGroup' {
                return $ControlResult.ResourceContext.ResourceDetails.createdBy.uniqueName
            }
            #assign to the person who recently triggered the build pipeline, or if the pipeline is empty assign it to the creator
            'Build' {
                $definitionId = $ControlResult.ResourceContext.ResourceDetails.id;
    
                try {
                    $apiurl = "https://dev.azure.com/{0}/{1}/_apis/build/builds?definitions={2}&api-version=6.0" -f $organizationName, $ControlResult.ResourceContext.ResourceGroupName , $definitionId;
			    	
                    $response = [WebRequestHelper]::InvokeGetWebRequest($apiurl)
                    #check for recent trigger
                    if ([Helpers]::CheckMember($response, "requestedBy")) {
                        return $response[0].requestedBy.uniqueName
                    }
                    #if no triggers found assign to the creator
                    else {
                        $apiurl = "https://dev.azure.com/{0}/{1}/_apis/build/definitions/{2}?api-version=6.0" -f $organizationName, $ControlResult.ResourceContext.ResourceGroupName , $definitionId;
                        $response = [WebRequestHelper]::InvokeGetWebRequest($apiurl)
                        return $response.authoredBy.uniqueName
                    }
                }
                catch {
                    return "";
                }	
			    	
            }
            #assign to the person who recently triggered the release pipeline, or if the pipeline is empty assign it to the creator
            'Release' {
                $definitionId = ($ControlResult.ResourceContext.ResourceId -split "release/")[-1];
                try {
                    $apiurl = "https://vsrm.dev.azure.com/{0}/{1}/_apis/release/releases?definitionId={2}&api-version=6.0" -f $organizationName, $ControlResult.ResourceContext.ResourceGroupName , $definitionId;
                    $response = [WebRequestHelper]::InvokeGetWebRequest($apiurl)
                    #check for recent trigger
                    if ([Helpers]::CheckMember($response, "modifiedBy")) {
                        return $response[0].modifiedBy.uniqueName
                    }
                    #if no triggers found assign to the creator
                    else {
                        $apiurl = "https://vsrm.dev.azure.com/{0}/{1}/_apis/release/definitions/{2}?&api-version=6.0" -f $organizationName, $ControlResult.ResourceContext.ResourceGroupName , $definitionId;
                        $response = [WebRequestHelper]::InvokeGetWebRequest($apiurl)
                        return $response.createdBy.uniqueName
                    }
                }
                catch {
                    return "";
                }
            }
            'Repository' {
                try {
                    $url = 'https://dev.azure.com/{0}/{1}/_apis/git/repositories/{2}/commits?searchCriteria.showOldestCommitsFirst=true&searchCriteria.$top=1&api-version=6.0' -f $organizationName, $ControlResult.ResourceContext.ResourceGroupName, $ControlResult.ResourceContext.ResourceDetails.Id;
                    $repoFirstCommit = @([WebRequestHelper]::InvokeGetWebRequest($url));
                    if ($repoFirstCommit.count -gt 0 -and [Helpers]::CheckMember($repoFirstCommit[0],"author")) {
                        return $repoFirstCommit[0].author.email;
                    }
                }
                catch {
                    return "";
                }
            }
            'SecureFile' {
                return $ControlResult.ResourceContext.ResourceDetails.createdBy.uniqueName
            }
            'Feed' {
                try {
                    $url = 'https://{0}.feeds.visualstudio.com/{1}/_apis/Packaging/Feeds/{2}/Permissions?includeIds=true&excludeInheritedPermissions=true' -f $organizationName, $ControlResult.ResourceContext.ResourceGroupName, $ControlResult.ResourceContext.ResourceDetails.Id;
                    $feedPermissionList = @([WebRequestHelper]::InvokeGetWebRequest($url));
                    if ($feedPermissionList.count -gt 0 -and [Helpers]::CheckMember($feedPermissionList[0],"identityDescriptor")) {
                        $resourceOwnerWithDescriptor = $feedPermissionList[0].identityDescriptor.Split('\');
                        if ($resourceOwnerWithDescriptor.count -ge 1) {
                            return $resourceOwnerWithDescriptor[1];
                        }
                    }
                }
                catch {
                    return "";
                }
            }
            'Environment' {
                return $ControlResult.ResourceContext.ResourceDetails.createdBy.uniqueName
            }  
            #assign to the person running the scan, as to reach at this point of code, it is ensured the user is PCA/PA and only they or other PCA
            #PA members can fix the control
            'Organization' {
                return [ContextHelper]::GetCurrentSessionUser();
            }
            'Project' {
                return [ContextHelper]::GetCurrentSessionUser();
    
            }
        }
        return "";
    }

    hidden [string] GetAssigneeFromOrgMapping($organizationName){
        $assignee = $null;
        if([BugMetaInfoProvider]::OrgMappingObj.ContainsKey($organizationName)){
            return [BugMetaInfoProvider]::OrgMappingObj[$organizationName]
        }
        $orgMapping = Get-Content "$($this.STMappingFilePath)\OrgSTData.csv" | ConvertFrom-Csv
        $orgOwnerDetails = @($orgMapping | where {$_."ADO Org Name" -eq $organizationName})
        if($orgOwnerDetails.Count -gt 0){
            $assignee = $orgOwnerDetails[0]."OwnerAlias"   
            [BugMetaInfoProvider]::OrgMappingObj[$organizationName] = $assignee
        }

        return $assignee;
    }

    #method to obtain sign in ID of TF scoped identities
    hidden [string] GetAssigneeFromTFScopedIdentity($identity,$organizationName){
        $assignee = $null;
        #TF scoped identities with alternate email address will be in the format: a.b@microsoft.com
        if($identity -like "*.*@microsoft.com"){
            #check for the correct identitity corresponding to this email
            $url="https://dev.azure.com/{0}/_apis/IdentityPicker/Identities?api-version=7.1-preview.1" -f $organizationName
            $body = "{'query':'{0}','identityTypes':['user'],'operationScopes':['ims','source'],'properties':['DisplayName','Active','SignInAddress'],'filterByEntityIds':[],'options':{'MinResults':40,'MaxResults':40}}" | ConvertFrom-Json
            $body.query = $identity
            try{
                $responseObj = [WebRequestHelper]::InvokePostWebRequest($url,$body)
                #if any user has been found, assign this bug to the sign in address of the user
                if($responseObj.results[0].identities.count -gt 0){
                    $assignee = $responseObj.results[0].identities[0].signInAddress
                }
            }
            catch{
                return $assignee;
            }                    
        }
        else{
            return $assignee;
        }

        return $assignee;
    }

}
