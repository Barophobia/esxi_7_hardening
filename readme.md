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
 - Certificates are not touched so if you don't want to use the self signed certificate then you must change them yourself.(It is recommended to keep a backup of the original certificates just incase they are required in the future)
 - Hosts are NOT put into lockdown mode

## Recommended remediations that must be done manually or are not completed by the script:

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

### 4.6(L1) Ensure Active Directory is used for local user authentication
To use AD for local user authentication, perform the following from the vSphere Web Client:
1. Select the host
2. Click on Configure then expand System.
3. Select Authentication Services.
4. Click Join Domain followed by the appropriate domain and credentials.
5. Click OK

Or

PowerCLI:
```
Get-VMHost HOST1 | Get-VMHostAuthentication | Set-VMHostAuthentication -Domain domain.local -User Administrator -Password Passw0rd -JoinDomain
```

### 4.7(L1) Ensure only authorized users and groups belong to the esxAdminsGroup group
To remove unauthorized users and groups belonging to esxAdminsGroup, perform the following steps after coordination between vSphere admins and Active Directory admins:
1. Verify the setting of the esxAdminsGroup attribute.
2. View the list of members for that Microsoft Active Directory group.
3. Remove all unauthorized users and groups from that group.

If full admin access for the AD ESX admins group is not desired, you can disable this behavior using the advanced host setting:
*"Config.HostAgent.plugins.hostsvc.esxAdminsGroupAutoAdd"*

### 4.8(L1) Ensure the Exception users list is properly configured
To correct the membership of the Exception Users list, perform the following in the vSphere Web Client:
1. Select the host.
2. Click on Configure then expand System and select Security Profile.
3. Select Edit next to Lockdown Mode.
4. Click on Exception Users.
5. Add or delete users as appropriate.
6. Click OK.

### 5.4(L1) Ensure CIM access is limited
To limit CIM access, perform the following:
1. Create a limited-privileged service account for CIM and other third-party applications.
2. This account should access the system via vCenter.
3. Give the account the CIM Interaction privilege only. This will enable the account
to obtain a CIM ticket, which can then be used to perform both read and write CIM operations on the target host. If an account must connect to the host directly, this account must be granted the full "Administrator" role on the host. This is not recommended unless required by the monitoring software being used.

Or run the following PowerCLI command:

```
New-VMHostAccount -ID ServiceUser -Password <password> -UserAccount
```
### 5.5/5.6(L1 & L2) Ensure Normal/Strict Lockdown mode is enabled
To enable lockdown mode, perform the following from the vSphere web client:
1. From the vSphere Web Client, select the host.
2. Select Configure then expand System and select Security Profile.
3. Across from Lockdown Mode click on Edit.
4. Click the radio button for Normal or Strict.
5. Click OK.

### 5.7(L2) Ensure the SSH authorized_keys file is empty
This isn't done by the script as you should be using SSH keys in a secure environment.
To remove all keys from the authorized_keys file, perform the following:
1. Logon to the ESXi shell as root or another admin user. SSH may need to be enabled first
2. Edit the /etc/ssh/keys-root/authorized_keys file.
3. Remove all keys from the file and save the file.

### 5.10(L1) Ensure DCUI has a trusted users list for lockdown mode
To set a trusted users list for DCUI, perform the following from the vSphere web client:
1. From the vSphere Web Client, select the host.
2. Click Configure then expand System.
3. Select Advanced System Settings then click Edit.
4. Enter DCUI.Access in the filter.
5. Set the DCUI.Access attribute is set to a comma-separated list of the users who are allowed to override lockdown mode.

### 5.11(L2) Ensure contents of exposed configuration files have not been modified.
In a secure environment data integrity should be monitored and authorised people should have access to the required systems through an RBAC system. 

Host profiles could be used to track configuration changes on hosts but they do not track everything.

### 6.1(L1) Ensure bidirectional CHAP authentication for iSCSI traffic is enabled
To enable bidirectional CHAP authentication for iSCSI traffic, perform the following:
1. From the vSphere Web Client, select the host.
2. Click Configure then expand Storage.
3. Select Storage Adapters then select the iSCSI Adapter.
4. Under Properties click on Edit next to Authentication.
5. Next to Authentication Method select Use bidirectional CHAP from the dropdown.
6. Specify the outgoing CHAP name.
    • Make sure that the name you specify matches the name configured on the storage side.
        o To set the CHAP name to the iSCSI adapter name, select "Use initiator name".
        o To set the CHAP name to anything other than the iSCSI initiator name, deselect "Use initiator name" and type a name in the Name text box.
7. Enter an outgoing CHAP secret to be used as part of authentication. Use the same secret as your storage side secret.
8. Specify incoming CHAP credentials. Make sure your outgoing and incoming secrets do not match.
9. Click OK.
10. Click the second to last symbol labeled Rescan Adapter.

### 6.2(L2) Ensure the uniqueness of CHAP authentication secrets for iSCSI traffic
To change the values of CHAP secrets so they are unique, perform the following:
1. From the vSphere Web Client, select the host.
2. Click Configure then expand Storage.
3. Select Storage Adapters then select the iSCSI Adapter.
4. Under Properties click on Edit next to Authentication.
5. Next to Authentication Method specify the authentication method from the dropdown.
    o None
    o Use unidirectional CHAP if required by target
    o Use unidirectional CHAP unless prohibited by target
    o Use unidirectional CHAP
    o Use bidirectional CHAP
6. Specify the outgoing CHAP name.
    • Make sure that the name you specify matches the name configured on the storage side.
        o To set the CHAP name to the iSCSI adapter name, select "Use initiator name".
        o To set the CHAP name to anything other than the iSCSI initiator name, deselect "Use initiator name" and type a name in the Name text box.
7. Enter an outgoing CHAP secret to be used as part of authentication. Use the same secret as your storage side secret.
8. If configuring with bidirectional CHAP, specify incoming CHAP credentials.
    • Make sure your outgoing and incoming secrets do not match.
9. Click OK.
10. Click the second to last symbol labeled Rescan Adapter

### 6.3(L1) Ensure SAN Resources are segregated properly
SAN's should have restictive zoning to prevent misconfigurations that can occur.

### 7.1(L1) Ensure the vSwitch Forged Transmits policy is set to reject
This should be set to reject but can effect applications so an exception should be made for the port groups that require this.
As this is different for everyone it is not included in the script.

To set the policy:
```
esxcli network vswitch standard policy security set -v vSwitch2 -f false
```
Change the vswitch in the command to whatever is required.

### 7.2(L1) Ensure the vSwitch MAC address change policy is set to reject
This should be set to reject to stop bad actors.
As this is different for everyone it is not included in the script.

To set the policy:
```
esxcli network vswitch standard policy security set -v vSwitch2 -m false
```

### 7.3(L1) Ensure the vSwitch Promiscuous mode policy is set to reject
There are legitimate reasons to leave this enabled. Some security devices required the ability to see all packets on a vSwitch.

To set the policy:
```
esxcli network vswitch standard policy security set -v vSwitch2 -p false
```

### 7.4(L1) Ensure port groups are not configured to the value of the native LAN


# Create a new host user account -Host Local connection required-
New-VMHostAccount -ID ServiceUser -Password <password> -UserAccount

## Issues or feature requests:
 If you have a setting that you would like to see in this please let me know

 If you have an issue please create an issue on this repo and I will fix it.

