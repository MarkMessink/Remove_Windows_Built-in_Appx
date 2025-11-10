<#
.SYNOPSIS
	This script will remove all built-in appx with a provisioning package that's not specified in the 'white-list' in this script.
	
	FileName:    RemoveBuiltinAppx.ps1
    Author:      Mark Messink
    Contact:     
    Created:     2020-07-05
    Updated:     2024-05-08

    Version history:
	1.0.3 - (2021-12-21) Windows 10 build 21H2, Windows 11 build 21H2
	1.0.4 - Changed logging
	1.0.5 - Add creating list of installed Appx to Installed_Appx_List.txt
	1.0.6 - (2022-12-21) Windows 10 build 21H2, Windows 11 build 22H2
	1.0.7 - (2024-05-08) Windows 11 build 23H2, Windows Insider preview 26080

.DESCRIPTION
	This script will remove all built-in appx with a provisioning package that's not specified in the 'white-list' in this script.

.PARAMETER
	<beschrijf de parameters die eventueel aan het script gekoppeld moeten worden>

.INPUTS
	White list of appx packages to keep installed
	Create new list --> 'Get-AppxProvisionedPackage -online | FT Displayname'

.OUTPUTS
	logfiles:
	PSlog_<naam>	Log gegenereerd door een powershell script
	INlog_<naam>	Log gegenereerd door Intune (Win32)
	AIlog_<naam>	Log gegenereerd door de installer van een applicatie bij de installatie van een applicatie
	ADlog_<naam>	Log gegenereerd door de installer van een applicatie bij de de-installatie van een applicatie
	Een datum en tijd wordt automatisch toegevoegd

.EXAMPLE
	./scriptnaam.ps1

.LINK Information
	https://learn.microsoft.com/en-us/windows/application-management/provisioned-apps-windows-client-os

.NOTES
	WindowsBuild:
	Het script wordt uitgevoerd tussen de builds LowestWindowsBuild en HighestWindowsBuild
	LowestWindowsBuild = 0 en HighestWindowsBuild 50000 zijn alle Windows 10/11 versies
	LowestWindowsBuild = 19000 en HighestWindowsBuild 19999 zijn alle Windows 10 versies
	LowestWindowsBuild = 22000 en HighestWindowsBuild 22999 zijn alle Windows 11 versies
	Zie: https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information


.NOTES
	Microsoft Store:
	The Store app can be removed. If you want to remove and reinstall the Store app, you can only bring Store back by either restoring your system from a backup or resetting your system. 
	Instead of removing the Store app, you should use group policies to hide or disable it.
	
.NOTES
	Remove an Appx:
	You can remove an app by adding a ### to the beginning of a line
	every line ends with a comma except the last line!
	
#>

#################### Variabelen #####################################
$logpath = "C:\IntuneLogs"
$NameLogfile = "PSlog_RemoveBuiltinAppx.txt"
$LowestWindowsBuild = 26080
$HighestWindowsBuild = 50000
$InstalledAppxList = "Installed_Appx_List.txt"



#################### Einde Variabelen ###############################


#################### Start base script ##############################
### Niet aanpassen!!!

# Prevent terminating script on error.
$ErrorActionPreference = 'Continue'

# Create logpath (if not exist)
If(!(test-path $logpath))
{
      New-Item -ItemType Directory -Force -Path $logpath
}

# Add date + time to Logfile
$TimeStamp = "{0:yyyyMMdd}" -f (get-date)
$logFile = "$logpath\" + "$TimeStamp" + "_" + "$LowestWindowsBuild" + "_" + "$NameLogfile"

# Start Transcript logging
Start-Transcript $logFile -Append -Force

# Start script timer
$scripttimer = [system.diagnostics.stopwatch]::StartNew()

