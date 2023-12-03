#Require -PSEdition Core
#Require -Module PSDscResources

Configuration ChocolateyInstall {

	Import-DscResource -Module cChoco
 	Import-DscResource –Module PSDesiredStateConfiguration

    Environment chocoInstall {
        Name  = 'ChocolateyInstall'
    }

    File chocoInstall {
		DependsOn       = '[Environment]chocoInstall'
        DestinationPath = Join-Path $env:ChocolateyInstall 'choco.exe'
    }

}
