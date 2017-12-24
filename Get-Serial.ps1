Function Get-SerialNumber {
<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
    [cmdletbinding()]
    param (
        [parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [validatePattern("^jegw[ltw]-[a-z][a-z][a-z0]\d{3}$")]
        [alias("CN","Workstation","Computer")]
        [string[]]
        $ComputerName = $env:COMPUTERNAME
    )
    Begin {
    }
    Process {
        
    }
    End {
    }
}