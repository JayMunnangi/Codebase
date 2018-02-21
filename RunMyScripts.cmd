@Echo Off
FOR /f %%i IN ('DIR *.Sql /B') do call :RunScript %%i
GOTO :END

:RunScript
Echo Executing Script: %1
SQLCMD -S YourServer\YourInstance -U YourUserName -P YourPassword -i %1
Echo Completed Script: %1

 :END