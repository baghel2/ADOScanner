Set-StrictMode -Version Latest 
class ADLSTest:SVTTestBase{
    ADLSTest([TestCase] $testcase, [TestSettings] $testsettings, [TestContext] $testContext):Base($testcase, $testsettings, $testContext){

    
    }
	#Cleanup the resource
    [void]Cleanup(){
		try{				
			Remove-AzResource -ResourceName $this.Resource.ResourceName -ResourceType $this.Resource.ResourceType -ResourceGroupName $this.Resource.ResourceGroupName -Force
			[CommonHelper]::Log("Deleted ADLS: " + $this.Resource.ResourceName, [MessageType]::Information)
		
		}
		catch{
			[CommonHelper]::Log("Failed to cleanup resource: " + $this.Resource.ResourceName, [MessageType]::Error)
			[CommonHelper]::Log($_, [MessageType]::Error)
		}
    }
}