SELECT db.name AS database_name, mf.name as actual_logical_name,mf.physical_name
 
--LEFT(REVERSE(LEFT(REVERSE(mf.Physical_Name),CHARINDEX('\', REVERSE(mf.Physical_Name), 1) - 1)),
 
--LEN(REVERSE(LEFT(REVERSE(mf.Physical_Name),CHARINDEX('\', REVERSE(mf.Physical_Name), 1) - 1))) - 4) as new__logical_name
 
--'ALTER DATABASE ['+db.name +'] MODIFY FILE (NAME=N'''+ mf.name + ''',NEWNAME=N'''+
 
--LEFT(REVERSE(LEFT(REVERSE(mf.Physical_Name),CHARINDEX('\', REVERSE(mf.Physical_Name), 1) - 1)),
 
--LEN(REVERSE(LEFT(REVERSE(mf.Physical_Name),CHARINDEX('\', REVERSE(mf.Physical_Name), 1) - 1))) - 4) +''')' as change_script
 
FROM sys.master_files mf INNER JOIN sys.databases db ON db.database_id = mf.database_id
WHERE db.database_id>4 AND mf.Physical_Name NOT LIKE '%'+mf.name+'%'
and db.name like '%Lancaster%' --and mf.physical_name like 'E:\%'