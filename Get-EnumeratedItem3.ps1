function Get-EnumeratedItem3 {

    [CmdletBinding()]
    Param (

        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [Alias("FilePath")]
        [string[]]$Path,

        [string]$Filter,

        [switch]$Recurse
    )
  
    Begin {

        #Converts relative path to absolute path
        $path = Convert-Path $path
    }

    Process {
        switch ($PSBoundParameters) {

            ($_.ContainsKey("Filter") -and ($_.ContainsKey("Recurse"))) {
        
                Write-Verbose "Recursively pulling all folders in $path with filter: $filter"
                $folders = [System.IO.Directory]::EnumerateDirectories($path, "*$Filter*", 'AllDirectories')
            }

            ($_.ContainsKey("Filter") -and (-not $_.ContainsKey("Recurse"))) {
        
                Write-Verbose "Pulling folders in $path with filter: $filter"
                $folders = [System.IO.Directory]::EnumerateDirectories($path, "*$Filter*", 'TopDirectoryOnly')
            }

            ((-not $_.ContainsKey("Filter")) -and ($_.ContainsKey("Recurse"))) {
        
                Write-Verbose "Recursively pulling all folders in $path"
                $folders = [System.IO.Directory]::EnumerateDirectories($path, "*", 'AllDirectories')
            }

            default {

                Write-Verbose "Pulling folders in $path"
                $folders = [System.IO.Directory]::EnumerateDirectories($path, "*", 'TopDirectoryOnly')
            }
        }

        foreach ($folder in $folders) {
      
            $folder
            #$obj = [System.IO.FileInfo]$folder
            #Add-Member -InputObject $obj -MemberType NoteProperty -Name PSParentPath -Value ([System.IO.Path]::GetDirectoryName($folder))

            #Write-Output $obj
        }
    }

    End {

    }
}
