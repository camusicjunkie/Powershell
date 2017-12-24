function Get-EnumeratedItem2 {
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

    [CmdletBinding()]
    Param (

        [Parameter(ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [Alias("FilePath")]
        [string[]]$Path = $PWD,

        [string]$Filter,

        [switch]$Recurse
    )
    
    Begin {

        #Converts relative path to absolute path
        $path = Convert-Path $path
    }

    Process {
        
        if (-not $PSBoundParameters.ContainsKey("Recurse")) {
            
            if (-not $PSBoundParameters.ContainsKey("Filter")) {
            
                Write-Verbose "Pulling folders in $Path"
                [System.IO.FileInfo[]]$files = [System.IO.Directory]::EnumerateFiles($Path, '*', 'TopDirectoryOnly')
                [System.IO.DirectoryInfo[]]$folders = [System.IO.Directory]::EnumerateDirectories($Path, '*', 'TopDirectoryOnly')
            } else {
                
                Write-Verbose "Pulling folders in $Path with filter: $Filter"
                [System.IO.FileInfo[]]$files = [System.IO.Directory]::EnumerateFiles($Path, "*$Filter*", 'TopDirectoryOnly')
            }

            $obj = [pscustomobject]@{
                

            }
            Add-Member -InputObject $obj -MemberType NoteProperty -Name PSParentPath -Value ([System.IO.Path]::GetDirectoryName($files[0]))

            #foreach ($file in $files) {
            #
            #    Write-Verbose $file
            #    Write-Output $root
            #    #Add-Member -InputObject $file -MemberType NoteProperty -Name PSParentPath -Value ([System.IO.Path]::GetDirectoryName($file))
            #    Write-Output $file
            #}
        } else {
            
            if (-not $PSBoundParameters.ContainsKey("Filter")) {
            
                Write-Verbose "Recursively pulling all folders in $Path"
                [System.IO.DirectoryInfo[]]$folders = [System.IO.Directory]::EnumerateDirectories($Path, '*', 'AllDirectories')
            } else {
            
                Write-Verbose "Recursively pulling all folders in $Path with filter: $Filter"
                [System.IO.DirectoryInfo[]]$folders = [System.IO.Directory]::EnumerateDirectories($Path, "*$Filter*", 'AllDirectories')
            }

            foreach ($folder in $folders) {
                
                $obj = @{
                    
                    'Folder' = $folder.name
                    '' = ''
                }
                Add-Member -InputObject $obj -MemberType NoteProperty -Name PSParentPath -Value ([System.IO.Path]::GetDirectoryName($folder))
            
                Write-Output $obj
            }
        }
    }

    End {

    }
}

#enumerateFiles (path, searchPattern, searchOption)
#recurse - add or remove 'alldirectories' from enumeratefiles search option
#norecurse - add or remove 'topDirectoryOnly' from enumeratefiles search option
#filter - modify search pattern for specific string in between wildcards. default is "*"
#convert-path . will find current directory