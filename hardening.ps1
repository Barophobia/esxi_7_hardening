# ESXi Hardening using PowerCLI

$NTPServer1 = Read-Host 'Set Primary NTP Server'
$NTPServer2 = Read-Host 'Set Secondary NTP Server (Leave blank if not required)'

$serviceuserpass = Read-Host 'Set password for service user account' -AsSecureString

#1.2 (L1) Ensure the image profile VIB acceptance level is configured properly
Foreach ($VMHost in Get-VMHost ) {
 $ESXCli = Get-EsxCli -VMHost $VMHost
 $ESXCli.software.acceptance.Set("PartnerSupported")
}

#1.4(L2) Ensure the default alue of individual salt per vm is configured
Get-VMHost | Get-AdvancedSetting -Name Mem.ShareForceSalting | Set-AdvancedSetting -Value 2

#2.1(L1) Ensure NTP time synchronization is configured properly
$NTPServers = '$NTPServer1', '$NTPServer2'
Get-VMHost | Add-VmHostNtpServer $NTPServers

#2.3(L1) Ensure Managed Object Browser (MOB) is disabled 
Get-VMHost | Get-AdvancedSetting -Name Config.HostAgent.plugins.solo.enableMob | Set-AdvancedSetting -value "false"

#2.4(L2) Ensure default self-signed certificate for ESXi communication is not used
# To change the Cert replace the self signed certificate with your own, it is recommended to rename the current certificates and keep them just incase you need them in the future.

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

#7.3(L Ensure the vSwitch Promiscuous Mode policy is set to reject
Get-VirtualSwitch | Get-SecurityPolicy | Set-SecurityPolicy -AllowPromiscuous $false
Get-VirtualPortGroup | Get-SecurityPolicy | Set-SecurityPolicy -AllowPromiscuousInherited $true 