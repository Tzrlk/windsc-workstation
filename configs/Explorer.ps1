#!/usr/bin/env pwsh
#Requires -PSEdition Core
#Requires -Modules @{ ModuleName="PSDesiredStateConfiguration"; ModuleVersion="2.0"; MaximumVersion="2.99" }
#Requires -Modules PSDscResources

configuration Explorer {

    File appData {
        DestinationPath = Join-Path $env:USERPROFILE 'AppData'
        Type            = 'Directory'
        Attributes      = @( 'ReadOnly' )
    }
 
    File programData {
        DestinationPath = $env:ProgramData
        Type            = 'Directory'
        Attributes      = @( 'ReadOnly' )
    }

    Registry folderViewExpand {
        Key       = 'HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        ValueName = 'NavPaneExpandToCurrentFolder'
        ValueType = 'DWord'
        ValueData = @( '1' )
    }

    Registry folderViewFileExt {
        Key       = 'HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        ValueName = 'HideFileExt'
        ValueType = 'DWord'
        ValueData = @( '0' )
    }

    Registry folderViewSeparateProc {
        Key       = 'HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        ValueName = 'SeparateProcess'
        ValueType = 'DWord'
        ValueData = @( '1' )
    }

}
