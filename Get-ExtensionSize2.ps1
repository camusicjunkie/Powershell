Function Get-ExtensionSize {
    [cmdletbinding()]
    param (
        [parameter(ValueFromPipeline=$true)]
        [string[]]
        $Path = $HOME
    )

    Process {
        Try {

            $parentFolder = Get-ChildItem $path -Directory

            if ($parentFolder.count -ne 0) {

                foreach ($folder in $parentFolder.FullName) {

                    $files = Get-ChildItem -Path $folder -Recurse -File -ErrorAction SilentlyContinue

                    if ($files.count -eq 0) {
                        continue
                    }
            
                    $group = $files | Group-Object Extension
                    $group |
                    ForEach-Object {
                        $props = @{
                            ParentFolder = $folder
                            Size = ($_.Group | 
                                Measure-Object -Property Length -Sum).Sum
                            Extension = $_.Name -replace '^\.'
                            Count = $_.Count
                        }
        
                        $obj = New-Object -TypeName PSObject -Property $props
                        Write-Output $obj
                    }
                }
            } else {

                $files = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
                $group = $files | Group-Object Extension
            
                foreach ($ext in $group) {
                    $props = @{
                        ParentFolder = $($path)
                        Size = ($ext.Group | 
                            Measure-Object -Property Length -Sum).Sum
                        Extension = $ext.Name -replace '^\.'
                        Count = $ext.Count
                    }

                    $obj = New-Object -TypeName PSObject -Property $props
                    Write-Output $obj
                }
            }

        } Catch [System.UnauthorizedAccessException] {
            
            "Access to $path is denied."

        } Catch {
            
            "An error has occured."
        }        
    }
}