Set-StrictMode -Version Latest
class CommonSVTControls: ADOSVTBase {

    hidden [PSObject] $Repos; # This is used for fetching repo details
    #hidden [PSObject] $ProjectId;
    hidden [string] $checkInheritedPermissionsSecureFile = $false
    hidden [string] $checkInheritedPermissionsEnvironment = $false

    CommonSVTControls([string] $organizationName, [SVTResource] $svtResource): Base($organizationName, $svtResource) {

        if ([Helpers]::CheckMember($this.ControlSettings, "SecureFile.CheckForInheritedPermissions") -and $this.ControlSettings.SecureFile.CheckForInheritedPermissions) {
            $this.checkInheritedPermissionsSecureFile = $true
        }

        if ([Helpers]::CheckMember($this.ControlSettings, "Environment.CheckForInheritedPermissions") -and $this.ControlSettings.Environment.CheckForInheritedPermissions) {
            $this.checkInheritedPermissionsEnvironment = $true
        }
    }

    hidden [ControlResult] CheckInactiveRepo([ControlResult] $controlResult)
    {
        $controlResult.VerificationResult = [VerificationResult]::Failed
        try
        {
            $repoDefnsObj = $this.ResourceContext.ResourceDetails;
            $threshold = $this.ControlSettings.Repo.RepoHistoryPeriodInDays

            $currentDate = Get-Date
            # check if repo is disabled or not
            if ($repoDefnsObj.isDisabled) {
                $controlResult.AddMessage([VerificationResult]::Failed, "Repositories does not have any commits in last $($threshold) days. ");
            }
            else {
                # check if repo has commits in past RepoHistoryPeriodInDays days
                $thresholdDate = $currentDate.AddDays(-$threshold);
                $url = "https://dev.azure.com/$($this.OrganizationContext.OrganizationName)/$($this.ResourceContext.ResourceGroupName)/_apis/git/repositories/$($repoDefnsObj.id)/commits?searchCriteria.fromDate=$($thresholdDate)&&api-version=6.0"
                try {
                    $repoCommitHistoryObj = @();
                    $repoCommitHistoryObj += @([WebRequestHelper]::InvokeGetWebRequest($url))
                    # When there are no commits, CheckMember in the below condition returns false when checknull flag [third param in CheckMember] is not specified (default value is $true). Assiging it $false.
                    if (([Helpers]::CheckMember($repoCommitHistoryObj[0], "count", $false)) -and ($repoCommitHistoryObj[0].count -eq 0)) {
                        $controlResult.AddMessage([VerificationResult]::Failed, "Repositories does not have any commits in last $($threshold) days. ");
                    }
                    else {
                        $controlResult.AddMessage([VerificationResult]::Passed, "Repositories is in active state.");
                    }
                }
                catch {
                    $controlResult.AddMessage([VerificationResult]::Error, "Could not fetch the history of repository [$($repoDefnsObj.name)].");
                    $controlResult.LogException($_)
                }
            }
        }
        catch {
            $controlResult.AddMessage([VerificationResult]::Error, "Could not fetch details of repository.", $_);
            $controlResult.LogException($_)
        }
        return $controlResult
    }

    hidden [ControlResult] CheckRepositoryPipelinePermission([ControlResult] $controlResult)
    {
        $controlResult.VerificationResult = [VerificationResult]::Failed
        try
        {
            $projectId = ($this.ResourceContext.ResourceId -split "project/")[-1].Split('/')[0]
            $url = "https://dev.azure.com/{0}/{1}/_apis/pipelines/pipelinePermissions/repository/{2}.{3}" -f $this.OrganizationContext.OrganizationName, $projectId, $projectId, $this.ResourceContext.ResourceDetails.Id;
            $repoPipelinePermissionObj = @([WebRequestHelper]::InvokeGetWebRequest($url));

            if (($repoPipelinePermissionObj.Count -gt 0) -and ([Helpers]::CheckMember($repoPipelinePermissionObj[0], "allPipelines")) -and ($repoPipelinePermissionObj[0].allPipelines.authorized -eq $true))
            {
                $controlResult.AddMessage([VerificationResult]::Failed, "Repository is accessible to all pipelines.");
            }
            else
            {
                $controlResult.AddMessage([VerificationResult]::Passed, "Repository is not accessible to all pipelines.");
            }
        }
        catch
        {
            $controlResult.AddMessage([VerificationResult]::Error, "Could not fetch repository pipeline permission.");
            $controlResult.LogException($_)
        }
       return $controlResult
    }

