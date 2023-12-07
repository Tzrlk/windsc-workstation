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

. ./lib/Format-DscStatus.ps1
. ./lib/Write-ScriptAnalyzerCheckstyle.ps1

$Sources = Get-ChildItem -Path .\configs -Include *.ps1 -Recurse
$Tests   = Get-ChildItem -Path .\tests -Include *.Tests.ps1 -Recurse

# Synopsis: Statically analyses the codebase for badness.
Add-BuildTask lint -Inputs $Sources -Outputs "${PSScriptRoot}/checkstyle.xml" {
	Import-Module PSScriptAnalyzer

	# Run the linter, producing a list of result objects.
	$Results = Invoke-ScriptAnalyzer `
			-Path $PSScriptRoot `
			-CustomRulePath "${PSScriptRoot}/.lint-rules" `
			-RecurseCustomRulePath `
			-IncludeDefaultRules `
			-ReportSummary `
			-Recurse

	# Get the total count of errors in the results.
	$ErrorCount = $Results `
		| Where-Object { $_.Severity -eq [DiagnosticSeverity]::Error } `
		| Measure-Object

	# Cannot have any errors at all
	Assert-Build `
		-Condition ( $ErrorCount.Count -eq 0 ) `
		-Message "Cannot have any linting errors. $( $ErrorCount.Count ) errors found."

	Write-ScriptAnalyzerCheckstyle $Results

}

# Synopsis: Generates JUnit and JaCoCo output using availabel Pester tests.
Add-BuildTask test -Inputs ( $Sources + $Tests ) -Outputs junit.xml, coverage.xml {
	Import-Module Pester
	# https://pester.dev/docs/commands/New-PesterConfiguration
	Invoke-Pester -Configuration @{
		Run = @{
			Path          = '.'
			TestExtension = '.tests.ps1'
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

# https://learn.microsoft.com/en-us/powershell/dsc/getting-started/wingettingstarted?view=dsc-1.1

task 'dsc-install' {
	Install-Module 'PSDscResources'
	Install-Module 'PSDesiredStateConfiguration' -MinimumVersion 2.0 -MaximumVersion 2.99
}

task 'dsc-build' -Inputs $Sources -Outputs .\Workstation\localhost.mof {
	Import-Module PSDesiredStateConfiguration -MinimumVersion 2.0 -MaximumVersion 2.99

	# Sort out the configuration inputs before using them.
	$Configs = $Input | ForEach-Object {
		Write-Verbose "Loading config from $_"
		. $_
		$_ | Split-Path -LeafBase
	}

	# Write-Debug "Creating workstation config from $( $Configs.GetEnumerator() )"
	configuration Workstation {
		Node 'localhost' {
			$Configs | ForEach-Object {
				Write-Verbose "Executing $_ within localhost node context."
				& $_ -Verbose
			}
		}
	}

	Write-Debug "Executing Workstation config build."
	Workstation -Verbose

}

task 'dsc-test' -Inputs .\Workstation\localhost.mof -Outputs .\Workstation\localhost.tested {
	Test-DscConfiguration -Path .\Workstation `
			-ErrorAction 'Stop' `
		| Format-DscStatus
	New-Item -Path $Outputs -Type File -Force | Out-Nulls
}

task 'dsc-apply' -Inputs .\Workstation\localhost.mof -Outputs .\Workstation\localhost.applied {
	Start-DscConfiguration `
		-Path .\Workstation `
		-Force `
		-Wait `
		-Verbose
	Get-DscConfigurationStatus `
		| Format-DscStatus
	New-Item -Path $Outputs -Type File -Force | Out-Null
}

# Synopsis: Default task.
Add-BuildTask . lint, test, dsc-build, dsc-test
