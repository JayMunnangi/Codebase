if exists (Select * from sys.databases SD where SD.name='<DBANEM>' and (SD.is_in_standby+SD.state)=0)
            Begin
            BACKUP DATABASE [<DBNAME>] 
             TO  DISK = N'<BackupLocation>' 
             WITH  COPY_ONLY, NOFORMAT, NOINIT,  
             NAME = N'<BackupFileName>', SKIP, NOREWIND, NOUNLOAD,  STATS = 10
            End
