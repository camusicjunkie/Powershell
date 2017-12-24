Function Get-ExtensionSize {
    [cmdletbinding()]
    param (
        [parameter(ValueFromPipeline=$true)]
        [string[]]
        $Path = $HOME
    )

    Process {
        $parentFolder = Get-ChildItem $path -Directory

        if ($parentFolder.count -ne 0) {

            foreach ($folder in $parentFolder.FullName) {
                
                Try {
                    
                    Get-ChildItem -Path $folder -Recurse -File -Force -ErrorAction Stop |
                        Select-Object -First 1

                    Write-Verbose "Working on $folder"
                    $files = Get-ChildItem -Path $folder -Recurse -File
                    
                    foreach ($file in $files) {
                        
                    }

                    if ($files -eq $null) {
                        Write-Verbose "$folder is empty"
                        continue
                    }
                
                    $files | Group-Object Extension |
                    ForEach-Object {

                        $props = @{
                            ParentFolder = $folder
                            Size = ($_.Group | Measure-Object -Property Length -Sum).Sum
                            Extension = $_.Name -replace '^\.'
                            Count = $_.Count
                        }
                
                        $obj = New-Object -TypeName PSObject -Property $props
                        Write-Output $obj
                    }
                } Catch [System.UnauthorizedAccessException] {
                    
                    Write-Warning "Access to $($_.targetObject) is denied."
                    continue
                } Catch {
                    
                    Write-Warning $_
                    continue
                }
            }
        } else {

            Try {
                $files = Get-ChildItem -Path $path -ErrorAction Stop
                $group = $files | Group-Object Extension
            
                foreach ($ext in $group) {

                    $props = @{
                        ParentFolder = $($path)
                        Size = ($ext.Group | Measure-Object -Property Length -Sum).Sum
                        Extension = $ext.Name -replace '^\.'
                        Count = $ext.Count
                    }

                    $obj = New-Object -TypeName PSObject -Property $props
                    Write-Output $obj
                }
            } Catch {

                Write-Warning "Error occurred."
            }
        }      
    }
}