# ESXi Hardening using PowerCLI for a single server.

#Used to connect to the host
$Host = Read-Host 'ESXi IP: '
$HostUser = Read-Host 'Host User: '
$HostPass = Read-Host 'User Password: ' -AsSecureString

#Used for NTP settings
$NTPServer1 = Read-Host 'Set Primary NTP Server'
$NTPServer2 = Read-Host 'Set Secondary NTP Server (Set as 0.0.0.0 if secondary not required)'

#Used for CIM Account
$serviceuserpass = Read-Host 'Set password for service user account' -AsSecureString

#Connect to the ESXi Host
Connect-VIServer -Server $Host -User $HostUser -Password $HostPass

#1.2 (L1) Ensure the image profile VIB acceptance level is configured properly
Foreach ($VMHost in Get-VMHost ) {
 $ESXCli = Get-EsxCli -VMHost $VMHost
 $ESXCli.software.acceptance.Set("PartnerSupported")
}

#1.4(L2) Ensure the default alue of individual salt per vm is configured
Get-VMHost | Get-AdvancedSetting -Name Mem.ShareForceSalting | Set-AdvancedSetting -Value 2

#2.1(L1) Ensure NTP time synchronization is configured properly
#Start NTP client service and set to automatic
Get-VMHost | Get-VmHostService | Where-Object {$_.key -eq “ntpd”} | Start-VMHostService

$NTPServers = "$NTPServer1", "$NTPServer2"
Get-VMHost | Add-VmHostNtpServer $NTPServers

#2.3(L1) Ensure Managed Object Browser (MOB) is disabled 
Get-VMHost | Get-AdvancedSetting -Name Config.HostAgent.plugins.solo.enableMob | Set-AdvancedSetting -value "false"

#2.5(L1) Ensure SNMP is configured properly
Get-VmHostSNMP | Set-VMHostSNMP -Enabled:$false

#2.6(L1) Ensure dvfilter API is not configured if not used
Get-VMHost | Foreach { Set-AdvancedSetting -VMHost $_ -Name Net.DVFilterBindIpAddress -IPValue "" }

#2.9(L2) Ensure VDS Health check is disabled
Get-View -ViewType DistributedVirtualSwitch | ?{($_.config.HealthCheckConfig | ?{$_.enable -notmatch "False"})}| %{$_.UpdateDVSHealthCheckConfig(@((New-Object Vmware.Vim.VMwareDVSVlanMtuHealthCheckConfig -property @{enable=0}),(New-Object Vmware.Vim.VMwareDVSTeamingHealthCheckConfig -property @{enable=0})))}

#4.2(L1) Ensure passwords are required to be complex
Get-VMHost | Get-AdvancedSetting -Name Security.PasswordQualityControl | Set-AdvancedSetting -Value "retry=3 min=disabled,disabled,disabled,disabled,14"

#4.3(L1) Ensure the maximum failed login attempts is set to 5
Get-VMHost | Get-AdvancedSetting -Name Security.AccountLockFailures | Set-AdvancedSetting -Value 5

#4.4(L1) Ensure account lockout is set to 15 minutes
Get-VMHost | Get-AdvancedSetting -Name Security.AccountUnlockTime | Set-AdvancedSetting -Value 900

#4.5(L1) Ensure previous 5 passwords are prohibited
Get-VMHost | Get-AdvancedSetting Security.PasswordHistory | Set-AdvancedSetting -Value 5

#5.1(L1) Ensure the DCUI timeout is set to 600 seconds or less
Get-VMHost | Get-AdvancedSetting -Name UserVars.DcuiTimeOut | Set-AdvancedSetting -Value 600

#5.2(L1) Ensure the ESXi Shell is disabled
Get-VMHost | Get-VMHostService | Where { $_.key -eq "TSM" } | Set-VMHostService -Policy Off

#5.3(L1) Ensure SSH is disabled
Get-VMHost | Get-VMHostService | Where { $_.key -eq "TSM-SSH" } | Set-VMHostService -Policy Off

#5.4(L1) Ensure CIM access is limited
New-VMHostAccount -ID ServiceUser -Password $serviceuserpass -UserAccount

