Set-StrictMode -Version Latest 
class BatchResource:SVTControlTestResource{
	
	BatchResource([TestCase] $testcase, [TestSettings] $testsettings, [TestContext] $testContext):Base($testcase, $testsettings, $testContext){
     
    }

	#Setting the properties as required by this resource type.
	[void]SetDerivedResourceProps(){
		#Fetch the resource name from Template file if its not null
		if(![string]::IsNullOrEmpty($this.Template)){
				$this.ResourceName = $this.GetResourceNameFromARMJson($this.Template, "ResourceName","defaultValue")
			}
		else{
			$this.ResourceName = "azsktestBatch" #Else set the default resource name
		}
		$this.ResourceType = "Microsoft.Batch/batchAccounts" 
	}



	#Since Batch is upgradable, ARM deploy it to assign new properties instead of running any other functions.
	[void] InitializeResource( ){
		
		if(![string]::IsNullOrEmpty($this.Template)){
			$linkedResourceName = $this.GetResourceNameFromARMJson($this.Template, "storageAccountName","defaultValue")
			}
		else{
			$linkedResourceName = "azsktestlinkedstorage" #Else set the default resource name
		}
		$linkedResourceType = "Microsoft.Storage/storageAccounts" 
		$linkedResourceExists=$this.IfLinkedResourceExists($linkedResourceName,$linkedResourceType)
		if(!$linkedResourceExists){
				$this.CreateLinkedResource($linkedResourceName)
		}
			
		$this.ARMDeployResource()	
    }
}
