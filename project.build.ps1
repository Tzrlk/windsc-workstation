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

Param (

    [Parameter(Position=0)]
    [String[]] $Tasks

)

$ErrorActionPreference = 'Stop'

if ([System.IO.Path]::GetFileName($MyInvocation.ScriptName) -ne 'Invoke-Build.ps1') {
    Import-Module 'InvokeBuild'
        
    Invoke-Build -Task $Tasks -File $MyInvocation.MyCommand.Path @PSBoundParameters
    return
}

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

# TODO: Tasks for lint, pester, dsc.

# https://learn.microsoft.com/en-us/powershell/dsc/getting-started/wingettingstarted?view=dsc-1.1

task 'dsc-install' {
    Install-Module 'PSDscResources'
	Install-Module 'xPSDesiredStateConfiguration'
}

task 'dsc-build' -Inputs .\configs\powershell.ps1 -Outputs .\Workstation\localhost.mof {
 	. .\configs\powershell.ps1

	Import-Module 'xPSDesiredStateConfiguration'
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
