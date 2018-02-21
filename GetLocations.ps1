Function fnGetDefaultDBLocation
 
{
 
Param ([string] $vInstance)
 
# Get the registry key associated with the Instance Name
 
$vRegInst = (Get-ItemProperty -Path HKLM:"SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL" -ErrorAction SilentlyContinue).$vInstance
 
$vRegPath = "SOFTWARE\Microsoft\Microsoft SQL Server\" + $vRegInst + "\MSSQLServer"
 
# Get the Data and Log file paths if available
 
$vDataPath = (Get-ItemProperty -Path HKLM:$vRegPath -ErrorAction SilentlyContinue).DefaultData
 
$vLogPath = (Get-ItemProperty -Path HKLM:$vRegPath -ErrorAction SilentlyContinue).DefaultLog
 
# Report the entries found
 
if ($vDataPath.Length -lt 1)
 
{
 
$vRegPath = "SOFTWARE\Microsoft\Microsoft SQL Server\" + $vRegInst + "\Setup"
 
$vDataPath = (Get-ItemProperty -Path HKLM:$vRegPath -ErrorAction SilentlyContinue).SQLDataRoot + "\Data\"
 
Write-Host "Default Data Path: " $vDataPath
 
}
 
else
 
{
 
Write-Host "Default Data Path:" $vDataPath
 
}
 
if ($vLogPath.Length -lt 1)
 
{
 
$vRegPath = "SOFTWARE\Microsoft\Microsoft SQL Server\" + $vRegInst + "\Setup"
 
$vDataPath = (Get-ItemProperty -Path HKLM:$vRegPath -ErrorAction SilentlyContinue).SQLDataRoot + "\Data\"
 
Write-Host "Default Log Path: " $vDataPath
 
}
 
else
 
{
 
Write-Host "Default Log Path:" $vLogPath
 
}
 
}
 
fnGetDefaultDBLocation "MSSQLServer"