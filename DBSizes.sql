Use master
Go

Create Table #tmp_DBNames (
	DBName Varchar(200)
)

Create table #tmp_DBSpacing (
	DBName varchar(200),
	FileID Int,
	database_size Decimal(35,2),
	[MaxSize] Decimal(35,2),
	Growth Decimal(35,2)
)

Create Table #DBFile_Info (
	FileID int,
	FileGroup int,
	TotalExtents Dec(20,2),
	UsedExtents Dec(20,2),
	DB_FileName Varchar(200),
	FilePathName Varchar(500)
)

Create Table #DB_Logfile_Info (
	DBName Varchar(200),
	LogSize_Reserved Dec(20,2),
	LogSpace_Used_Percent Dec(20,2),
	Status bit
)

Create Table #DBResults (
	DBName Varchar(200),
	FileID Int,
	DB_Reserved_Space Dec(20,2),
	DB_Used_Space Dec(20,2),
	DB_Free_Space Dec(20,2),
	DB_Free_Percent Dec(20,2),
	DB_Max_Size Dec(35,2),
	DB_Growth Dec(35,2),
	Log_Reserved_Space Dec(20,2),
	Log_Used_Percent Dec(20,2),
	Log_Free_Percent Dec(20,2),
	Log_Max_Size Dec(35,2),
	Log_Growth Dec(35,2)
)

Create Table #DBFileUsage_Report (
	DBName Varchar(200),
	FileType Varchar(100),
	DB_Size_GB dec(35,4),
	Datafile_freespace_GB dec(35,4),
	DB_Pct_Used dec(35,4),
	DB_File_Max_Size_GB dec(35,4),
	DB_File_Allowed_Growth_GB dec(35,4),
	DB_File_Growth_Increment_GB dec(35,4),
	TLog_Size_GB dec(35,4),
	Logfile_Freespace_GB dec(35,4),
	Log_Pct_Used dec(35,4),
	Log_File_Max_Size_GB dec(35,4),
	Log_File_Allowed_Growth_GB dec(35,4),
	Log_File_Growth_Increment_GB dec(35,4)
)


Declare @DBName Varchar(200)
Declare @Cmd VarChar(4000)
Declare @nCmd NVarChar(4000)
Declare @RunCMD nVarchar(500)
Declare @TotalMaxLogSize Dec(20,2)
Declare @TotalLogGrowth Dec(20,2)

Insert Into #tmp_DBNames
Select Name 
from sysdatabases
--Where Name not in ('master','msdb','model','tempdb')
Where Name not in ('master','msdb','model')

-- only need to run once as it gets all DB's for current instance
Insert Into #DB_Logfile_Info
exec ('DBCC SQLPERF(LOGSPACE)')

Declare DBNames_Cursor Cursor For
	Select DBName
	From #tmp_DBNames


Open DBNames_Cursor

Fetch Next From DBNames_Cursor
into @DBName

