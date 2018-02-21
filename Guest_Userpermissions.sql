SET NOCOUNT ON
CREATE TABLE #guest_perms 
 ( db SYSNAME, class_desc SYSNAME, 
  permission_name SYSNAME, ObjectName SYSNAME NULL)
EXEC master.sys.sp_MSforeachdb
'INSERT INTO #guest_perms
 SELECT ''?'' as DBName, p.class_desc, p.permission_name, 
   OBJECT_NAME (major_id, DB_ID(''?'')) as ObjectName
 FROM [?].sys.database_permissions p JOIN [?].sys.database_principals l
  ON p.grantee_principal_id= l.principal_id 
 WHERE l.name = ''guest'' AND p.[state] = ''G'''
 
SELECT db AS DatabaseName, class_desc, permission_name, 
 CASE WHEN class_desc = 'DATABASE' THEN db ELSE ObjectName END as ObjectName, 
 CASE WHEN DB_ID(db) IN (1, 2, 4) AND permission_name = 'CONNECT' THEN 'Default' 
  ELSE 'Potential Problem!' END as CheckStatus
FROM #guest_perms
DROP TABLE #guest_perms