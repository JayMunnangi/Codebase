DECLARE GET_DATABASES CURSOR
READ_ONLY
FOR SELECT NAME FROM SYS.DATABASES WHERE COMPATIBILITY_LEVEL != '120'
 
DECLARE @DATABASENAME NVARCHAR(255)
DECLARE @COUNTER INT
 
SET @COUNTER = 1
 
OPEN GET_DATABASES
FETCH NEXT FROM GET_DATABASES INTO @DATABASENAME
WHILE (@@fetch_status <> -1)
BEGIN
IF (@@fetch_status <> -2)
BEGIN
-- CHANGE DATABASE COMPATIBILITY
EXECUTE sp_dbcmptlevel @DATABASENAME , '120'
 
PRINT  @DATABASENAME + ' changed'
 
SET @COUNTER = @COUNTER + 1
END
 
FETCH NEXT FROM GET_DATABASES INTO @DATABASENAME
END
 
CLOSE GET_DATABASES
DEALLOCATE GET_DATABASES
 
GO
