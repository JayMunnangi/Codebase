DECLARE @loginNameToDrop sysname
SET @loginNameToDrop = 'CRIMSONAD\ogdend';

DECLARE sessionsToKill CURSOR FAST_FORWARD FOR
    SELECT session_id
    FROM sys.dm_exec_sessions
    WHERE login_name = @loginNameToDrop
OPEN sessionsToKill

DECLARE @sessionId INT
DECLARE @statement NVARCHAR(200)

FETCH NEXT FROM sessionsToKill INTO @sessionId

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT 'Killing session ' + CAST(@sessionId AS NVARCHAR(20)) + ' for login ' + @loginNameToDrop

    SET @statement = 'KILL ' + CAST(@sessionId AS NVARCHAR(20))
    EXEC sp_executesql @statement

    FETCH NEXT FROM sessionsToKill INTO @sessionId
END

CLOSE sessionsToKill
DEALLOCATE sessionsToKill

PRINT 'Dropping login ' + @loginNameToDrop
SET @statement = 'DROP LOGIN [' + @loginNameToDrop + ']'
EXEC sp_executesql @statement