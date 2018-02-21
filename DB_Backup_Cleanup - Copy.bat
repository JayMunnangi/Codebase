PushD "D:\Shares\stg_db_backups\CCC1\AUS-CCCLDGDB01" && (forfiles /s /m *.bak /d -15 /c "cmd /c del @path") & PopD
pause
pause
pause
pause
PushD "D:\Shares\stg_db_backups\CCC2\" && (forfiles /s /m *.bak /d -15 /c "cmd /c del @path") & PopD
PushD "D:\Shares\stg_db_backups\CCR\" && (forfiles /s /m *.bak /d -15 /c "cmd /c del @path") & PopD
PushD "D:\Shares\stg_db_backups\DPE\" && (forfiles /s /m *.bak /d -15 /c "cmd /c del @path") & PopD
PushD "D:\Shares\stg_db_backups\CMA\" && (forfiles /s /m *.bak /d -15 /c "cmd /c del @path") & PopD
PushD "D:\Shares\stg_db_backups\MGA\" && (forfiles /s /m *.bak /d -15 /c "cmd /c del @path") & PopD
PushD "D:\Shares\stg_db_backups\CMR\" && (forfiles /s /m *.bak /d -15 /c "cmd /c del @path") & PopD
PushD "D:\Shares\stg_db_backups\PRM\" && (forfiles /s /m *.bak /d -15 /c "cmd /c del @path") & PopD
PushD "D:\Shares\stg_db_backups\CQM\" && (forfiles /s /m *.bak /d -15 /c "cmd /c del @path") & PopD
PushD "D:\Shares\stg_db_backups\IRD\" && (forfiles /s /m *.bak /d -15 /c "cmd /c del @path") & PopD
PushD "D:\Shares\stg_db_backups\PLT\" && (forfiles /s /m *.bak /d -15 /c "cmd /c del @path") & PopD
PushD "D:\Shares\stg_db_backups\MGA2\" && (forfiles /s /m *.bak /d -15 /c "cmd /c del @path") & PopD

PushD "D:\Shares\prod_db_backup\CCC1\" && (forfiles /s /m *.bak /d -56 /c "cmd /c del @path") & PopD