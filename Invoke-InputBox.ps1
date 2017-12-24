function Invoke-InputBox {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True)]
        [string]$Prompt,

        [Parameter(Mandatory=$True)]
        [string]$Title,

        [Parameter()]
        [string]$Default = 'jegw-fs-001v'
    )

    Add-Type -Assembly Microsoft.VisualBasic

    $input = [Microsoft.VisualBasic.Interaction]::inputbox($prompt,$title,$default)
    Write-Output "My server name is $input."
} #function