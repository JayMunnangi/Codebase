--Who changed

SELECT  [Transaction SID]
    ,suser_sname([Transaction SID]) AS 'Login Name'
FROM::fn_dblog(DEFAULT, DEFAULT)
WHERE [Transaction Name] = 'ALTER LOGIN'

-- What changed

SELECT [Lock Information]
FROM::fn_dblog(DEFAULT, DEFAULT)
WHERE [Lock Information] LIKE '%SERVER_PRINCIPAL%'

SELECT name 
FROM sys.server_principals
WHERE principal_id = 270