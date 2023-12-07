#!/usr/bin/env pwsh
#Requires -PSEdition Core
#Requires -Modules @{ ModuleName="PSDesiredStateConfiguration"; ModuleVersion="2.0"; MaximumVersion="2.99" }

<#
	.SYNOPSIS
		Formats a DSC status into something more readable than the default.
	.PARAMETER Status
		The status object returned either by invoking a DSC configuration, or
		running Get-DscConfiguration explicitly.
#>
function Format-DscStatus {
    [CmdletBinding()]
    param (

        [Parameter(Mandatory,ValueFromPipeline)]
        [ValidateNotNull()]
        [Object]
        $Status

    )
	begin {
		$Resolved   = @()
		$Unresolved = @()
		function Convert-DscStatusItem {
			param (
				[Parameter(Mandatory,ValueFromPipeline)]
				[Object] $Item
			)
			process {
				$LocationArgs = $Item.SourceInfo.Replace("${PSScriptRoot}\", '').Replace('::', ' ').Split()
				[PSCustomObject]@{
					Name = $Item.InstanceName
					Type = $Item.ResourceName
					File = $LocationArgs[0]
					Line = $LocationArgs[1]
				}
			}
		}
	}
	process {
		
		Write-Debug "Processing resources in desired state."
		$Status.ResourcesInDesiredState | Convert-DscStatusItem | ForEach-Object { $Resolved += $_ }

		Write-Debug "Processing resources not in desired state."
		$Status.ResourcesNotInDesiredState | Convert-DscStatusItem | ForEach-Object { $Unresolved += $_ }

	}
	end {

		Write-Output 'Resolved:'
		$Resolved | Format-Table

		Write-Output 'Unresolved:'
		$Unresolved | Format-Table

	}

}
