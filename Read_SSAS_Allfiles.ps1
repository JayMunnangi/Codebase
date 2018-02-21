cls;

# Setting up Parameters
$Path = "<Insert Valid Path and Filename w/.csv extension here";
$Include = '*.abf,*.trc,*.dstore'
$Servers= @( "<Insert Comma Seperated List of Server here>" )
$Output = @();

# Looping all servers listed
foreach ($Server in $Servers) {
    # Getting the logical disks on server
    $Disks = gwmi -ComputerName $Server Win32_LogicalDisk | where {$_.DriveType -eq '3'} 
    ForEach( $Disk in $Disks ) {                    
        # Getting all folders that contains included file extensions
        $ChildItems = Get-ChildItem ($Disk.Name + "\") -Recurse -ErrorAction SilentlyContinue -Include $Include
        # For each file, create an entry
        ForEach( $Item in $ChildItems ) { 
            $Temp = New-Object System.Object
            $Temp | Add-Member -MemberType NoteProperty -Name "Server" -Value $Server
            $Temp | Add-Member -MemberType NoteProperty -Name "Path" -Value $Item.Directory                        
            # Add Entry to list
            $Output += $Temp
        }         
    }
}

# Remove duplicates and select only Path member
$Result = $Output | Select-Object -un -Property Path

# Write to CSV file
$Result |out-file -filepath $Path;