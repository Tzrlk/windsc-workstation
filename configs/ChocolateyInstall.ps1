#!/usr/bin/env pwsh
#Requires -PSEdition Core
#Requires -Modules @{ ModuleName="PSDesiredStateConfiguration"; ModuleVersion="2.0"; MaximumVersion="2.99" }
#Requires -Modules PSDscResources, cChoco

configuration ChocolateyInstall {

 	Import-DscResource –Module PSDesiredStateConfiguration
	Import-DscResource -Module cChoco

	cChocoInstaller installChoco {
		InstallDir = Join-Path $env:ProgramData 'chocolatey'
	}

	cChocoFeature useRememberedArgumentsForUpgrades {
		DependsOn   = "[cChocoInstaller]installChoco"
		FeatureName = 'useRememberedArgumentsForUpgrades'
		Ensure      = 'Present'
	}

}
