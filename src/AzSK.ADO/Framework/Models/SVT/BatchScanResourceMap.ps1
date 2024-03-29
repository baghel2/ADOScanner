Set-StrictMode -Version Latest 
class BatchScanResourceMap
{
    [int] $Skip
    [int] $Top
    [string] $BuildCurrentContinuationToken
    [string] $BuildNextContinuationToken
    [BatchScanState] $BatchScanState
    [DateTime] $TokenLastModifiedTime
    [string] $ReleaseCurrentContinuationToken
    [string] $ReleaseNextContinuationToken
    [int] $ResourceCount
    [string] $SkipMarker
    [string] $UpcError
    
       
}

enum BatchScanState{
	INIT
	COMP
}