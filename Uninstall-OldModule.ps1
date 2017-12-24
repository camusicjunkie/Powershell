Function Uninstall-OldModule {

    [cmdletbinding(SupportsShouldProcess=$true, ConfirmImpact='medium')]
    param (
    
        [parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   ParameterSetName='name')]
        [alias('Module')]
        [string[]] $Name,

        [parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   ParameterSetName='inputObject')]
        [object[]] $InputObject,

        [switch] $AllDependencies
    )

    begin {
    
    }

    process {
        
        foreach ($module in $Name) {

            if ($PSBoundParameters.ContainsKey('AllDependencies')) {
                
                $oldModule = Get-OldInstalledModule -Name $module

                $psd = Import-PowerShellDataFile "$($oldModule.InstalledLocation)\$($oldModule.Name).psd1"
                while ($psd.RequiredModules) {
                    
                    if ($psd.RequiredModules = 1) {
                    
                        Write-Warning "Module: $module only has one dependency"
                    } elseif ($psd.RequiredModules > 1) {
                    
                        Write-Warning "Module: $module has more than one dependency"
                    }
                }

                #while ($psd.RequiredModules) {
                #
                #    $requiredModule = Get-InstalledModule -Name "$($psd.RequiredModules.ModuleName)"
                #
                #    Write-Verbose "Found dependencies in $requiredModule"
                #    $psd = Import-PowerShellDataFile "$($requiredModule.InstalledLocation)\$($requiredModule.Name).psd1"
                #}
                #
                #Write-Verbose "Looking for old modules in $requiredModule"
                #$latestModule = Get-InstalledModule -Name $requiredModule
                #$oldModule = Get-InstalledModule -Name $requiredModule -AllVersions | Where-Object {$_.Version -ne $latestModule.Version}
                #
                #if ($PSCmdlet.ShouldProcess("Performing the operation `"$($MyInvocation.MyCommand)`" on target `"$object`" for all versions less than `"$($latestModule.version)`"",
                #                            "Are you sure you want to uninstall the old versions of module $object ?",
                #                            "Uninstalling $object")) {
                #
                #    #Uninstall-Module -InputObject $oldModule
                #}
            } else {
            
                try {
                
                    $oldModule = Get-OldInstalledModule -Name $module

                    if ($PSCmdlet.ShouldProcess("Performing the operation `"$($MyInvocation.MyCommand)`" on target `"$module`" for all versions less than `"$($oldModule.version)`"",
                                            "Are you sure you want to uninstall the old versions of module $module ?",
                                            "Uninstalling $module")) {
                
                        Uninstall-Module -Name $module -ErrorAction Stop
                    }
                } catch {
        
                    $errorID = ($_.FullyQualifiedErrorID -split ',')[0]
                    $errorIDString = 'UnableToUninstallAsOtherModulesNeedThisModule'
                    if ($errorID -eq $errorIDString) {
            
                        Write-Warning "Module: $module has dependencies that need to be uninstalled first."
                    } else {
                
                        Write-Warning "An error occured trying to uninstall module: $module"
                    }
                }
            }
        }
    }
}



    #process {
    #
    #    if ($PSBoundParameters.ContainsKey('AllDependencies')) {
    #
    #        # if there is only 1 dependency in module file run this code
    #        $psd = Import-PowerShellDataFile "$($object.InstalledLocation)\$($object.Name).psd1"
    #        while ($psd['RequiredModules']) {
    #                    
    #            $requiredModule = Get-InstalledModule -Name "$($psd['RequiredModules'].ModuleName)"
    #
    #            Write-Verbose "Found dependencies in $requiredModule"
    #            $psd = Import-PowerShellDataFile "$($requiredModule.InstalledLocation)\$($requiredModule.Name).psd1"
    #        }
    #
    #        Write-Verbose "Looking for old modules in $requiredModule"
    #        $latestModule = Get-InstalledModule -Name $requiredModule
    #        $oldModule = Get-InstalledModule -Name $requiredModule -AllVersions | Where-Object {$_.Version -ne $latestModule.Version}
    #
    #        if ($PSCmdlet.ShouldProcess("Performing the operation `"$($MyInvocation.MyCommand)`" on target `"$object`" for all versions less than `"$($latestModule.version)`"",
    #                                    "Are you sure you want to uninstall the old versions of module $object ?",
    #                                    "Uninstalling $object")) {
    #            
    #            #Uninstall-Module -InputObject $oldModule
    #        }
    #
    #        #if there is more than 1 dependency run this code
    #        elseif (code) {
    #    
    #            ### CODE ###
    #        }
    #    } else {
    #        
    #        try {
    #        
    #            
    #        } catch {
    #        
    #            $_.
    #        }
    #        $latestModule = Get-InstalledModule $Name
    #        $oldModules = Get-InstalledModule $Name -AllVersions | Where-Object {$_.Version -ne $latestModule.Version}
    #
    #        if ($PSCmdlet.ShouldProcess("Performing the operation `"$($MyInvocation.MyCommand)`" on target `"$object`" for all versions less than `"$($latestModule.version)`"",
    #                                    "Are you sure you want to uninstall the old versions of module $object ?",
    #                                    "Uninstalling $object")) {
    #            
    #            #Uninstall-Module -InputObject $oldModule
    #        }
    #    }
    #}
    #
    #end {
    #
    #}