#5.8(L1) Ensure idle ESXi shell and SSH sessions time out after 300 seconds or less
Get-VMHost | Get-AdvancedSetting -Name 'UserVars.ESXiShellInteractiveTimeOut' | Set-AdvancedSetting -Value "300"

#5.9(L1) Ensure the shell services timeout is set to 1 hour or less
Get-VMHost | Get-AdvancedSetting -Name 'UserVars.ESXiShellTimeOut' | Set-AdvancedSetting -Value "3600"

#5.10(L1) Ensure DCUI has a trusted users list for lockdown mode
Get-VMHost | Get-AdvancedSetting -Name 'DCUI.Access' | Set-AdvancedSetting -Value "root"

#7.1(L1) Ensure the vSwitch Forged Transmits policy is set to reject
Get-VirtualSwitch | Get-SecurityPolicy | Set-SecurityPolicy -ForgedTransmits $false
Get-VirtualPortGroup | Get-SecurityPolicy | Set-SecurityPolicy -AllowPromiscuousInherited $true

#7.2(L1) Ensure the vSwitch MAC Address Change policy is set to reject
Get-VirtualSwitch | Get-SecurityPolicy | Set-SecurityPolicy -MacChanges $false
Get-VirtualPortGroup | Get-SecurityPolicy | Set-SecurityPolicy -MacChangesInherited $true 

#7.3(L1) Ensure the vSwitch Promiscuous Mode policy is set to reject
Get-VirtualSwitch | Get-SecurityPolicy | Set-SecurityPolicy -AllowPromiscuous $false
Get-VirtualPortGroup | Get-SecurityPolicy | Set-SecurityPolicy -AllowPromiscuousInherited $true

#8.1.1(L2) Ensure only one remote console connection is permitted to a VM at any time 
Get-VM | New-AdvancedSetting -Name "RemoteDisplay.maxConnections" -value 1 -Force

# 8.2.1(L1) Ensure unnecessary floppy devices are disconnected
Get-VM | Get-FloppyDrive | Remove-FloppyDrive

# 8.2.2(L2) Ensure unnecessary CD/DVD devices are disconnected
Get-VM | Get-CDDrive | Remove-CDDrive

# 8.2.5 (L1) Ensure unnecessary USB devices are disconnected
Get-VM | Get-USBDevice | Remove-USBDevice

# 8.2.6 (L1) Ensure unauthorized modification and disconnection of devices is disabled
Get-VM | New-AdvancedSetting -Name "isolation.device.edit.disable" -value $true

# 8.2.7 (L1) Ensure unauthorized connection of devices is disabled
Get-VM | New-AdvancedSetting -Name "isolation.device.connectable.disable" -value $true

# 8.2.8 (L1) Ensure PCI and PCIe device passthrough is disabled
Get-VM | New-AdvancedSetting -Name "pciPassthru*.present" -value ""

# 8.4.2 (L2) Ensure Autologon is disabled
Get-VM | New-AdvancedSetting -Name "isolation.tools.ghi.autologon.disable" -value $true

# 8.4.3 (L2) Ensure BIOS BBS is disabled
Get-VM | New-AdvancedSetting -Name "isolation.bios.bbs.disable" -value $true

# 8.4.4 (L2) Ensure Guest Host Interaction Protocol Handler is set to disabled
Get-VM | New-AdvancedSetting -Name "isolation.tools.ghi.protocolhandler.info.disable" -value $true

# 8.4.5 (L2) Ensure Unity Taskbar is disabled
Get-VM | New-AdvancedSetting -Name "isolation.tools.unity.taskbar.disable" -value $true

# 8.4.6 (L2) Ensure Unity Active is disabled
Get-VM | New-AdvancedSetting -Name "isolation.tools.unityActive.disable" -value $True

# 8.4.7 (L2) Ensure Unity Window Contents is disabled
Get-VM | New-AdvancedSetting -Name "isolation.tools.unity.windowContents.disable" -value $True

# 8.4.8 (L2) Ensure Unity Push Update is disabled
Get-VM | New-AdvancedSetting -Name "isolation.tools.unity.push.update.disable" -value $true