    hidden [ControlResult] CheckRepoRBACAccess([ControlResult] $controlResult) {

        #Control is dissabled mow
        <#
        {
      "ControlID": "ADO_Repository_AuthZ_Grant_Min_RBAC_Access",
      "Description": "All teams/groups must be granted minimum required permissions on repositories.",
      "Id": "Repository110",
      "ControlSeverity": "High",
      "Automated": "Yes",
      "MethodName": "CheckRepoRBACAccess",
      "Rationale": "Granting minimum access by leveraging RBAC feature ensures that users are granted just enough permissions to perform their tasks. This minimizes exposure of the resources in case of user/service account compromise.",
      "Recommendation": "Go to Project Settings --> Repositories --> Permissions --> Validate whether each user/group is granted minimum required access to repositories.",
      "Tags": [
        "SDL",
        "TCP",
        "Automated",
        "AuthZ",
        "RBAC"
      ],
      "Enabled": true
    },
        #>
        $accessList = @()
        #permissionSetId = '2e9eb7ed-3c0a-47d4-87c1-0ffdd275fd87' is the std. namespaceID. Refer: https://docs.microsoft.com/en-us/azure/devops/organizations/security/manage-tokens-namespaces?view=azure-devops#namespaces-and-their-ids
        try{

            $url = 'https://dev.azure.com/{0}/_apis/Contribution/HierarchyQuery?api-version=5.0-preview.1' -f $($this.OrganizationContext.OrganizationName);
            $refererUrl = "https://dev.azure.com/$($this.OrganizationContext.OrganizationName)/$($this.ResourceContext.ResourceGroupName)/_settings/repositories?_a=permissions";
            $inputbody = '{"contributionIds":["ms.vss-admin-web.security-view-members-data-provider"],"dataProviderContext":{"properties":{"permissionSetId": "2e9eb7ed-3c0a-47d4-87c1-0ffdd275fd87","permissionSetToken":"","sourcePage":{"url":"","routeId":"ms.vss-admin-web.project-admin-hub-route","routeValues":{"project":"","adminPivot":"repositories","controller":"ContributedPage","action":"Execute"}}}}}' | ConvertFrom-Json
            $inputbody.dataProviderContext.properties.sourcePage.url = $refererUrl
            $inputbody.dataProviderContext.properties.sourcePage.routeValues.Project = $this.ResourceContext.ResourceGroupName;
            $inputbody.dataProviderContext.properties.permissionSetToken = "repoV2/$($this.ResourceContext.ResourceDetails.id)"

            # Get list of all users and groups granted permissions on all repositories
            $responseObj = [WebRequestHelper]::InvokePostWebRequest($url, $inputbody);

            # Iterate through each user/group to fetch detailed permissions list
            if([Helpers]::CheckMember($responseObj[0],"dataProviders") -and ($responseObj[0].dataProviders.'ms.vss-admin-web.security-view-members-data-provider') -and ([Helpers]::CheckMember($responseObj[0].dataProviders.'ms.vss-admin-web.security-view-members-data-provider',"identities")))
            {
                $body = '{"contributionIds":["ms.vss-admin-web.security-view-permissions-data-provider"],"dataProviderContext":{"properties":{"subjectDescriptor":"","permissionSetId": "2e9eb7ed-3c0a-47d4-87c1-0ffdd275fd87","permissionSetToken":"","accountName":"","sourcePage":{"url":"","routeId":"ms.vss-admin-web.project-admin-hub-route","routeValues":{"project":"","adminPivot":"repositories","controller":"ContributedPage","action":"Execute"}}}}}' | ConvertFrom-Json
                $body.dataProviderContext.properties.sourcePage.url = $refererUrl
                $body.dataProviderContext.properties.sourcePage.routeValues.Project = $this.ResourceContext.ResourceGroupName;
                $body.dataProviderContext.properties.permissionSetToken = "repoV2/$($this.ResourceContext.ResourceDetails.id)"

                $accessList += $responseObj.dataProviders."ms.vss-admin-web.security-view-members-data-provider".identities | Where-Object { $_.subjectKind -eq "group" } | ForEach-Object {
                    $identity = $_
                    $body.dataProviderContext.properties.accountName = $_.principalName
                    $body.dataProviderContext.properties.subjectDescriptor = $_.descriptor

                    $identityPermissions = [WebRequestHelper]::InvokePostWebRequest($url, $body);
                    $configuredPermissions = $identityPermissions.dataproviders."ms.vss-admin-web.security-view-permissions-data-provider".subjectPermissions | Where-Object {$_.permissionDisplayString -ne 'Not set'}
                    return @{ IdentityName = $identity.DisplayName; IdentityType = $identity.subjectKind; Permissions = ($configuredPermissions | Select-Object @{Name="Name"; Expression = {$_.displayName}},@{Name="Permission"; Expression = {$_.permissionDisplayString}}) }
                }

                $accessList += $responseObj.dataProviders."ms.vss-admin-web.security-view-members-data-provider".identities | Where-Object { $_.subjectKind -eq "user" } | ForEach-Object {
                    $identity = $_
                    $body.dataProviderContext.properties.subjectDescriptor = $_.descriptor

                    $identityPermissions = [WebRequestHelper]::InvokePostWebRequest($url, $body);
                    $configuredPermissions = $identityPermissions.dataproviders."ms.vss-admin-web.security-view-permissions-data-provider".subjectPermissions | Where-Object {$_.permissionDisplayString -ne 'Not set'}
                    return @{ IdentityName = $identity.DisplayName; IdentityType = $identity.subjectKind; Permissions = ($configuredPermissions | Select-Object @{Name="Name"; Expression = {$_.displayName}},@{Name="Permission"; Expression = {$_.permissionDisplayString}}) }
                }
            }

            if(($accessList | Measure-Object).Count -ne 0)
            {
                $accessList= $accessList | Select-Object -Property @{Name="IdentityName"; Expression = {$_.IdentityName}},@{Name="IdentityType"; Expression = {$_.IdentityType}},@{Name="Permissions"; Expression = {$_.Permissions}}
                $controlResult.AddMessage([VerificationResult]::Verify,"Validate that the following identities have been provided with minimum RBAC access to repositories.", $accessList);
                $controlResult.SetStateData("List of identities having access to repositories: ", ($responseObj.dataProviders."ms.vss-admin-web.security-view-members-data-provider".identities | Select-Object -Property @{Name="IdentityName"; Expression = {$_.FriendlyDisplayName}},@{Name="IdentityType"; Expression = {$_.subjectKind}},@{Name="Scope"; Expression = {$_.Scope}}));
            }
            else
            {
                $controlResult.AddMessage([VerificationResult]::Passed,"No identities have been explicitly provided access to repositories.");
            }
            $responseObj = $null;

        }
        catch{
            $controlResult.AddMessage([VerificationResult]::Manual,"Unable to fetch repositories permission details. $($_) Please verify from portal all teams/groups are granted minimum required permissions.");
            $controlResult.LogException($_)
        }

        return $controlResult
    }

