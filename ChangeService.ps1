#Load the SqlWmiManagement assembly off of the DLL

[System.Reflection.Assembly]::LoadWithPartialName(“Microsoft.SqlServer.SqlWmiManagement”) | out-null

$SMOWmiserver = New-Object (‘Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer’) “ashfinwmdb-p03” #Suck in the server you want

 

#These just act as some queries about the SQL Services on the machine you specified.

$SMOWmiserver.Services | select name, type, ServiceAccount, DisplayName, Properties, StartMode, StartupParameters | Format-Table

#Same information just pivot the data

$SMOWmiserver.Services | select name, type, ServiceAccount, DisplayName, Properties, StartMode, StartupParameters | Format-List

 

#Specify the “Name” (from the query above) of the one service whose Service Account you want to change.

#$ChangeService=$SMOWmiserver.Services | where {$_.name -eq “SQLBrowser”} #Make sure this is what you want changed!
#$ChangeService=$SMOWmiserver.Services | where {$_.name -eq “ReportServer”} #Make sure this is what you want changed!
#$ChangeService=$SMOWmiserver.Services | where {$_.name -eq “SQL Server Distributed Replay Client”} #Make sure this is what you want changed!
#$ChangeService=$SMOWmiserver.Services | where {$_.name -eq “MsDtsServer120”} #Make sure this is what you want changed!
#$ChangeService=$SMOWmiserver.Services | where {$_.name -eq "MSSQLServerOLAPService"} #Make sure this is what you want changed!
$ChangeService=$SMOWmiserver.Services | where {$_.name -eq “SQLSERVERAGENT”} #Make sure this is what you want changed!

#Check which service you have loaded first

$ChangeService

 

$UName=”ADVISORY\svc_MSSQLSERVER”

$PWord=”0umn(4k&h*$)L”

 

$ChangeService.SetServiceAccount($UName, $PWord)

#Now take a look at it afterwards

$ChangeService

 

#To soo what else you could do to that service run this:  $ChangeService | gm