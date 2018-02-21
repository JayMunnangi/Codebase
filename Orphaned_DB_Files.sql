------------------------------------------------------------------------------- 
-- Generates a list of MDF, NDF, and LDF files that do not have a matching      
-- entry in the instance - that is, finds the orphaned ones.  You can exclude   
-- specific drives, and specific folders.                                       
------------------------------------------------------------------------------- 

set nocount on

-- Get the set of fixed drives. Some drives you'll want to exclude. 
if object_id('tempdb..#tmpDrives') is not null
    drop table #tmpDrives
 
create table #tmpDrives
(
    Drive        char(1) not null,
    MBFreeUnused int     not null
)

insert #tmpDrives  exec xp_fixeddrives

delete from #tmpDrives
 where Drive in ('C')

-- Iterate through all the fixed drives, looking for database files. 
-- Some files we'll want to delete. 
if object_id('tempdb..#tmpOsFiles') is not null
    drop table #tmpOsFiles
 
create table #tmpOsFiles
(
    OsFile varchar(260) null
)

declare @Drive char(1)
declare @Sql nvarchar(4000)

declare cur cursor for
    select Drive from #tmpDrives

open cur
fetch next from cur into @Drive

while @@fetch_status = 0
begin
    raiserror(@Drive, 10, 1) with nowait

    set @Sql = 'dir ' + @Drive + ':\*.mdf /a-d /a-h /a-s /a-r /b /s'
    insert #tmpOsFiles  exec xp_cmdshell @Sql

    set @Sql = 'dir ' + @Drive + ':\*.ndf /a-d /a-h /a-s /a-r /b /s'
    insert #tmpOsFiles  exec xp_cmdshell @Sql

    set @Sql = 'dir ' + @Drive + ':\*.ldf /a-d /a-h /a-s /a-r /b /s'
    insert #tmpOsFiles  exec xp_cmdshell @Sql

    fetch next from cur into @Drive
end

close cur
deallocate cur

delete from #tmpOsFiles
 where OsFile is null
    or OsFile = 'File Not Found'
    or OsFile like '%:\$RECYCLE_BIN\%' escape '~' 
    or OsFile like '%:\Program Files\Microsoft SQL Server%' escape '~' 
    or OsFile like '%:\SW_DVD9_SQL_Svr_Enterprise_Edtn_2008_R2_English_MLF_X16-29540%' escape '~'

-- For each file, get the date modified and the size.  The dir command gives 
-- use a line like this:10/08/2013  02:37 PM            228253 TLXPVSQL01_TSS_ERD.png
alter table #tmpOsFiles
  add DtModified datetime null default(''),
      SizeMB     int      null default('')

declare @Dir    nvarchar(260)
declare @OsFile nvarchar(260)

if object_id('tempdb..#tmpOsFileDetails') is not null
    drop table #tmpOsFileDetails
 
create table #tmpOsFileDetails
(
    OsFileDetails nvarchar(4000) null
)

declare cur cursor for
    select OsFile from #tmpOsFiles

open cur

fetch next from cur into @OsFile

while @@fetch_status = 0
begin
    set @Sql = 'dir "' + @OsFile + '" /-c'
    insert #tmpOsFileDetails  exec xp_cmdshell @Sql

    delete from #tmpOsFileDetails
     where OsFileDetails is null
        or OsFileDetails like '%Volume in drive % is %'
        or OsFileDetails like '%Volume Serial Number is %'
        or OsFileDetails like '%1 File(s) %'
        or OsFileDetails like '%0 Dir(s) %'

    select @Dir = rtrim(ltrim(replace(OsFileDetails, 'Directory of', ''))) + '\'
      from #tmpOsFileDetails
     where OsFileDetails like '%Directory of %'

    delete from #tmpOsFileDetails
     where OsFileDetails like '%Directory of %'
    
    update #tmpOsFiles
       set DtModified = substring(ofd.OsFileDetails,  1, 20),
           SizeMB     = cast(substring(ofd.OsFileDetails, 21, 19) as bigint) / 1024 / 1024
      from #tmpOsFileDetails   ofd
      join #tmpOsFiles         os
        on os.OsFile = @Dir + substring(ofd.OsFileDetails, 40, 4000)

    delete from #tmpOsFileDetails

    fetch next from cur into @OsFile
end

close cur
deallocate cur

-- Now list the OS files that don't have an entry in the instance. 
    select os.*
         , datediff(Day, os.DtModified, getdate()) as DaysOld
      from master.sys.master_files   mf
right join #tmpOsFiles               os
        on mf.physical_name = os.OsFile
     where mf.physical_name is null
  order by os.SizeMB desc