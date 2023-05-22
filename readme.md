# ESXI Hardening PowerCLI Script

## Things to take into account before blindly running the script:

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
<details open>
<summary>General (Section 1)</summary>
<br>

### 1.1(L1) Ensure ESXi is properly patched - 
This should have a defined process in the environment and cannot be automated by this script.

### 1.3 (L1) Ensure no unauthorized kernel modules are loaded on the host
By default ESXi hosts do not permit the loading of kernel modules but this can be overridden - if you suspect unauthorized modules are being used, audit the kernel for any unsigned modules.

</details>

### 2.2(L1) Ensure the ESXi host firewall is configured to restrict access to services running on the host.
This cannot be automated - If you want to use the internal ESXi firewall do this thorugh the web client.

#2.4(L2) Ensure default self-signed certificate for ESXi communication is not used
# To change the Cert replace the self signed certificate with your own, it is recommended to rename the current certificates and keep them just incase you need them in the future.

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

### 7.4(L1) Ensure port groups are not configured to the value of the native LAN
To stop using the native VLAN ID for port groups, perform the following:
1. From the vSphere Web Client, select the host.
2. Click Configure then expand Networking.
3. Select Virtual switches.
4. Expand the Standard vSwitch.
5. View the topology diagram of the switch, which shows the various port groups
associated with that switch.
6. For each port group on the vSwitch, verify and record the VLAN IDs used.
7. If a VLAN ID change is needed, click the name of the port group in the topology
diagram of the virtual switch.
8. Click the Edit settings option.
9. In the Properties section, enter an appropriate name in the Network label field.
10. In the VLAN ID dropdown select or type a new VLAN.
11. Click OK

### 7.5(L1) Ensure port groups are not configured to VLAN values reserved by upstream physical switches
To change the VLAN values for port groups to non-reserved values, perform the following:

1. From the vSphere Web Client, select the host.
2. Click Configure then expand Networking.
3. Select Virtual switches.
4. Expand the Standard vSwitch.
5. View the topology diagram of the switch, which shows the various port groups
associated with that switch.
6. For each port group on the vSwitch, verify and record the VLAN IDs used.
Page 111
7. If a VLAN ID change is needed, click the name of the port group in the topology
diagram of the virtual switch.
8. Click the Edit settings option.
9. In the Properties section, enter an appropriate name in the Network label field.
10. In the VLAN ID dropdown select or type a new VLAN.
11. Click OK.

### 7.6 (L1) Ensure port groups are not configured to VLAN 4095 and 0 except for Virtual Guest Tagging (VGT)
To set port groups to values other than 4095 and 0 unless VGT is required, perform the following:

1. From the vSphere Web Client, select the host.
2. Click Configure then expand Networking.
3. Select Virtual switches.
4. Expand the Standard vSwitch.
5. View the topology diagram of the switch, which shows the various port groups
associated with that switch.
Page 113
6. For each port group on the vSwitch, verify and record the VLAN IDs used.
7. If a VLAN ID change is needed, click the name of the port group in the topology
diagram of the virtual switch.
8. Click the Edit settings option.
9. In the Properties section, enter an appropriate name in the Network label field.
10. In the VLAN ID dropdown select or type a new VLAN.
11. Click OK

### 7.7 (L1) Ensure Virtual Distributed Switch Netflow traffic is sent to an authorized collector
Using the vSphere Web Client:

1. Go to the Networking section of vCenter
2. After selecting each individual switch you will need to perform the following.
3. Go to Configure then expand Settings.
4. Click on Netflow.
5. Click on Edit.
6. Enter the Collector IP address and Collector port as required.
7. Click OK.



## Issues or feature requests:
 If you have a setting that you would like to see in this please let me know

 If you have an issue please create an issue or PR and I will fix it.

