[CmdletBinding()]
Param(
  [Parameter(Mandatory=$True,Position=1)]
   [string]$InputFileName,
	
   [Parameter(Mandatory=$True,Position=2)]
   [string]$DirectoryToSaveTo,

   [Parameter(Mandatory=$True,Position=3)]
   [string]$To,

   [Parameter(Mandatory=$True,Position=4)]
   [string]$From,

   [Parameter(Mandatory=$True,Position=5)]
   [string]$SMTP

)

$Filename='SQLInventory'

# before we do anything else, are we likely to be able to save the file?
# if the directory doesn't exist, then create it
if (!(Test-Path -path "$DirectoryToSaveTo")) #create it if not existing
  {
  New-Item "$DirectoryToSaveTo" -type directory | out-null
  }

#Create a new Excel object using COM 
$Excel = New-Object -ComObject Excel.Application
$Excel.visible = $True
$Excel = $Excel.Workbooks.Add()
$Sheet = $Excel.Worksheets.Item(1)

#Counter variable for rows
$intRow = 1
$xlOpenXMLWorkbook=[int]51

#Read thru the contents of the SQL_Servers.txt file
$Sheet.Cells.Item($intRow,1)  ="InstanceName"
$Sheet.Cells.Item($intRow,2)  ="ComputerNamePhysicalNetBIOS"
$Sheet.Cells.Item($intRow,3)  ="NetName"
$Sheet.Cells.Item($intRow,4)  ="OS"
$Sheet.Cells.Item($intRow,5)  ="OSVersion"
$Sheet.Cells.Item($intRow,6)  ="Platform"
$Sheet.Cells.Item($intRow,7)  ="Product"
$Sheet.Cells.Item($intRow,8)  ="edition"
$Sheet.Cells.Item($intRow,9)  ="Version"
$Sheet.Cells.Item($intRow,10)  ="VersionString"
$Sheet.Cells.Item($intRow,11) ="ProductLevel"
$Sheet.Cells.Item($intRow,12) ="DatabaseCount"
$Sheet.Cells.Item($intRow,13) ="HasNullSaPassword"
$Sheet.Cells.Item($intRow,14) ="IsCaseSensitive"
$Sheet.Cells.Item($intRow,15) ="IsFullTextInstalled"
$Sheet.Cells.Item($intRow,16) ="Language"
$Sheet.Cells.Item($intRow,17) ="LoginMode"
$Sheet.Cells.Item($intRow,18) ="Processors"
$Sheet.Cells.Item($intRow,19) ="PhysicalMemory"
$Sheet.Cells.Item($intRow,10) ="MaxMemory"
$Sheet.Cells.Item($intRow,21) ="MinMemory"
$Sheet.Cells.Item($intRow,22) ="IsSingleUser"
$Sheet.Cells.Item($intRow,23) ="IsClustered"
$Sheet.Cells.Item($intRow,24) ="Collation"
$Sheet.Cells.Item($intRow,25) ="MasterDBLogPath"
$Sheet.Cells.Item($intRow,26) ="MasterDBPath"
$Sheet.Cells.Item($intRow,27) ="ErrorLogPath"
$Sheet.Cells.Item($intRow,28) ="BackupDirectory"
$Sheet.Cells.Item($intRow,29) ="DefaultLog"
$Sheet.Cells.Item($intRow,20) ="ResourceLastUpdatetime"
$Sheet.Cells.Item($intRow,31) ="AuditLevel"
$Sheet.Cells.Item($intRow,32) ="DefaultFile"
$Sheet.Cells.Item($intRow,33) ="xp_cmdshell"
$Sheet.Cells.Item($intRow,34) ="Domain"
$Sheet.Cells.Item($intRow,35) ="IPAddress"

  for ($col = 1; $col –le 34; $col++)
     {
          $Sheet.Cells.Item($intRow,$col).Font.Bold = $True
          $Sheet.Cells.Item($intRow,$col).Interior.ColorIndex = 48
          $Sheet.Cells.Item($intRow,$col).Font.ColorIndex = 34
     }

$intRow++

