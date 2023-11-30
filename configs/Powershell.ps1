Import-Module cChoco
Configuration Powershell {
	Import-DscResource -Module cChoco
 	Import-DscResource -Module xPSDesiredStateConfiguration
  	Import-DscResource -Module PSDesiredStateConfiguration

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
 
