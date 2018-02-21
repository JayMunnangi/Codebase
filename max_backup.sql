DBCC TRACEON (3605, -1)
DBCC TRACEON (3213, -1)

BACKUP DATABASE [CMR_prod] TO  
DISK = N'\\atxentwfps-p02\prod_db_backup\CMR\ATXCMRWSQL-P02\CMR_prod\ParallelTest\AdWks001-singleton.bak' 
--DISK = N'\\atxentwfps-p02\prod_db_backup\CMR\ATXCMRWSQL-P02\CMR_prod\ParallelTest\AdWks002.bak',  
--DISK = N'\\atxentwfps-p02\prod_db_backup\CMR\ATXCMRWSQL-P02\CMR_prod\ParallelTest\AdWks003.bak',
--DISK = N'\\atxentwfps-p02\prod_db_backup\CMR\ATXCMRWSQL-P02\CMR_prod\ParallelTest\AdWks004.bak',
--DISK = N'\\atxentwfps-p02\prod_db_backup\CMR\ATXCMRWSQL-P02\CMR_prod\ParallelTest\AdWks005.bak',
--DISK = N'\\atxentwfps-p02\prod_db_backup\CMR\ATXCMRWSQL-P02\CMR_prod\ParallelTest\AdWks006.bak'
WITH COPY_ONLY, STATS = 10, COMPRESSION

--Adding Buffer
@BUFFERCOUNT = 2200,
@BLOCKSIZE = 65536,
@MAXTRANSFERSIZE=2097152,
GO

DBCC TRACEOFF(3605, -1)
DBCC TRACEOFF(3213, -1)


sqlcmd -E -S $(ESCAPE_SQUOTE(SRVR)) -d master -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = 'USER_DATABASES', @Directory = N'\\atxentwfps-p02\prod_db_backup\CMR', @BackupType = 'FULL', @Verify = 'N',@BUFFERCOUNT = 2200,@BLOCKSIZE = 65536,@MAXTRANSFERSIZE=2097152, @compress = 'Y', @CleanupTime = 672, @CheckSum = 'Y', @LogToTable = 'Y'" -b