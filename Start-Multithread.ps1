$paths = Get-ChildItem -Path 'G:\All Music\iTunes\' -Directory
$script = 'G:\Powershell\Scripts\Get-ExtSizes.ps1'
$maxThreads = 10
$sleepTime = 500
$jobName = 'extSizes'

Get-Job -State Completed | Remove-Job

$i = 0
foreach ($path in $paths) {
    $jobCount = (Get-Job -State Completed).Count
    Write-Progress -Activity 'Please wait' `
                   -Status "Jobs still running: $($paths.Count - $i)" `
                   -PercentComplete (($jobCount / $paths.Count) * 100)

    while ((Get-Job -State Running).Count -ge $maxThreads) {
        Write-Output "Waiting for open thread (Maximum: $MaxThreads)"
        Start-Sleep -Milliseconds $sleepTime
    }

    $i++
    Start-Job -Name $jobName$i -FilePath $script -ArgumentList $path
}

while((Get-Job -State Running).count -gt 0) {
    $jobCount = (Get-Job -State Running).Count
    Write-Progress -Activity 'Please wait' `
                   -Status "Waiting for running jobs to finish $($paths.Count - $jobCount)" `
                   -PercentComplete ($jobCount / $paths.Count * 100)
    Start-Sleep -Milliseconds $sleepTime
}

Write-Progress -Activity 'Done' `
               -Status 'All background jobs have completed' `
               -PercentComplete 100
Start-Sleep -Milliseconds $sleepTime

Write-Progress -Activity 'Done' -Completed

Get-Job | Receive-Job -Keep | ForEach-Object {
    $_ | Select-Object Extension, Count, SizeGB, FilePath #| 
        #Export-Csv 'C:\Users\John Steele\Downloads\paths.csv' -Append -NoTypeInformation
}