# 8.4.9 (L2) Ensure Drag and Drop Version Get is disabled
Get-VM | New-AdvancedSetting -Name "isolation.tools.vmxDnDVersionGet.disable" -value $true

# 8.4.10 (L2) Ensure Drag and Drop Version Set is disabled
Get-VM | New-AdvancedSetting -Name "isolation.tools.guestDnDVersionSet.disable" -value $true

# 8.4.11 (L2) Ensure Shell Action is disabled
Get-VM | New-AdvancedSetting -Name "isolation.ghi.host.shellAction.disable" -value $true

# 8.4.12 (L2) Ensure Request Disk Topology is disabled
Get-VM | New-AdvancedSetting -Name "isolation.tools.dispTopoRequest.disable" -value $true

# 8.4.13 (L2) Ensure Trash Folder State is disabled
Get-VM | New-AdvancedSetting -Name "isolation.tools.trashFolderState.disable" -value $true

# 8.4.14 (L2) Ensure Guest Host Interaction Tray Icon is disabled
Get-VM | New-AdvancedSetting -Name "isolation.tools.ghi.trayicon.disable" -value $true

# 8.4.15 (L2) Ensure Unity is disabled
Get-VM | New-AdvancedSetting -Name "isolation.tools.unity.disable" -value $true

# 8.4.16 (L2) Ensure Unity Interlock is disabled
Get-VM | New-AdvancedSetting -Name "isolation.tools.unityInterlockOperation.disable" -value $true

# 8.4.17 (L2) Ensure GetCreds is disabled
Get-VM | New-AdvancedSetting -Name "isolation.tools.getCreds.disable" -value $true

# 8.4.18 (L2) Ensure Host Guest File System Server is disabled
Get-VM | New-AdvancedSetting -Name "isolation.tools.hgfsServerSet.disable" -value $true

# 8.4.19 (L2) Ensure Guest Host Interaction Launch Menu is disabled
Get-VM | New-AdvancedSetting -Name "isolation.tools.ghi.launchmenu.change" -value $true

# 8.4.20 (L2) Ensure memSchedFakeSampleStats is disabled
Get-VM | New-AdvancedSetting -Name "isolation.tools.memSchedFakeSampleStats.disable" -value $true
 
# 8.4.21 (L1) Ensure VM Console Copy operations are disabled
Get-VM | New-AdvancedSetting -Name "isolation.tools.copy.disable" -value $true

# 8.4.22 (L1) Ensure VM Console Drag and Drop operations is disabled
Get-VM | New-AdvancedSetting -Name "isolation.tools.dnd.disable" -value $true

# 8.4.23 (L1) Ensure VM Console GUI Options is disabled
Get-VM | New-AdvancedSetting -Name "isolation.tools.setGUIOptions.enable" -value $false

# 8.4.24 (L1) Ensure VM Console Paste operations are disabled
Get-VM | New-AdvancedSetting -Name "isolation.tools.paste.disable" -value $true

# 8.5.2 (L2) Ensure hardware-based 3D acceleration is disabled
Get-VM | New-AdvancedSetting -Name "mks.enable3d" -value $false

# 8.6.1 (L2) Ensure nonpersistent disks are limited
Get-VM | Get-HardDisk | Set-HardDisk -Persistence IndependentPersistent

# 8.6.2 (L1) Ensure virtual disk shrinking is disabled
Get-VM | New-AdvancedSetting -Name "isolation.tools.diskShrink.disable" -value $true

# 8.6.3 (L1) Ensure virtual disk wiping is disabled
Get-VM | New-AdvancedSetting -Name "isolation.tools.diskWiper.disable" -value $true

# 8.7.1 (L1) Ensure the number of VM log files is configured properly
Get-VM | New-AdvancedSetting -Name "log.keepOld" -value "10"

# 8.7.2 (L2) Ensure host information is not sent to guests
Get-VM | New-AdvancedSetting -Name "tools.guestlib.enableHostInfo" -value $false

# 8.7.3 (L1) Ensure VM log file size is limited
Get-VM | New-AdvancedSetting -Name "log.rotateSize" -value "1024000"