While @@Fetch_Status = 0
Begin

	Set @Cmd = 'Select	fileid,
						convert(decimal(35,2),size) / convert( float, (1048576 /(select low from master.dbo.spt_values where number = 1 and type = ''E''))),
						convert(decimal(35,2),maxsize) / convert( float, (1048576 /(select low from master.dbo.spt_values where number = 1 and type = ''E''))),
						convert(decimal(35,2),growth) / convert( float, (1048576 /(select low from master.dbo.spt_values where number = 1 and type = ''E'')))
						From [' + @DBName + '].dbo.sysfiles'

	Set @nCmd = Cast(@Cmd As nVarchar(1000))

	insert Into #tmp_DBSpacing (fileid, database_size,[MaxSize],growth)
	Exec sp_Executesql @nCmd

	Update #tmp_DBSpacing
	Set DBName = @DBName 
	Where DBName is Null

	Set @RunCMD = 'Use [' + @DBName + '] DBCC showfilestats'

	Insert into #DBFile_Info
	Exec sp_executesql @RunCMD

	Insert Into #DBResults (DBName, FileID, DB_Reserved_Space, DB_Used_Space, DB_Free_Space, DB_Free_Percent, Log_Reserved_Space, Log_Used_Percent, Log_Free_Percent)
	Select	@DBName, 
			FileID,
			(TotalExtents * 64 /1024), 
			(UsedExtents * 64 / 1024),
			(TotalExtents * 64 /1024) - (UsedExtents * 64 / 1024),
			(((TotalExtents * 64 /1024) - (UsedExtents * 64 / 1024)) / (TotalExtents * 64 /1024)) * 100,
			LogSize_Reserved,
			LogSpace_Used_Percent,
			100 - LogSpace_Used_Percent		
	From #DBFile_Info dfi ,#DB_Logfile_Info dli
	Where dli.DBName = @DBName

	-- Update the newly populated DBResults with the MaxSize values for the data files
	Update #DBResults
	Set DB_Max_Size = #tmp_DBSpacing.[MaxSize],
		DB_Growth = #tmp_DBSpacing.Growth
	From #tmp_DBSpacing Inner Join #DBResults On #DBResults.DBName = #tmp_DBSpacing.DBName
												And #DBResults.FileID = #tmp_DBSpacing.FileID 
	Where #DBResults.DBName = @DBName

	-- Determine the maxsize for the tlog file(s)
	Select @TotalMaxLogSize = Sum(#tmp_DBSpacing.[MaxSize]),
			@TotalLogGrowth = Sum(#tmp_DBSpacing.Growth)
	From #tmp_DBSpacing 
	Where #tmp_DBSpacing.FileId Not In (Select FileID 
							From #DBResults
							Where DBName = #tmp_DBSpacing.DBName)
	And #tmp_DBSpacing.DBName = @DBName

	-- Update the max Tlog size based on the above calculation
	Update #DBResults
	Set Log_Max_Size = @TotalMaxLogSize,
		Log_Growth = @TotalLogGrowth
	Where DBName = @DBName

	Truncate table #DBFile_Info

	Fetch Next From DBNames_Cursor
	into @DBName

End

Close DBNames_Cursor
Deallocate DBNames_Cursor


Insert Into #DBFileUsage_Report
Select DBName,
		FileType = Case
			When FileId = 1 Then 'Primary File'
			Else 'Secondary File'
		End,
		(DB_Reserved_Space/1024) As 'DB File Size (GB)' ,
		(DB_Free_Space/1024) As 'DB Free Space in File (GB)',
		'DB % Used' = Case 
				When (DB_Reserved_Space/DB_Max_Size) * 100 < 0 Then 0
				Else (DB_Reserved_Space/DB_Max_Size) * 100
		End,
		(DB_Max_Size/1024) As 'DB Max Size (GB)',
		'Allowed DB Growth' = Case
				When DB_Max_Size - DB_Reserved_Space < 0 Then 0
				Else (DB_Max_Size - DB_Reserved_Space)/1024
		End,
		(DB_Growth/1024) As 'Growth Increment (GB)',
		(Log_Reserved_Space/1024) As 'Logfile Size (GB)',
		(((Log_Reserved_Space * Log_Free_Percent) /100)/1024) As 'Logfile Freespace (GB)',
		--((Log_Reserved_Space/Log_Max_Size) * 100) As 'Log % Used'
		'Log % Used' = Case
			When Log_Max_Size > 0 Then ((Log_Reserved_Space/Log_Max_Size) * 100)
			else 0
		End,
		(Log_Max_Size/1024) As 'Log Max Size (GB)',
		--((Log_Max_Size - Log_Reserved_Space)/1024) As 'Allowed Log Growth (GB)'
		'Allowed Log Growth (GB)' = Case
			When Log_Max_Size > 0 Then ((Log_Max_Size - Log_Reserved_Space)/1024)
			Else 0
		End,
		(Log_Growth/1024) As 'Growth Increment (GB)'
from #DBResults 
Order By DBName Asc, DB_Reserved_Space Desc
/*
Select DBName,
		--location.Drive,
		FileType = Case
			When FileId = 1 Then 'Primary File'
			Else 'Secondary File'
		End,
		'DB File Size (GB)' = Case 
			When DB_Reserved_Space/1024 > 1 Then Cast(DB_Reserved_Space/1024 As Varchar(50)) + ' GB'
			Else Cast(DB_Reserved_Space As Varchar(50)) + ' MB'
		End,
		'DB Free Space in File' = Case 
			When DB_Free_Space/1024 > 1 Then Cast(DB_Free_Space/1024 As Varchar(50)) + ' GB'
			Else Cast(DB_Free_Space As Varchar(50)) + ' MB'
		End,
		'DB % Used' = Case 
				When (DB_Reserved_Space/DB_Max_Size) * 100 < 0 Then 'Max Size not set'
				Else Cast((DB_Reserved_Space/DB_Max_Size) * 100 As Varchar)
		End,
		'DB Max Size' =Case 
			When DB_Max_Size < 0 Then 'Max Size not set'
			When DB_Max_Size/1024 > 1 Then Cast(DB_Max_Size/1024 As Varchar(50)) + ' GB'
			Else Cast(DB_Max_Size As Varchar(50)) + ' MB'
		End,
		'Allowed DB Growth' = Case
				When DB_Max_Size - DB_Reserved_Space < 0 Then 'No Allowed DB Growth'
				When (DB_Max_Size - DB_Reserved_Space)/1024 > 1 Then Cast((DB_Max_Size - DB_Reserved_Space)/1024 As Varchar(50)) + ' GB'
				Else Cast((DB_Max_Size - DB_Reserved_Space) As Varchar(50)) + ' MB'
		End,
		'Growth Increment' = Case
				When DB_Growth < 0 Then 'No Growth Increment Set'
				When DB_Growth/1024 > 1 Then Cast(DB_Growth/1024 As Varchar(50)) + ' GB'
				Else Cast(DB_Growth As Varchar(50)) + ' MB'
		End,
		Case 
			When Log_Reserved_Space/1024 > 1 Then Cast(Log_Reserved_Space/1024 As Varchar(50)) + ' GB'
			Else Cast(Log_Reserved_Space As Varchar(50)) + ' MB'
		End,
		'Logfile Freespace in MB' = Case
			When ((Log_Reserved_Space * Log_Free_Percent) /100)/1024 > 1 Then Cast (((Log_Reserved_Space * Log_Free_Percent) /100)/1024 as Varchar(100)) + ' GB'
			Else Cast (((Log_Reserved_Space * Log_Free_Percent) /100) as Varchar(100)) + ' MB'
		END,
		'Log % Used' = Case
			When (Log_Reserved_Space/Log_Max_Size) * 100 < 0 Then 'Max Size not set'
			Else Cast((Log_Reserved_Space/Log_Max_Size) * 100 As Varchar)
		End,
		'Log Max Size' = Case
			When Log_Max_Size < 0 Then 'Max Size not set'
			When Log_Max_Size/1024 > 1 Then Cast(Log_Max_Size/1024 As Varchar(50)) + ' GB'
			Else Cast(Log_Max_Size As Varchar(50)) + ' MB'
		End,
		'Allowed Log Growth' = Case
				When Log_Max_Size - Log_Reserved_Space < 0 Then 'No Allowed DB Growth'
				When (Log_Max_Size - Log_Reserved_Space)/1024 > 1 Then Cast((Log_Max_Size - Log_Reserved_Space)/1024 As Varchar(50)) + ' GB'
				Else Cast((Log_Max_Size - Log_Reserved_Space) As Varchar(50)) + ' MB'
		End,
		'Growth Increment' = Case
				When Log_Growth < 0 Then 'No Growth Increment Set'
				When Log_Growth/1024 > 1 Then Cast(Log_Growth/1024 As Varchar(50)) + ' GB'
				Else Cast(Log_Growth As Varchar(50)) + ' MB'
		End
from #DBResults 
Order By DBName Asc, DB_Reserved_Space Desc
*/
Select * from #DBFileUsage_Report
--where DBName in ('dev0NextCCDB','TempDB')

Drop Table #tmp_DBNames
Drop table #tmp_DBSpacing
Drop Table #DBFile_Info
Drop Table #DBResults
Drop Table #DB_Logfile_Info
Drop Table #DBFileUsage_Report

