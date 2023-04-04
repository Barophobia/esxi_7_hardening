# ESXI Hardening PowerCLI Script

## Things to take into account before blindly running the script:

 - you may need to change the NTP variables in the script if you want to use a specific ntp server, this can be done in line 24.
 - This script DISABLES snmp, if this is required change line 37 to:
 ```
Get-VmHostSNMP | Set-VMHostSNMP -Enabled:$true -ReadOnlyCommunity '<secret>'
Set-VMHostSnmp -AddTarget -TargetCommunity '<trapCommunity>' -TargetHost '<trapDestination>'
 ```
 Make sure you change the values inside the '<>' to the correct value.
 - This script will NOT configure the internal ESXi firewall, if you want to do that you must do it through the web ui.
 - Certificates are not touched so if you don't want to use the self signed certificate then you must change them yourself. (It is recommended to keep a backup of the original certificates just incase they are required in the future)

## Recommended remediations that must be done manually:

### 2.7(L1) Ensure expired and revoked SSL certificates are removed from the ESXi server

### 2.8(L1) Ensure vSphere Authentication Proxy is used when adding hosts to active directory
This must be done through the web ui.

To properly set the vSphere Authentication Proxy from Web Client directly:
1. Select the host
2. Click on Configure then expand System, select Authentication Services.
3. Click on Join Domain
4. Select Using Proxy Server radio button.
5. Provide proxy server IP address.

To properly set the vSphere Authentication Proxy via Host Profiles:
1. In the vSphere Web Client go to Home in the menu.
2. Click on Policies and Profiles followed by Host Profiles.
3. Choose the appropriate host profile
4. Select Configure followed by Edit Host Profile... then expand Security and Services followed by Security Settings, then Authentication configuration.
5. Select Active Directory configuration.
6. Set the JoinDomain Method is configured to Use vSphere Authentication Proxy to add the host to the domain.
7. Click on Save.

### 3.1(L1) Ensure a centralised location is configured to collect ESXi host core dumps
Configure remote Dump Collector Server
```
esxcli system coredump network set -v [VMK#] -i [DUMP_SERVER] -o [PORT]
```

Enable remote Dump Collector
```
esxcli system coredump network set -e true
```

### 3.3(L1) Ensure remote logging is configured for ESXi hosts
To configure remote logging properly, perform the following from the vSphere web client:
1. Select the host
2. Click Configure then expand System then select Advanced System Settings.
3. Select Edit then enter Syslog.global.logHost in the filter.
4. Set the Syslog.global.logHost to the hostname or IP address of the central log server.
5. Click OK.

or

PowerCli:
```
Get-VMHost | Foreach { Set-AdvancedSetting -VMHost $_ -Name Syslog.global.logHost -Value "<NewLocation>" }
```
Make sure you change the '<NewLocation>'.

### 4.1(L1) Ensure a non-root user account exists for local admin access
To create one or more named user accounts (local ESXi user accounts), perform the following using the vSphere client (not the vSphere web client) for each ESXi host:
1. Connect directly to the ESXi host using the vSphere Client.
2. Login as root.
3. Select Manage, then select the Security & Users tab.
4. Select Users then click Add user to add a new user.
5. Once added now select the Host, then select Actions followed by Permissions. 
6. Assign the Administrator role to the user.

## Issues or feature requests:
 If you have a setting that you would like to see in this please let me know

 If you have an issue please create an issue on this repo and I will fix it.

