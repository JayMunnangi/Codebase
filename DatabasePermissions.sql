/*
This Transact-SQL script list all permissions within the current database to get a quick overview.
The script returns object, principal and permission name with the current state.

Works with SQL Server 2005 and higher versions in all editions.

Links:
   sys.database_permissions: http://msdn.microsoft.com/en-us/library/ms188367.aspx
*/

-- List all Database Permissions
SELECT PER.class_desc AS PermClass
      ,PER.[type] AS PermType
      ,ISNULL(SCH.name + N'.' + OBJ.name
             ,DB_NAME()) AS ObjectName
      ,ISNULL(COL.Name, N'') AS ColumnName
      ,PRC.name AS PrincName
      ,PRC.type_desc AS PrincType      
      ,GRT.name AS GrantorName
      ,PER.permission_name AS PermName
      ,PER.state_desc AS PermState      
FROM sys.database_permissions AS PER
     INNER JOIN sys.database_principals AS PRC
         ON PER.grantee_principal_id = PRC.principal_id
     INNER JOIN sys.database_principals AS GRT
         ON PER.grantor_principal_id = GRT.principal_id
     LEFT JOIN sys.objects AS OBJ
         ON PER.major_id = OBJ.object_id
     LEFT JOIN sys.schemas AS SCH
         ON OBJ.schema_id = SCH.schema_id
     LEFT JOIN sys.columns AS COL
         ON PER.major_id = COL.object_id
            AND PER.minor_id = COL.column_id
WHERE PER.major_id >= 0
ORDER BY PermClass
        ,ObjectName
        ,PrincName
        ,PermType
        ,PermName;


   
   
   