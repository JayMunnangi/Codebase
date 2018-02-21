--Script 1: Backup specific database

-- 1. Variable declaration

DECLARE @path VARCHAR(500)
DECLARE @name VARCHAR(500)
DECLARE @pathwithname VARCHAR(500)
DECLARE @time DATETIME
DECLARE @year VARCHAR(4)
DECLARE @month VARCHAR(2)
DECLARE @day VARCHAR(2)
DECLARE @hour VARCHAR(2)
DECLARE @minute VARCHAR(2)
DECLARE @second VARCHAR(2)

-- 2. Setting the backup path

SET @path = '\\atxentwfps-p02\prod_db_backup\IRD\IRDWSWQL-P01\HermesProd1\DIFF\'
--SET @path = 'E:\Backup\'

-- 3. Getting the time values

SELECT @time   = GETDATE()
SELECT @year   = (SELECT CONVERT(VARCHAR(4), DATEPART(yy, @time)))
SELECT @month  = (SELECT CONVERT(VARCHAR(2), FORMAT(DATEPART(mm,@time),'00')))
SELECT @day    = (SELECT CONVERT(VARCHAR(2), FORMAT(DATEPART(dd,@time),'00')))
SELECT @hour   = (SELECT CONVERT(VARCHAR(2), FORMAT(DATEPART(hh,@time),'00')))
SELECT @minute = (SELECT CONVERT(VARCHAR(2), FORMAT(DATEPART(mi,@time),'00')))
SELECT @second = (SELECT CONVERT(VARCHAR(2), FORMAT(DATEPART(ss,@time),'00')))

-- 4. Defining the filename format

SELECT @name ='HermesProd1' + '_' + @year + @month + @day + @hour + @minute + @second

SET @pathwithname = @path + @name + '.bak'

--5. Executing the backup command

BACKUP DATABASE [HermesProd1] 
TO DISK = @pathwithname WITH Name=N'@name,Encrypted',DIFFERENTIAL,FORMAT, INIT, SKIP, NOREWIND, NOUNLOAD, STATS = 5, COMPRESSION,
ENCRYPTION
(
    ALGORITHM = AES_256, SERVER CERTIFICATE = iRoundProductionCert
)
GO