If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))

{   
$arguments = "& '" + $myinvocation.mycommand.definition + "'"
Start-Process powershell -Verb runAs -ArgumentList $arguments
Break
}

#Starting and Stopping SQL Server Services

#You can use Start-Service PowerShell cmdlets to start a Windows service on a local or remote machine. With this script you can start SQL Server related services.

# Start SQL Server Database   engine service (default instance)
Start-Service -Name 'MSSQLSERVER' 
 
# Start SQL Server Integration   Services on SQL Server 2012 box
Start-Service -Name 'MsDtsServer120' 
 
# Start SQL Server Analysis   services engine service (default instance)
Start-Service -Name 'MSSQLServerOLAPService'   
 
# Start SQL Server Reporting   Server service (default instance)
Start-Service -Name 'ReportServer' 
 
# Start SQL Server SQL Server   Agent service (default instance)
Start-Service -Name 'SQLSERVERAGENT'

