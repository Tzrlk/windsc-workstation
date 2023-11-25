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

# TODO: Tasks for lint, pester, dsc.

# https://learn.microsoft.com/en-us/powershell/dsc/getting-started/wingettingstarted?view=dsc-1.1

task 'dsc-install' {
    Install-Module 'PSDscResources'
}


task 'dsc-apply' {

    Start-DscConfiguration -Path '' -Wait -Verbose

}