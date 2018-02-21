@echo off
IF %1.==. GOTO MissingArg1
IF %2.==. GOTO MissingArg2

REM ----------------------------------------

REM Change to director containing SQLDumper
cd "C:\Program Files\Microsoft SQL Server\110\Shared"

REM Take Full-Dump (0x34)
SqlDumper.exe %1 0 0x34:0x4 0 %2

REM "goto" loop construct
:loop

REM Wait 60 seconds
TIMEOUT /T 60

REM Take Mini-Dump (0x24)
SqlDumper.exe %1 0 0x24:0x4 0 %2

REM cycle back up to start of loop
goto loop

REM ----------------------------------------

:MissingArg1
  ECHO Missing PID argument
 GOTO End1
:MissingArg2
  ECHO Missing output directory argument
 GOTO End1

:End1