foreach ($instanceName in Get-Content $InputFileName)
{
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
$server1 = New-Object -Type Microsoft.SqlServer.Management.Smo.Server -ArgumentList $instanceName
$s=$server1.Information.Properties |Select Name, Value 
$st=$server1.Settings.Properties |Select Name, Value
$CP=$server1.Configuration.Properties |Select DisplayName, Description, RunValue, ConfigValue
$dbs=$server1.Databases.count
$BuildNumber=$s | where {$_.name -eq "BuildNumber"}|select value
$edition=$s | where {$_.name -eq "edition"}|select value
$ErrorLogPath =$s | where {$_.name -eq "ErrorLogPath"}|select value
$HasNullSaPassword =$s | where {$_.name -eq "HasNullSaPassword"}|select value
$IsCaseSensitive =$s | where {$_.name -eq "IsCaseSensitive"}|select value
$Platform =$s | where {$_.name -eq "Platform"}|select value
$IsFullTextInstalled =$s | where {$_.name -eq "IsFullTextInstalled"}|select value
$Language =$s | where {$_.name -eq "Language"}|select value
$MasterDBLogPath =$s | where {$_.name -eq "MasterDBLogPath"}|select value
$MasterDBPath =$s | where {$_.name -eq "MasterDBPath"}|select value
$NetName =$s | where {$_.name -eq "NetName"}|select value
$OSVersion =$s | where {$_.name -eq "OSVersion"}|select value
$PhysicalMemory =$s | where {$_.name -eq "PhysicalMemory"}|select value
$Processors =$s | where {$_.name -eq "Processors"}|select value
$IsSingleUser =$s | where {$_.name -eq "IsSingleUser"}|select value
$Product =$s | where {$_.name -eq "Product"}|select value
$VersionString =$s | where {$_.name -eq "VersionString"}|select value
$Collation =$s | where {$_.name -eq "Collation"}|select value
$IsClustered =$s | where {$_.name -eq "IsClustered"}|select value
$ProductLevel =$s | where {$_.name -eq "ProductLevel"}|select value
$ComputerNamePhysicalNetBIOS =$s | where {$_.name -eq "ComputerNamePhysicalNetBIOS"}|select value
$ResourceLastUpdateDateTime =$s | where {$_.name -eq "ResourceLastUpdateDateTime"}|select value
$AuditLevel =$st | where {$_.name -eq "AuditLevel"}|select value
$BackupDirectory =$st | where {$_.name -eq "BackupDirectory"}|select value
$DefaultFile =$st | where {$_.name -eq "DefaultFile"}|select value
$DefaultLog =$st | where {$_.name -eq "DefaultLog"}|select value
$LoginMode =$st | where {$_.name -eq "LoginMode"}|select value
$min=$CP | where {$_.Displayname -like "*min server memory*"}|select configValue
$max=$CP | where {$_.Displayname -like "*max server memory*"}|select configValue
$xp_cmdshell=$CP | where {$_.Displayname -like "*xp_cmdshell*"}|select configValue
$FQDN=[System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().Name
$IPAddress=(Get-WmiObject Win32_NetworkAdapterConfiguration -ComputerName $instanceName | ? {$_.IPEnabled}).ipaddress

if ($HasNullSaPassword.value -eq $NULL)
{
	$HasNullSaPassword.value='No'
}
if($DefaultFile.value -eq '')
{
	$DefaultFile.value='NA'
}
if ($VersionString.value -like '8*')
{
	$SQLServer='SQL SERVER 2000'
}
elseif ($VersionString.value -like '9*')
{
	$SQLServer='SQL SERVER 2005'
}
elseif ($VersionString.value -like '10.0*')
{
	$SQLServer='SQL SERVER 2008'
}
elseif ($VersionString.value -like '10.5*')
{
	$SQLServer='SQL SERVER 2008 R2'
}
elseif ($VersionString.value -like '11*')
{
	$SQLServer='SQL SERVER 2012'
}
else
{
	$SQLServer='Invalid'
}


if ($OSVersion.value -like '5.0*')
{
	$OSVer='Windows 2000'
}
elseif ($OSVersion.value -like '5.1*')
{
	$OSVer='Windows XP'
}
elseif ($OSVersion.value -like '5.2*')
{
	$OSVer='Windows Server 2003'
}
elseif ($OSVersion.value -like '6.0*')
{
	$OSVer='Windows Server 2008'
}
elseif ($OSVersion.value -like '6.1*')
{
	$OSVer='Windows Server 2008 R2'
}
elseif ($OSVersion.value -like '6.2*')
{
	$OSVer='Windows Server 2012'
}
else
{
	$OSVer='NA'
}
	$Sheet.Cells.Item($intRow,1)   =$instanceName
        $Sheet.Cells.Item($intRow,2)   =$ComputerNamePhysicalNetBIOS.value
        $Sheet.Cells.Item($intRow,3)   =$NetName.value
        $Sheet.Cells.Item($intRow,4)   =$OSVer
        $Sheet.Cells.Item($intRow,5)   =$OSVersion.value
        $Sheet.Cells.Item($intRow,6)   = $Platform.value
        $Sheet.Cells.Item($intRow,7)   = $Product.value
        $Sheet.Cells.Item($intRow,8)   = $edition.value
        $Sheet.Cells.Item($intRow,9)   = $SQLServer
        $Sheet.Cells.Item($intRow,10)  = $VersionString.value
        $Sheet.Cells.Item($intRow,11)  = $ProductLevel.value
        $Sheet.Cells.Item($intRow,12)  = $Dbs
        $Sheet.Cells.Item($intRow,13)  = $HasNullSaPassword.value
        $Sheet.Cells.Item($intRow,14)  = $IsCaseSensitive.value
        $Sheet.Cells.Item($intRow,15)  = $IsFullTextInstalled.value
        $Sheet.Cells.Item($intRow,16)  = $Language.value
        $Sheet.Cells.Item($intRow,17)  = $LoginMode.value
        $Sheet.Cells.Item($intRow,18)  = $Processors.value
        $Sheet.Cells.Item($intRow,19)  = $PhysicalMemory.value
        $Sheet.Cells.Item($intRow,10)  = $Max.Configvalue
        $Sheet.Cells.Item($intRow,21)  = $Min.Configvalue
        $Sheet.Cells.Item($intRow,22)  = $IsSingleUser.value
        $Sheet.Cells.Item($intRow,23)  = $IsClustered.value
        $Sheet.Cells.Item($intRow,24)  = $Collation.value
        $Sheet.Cells.Item($intRow,25)  = $MasterDBLogPath.value
        $Sheet.Cells.Item($intRow,26)  = $MasterDBPath.value
        $Sheet.Cells.Item($intRow,27)  = $ErrorLogPath.value
        $Sheet.Cells.Item($intRow,28)  = $BackupDirectory.value
        $Sheet.Cells.Item($intRow,29)  = $DefaultLog.value
        $Sheet.Cells.Item($intRow,20)  = $ResourceLastUpdateDateTime.value
        $Sheet.Cells.Item($intRow,31)  = $AuditLevel.value
        $Sheet.Cells.Item($intRow,32) = $DefaultFile.value
        $Sheet.Cells.Item($intRow,33) = $xp_cmdshell.Configvalue
        $Sheet.Cells.Item($intRow,34) = $FQDN
        $Sheet.Cells.Item($intRow,35) = $IPAddress

	  
$intRow ++

}
  
$filename = "$DirectoryToSaveTo$filename.xlsx"
if (test-path $filename ) { rm $filename } #delete the file if it already exists
$Sheet.UsedRange.EntireColumn.AutoFit()
cls
$Excel.SaveAs($filename, $xlOpenXMLWorkbook) #save as an XML Workbook (xslx)
$Excel.Saved = $True
$Excel.Close()





Function sendEmail([string]$emailFrom, [string]$emailTo, [string]$subject,[string]$body,[string]$smtpServer,[string]$filePath)
{
#initate message
$email = New-Object System.Net.Mail.MailMessage 
$email.From = $emailFrom
$email.To.Add($emailTo)
$email.Subject = $subject
$email.Body = $body
# initiate email attachment 
$emailAttach = New-Object System.Net.Mail.Attachment $filePath
$email.Attachments.Add($emailAttach) 
#initiate sending email 
$smtp = new-object Net.Mail.SmtpClient($smtpServer)
$smtp.Send($email)
}

#Call Function 
sendEmail -emailFrom $from -emailTo $to "SQL INVENTORY" "SQL INVENTORY DETAILS - COMPLETE DETAILS" -smtpServer $SMTP -filePath $filename
