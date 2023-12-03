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
    [String[]] $Tasks

)

$ErrorActionPreference = 'Stop'

if ([System.IO.Path]::GetFileName($MyInvocation.ScriptName) -ne 'Invoke-Build.ps1') {
    Import-Module 'InvokeBuild'
        
    Invoke-Build -Task $Tasks -File $MyInvocation.MyCommand.Path @PSBoundParameters
    return
}

# TODO: Put this in its own file.
function Display-Status {

    [CmdletBinding()]
    param(

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [Object]
        $Status

    )

    Write-Output 'Resolved:'
    if ( $Status.ResourcesInDesiredState ) {
        $Status.ResourcesInDesiredState | ForEach-Object {
            $LocationArgs = $_.SourceInfo.Replace("${PSScriptRoot}\", '').Replace('::', ' ').Split()
            [PSCustomObject]@{
                Name = $_.InstanceName
                Type = $_.ResourceName
                File = $LocationArgs[0]
                Line = $LocationArgs[1]
            }

        } | Format-Table
    }

    Write-Output 'Unresolved:'
    if ( $Status.ResourcesNotInDesiredState ) {
        $Status.ResourcesNotInDesiredState | ForEach-Object {
            $LocationArgs = $_.SourceInfo.Replace("${PSScriptRoot}\", '').Replace('::', ' ').Split()
            [PSCustomObject]@{
                Name   = $_.InstanceName
                Type   = $_.ResourceName
                File   = $LocationArgs[0]
                Line   = $LocationArgs[1]

            }
        } | Format-Table
    }

}


Import-Module PSScriptAnalyzer
Import-Module Pester

$Sources = Get-ChildItem -Path . -Include *.ps1 -Exclude *.Tests.ps1 -Recurse -Name
$Tests   = Get-ChildItem -Path . -Include *.Tests.ps1 -Recurse -Name
$Modules = Get-ChildItem -Path . -Include *.psd1 -Recurse -Name

# Synopsis: Statically analyses the codebase for badness.
Add-BuildTask lint -Inputs ${Sources} -Outputs "${PSScriptRoot}/checkstyle.xml" {

	# Run the linter, producing a list of result objects.
	$Results = Invoke-ScriptAnalyzer `
			-Path "${PSScriptRoot}" `
			-CustomRulePath "${PSScriptRoot}/.lint-rules" `
			-RecurseCustomRulePath `
			-IncludeDefaultRules `
			-ReportSummary `
			-Recurse

	# Get the total count of errors in the results.
	$ErrorCount = ${Results} `
		| Where-Object { ${_}.Severity -eq [DiagnosticSeverity]::Error } `
		| Measure-Object

	# Cannot have any errors at all
	Assert-Build `
		-Condition ( ${ErrorCount}.Count -eq 0 ) `
		-Message "Cannot have any linting errors. $(${ErrorCount}.Count) errors found."

	# Group results again by file to work better in the report.
	$FileResults = ${Results} | Group-Object `
		-Property ScriptName `
		-AsHashTable

	# Write a checkstyle-formatted report to disk.
	# https://github.com/PowerShell/PSScriptAnalyzer/issues/1296
	$XmlWriter = New-Object System.Xml.XmlTextWriter("${Outputs}", $Null)
	try {
		$XmlWriter.Formatting = 'Indented'
		$XmlWriter.Indentation = 1
		$XmlWriter.IndentChar = "`t"
		$XmlWriter.WriteStartDocument()
		$XmlWriter.WriteStartElement("checkstyle")
		$XmlWriter.WriteAttributeString("version", "1.0.0")
		foreach ($FileResult in (${FileResults} ?? @{}).GetEnumerator()) {
			$XmlWriter.WriteStartElement("file")
			$XmlWriter.WriteAttributeString("name", ${FileResult}.Name)
			foreach ($Result in ${FileResult}.Value) {
				$XmlWriter.WriteStartElement("error")
				$XmlWriter.WriteAttributeString("line", ${Result}.Line)
				$XmlWriter.WriteAttributeString("column", ${Result}.Column)
				$XmlWriter.WriteAttributeString("severity", ${Result}.Severity)
				$XmlWriter.WriteAttributeString("message", ${Result}.Message)
				$XmlWriter.WriteAttributeString("source", ${Result}.RuleName)
				$XmlWriter.WriteEndElement()
			}
			$XmlWriter.WriteEndElement()
		}
		$XmlWriter.WriteEndElement()
		$XmlWriter.WriteEndDocument()
		$XmlWriter.Flush()
	} finally {
		$XmlWriter.Close()
	}

}

# Synopsis: Generates JUnit and JaCoCo output using availabel Pester tests.
Add-BuildTask test -Inputs ( ${Sources} + ${Tests} ) -Outputs junit.xml, coverage.xml {
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
	Install-Module 'xPSDesiredStateConfiguration'
}

task 'dsc-build' -Inputs .\configs\powershell.ps1 -Outputs .\Workstation\localhost.mof {
 	. .\configs\Powershell.ps1

	Import-Module 'xPSDesiredStateConfiguration'

 	# TODO: This can probably be put in its own file.
	Configuration Workstation {
 		Node 'localhost' {
   			Powershell
		}
 	}

	Workstation
}

task 'dsc-test' -Inputs .\Workstation\localhost.mof {
	$Result = Test-Dsc-Configuration -Path .\Workstation
 	Display-Status $Result
}

task 'dsc-apply' -Inputs .\Workstation\localhost.mof {
	Start-DscConfiguration -Path .\Workstation -Force -Wait -Verbose
	Display-Status ( Get-DscConfigurationStatus )
}

# Synopsis: Default task.
Add-BuildTask . lint, test, dsc-build, dsc-test
