Set-StrictMode -Version Latest
class SARIFLog{
    [string] $version
    # [string] $schema
    [SARIFRun[]] $runs
    SARIFLog(){
        $this.version="2.1.0"
        # $this.schema="https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json"
        $this.runs=$null;
    }
    hidden [void] PublishLogs([string] $FolderPath,[SVTEventContext[]] $ControlResults,[SVTEventContext[]]$ClosedBugs){
        $this.runs+=[SARIFRun]::new($ControlResults,$ClosedBugs)
        #endregion
        $filePath=$FolderPath+"\logs.sarif"
        $this |ConvertTo-Json -Depth 10 | Out-File $filePath
    }

}