    hidden [PSObject] FetchRepositoriesList() {
        if($null -eq $this.Repos) {
            # fetch repositories
            $repoDefnURL = ("https://dev.azure.com/$($this.OrganizationContext.OrganizationName)/$($this.ResourceContext.ResourceGroupName)/_apis/git/repositories?api-version=6.1-preview.1")
            try {
                $repoDefnsObj = [WebRequestHelper]::InvokeGetWebRequest($repoDefnURL);
                $this.Repos = $repoDefnsObj;
            }
            catch {
                $this.Repos = $null
            }
        }
        return $this.Repos
    }

    hidden [ControlResult] CheckBroaderGroupAccessOnFeeds([ControlResult] $controlResult)
    {
        $controlResult.VerificationResult = [VerificationResult]::Failed
        try
        {
            $RestrictedBroaderGroupsForFeeds = $null;
            if ([Helpers]::CheckMember($this.ControlSettings, "Feed.RestrictedBroaderGroupsForFeeds")) {
                $restrictedBroaderGroupsForFeeds = $this.ControlSettings.Feed.RestrictedBroaderGroupsForFeeds

                #GET https://feeds.dev.azure.com/{organization}/{project}/_apis/packaging/Feeds/{feedId}/permissions?api-version=6.0-preview.1
                #Using visualstudio api because new api (dev.azure.com) is giving null in the displayName property.
                $url = 'https://{0}.feeds.visualstudio.com/{1}/_apis/Packaging/Feeds/{2}/Permissions?includeIds=true&excludeInheritedPermissions=false&includeDeletedFeeds=false' -f $this.OrganizationContext.OrganizationName, $this.ResourceContext.ResourceGroupName, $this.ResourceContext.ResourceDetails.Id;
                $feedPermissionList = @([WebRequestHelper]::InvokeGetWebRequest($url));
                $excesiveFeedsPermissions = @(($feedPermissionList | Where-Object {$_.role -eq "administrator" -or $_.role -eq "collaborator" -or $_.role -eq "contributor"}) | Select-Object -Property @{Name="FeedName"; Expression = {$this.ResourceContext.ResourceName}},@{Name="Role"; Expression = {$_.role}},@{Name="DisplayName"; Expression = {$_.displayName}}) ;
                $feedWithBroaderGroup = @($excesiveFeedsPermissions | Where-Object { $restrictedBroaderGroupsForFeeds -contains $_.DisplayName.split('\')[-1] })
                $feedWithroaderGroupCount = $feedWithBroaderGroup.count;

                if ($feedWithroaderGroupCount -gt 0)
                {
                    $controlResult.AddMessage([VerificationResult]::Failed, "Count of broader groups that have administrator/contributor/collaborator access to feed: $($feedWithroaderGroupCount)")

                    $display = ($feedWithBroaderGroup |  FT FeedName, Role, DisplayName -AutoSize | Out-String -Width 512)
                    $controlResult.AddMessage("`nList of groups: ", $display)
                }
                else
                {
                    $controlResult.AddMessage([VerificationResult]::Passed,  "Feed is not granted with administrator/contributor/collaborator permission to broad groups.");
                }
                $controlResult.AddMessage("`nNote: `nThe following groups are considered 'broader groups': `n$($restrictedBroaderGroupsForFeeds | FT | out-string)");
            }
            else
            {
                $controlResult.AddMessage([VerificationResult]::Error,  "List of broader groups for feeds is not defined in control settings for your organization.");
            }
        }
        catch
        {
            $controlResult.AddMessage([VerificationResult]::Error,  "Could not fetch feed permissions.");
            $controlResult.LogException($_)
        }
        return $controlResult
    }

    hidden [ControlResult] CheckSecureFilesPermission([ControlResult] $controlResult)
    {
        $controlResult.VerificationResult = [VerificationResult]::Failed
        try {
            $url = "https://dev.azure.com/{0}/{1}/_apis/build/authorizedresources?type=securefile&id={2}&api-version=6.0-preview.1" -f $this.OrganizationContext.OrganizationName, $this.ResourceContext.ResourceGroupName, $this.ResourceContext.ResourceDetails.Id
            $secureFileObj = @([WebRequestHelper]::InvokeGetWebRequest($url));

            if(($secureFileObj.Count -gt 0) -and [Helpers]::CheckMember($secureFileObj[0], "authorized") -and  $secureFileObj[0].authorized -eq $true) {
                $controlResult.AddMessage([VerificationResult]::Failed, "Secure file is accesible to all pipelines.");
            }
            else {
                $controlResult.AddMessage([VerificationResult]::Passed, "Secure file is not accesible to all pipelines.");
            }
        }
        catch {
            $controlResult.AddMessage([VerificationResult]::Error, "Could not fetch authorization details of secure file.");
            $controlResult.LogException($_)
        }
        return $controlResult
    }

    hidden [ControlResult] CheckBroaderGroupAccessOnSecureFile([ControlResult] $controlResult)
    {
        $controlResult.VerificationResult = [VerificationResult]::Failed
        try
        {
            $restrictedBroaderGroupsForSecureFile = $null;
            if ([Helpers]::CheckMember($this.ControlSettings, "SecureFile.RestrictedBroaderGroupsForSecureFile")) {
                $restrictedBroaderGroupsForSecureFile = $this.ControlSettings.SecureFile.RestrictedBroaderGroupsForSecureFile

                $projectId = ($this.ResourceContext.ResourceId -split "project/")[-1].Split('/')[0]
                $url = 'https://dev.azure.com/{0}/_apis/securityroles/scopes/distributedtask.securefile/roleassignments/resources/{1}%24{2}' -f $this.OrganizationContext.OrganizationName, $projectId, $this.ResourceContext.ResourceDetails.Id;
                $secureFilePermissionList = @([WebRequestHelper]::InvokeGetWebRequest($url));

                $roleAssignmentsToCheck = $secureFilePermissionList;
                if ($this.checkInheritedPermissionsSecureFile -eq $false) {
                    $roleAssignmentsToCheck = $secureFilePermissionList | where-object { $_.access -ne "inherited" }
                }
                
                $excesiveSecureFilePermissions = @(($roleAssignmentsToCheck | Where-Object {$_.role.name -eq "administrator" -or $_.role.name -eq "user"}) | Select-Object -Property @{Name="SecureFileName"; Expression = {$this.ResourceContext.ResourceName}},@{Name="Role"; Expression = {$_.role.name}},@{Name="DisplayName"; Expression = {$_.identity.displayName}}) ;
                $secureFileWithBroaderGroup = @($excesiveSecureFilePermissions | Where-Object { $restrictedBroaderGroupsForSecureFile -contains $_.DisplayName.split('\')[-1] })
                $secureFileWithBroaderGroupCount = $secureFileWithBroaderGroup.count;

                if ($secureFileWithBroaderGroupCount -gt 0)
                {
                    $controlResult.AddMessage([VerificationResult]::Failed, "Count of broader groups that have user/administrator access to secure file: $($secureFileWithBroaderGroupCount)")

                    $display = ($secureFileWithBroaderGroup |  FT SecureFileName, Role, DisplayName -AutoSize | Out-String -Width 512)
                    $controlResult.AddMessage("`nList of groups: ", $display)
                }
                else
                {
                    $controlResult.AddMessage([VerificationResult]::Passed,  "Secure file is not granted with user/administrator permission to broad groups.");
                }
                $controlResult.AddMessage("`nNote: `nThe following groups are considered 'broader groups': `n$($restrictedBroaderGroupsForSecureFile | FT | out-string)");
            }
            else
            {
                $controlResult.AddMessage([VerificationResult]::Error,  "List of broader groups for secure file is not defined in control settings for your organization.");
            }
        }
        catch
        {
            $controlResult.AddMessage([VerificationResult]::Error,  "Could not fetch secure file permissions.");
            $controlResult.LogException($_)
        }
        return $controlResult
    }

    hidden [ControlResult] CheckEnviornmentAccess([ControlResult] $controlResult)
    {
        $controlResult.VerificationResult = [VerificationResult]::Failed
        try
        {
            $url = "https://dev.azure.com/{0}/{1}/_apis/pipelines/pipelinePermissions/environment/{2}" -f $this.OrganizationContext.OrganizationName, $this.ResourceContext.ResourceGroupName, $this.ResourceContext.ResourceDetails.Id;
            $envPipelinePermissionObj = @([WebRequestHelper]::InvokeGetWebRequest($url));

            if (($envPipelinePermissionObj.Count -gt 0) -and ([Helpers]::CheckMember($envPipelinePermissionObj[0],"allPipelines")) -and ($envPipelinePermissionObj[0].allPipelines.authorized -eq $true))
            {
                $controlResult.AddMessage([VerificationResult]::Failed, "Environment is accessible to all pipelines.");
            }
            else
            {
                $controlResult.AddMessage([VerificationResult]::Passed, "Environment is not accessible to all pipelines.");
            }
        }
        catch
        {
            $controlResult.AddMessage([VerificationResult]::Error, "Could not fetch environment's pipeline permission setting.");
            $controlResult.LogException($_)
        }
       return $controlResult
    }

    hidden [ControlResult] CheckBroaderGroupAccessOnEnvironment([ControlResult] $controlResult)
    {
        $controlResult.VerificationResult = [VerificationResult]::Failed
        try
        {
            $restrictedBroaderGroupsForEnvironment = $null;
            if ([Helpers]::CheckMember($this.ControlSettings, "Environment.RestrictedBroaderGroupsForEnvironment")) {
                $restrictedBroaderGroupsForEnvironment = $this.ControlSettings.Environment.RestrictedBroaderGroupsForEnvironment

                $projectId = ($this.ResourceContext.ResourceId -split "project/")[-1].Split('/')[0]
                $url = 'https://dev.azure.com/{0}/_apis/securityroles/scopes/distributedtask.environmentreferencerole/roleassignments/resources/{1}_{2}' -f $this.OrganizationContext.OrganizationName, $projectId, $this.ResourceContext.ResourceDetails.Id;
                $environmentPermissionList = @([WebRequestHelper]::InvokeGetWebRequest($url));

                $roleAssignmentsToCheck = $environmentPermissionList;
                if ($this.checkInheritedPermissionsEnvironment -eq $false) {
                    $roleAssignmentsToCheck = $environmentPermissionList | where-object { $_.access -ne "inherited" }
                }
                
                $excesiveEnvironmentPermissions = @(($roleAssignmentsToCheck | Where-Object {$_.role.name -eq "administrator" -or $_.role.name -eq "user"}) | Select-Object -Property @{Name="EnvironmentName"; Expression = {$this.ResourceContext.ResourceName}},@{Name="Role"; Expression = {$_.role.name}},@{Name="DisplayName"; Expression = {$_.identity.displayName}}) ;
                $environmentWithBroaderGroup = @($excesiveEnvironmentPermissions | Where-Object { $restrictedBroaderGroupsForEnvironment -contains $_.DisplayName.split('\')[-1] })
                $environmentWithBroaderGroupCount = $environmentWithBroaderGroup.count;

                if ($environmentWithBroaderGroupCount -gt 0)
                {
                    $controlResult.AddMessage([VerificationResult]::Failed, "Count of broader groups that have user/administrator access to environment: $($environmentWithBroaderGroupCount)")

                    $display = ($environmentWithBroaderGroup |  FT EnvironmentName, Role, DisplayName -AutoSize | Out-String -Width 512)
                    $controlResult.AddMessage("`nList of groups: ", $display)
                }
                else
                {
                    $controlResult.AddMessage([VerificationResult]::Passed,  "Environment is not granted with user/administrator permission to broad groups.");
                }
                $controlResult.AddMessage("`nNote: `nThe following groups are considered 'broader groups': `n$($restrictedBroaderGroupsForEnvironment | FT | out-string)");
            }
            else
            {
                $controlResult.AddMessage([VerificationResult]::Error,  "List of broader groups for environment is not defined in control settings for your organization.");
            }
        }
        catch
        {
            $controlResult.AddMessage([VerificationResult]::Error,  "Could not fetch environment permissions.");
            $controlResult.LogException($_)
        }
        return $controlResult
    }
}
