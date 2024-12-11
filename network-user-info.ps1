# Collect basic system and user data

# Get the currently logged-in user
$user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

# Get the SID using Get-WmiObject (this avoids errors with the SecurityIdentifier constructor)
$userSID = (Get-WmiObject -Class Win32_UserAccount -Filter "Name='$env:USERNAME'" | Select-Object -ExpandProperty SID)

# Get user full name (if available)
$userInfo = Get-WmiObject -Class Win32_UserAccount -Filter "Name='$env:USERNAME'" 
$fullName = $userInfo.FullName

# Get the computer name
$computerName = $env:COMPUTERNAME

# Get the OS version
$osVersion = [System.Environment]::OSVersion

# Get the system architecture (32-bit or 64-bit)
$architecture = [System.Environment]::Is64BitOperatingSystem
if ($architecture) {
    $architecture = '64-bit'
} else {
    $architecture = '32-bit'
}

# Get the computer model
$computerModel = (Get-WmiObject -Class Win32_ComputerSystem).Model

# Get the system boot time
$bootTime = (Get-WmiObject -Class Win32_OperatingSystem).LastBootUpTime

# Check if the computer is domain-joined
$domainJoined = (Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain

# Domain-related info if the computer is domain-joined
$domainController = ""
$domainName = ""
if ($domainJoined) {
    $domainController = (Get-WmiObject -Class Win32_NTDomain).Name
    $domainName = (Get-WmiObject -Class Win32_ComputerSystem).Domain
}

# Get user profile path
$userProfilePath = [System.Environment]::GetFolderPath('UserProfile')

# Get the list of network interfaces and their statuses
$networkInterfaces = Get-NetAdapter | Select-Object Name, Status, MACAddress

# Get the IP addresses of the active network interfaces
$networkIPs = Get-NetIPAddress | Select-Object InterfaceAlias, IPAddress, AddressFamily

# Get the routing table to see the active routes
$routes = Get-NetRoute | Select-Object DestinationPrefix, NextHop, InterfaceAlias

# Gather the information in a string
$systemInfo = @"
System Information:
-------------------
Computer Name: $computerName
OS Version: $osVersion
Logged-in User: $user
Full Name: $fullName
User SID: $userSID
System Architecture: $architecture
Computer Model: $computerModel
Boot Time: $bootTime
User Profile Path: $userProfilePath

Domain Info:
------------
Domain Joined: $domainJoined
Domain Controller: $domainController
Domain Name: $domainName

Network Interfaces:
-------------------
$($networkInterfaces | Format-Table -AutoSize | Out-String)

IP Addresses:
-------------
$($networkIPs | Format-Table -AutoSize | Out-String)

Routing Table:
--------------
$($routes | Format-Table -AutoSize | Out-String)
"@

# Determine a safe folder path (either C:\Temp or AppData if C:\Temp doesn't exist)
$tempPath = "C:\Temp"
if (-not (Test-Path $tempPath)) {
    # Create C:\Temp if it doesn't exist
    New-Item -ItemType Directory -Path $tempPath
}

# Save the information to a text file in C:\Temp
$systemInfo | Out-File "$tempPath\system_info.txt" -Force
