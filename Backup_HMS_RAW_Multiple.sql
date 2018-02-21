BACKUP DATABASE [HMS_RAW] 
TO  DISK = '\\192.168.17.95\nonproddata1\CMA\Required_Backups\HMS_DoNotDelete\HMS_RAW_File1.bak',
DISK= '\\192.168.17.95\nonproddata1\CMA\Required_Backups\HMS_DoNotDelete\HMS_RAW_File2.bak',
DISK= '\\192.168.17.95\nonproddata1\CMA\Required_Backups\HMS_DoNotDelete\HMS_RAW_File3.bak',
DISK= '\\192.168.17.95\nonproddata1\CMA\Required_Backups\HMS_DoNotDelete\HMS_RAW_File4.bak'
WITH  COPY_ONLY, NOFORMAT, NOINIT,  NAME = N'HMS_RAW-Full Database Backup', SKIP, NOREWIND, NOUNLOAD,  STATS = 10,CHECKSUM, CONTINUE_AFTER_ERROR
GO