# Controle Windows Build
$WindowsBuild = [System.Environment]::OSVersion.Version.Build
Write-Output "------------------------------------"
Write-Output "Windows Build: $WindowsBuild"
Write-Output "------------------------------------"
If ($WindowsBuild -ge $LowestWindowsBuild -And $WindowsBuild -le $HighestWindowsBuild)
{
#################### Start base script ################################

#################### Start uitvoeren script code ####################
Write-Output "#####################################################################################"
Write-Output "### Start uitvoeren script code                                                   ###"
Write-Output "#####################################################################################"

#Create list installed Appx
[system.Environment]::OSVersion.Version | Out-File -FilePath $logpath\$InstalledAppxList -Append
Get-AppxProvisionedPackage -online | FT Displayname | Out-File -FilePath $logpath\$InstalledAppxList -Append

#Create WhiteList Array
$WhiteListedAppx = New-Object -TypeName System.Collections.ArrayList

<##### APPx that shouldn't be removed #####>
	$WhiteListedAppx.AddRange(@(
	"Microsoft.WindowsStore", # Microsoft Store - Remove is unsupported
	"Microsoft.SecHealthUI", # Microsoft defender - This app is part of Windows and cannot be uninstalled 
	"Microsoft.DesktopAppInstaller" # Winget feature - Cannot be uninstalled.
	))
	
<##### Microsoft Edge Browser, Use Default installed Edge or deploy Edge from Intune #####>
	$WhiteListedAppx.AddRange(@(
	### "Microsoft.MicrosoftEdge.Stable"
	))
	
<##### Other Apps #####>
	$WhiteListedAppx.AddRange(@(
	"Microsoft.CompanyPortal",
	"Microsoft.OneDriveSync"
	))
    		
<##### Windows 11 Build: 26080 #####>
	$WhiteListedAppx.AddRange(@(
    "Microsoft.ApplicationCompatibilityEnhancements",
    "Microsoft.AV1VideoExtension",   
    "Microsoft.AVCEncoderVideoExtension",                             
    "Microsoft.HEIFImageExtension",                
    "Microsoft.HEVCVideoExtension",                               
    "Microsoft.MicrosoftOfficeHub",                
    "Microsoft.MPEG2VideoExtension",                
    "Microsoft.Paint",               
    "Microsoft.RawImageExtension",
    "Microsoft.ScreenSketch",                 
    "Microsoft.SecHealthUI",                      
    "Microsoft.StorePurchaseApp",                    
    "Microsoft.VP9VideoExtensions",                  
    "Microsoft.WebMediaExtensions",                
    "Microsoft.WebpImageExtension",                               
    "Microsoft.WindowsAlarms",                    
    "Microsoft.WindowsCalculator",
    "Microsoft.WindowsCamera",                 
    "Microsoft.WindowsNotepad",                     
    "Microsoft.WindowsSoundRecorder",
    "MicrosoftCorporationII.QuickAssist",
    "MicrosoftWindows.Client.WebExperience"  # last whitelisted item no comma

	))

Write-Output "-------------------------------------------------------------------------------"
Write-Output "Starting built-in AppxPackage, AppxProvisioningPackage removal process"
Write-Output "-------------------------------------------------------------------------------"

# Determine provisioned apps
$AppArrayList = Get-AppxProvisionedPackage -Online | Select-Object -ExpandProperty DisplayName

# Loop through the list of appx packages
foreach ($App in $AppArrayList) {
	Write-Output "-------------------------------------------------------------------------------"
    Write-Output "Processing appx package: $($App)"

    # If application name not in appx package white list, remove AppxPackage and AppxProvisioningPackage
    if (($App -in $WhiteListedAppx)) {
        Write-Output "--- Skipping excluded application package: $($App)"
        }
        else {
            # Gather package names
            $AppPackageFullName = Get-AppxPackage -Name $App | Select-Object -ExpandProperty PackageFullName -First 1
            $AppProvisioningPackageName = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $App } | Select-Object -ExpandProperty PackageName -First 1

            # Attempt to remove AppxPackage
            if ($AppPackageFullName -ne $null) {
                try {
                    Write-Output ">>> Removing AppxPackage: $($AppPackageFullName)"
                    Remove-AppxPackage -Package $AppPackageFullName -ErrorAction Stop | Out-Null
                }
                catch [System.Exception] {
                    Write-Output "!!! Removing AppxPackage '$($AppPackageFullName)' failed: $($_.Exception.Message)"
                }
            }
            else {
                Write-Output "!!! Unable to locate AppxPackage for current app: $($App)"
            }

            # Attempt to remove AppxProvisioningPackage
            if ($AppProvisioningPackageName -ne $null) {
                try {
                    Write-Output ">>> Removing AppxProvisioningPackage: $($AppProvisioningPackageName)"
                    Remove-AppxProvisionedPackage -PackageName $AppProvisioningPackageName -Online -ErrorAction Stop | Out-Null
                }
                catch [System.Exception] {
                    Write-Output "!!! Removing AppxProvisioningPackage '$($AppProvisioningPackageName)' failed: $($_.Exception.Message)"
                }
            }
            else {
                Write-Output "!!! Unable to locate AppxProvisioningPackage for current app: $($App)"
            }
        }
    }

    # Complete
	Write-Output "-------------------------------------------------------------------------------"
    Write-Output "Completed built-in AppxPackage, AppxProvisioningPackage removal process"
	Write-Output "-------------------------------------------------------------------------------"

Write-Output "#####################################################################################"
Write-Output "### Einde uitvoeren script code                                                   ###"
Write-Output "#####################################################################################"
#################### Einde uitvoeren script code ####################

#################### End base script #######################

# Controle Windows Build
}Else {
Write-Output "-------------------------------------------------------------------------------------"
Write-Output "### Windows Build versie voldoet niet, de script code is niet uitgevoerd. ###"
Write-Output "-------------------------------------------------------------------------------------"
}

#Stop and display script timer
$scripttimer.Stop()
Write-Output "------------------------------------"
Write-Output "Script elapsed time in seconds:"
$scripttimer.elapsed.totalseconds
Write-Output "------------------------------------"

#Stop Logging
Stop-Transcript
#################### End base script ################################

#################### Einde Script ###################################