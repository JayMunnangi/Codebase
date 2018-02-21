EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;
GO
 
DECLARE @HkeyLocal nvarchar(18) = N'HKEY_LOCAL_MACHINE';
DECLARE @MSSqlServerRegPath nvarchar(31) = N'SOFTWARE\Microsoft\MSSQLServer';
DECLARE @InstanceRegPath sysname = @MSSqlServerRegPath + N'\MSSQLServer';
DECLARE @dataFolder nvarchar(512);
DECLARE @logFolder nvarchar(512);
 
EXEC master.dbo.xp_instance_regread @HkeyLocal, @InstanceRegPath, N'DefaultData', @dataFolder OUTPUT;
EXEC master.dbo.xp_instance_regread @HkeyLocal, @InstanceRegPath, N'DefaultLog', @logFolder OUTPUT;
 
 
DECLARE @cmd nvarchar(1024);
 
DECLARE @files table (physical_name nvarchar(MAX));
 
SET @cmd = N'dir "' + @dataFolder + N'" /s /b';
INSERT INTO @files(physical_name) EXEC xp_cmdshell @cmd;
 
SET @cmd = N'dir "' + @logFolder + N'" /s /b';
INSERT INTO @files(physical_name) EXEC xp_cmdshell @cmd;
 
DELETE FROM @files WHERE (physical_name IS NULL) OR (RIGHT(physical_name, 4) = '.cer');
 
 
SELECT
    f.physical_name
    FROM
    (
        SELECT DISTINCT
            physical_name
            FROM @files
    ) f
    WHERE
        NOT EXISTS
        (
            SELECT *
                FROM sys.master_files mf
                WHERE mf.physical_name = f.physical_name
        );
 
GO
 
--EXEC sp_configure 'xp_cmdshell', 0;
--EXEC sp_configure 'show advanced options', 0;
--RECONFIGURE;
--GO