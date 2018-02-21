/*
      -----------------------------------------------------------------
      Missing Database Backups
      -----------------------------------------------------------------
     
      For more SQL resources, check out SQLServer365.blogspot.com

      -----------------------------------------------------------------

      You may alter this code for your own purposes.
      You may republish altered code as long as you give due credit.
      You must obtain prior permission before blogging this code.
 
      THIS CODE AND INFORMATION ARE PROVIDED "AS IS"
     
      -----------------------------------------------------------------
*/
-- Change database context
USE msdb;
GO

-- Create temporary table for database names
IF OBJECT_ID('tempDB.dbo.#Database') IS NOT NULL
      DROP TABLE #Database ;
CREATE TABLE #Database
(
      ID INT IDENTITY (1,1),
      DatabaseName VARCHAR(255)
);
GO
-- Declare variables
DECLARE @Date DATETIME

-- Set variables
SET @Date = GETDATE()-1

-- Get database in FULL recovery WITH a FULL backup in the last 24 hours
INSERT INTO #Database
SELECT DISTINCT
      database_name
FROM
      msdb.dbo.backupset
WHERE
      recovery_model = 'FULL'
      AND [type] = 'D'
      AND backup_finish_date > @Date;

-- Get databases in FULL recovery without a FULL backup in the last 24 hours
SELECT
      b.database_name AS DatabaseName,
      MAX(b.backup_finish_date) AS LastFullBackup
FROM
      msdb.dbo.backupset b
WHERE
      b.database_name NOT IN (SELECT DatabaseName FROM #Database)
      AND b.recovery_model = 'FULL'
      AND b.[type] = 'D'
      AND b.backup_finish_date < @Date
GROUP BY b.database_name
ORDER BY b.database_name ASC;
GO

