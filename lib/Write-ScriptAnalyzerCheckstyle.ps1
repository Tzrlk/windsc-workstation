#!/usr/bin/env pwsh
#Requires -PSEdition Core
#Requires -Modules PSScriptAnalyzer

<#
	.SYNOPSIS
		Writes PSScriptAnalyzer results to a checkstyle-formatted file.
	.PARAMETER Results
		The results produced by running `Invoke-ScriptAnalyzer`.
#>
function Write-ScriptAnalyzerCheckstyle {
	param (

		[Parameter(Mandatory)]
		$Results

	)
	process {

		# Group results again by file to work better in the report.
		$FileResults = $Results | Group-Object `
			-Property ScriptName `
			-AsHashTable

		# Write a checkstyle-formatted report to disk.
		# https://github.com/PowerShell/PSScriptAnalyzer/issues/1296
		$XmlWriter = New-Object System.Xml.XmlTextWriter($Outputs, $Null)
		try {
			$XmlWriter.Formatting = 'Indented'
			$XmlWriter.Indentation = 1
			$XmlWriter.IndentChar = "`t"
			$XmlWriter.WriteStartDocument()
			$XmlWriter.WriteStartElement("checkstyle")
			$XmlWriter.WriteAttributeString("version", "1.0.0")
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
			$XmlWriter.WriteEndElement()
			$XmlWriter.WriteEndDocument()
			$XmlWriter.Flush()
		} finally {
			$XmlWriter.Close()
		}

	}
}
