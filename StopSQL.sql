#Likewise, you can use Stop-Service PowerShell cmdlets to stop a running Windows service on a local or remote machine.

# Stop SQL Server Database   engine service (default instance)
Stop-Service -Name 'MSSQLSERVER' 
 
 
# Stop SQL Server Integration   Services on SQL Server 2012 box
Stop-Service -Name 'MsDtsServer110' 
 
# Stop SQL Server Analysis   services engine service (default instance)
Stop-Service -Name 'MSSQLServerOLAPService'   
 
# Stop SQL Server Reporting   Server service (default instance)
Stop-Service -Name 'ReportServer' 
 
# Stop SQL Server SQL Server   Agent service (default instance)
Stop-Service -Name 'SQLSERVERAGENT'

# Stop SQL Server Database   engine service (default instance) along with dependent service
Stop-Service -Name 'MSSQLSERVER' -Force
