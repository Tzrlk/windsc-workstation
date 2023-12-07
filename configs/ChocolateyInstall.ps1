#!/usr/bin/env pwsh
#Requires -PSEdition Core
#Requires -Modules @{ ModuleName="PSDesiredStateConfiguration"; ModuleVersion="2.0"; MaximumVersion="2.99" }
#Requires -Modules PSDscResources, cChoco

configuration ChocolateyInstall {

 	Import-DscResource –Module PSDesiredStateConfiguration

    Environment chocoInstall {
        Name  = 'ChocolateyInstall'
    }

    File chocoInstall {
		DependsOn       = '[Environment]chocoInstall'
        DestinationPath = Join-Path $env:ChocolateyInstall 'choco.exe'
    }

}
