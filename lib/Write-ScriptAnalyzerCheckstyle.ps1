#!/usr/bin/env pwsh
#Requires -PSEdition Core
#Requires -Version 7.3
#Requires -Modules PSScriptAnalyzer

using namespace Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic

<#
	.SYNOPSIS
		Writes PSScriptAnalyzer results to a checkstyle-formatted file.
	.PARAMETER Results
		The results produced by running `Invoke-ScriptAnalyzer`.
	.NOTES
		https://github.com/PowerShell/PSScriptAnalyzer/issues/1296
#>
function Write-ScriptAnalyzerCheckstyle {
	param (

		[Parameter(Mandatory)]
		[DiagnosticRecord[]] $Results,

		[Parameter()]
		[String] $Output

	)
	begin {

		# Initialise the xml writer object.
		$XmlWriter = New-Object System.Xml.XmlTextWriter($Output, $Null)

		# Configure the output format
		$XmlWriter.Formatting = 'Indented'
		$XmlWriter.Indentation = 1
		$XmlWriter.IndentChar = "`t"

		# Open the main document
		$XmlWriter.WriteStartDocument()
		$XmlWriter.WriteStartElement("checkstyle")
		$XmlWriter.WriteAttributeString("version", "1.0.0")

	}
	process {

		# Group results by file to work better in the report.
		$FileResults = ( $Results | Group-Object `
			-Property ScriptName `
			-AsHashTable ) `
			?? @{}

		foreach ($FileResult in ($FileResults ?? @{}).GetEnumerator()) {
			$XmlWriter.WriteStartElement("file")
			$XmlWriter.WriteAttributeString("name", ${FileResult}.Name)
			foreach ($Result in $FileResult.Value) {
				$XmlWriter.WriteStartElement("error")
				$XmlWriter.WriteAttributeString("line", $Result.Line)
				$XmlWriter.WriteAttributeString("column", $Result.Column)
				$XmlWriter.WriteAttributeString("severity", $Result.Severity)
				$XmlWriter.WriteAttributeString("message", $Result.Message)
				$XmlWriter.WriteAttributeString("source", $Result.RuleName)
				$XmlWriter.WriteEndElement()
			}
			$XmlWriter.WriteEndElement()
		}

	}
	end {

		# Close the main document.
		$XmlWriter.WriteEndElement()
		$XmlWriter.WriteEndDocument()

		# Force pending writes to file.
		$XmlWriter.Flush()

	}
	clean {

		# Ensure that the writer is closed properly.
		$XmlWriter.Close()

	}
}
