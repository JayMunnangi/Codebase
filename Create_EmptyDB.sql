----------------------------------------------------------------------------------------
-- CREATE AN EMPTY COPY OF DATABASE
----------------------------------------------------------------------------------------
/* PART 1: Backup the good database */
BACKUP DATABASE [OriginalDB] 
        TO  DISK = N'd:\backup.bak' WITH NOFORMAT, INIT,  
            NAME = N'OriginalDB-Full Database Backup', SKIP, 
        NOREWIND, NOUNLOAD,  STATS = 33
GO

/* PART 2: If your destination database already exists, drop it */
USE master -- Make sure to include this -- it allows you to reuse script in same SSMS session
DROP DATABASE [migration]

/* PART 3: Restore the backup to the new location */
RESTORE DATABASE [TargetDB] 
        FROM  DISK = N'D:\backup.bak' WITH  FILE = 1,  
        MOVE N'OriginalDB' TO N'D:\sql data\TargetDB.mdf',  
        MOVE N'OriginalDB' TO N'C:\SQL Data\TargetDB_1.ldf',  
        NOUNLOAD,  STATS = 33
GO

/* PART 4: Delete all tables' data in the migration testing target */
PRINT N'Clearing [TargetDB]'
USE [TargetDB]
EXEC sp_msforeachtable "ALTER TABLE ? NOCHECK CONSTRAINT all"       -- disable all constraints
EXEC sp_MSForEachTable "DELETE FROM ?"                  -- delete data in all tables
exec sp_msforeachtable "ALTER TABLE ? WITH CHECK CHECK CONSTRAINT all"  -- enable all constraints
----------------------------------------------------------------------------------------
-- BLANK DATABASE COPY CREATED, READY FOR TESTING
-------------------------------------------------------------------------------