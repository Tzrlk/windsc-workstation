#!/usr/bin/env pwsh
#Requires -PSEdition Core
#Requires -Modules @{ ModuleName="PSDesiredStateConfiguration"; ModuleVersion="2.0"; MaximumVersion="2.99" }
#Requires -Modules PSDscResources, cChoco

Import-Module PSDesiredStateConfiguration -MinimumVersion 2.0 -MaximumVersion 2.99

configuration Powershell {
	Import-DscResource -Module cChoco
  	Import-DscResource -Module PSDscResources

	# Ensures that powershell 7 has been installed.
	File powershellExec {
 		DestinationPath = Join-Path $env:ProgramFiles 'Powershell\7\pwsh.exe'
 	}

	# Makes .ps1 files directly executable in ps core.
  	Registry powershellExec {
        DependsOn = '[File]powershellExec'
        Key       = 'HKEY_CLASSES_ROOT\Microsoft.PowerShellScript.1\Shell\Open\Command'
        ValueName = '(Default)'
        ValueType = 'String'
        ValueData = '"%ProgramFiles%\Powershell\7\pwsh.exe" -noLogo -file "%1"'
	}
 
 }
 
