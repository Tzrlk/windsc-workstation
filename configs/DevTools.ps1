Configuration DevtoolsConfig {

	Import-DscResource -Module cChoco
    Import-DscResource -Module xPSDesiredStateConfiguration
    Import-DscResource –Module PSDesiredStateConfiguration

    cChocoPackageInstaller vim {
		Name      = 'vim'
		Params    = [string]::Join(' ', (
			'/NoDesktopShortcuts'
		))
	}

	cChocoPackageInstaller git {
		Name      = 'git'
		Params    = [string]::Join(' ', (
			'/GitAndUnixToolsOnPath',
			'/NoShellIntegration',
			'/Symlinks',
			'/Editor:VIM'
		))
	}

    cChocoPackageInstaller awsCli {
		Name      = 'awscli'
	}

    cChocoPackageInstaller golang {
		Name      = 'golang'
	}

    cChocoPackageInstaller gradle {
		Name      = 'gradle'
	}

    cChocoPackageInstaller graphviz {
		Name      = 'graphviz'
	}

    cChocoPackageInstaller groovy {
		Name      = 'groovy'
	}

    cChocoPackageInstaller jetbrainsToolbox {
		Name      = 'jetbrainstoolbox'
	}

#    File jetbrainsToolboxVmOptions {
#        DestinationPath = Join-Path $env:APPDATA 'JetBrains'
#    }

    cChocoPackageInstaller jfrogCli {
		Name      = 'jfrog-cli'
	}

    cChocoPackageInstaller jq {
		Name      = 'jq'
	}

    cChocoPackageInstaller k9s {
		Name      = 'k9s'
	}

    cChocoPackageInstaller kotlinc {
        Name      = 'kotlinc'
    }

    cChocoPackageInstaller kubernetesCli {
        Name      = 'kubernetes-cli'
    }

    cChocoPackageInstaller helm {
        Name      = 'kubernetes-helm'
    }

    cChocoPackageInstaller logexpert {
        Name      = 'logexpert'
    }

    cChocoPackageInstaller make {
        Name      = 'make'
    }

#			"mingw"
#			"msys2"

    cChocoPackageInstaller nodejs {
        Name      = 'nodejs'
    }

#			"openjdk"

    cChocoPackageInstaller packer {
        Name      = 'packer'
    }

    cChocoPackageInstaller plantuml {
        Name      = 'plantuml'
    }

    cChocoPackageInstaller python3 {
        Name      = 'python3'
    }

    cChocoPackageInstaller ruby {
        Name      = 'ruby'
    }

    cChocoPackageInstaller terraform {
        Name      = 'terraform'
    }

    cChocoPackageInstaller terragruntt {
        Name      = 'terragruntt'
    }

    cChocoPackageInstaller yq {
        Name      = 'yq'
    }

}
