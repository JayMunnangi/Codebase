######################################
# Script: ReturnDefaultSQLFilePaths.ps1
#
######################################
# Return the Default File Paths for the
# Data Files, Log Files and Backup Files
#
######################################

$Server = '.\Developer'
$SMOServer = new-object ('Microsoft.SqlServer.Management.Smo.Server') $Server

# Get the Default File Locations

$DefaultFileLocation = $SMOServer.Settings.DefaultFile
$DefaultLogLocation = $SMOServer.Settings.DefaultLog

if ($DefaultFileLocation.Length -eq 0) 
    { 
        $DefaultFileLocation = $SMOServer.Information.MasterDBPath 
    }
if ($DefaultLogLocation.Length -eq 0) 
    { 
        $DefaultLogLocation = $SMOServer.Information.MasterDBLogPath 
    }

write-host 'Default File Locations'
write-host '======================'
write-host 'File Location :' $DefaultFileLocation
write-host 'Log Location :' $DefaultLogLocation
write-host 'Backup Location :' $SMOServer.BackupDirectory