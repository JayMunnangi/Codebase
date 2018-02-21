sp_configure 'show advanced options',1
RECONFIGURE WITH OVERRIDE
GO
sp_configure 'xp_cmdshell',1
RECONFIGURE WITH OVERRIDE
GO
DECLARE    @TimeZone            NVARCHAR(100)
,@ProductVersion    SYSNAME
,@PlatForm            SYSNAME
,@Windows_Version    SYSNAME
,@Processors        SYSNAME
,@PhysicalMemory    SYSNAME
,@ServiceAccount    SYSNAME
,@IPAddress            SYSNAME
,@DOMAIN            SYSNAME
,@MachineType        SYSNAME
,@SQLServerIP        VARCHAR(255)
,@CMD                VARCHAR(100)
,@Node1                VARCHAR(100)
,@Node2                VARCHAR(100)
,@Node1IP            VARCHAR(100)
,@Node2IP            VARCHAR(100)
,@OSEdition            VARCHAR(100)
,@OSVersion            VARCHAR(100)
,@OSName            VARCHAR(100)
,@OSPatchLevel        VARCHAR(100)
 
CREATE TABLE #TempTable
(
[Index] VARCHAR(2000),
[Name] VARCHAR(2000),
[Internal_Value] VARCHAR(2000),
[Character_Value] VARCHAR(2000)
) ;
 
INSERT INTO #TempTable
EXEC xp_msver;
-- Replace @Value_Name to N'TimeZoneKeyName' when running on Windows 2008
EXEC   master.dbo.xp_regread
@rootkey      = N'HKEY_LOCAL_MACHINE',
@key          = N'SYSTEM\CurrentControlSet\Control\TimeZoneInformation',
@value_name   = N'StandardName',
@value        = @TimeZone output
 
EXEC   master.dbo.xp_regread
@rootkey      = N'HKEY_LOCAL_MACHINE',
@key          = N'SYSTEM\CurrentControlSet\Services\MSSQLServer',
@value_name   = N'ObjectName',
@value        = @ServiceAccount output
 
EXEC   master.dbo.xp_regread
@rootkey      = N'HKEY_LOCAL_MACHINE',
@key          = N'SYSTEM\CurrentControlSet\Control\ProductOptions',
@value_name   = N'ProductType',
@value        = @MachineType output
 
EXEC   master.dbo.xp_regread
@rootkey      = N'HKEY_LOCAL_MACHINE',
@key          = N'SYSTEM\CurrentControlSet\Services\Tcpip\Parameters',
@value_name   = N'Domain',
@value        = @DOMAIN output
 
EXEC   master.dbo.xp_regread
@rootkey      = N'HKEY_LOCAL_MACHINE',
@key          = N'CLUSTER\NODES\1',
@value_name   = N'NodeName',
@value        = @Node1 output
 
EXEC   master.dbo.xp_regread
@rootkey      = N'HKEY_LOCAL_MACHINE',
@key          = N'CLUSTER\NODES\2',
@value_name   = N'NodeName',
@value        = @Node2 output
 
EXEC   master.dbo.xp_regread
@rootkey      = N'HKEY_LOCAL_MACHINE',
@key          = N'SOFTWARE\Microsoft\Windows NT\CurrentVersion',
@value_name   = N'ProductName',
@value        = @OSName output
 
create table #OSEdition (VALUe varchar(255),OSEdition varchar(255), data varchar(100))
insert into #OSEdition
EXEC   master.dbo.xp_regread
@rootkey      = N'HKEY_LOCAL_MACHINE',
@key          = N'SYSTEM\CurrentControlSet\Control\ProductOptions',
@value_name   = N'ProductSuite'
SET @OSEdition = (SELECT TOP 1 OSedition  FROM #OsEdition)
 
EXEC   master.dbo.xp_regread
@rootkey      = N'HKEY_LOCAL_MACHINE',
@key          = N'SOFTWARE\Microsoft\Windows NT\CurrentVersion',
@value_name   = N'CSDVersion',
@value        = @OSPatchLevel output
 
set @cmd = 'ping ' + @Node1
create table #Node1IP (grabfield varchar(255))
insert into #Node1IP exec master.dbo.xp_cmdshell @cmd
 
set @cmd = 'ping ' + @Node2
create table #Node2IP (grabfield varchar(255))
insert into #Node2IP exec master.dbo.xp_cmdshell @cmd
 
set @cmd = 'ping ' + @@servername
create table #SQLServerIP (grabfield varchar(255))
insert into #SQLServerIP exec master.dbo.xp_cmdshell @cmd
 
SET        @SQLServerIP    =    (
SELECT substring(grabfield,  charindex('[',grabfield)+1, charindex(']',grabfield)-charindex('[',grabfield)-1)
from #SQLServerIP  where left(grabfield,7) = 'Pinging'
)
SET        @Node1IP            =    (
SELECT substring(grabfield,  charindex('[',grabfield)+1, charindex(']',grabfield)-charindex('[',grabfield)-1)
from #Node1IP  where left(grabfield,7) = 'Pinging'
)
 
SET        @Node2IP            =    (
SELECT substring(grabfield,  charindex('[',grabfield)+1, charindex(']',grabfield)-charindex('[',grabfield)-1)
from #Node2IP  where left(grabfield,7) = 'Pinging'
)
 
SET        @ProductVersion =    (SELECT Character_Value from #TempTable where [INDEX]=2)
SET        @Platform        =    (SELECT Character_Value from #TempTable where [INDEX]=4)
SET        @Windows_Version=    (SELECT Character_Value from #TempTable where [INDEX]=15)
SET        @Processors        =    (SELECT Character_Value from #TempTable where [INDEX]=16)
SET        @PhysicalMemory    =    (SELECT Character_Value from #TempTable where [INDEX]=19)
 
SELECT
ServerName            =    @@SERVERNAME
,OSName                =    @OSName
,OSEdition            =    @OSEdition
,OSPatchLevel        =    @OSPatchLevel
,SQLServerIP        =    @SQLServerIP
,IsClustered        =    SERVERPROPERTY('IsClustered')
,Node1_Name            =    @Node1
,Node1_IP            =    @Node1IP
,Node2_Name            =    @Node2
,Node2_IP            =    @Node2IP
,SQLServerEdition    =    SERVERPROPERTY('Edition')
,SQLServerLevel        =    SERVERPROPERTY('ProductLevel')
,ServerTimeZone        =    @TimeZone
,SQLServerVersion    =    @ProductVersion
,SQLServerPlatform    =    @PlatForm
,ProcessorCore        =    @Processors
,PhysicalMemory        =    @PhysicalMemory
,ServiceAccountName    =    @ServiceAccount
,WKS_Server            =    @MachineType
,Domain                =    @DOMAIN
 
GO
DROP TABLE #Node1IP
DROP TABLE #NODE2IP
DROP TABLE #SQLServerIP
DROP TABLE #TempTable
DROP TABLE #OSEdition
GO
 
sp_configure 'xp_cmdshell',0
RECONFIGURE WITH OVERRIDE
GO
sp_configure 'show advanced options',0
RECONFIGURE WITH OVERRIDE
GO
