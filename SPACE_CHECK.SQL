/*please make sure you are in the current database.scripts works well for local disk
The script will try to bring the space utilisation less than 85*/
if  OBJECT_ID('#freesapce') is not null
begin
drop table #freesapce
end
create table #freesapce( drive char(10),val int)
insert into #freesapce   exec xp_fixeddrives;
go
declare @dbname varchar(50)=(select DB_NAME())
select DB_NAME(mf.database_id) 'db_name',

fp.drive,

fp.val 'mb on drive',

(size*8/1024) [occupied size],

mf.physical_name 'physical name of the file',

round(FILEPROPERTY(name,'spaceused')*8*1.0/1024,2) 'SPACE FILLED',

round(FILEPROPERTY(name,'spaceused')*1.0*100/size,2) [percent free],

mf.type_desc as 'file',FILEGROUP_NAME(mf.data_space_id) 'file groupname',

mf.name,

convert(nvarchar(20),left(round((FILEPROPERTY(name,'spaceused')*8*1.0/1024)*100/84,0),
CHARINDEX('.',(FILEPROPERTY(name,'spaceused')*8*1.0/1024)*100/84)-1)
-(size*8/1024)) +' of mb space added to '+db_name()+' in '+@@SERVERNAME 'log comment',

isnull(
               case 
                     when 
                          /*checking condition for space utilised more that 85%*/
                         (FILEPROPERTY(name,'spaceused')*1.0*100)/size >85 then  

                 case
                       /*checking condition for space available on the drive */
                      when (fp.val)-(left(round((FILEPROPERTY(name,'spaceused')*8*1.0/1024)*100/85,0),
                      CHARINDEX('.',(FILEPROPERTY(name,'spaceused')*8*1.0/1024)*100/85)-1)-
                      FILEPROPERTY(name,'spaceused')*8*1.0/1024)<0
                  then

                  case 
                      when mf.growth=0 and mf.type_desc not like '%LOG%' and mf.type_desc like '%ROW%'
                  then
                      CHAR(13)+'/*contact windows*/ use master ; '+CHAR(13)
                      +'alter database ['+DB_NAME(database_id)+']  modify file
                      ( NAME = N'''+name+''',size='+ convert (nvarchar(20),
                      size*8/1024+fp.val-1000)+' mb )'
                      /*fp.val-1000 above and below indicates we are leaving 1000mb of space on the drive and utilising
                      all the space leaving  1000mb to the drive*/

                  when 
                      max_size<>-1 or growth=0 and type_desc not like '%LOG%' and type_desc like '%ROW%'
                  then

                      CHAR(13)+'/*contact windows*/ use master ; '+CHAR(13)
                      +'alter database ['+DB_NAME(database_id)+']  modify file
                      ( NAME = N'''+name+''',size='+ convert (nvarchar(20),
                      size*8/1024+fp.val-1000)+' mb,
                      MAXSIZE ='+convert (nvarchar(20),
                      size*8/1024+fp.val-1000)+' mb )'
                   end 

            else
                   case 
                       /*if you want to bring it less your desired wish
                       ,for exapmle 90% then replace 84 by 89 i,e one less than the required*/
                       when mf.growth=0 and mf.type_desc not like '%LOG%' and mf.type_desc like '%ROW%'
                        then
                             '/*action required*/ '+CHAR(13)+'use master ; '+CHAR(13)
                              +'alter database ['+DB_NAME(database_id)+']  modify file
                              ( NAME = N'''+name+''',size='+
                              convert(nvarchar(20),left(round((FILEPROPERTY(name,'spaceused')*8*1.0/1024)*100/84,0),
                              CHARINDEX('.',(FILEPROPERTY(name,'spaceused')*8*1.0/1024)*100/84)-1))+' mb )'
                       
                       when max_size<>-1 or growth=0 and type_desc not like '%LOG%' and type_desc like '%ROW%'
                    then

                       '/*action required*/ '+CHAR(13)+'use master ; '+CHAR(13)
                       +'alter database ['+DB_NAME(database_id)+']  modify file
                        ( NAME = N'''+name+''',size='+
                        convert(nvarchar(20),left(round((FILEPROPERTY(name,'spaceused')*8*1.0/1024)*100/84,0),
                        CHARINDEX('.',(FILEPROPERTY(name,'spaceused')*8*1.0/1024)*100/84)-1))+' mb,
                        MAXSIZE ='+
                        convert(nvarchar(20),left(round((FILEPROPERTY(name,'spaceused')*8*1.0/1024)*100/84,0),
                        CHARINDEX('.',(FILEPROPERTY(name,'spaceused')*8*1.0/1024)*100/84)-1)+
                        left(round((FILEPROPERTY(name,'spaceused')*8*1.0/1024)*100/84,0),
                        CHARINDEX('.',(FILEPROPERTY(name,'spaceused')*8*1.0/1024)*100/84)-1)*5/100)
                        +'mb )'


                       end
                end

          else 

          '/*no action required */' end ,'auto growth unlimited -please check the drive space is full or not')action
from #freesapce fp left join
sys.master_files mf on fp.drive=SUBSTRING(mf.physical_name,1,1)
where database_id=DB_ID(@dbname)
/*mention the file group name instead of primary or if you have 
name of the file mention in the place of abcd.mdf
*/
--and FILEGROUP_NAME(mf.data_space_id)='PRIMARY' 
--mf.physical_name='abcd.mdf'
order by FILEGROUP_NAME(mf.data_space_id)



drop table #freesapce
go