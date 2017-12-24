param(
    [string] $ComputerName,
    [string] $ProcessName
)

Clear-Host

Write-Output "The named parameter, ComputerName is '$ComputerName'"
Write-Output "The named parameter, ProcessName is '$ProcessName'"
    
$Count = 0

ForEach ($argument in $args){
    write-output "`$arg[$count] is $argument"
    $count ++ 
}
