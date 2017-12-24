$scriptPath = $PSScriptRoot
$folderLocation = Join-Path -Path $scriptPath -ChildPath "MTSequential"

if (Test-Path $folderLocation) {
    if (Test-Path "$folderLocation\*") {
        Get-ChildItem -Path $folderLocation | Remove-Item -Force
    }
} else {
    New-Item -Path $folderLocation -ItemType Directory -Force | Out-Null
}

$ScriptBlock = {
    Param (
        [string]$fileName,
        [string]$url
    )
    $contents = Invoke-WebRequest $url -UseBasicParsing
    Set-Content $fileName $myString     # use a common variable
    Add-Content $fileName $contents     # add the text download from the www
}

Write-Warning "Run the processes sequentially"

Write-Output "First lets create the 500 text files by running the process sequentially"
$startTime = Get-Date

$myString = "This is not a session state"
1..500 | ForEach-Object {
    $fileName = "test$_.txt"
    $filePath = Join-Path -Path $folderLocation -ChildPath $fileName
    Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $filePath, "http://www.textfiles.com/100/adventur.txt"
}

$endTime = Get-Date

$totalSeconds = "{0:N4}" -f ($endTime - $startTime).TotalSeconds
Write-Output "All files created in $totalSeconds seconds"

Write-Warning "Run the processes in parallel"

$folderLocation = Join-Path -Path $scriptPath -ChildPath "MTParallel"

Write-Output "Now lets try creating 500 files by running up $numThreads background threads"

if (Test-Path $folderLocation) {
    if (Test-Path "$folderLocation\*") {
        Get-ChildItem -Path $folderLocation | Remove-Item -Force
    }
} else {
    New-Item -Path $folderLocation -ItemType Directory -Force | Out-Null
}

# Create session state
$myString = "This is a session state!"
$sessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$sessionstate.Variables.Add((New-Object -TypeName System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList "myString", $myString, "example string"))
   
# Create runspace pool consisting of $numThreads runspaces
$numThreads = 5000
$RunspacePool = [RunspaceFactory]::CreateRunspacePool(1, $numThreads, $sessionState, $Host)
$RunspacePool.Open()

$startTime = Get-Date
$Jobs = @()
1..500 | ForEach-Object {
    $fileName = "test$_.txt"
    $fileName = Join-Path -Path $folderLocation -ChildPath $fileName
    $Job = [powershell]::Create().AddScript($ScriptBlock).AddParameter("fileName", $fileName).AddParameter("url", "http://www.textfiles.com/100/adventur.txt")
    $Job.RunspacePool = $RunspacePool
    $Jobs += New-Object PSObject -Property @{
        RunNum = $_
        Job = $Job
        Result = $Job.BeginInvoke()}
}
 
Write-Warning "Waiting.."

Do {
   Write-Warning "."
   Start-Sleep -Seconds 10
} While ( $Jobs.Result.IsCompleted -contains $false) #Jobs.Result is a collection

$endTime = Get-Date
$totalSeconds = "{0:N4}" -f ($endTime - $startTime).TotalSeconds
Write-Output "All files created in $totalSeconds seconds"