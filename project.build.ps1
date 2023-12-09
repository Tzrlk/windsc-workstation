#!/usr/bin/env pwsh
<#
    .SYNOPSIS
        Build script for the project.
    .DESCRIPTION
        Will action the tasks needed to lint, test, and apply the
        configurations in this repository using `Invoke-Build`.
    .PARAMETER Tasks
        Specifies the tasks to execute.
    .EXAMPLE
        > ./project.build.ps1
        Invoke the default task.
    .EXAMPLE
        > ./project.build.ps1 task1, task2
        Invoke tasks 'task1' and 'task2'.
    .EXAMPLE
        > Invoke-Build task1, task2
        Tasks can also be invoked in the regular fashion.
#>
param (

    [Parameter(Position=0)]
    [String[]] $Tasks = @()

)

$ErrorActionPreference = 'Stop'

if ([System.IO.Path]::GetFileName($MyInvocation.ScriptName) -ne 'Invoke-Build.ps1') {
    Import-Module 'InvokeBuild'
	Write-Debug "Tasks: $Tasks"
	Write-Debug "File:  $( $MyInvocation.MyCommand.Path )"
    Invoke-Build -Task $Tasks -File $MyInvocation.MyCommand.Path @PSBoundParameters
    return
}

Import-Module gsudoModule
Import-Module PSDesiredStateConfiguration -MinimumVersion 2.0 -MaximumVersion 2.99

$Sources = Get-ChildItem -Path .\configs -Include *.ps1 -Recurse
$Tests   = Get-ChildItem -Path .\tests -Include *.Tests.ps1 -Recurse

$CONFIG_NAME = 'Workstation'

# Synopsis: Statically analyses the codebase for badness.
Add-BuildTask lint -Inputs $Sources -Outputs "${PSScriptRoot}/checkstyle.xml" {
	Import-Module PSScriptAnalyzer
	. ./lib/Write-ScriptAnalyzerCheckstyle.ps1

	# Run the linter, producing a list of result objects.
	$Results = Invoke-ScriptAnalyzer `
			-Path $PSScriptRoot `
			-RecurseCustomRulePath `
			-IncludeDefaultRules `
			-ReportSummary `
			-Recurse

	# Get the total count of errors in the results.
	$ErrorCount = $Results `
		| Where-Object { $_.Severity -eq 'Error' } `
		| Measure-Object

	# Cannot have any errors at all
	Assert-Build `
		-Condition ( $ErrorCount.Count -eq 0 ) `
		-Message "Cannot have any linting errors. $( $ErrorCount.Count ) errors found."

	Write-ScriptAnalyzerCheckstyle $Results $Outputs -Debug

}

# Synopsis: Generates JUnit and JaCoCo output using availabel Pester tests.
Add-BuildTask test @{
	Inputs  = ( $Sources + $Tests )
	Outputs = @( 'junit.xml', 'coverage.xml' )
	Jobs    = {
		Import-Module Pester
		# https://pester.dev/docs/commands/New-PesterConfiguration
		Invoke-Pester -Configuration @{
			Run = @{
				Path          = '.'
				TestExtension = '.Tests.ps1'
				'Exit'        = $True
			}
			CodeCoverage = @{
				Enabled      = $True
				OutputFormat = 'JaCoCo'
				OutputPath   = ${Outputs}[1]
			}
			TestResult = @{
				Enabled      = $True
				OutputFormat = 'JUnitXml'
				OutputPath   = ${Outputs}[0]
			}
		}
	}
}

# https://learn.microsoft.com/en-us/powershell/dsc/getting-started/wingettingstarted?view=dsc-2.0

# NOTE: Doesn't need an `If` check, since the command auto-filters non-stopped
#       services anyway.
task WinrmInitService @{
	If   = { (Get-Service -Name WinRm).Status -eq 'Stopped' }
	Jobs = {
		Invoke-Gsudo {
			Start-Service -Name WinRM -PassThru `
				| ForEach-Object { $_.WaitForStatus('Running') }
		}
	}
}

# Synopsis: Ensures that the config request size is enough to run DSC.
task WinrmInitRequestEnvelope @{
	If   = {
		Invoke-Gsudo {
			$CurrentSize = (Get-Item -Path WSMan:\localhost\MaxEnvelopeSizeKb).Value
			Write-Debug "WinRM request envelope size currently set to ${CurrentSize}."
			$CurrentSize -gt 2048 # wtf is this -gt instead of -lt ?
		}
	}
	Jobs = {
		Invoke-Gsudo {
			Set-Item -Path WSMan:\localhost\MaxEnvelopeSizeKb -Value 2048
		}
	}
}

# Synopsis: Performs all the required WinRM initialisation steps.
task WinrmInit -Jobs WinrmInitService, WinrmInitRequestEnvelope

# Synopsis: Builds the configuration.
Add-BuildTask Build @{
	Inputs  = $Sources
	Outputs = @(
		".\${CONFIG_NAME}\localhost.mof",
		".\${CONFIG_NAME}\localhost.meta.mof"
	)
	Jobs    = {

		# Sort out the configuration inputs before using them.
		$Configs = $Input | ForEach-Object {
			Write-Verbose "Loading config from $_"
			. $_
			$_ | Split-Path -LeafBase
		}

		configuration $CONFIG_NAME {

			LocalConfigurationManager {
				DebugMode = 'ForceModuleImport'
			}

			$Configs | ForEach-Object {
				Write-Verbose "Executing $_ within localhost node context."
				& $_
			}

		}

		Write-Debug "Executing Workstation config build."
		& $CONFIG_NAME

	}
}

# Synopsis: Runs DSC testing on compiled config.
Add-BuildTask 'TestDsc' @{
	Inputs  = ".\${CONFIG_NAME}\localhost.mof"
	Outputs = ".\${CONFIG_NAME}\localhost.tested"
	Jobs    = @( 'Build', {

		Invoke-Gsudo -ArgumentList ".\${CONFIG_NAME}" {
			. ./lib/Format-DscStatus.ps1
			Test-DscConfiguration `
					-Path $Args[0] `
					-ErrorAction 'Stop' `
				| Format-DscStatus
		}

		New-Item -Path $Outputs -Type File -Force `
			| Out-Null

	} )
}

# Synopsis: Applies compiled config.
Add-BuildTask Apply @{
	Inputs  = ".\${CONFIG_NAME}\localhost.mof"
	Outputs = ".\${CONFIG_NAME}\localhost.applied"
	Jobs    = @( 'TestDsc', {

		Invoke-Gsudo {
			Start-DscConfiguration `
				-Path ".\${CONFIG_NAME}" `
				-Force `
				-Wait `
				-Verbose
		}

		. ./lib/Format-DscStatus.ps1
		Get-DscConfigurationStatus `
			| Format-DscStatus

		New-Item -Path $Outputs -Type File -Force `
			| Out-Null
			
	} )
}

# Synopsis: Default task.
Add-BuildTask . Lint, Build, 'TestDsc'
