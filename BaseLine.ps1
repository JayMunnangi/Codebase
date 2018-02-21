SET<#
This PowerShell routine creates an excel spreadsheet with the current configuration settings of all your servers. Each instance is on a different worksheet and the worksheets have the name of the instance. It works by using ODBC connections created locally on your workstation.
Once the spreadsheet is created, the PowerShell script is no longer needed since the data can be refreshed from within Excel. This means that you will have a live record of the configuration settings of your instances.
#>
#change these following settings to your environment
$DirectoryToSaveTo='C:\Users\munnangj\Desktop\Jay\'
$Filename='DatabaseConfiguration'
#
<#
Just make your list of servers here as an XML fragment
these instance names are actually User ODBC DSNs DSNs. Better for Excel.
We associate a version number with each just so you are sure
of a script that will run (You can't get this info from the DSN, and
Excel only allows one select statement in an Excel query
#>

$Servers=[xml] @'
<serverList>
      <server  version="2008" name="ASHSWDWSQL-P01" />
    </serverList>
'@
 
# constants.
$xlCenter=-4108
$xlTop=-4160
$xlOpenXMLWorkbook=[int]51
# and we put the queries in here
$SQL2005=@"
SELECT  name, value, minimum, maximum, value_in_use as [Value in use], 
        description, is_dynamic AS [Dynamic?], is_advanced AS [Advanced?]
FROM    sys.configurations ORDER BY name ;

"@
$SQL2008=@"
SELECT  name, value, minimum, maximum, value_in_use as [Value in use], 
        description, is_dynamic AS [Dynamic?], is_advanced AS [Advanced?]
FROM    sys.configurations ORDER BY name ;
"@

$SQL2000=@"
SELECT  Name, c.Value, low AS [minimum], high AS [Maximum],
        master.dbo.syscurconfigs.value AS [Value In Use],
        c.comment AS [Description]
FROM    master.dbo.spt_values v
        INNER JOIN master.dbo.sysconfigures c ON number = c.config
        INNER JOIN master.dbo.syscurconfigs ON number = master.dbo.syscurconfigs.config
WHERE   type = 'C'
ORDER BY LOWER(name)

"@

# before we do anything else, are we likely to be able to save the file?
# if the directory doesn't exist, then create it
if (!(Test-Path -path "$DirectoryToSaveTo")) #create it if not existing
  {
  New-Item "$DirectoryToSaveTo" -type directory | out-null
  }
$excel = New-Object -Com Excel.Application #open a new instance of Excel
$excel.Visible = $True #make it visible (for debugging more than anything)
$wb = $Excel.Workbooks.Add() #create a workbook
$currentWorksheet=1 #there are three open worksheets you can fill up
foreach ($server in $servers.serverlist.server)
      { #only create the worksheet if necessary
      if ($currentWorksheet-lt 4) {$ws = $wb.Worksheets.Item($currentWorksheet)}
      else  {$ws = $wb.Worksheets.Add()} #add if it doesn't exist
      $currentWorksheet += 1 #keep a tally
      if  ($server.version -eq 2005) {$SQL=$SQL2005} #get the right SQL Script
      if  ($server.version -eq 2008) {$SQL=$SQL2008}
      if ($server.version -eq 2000) {$SQL=$SQL2000}
      $currentName=$server.name  # and name the worksheet
      $ws.name=$currentName # so it appears in the tab
      # note we create the query so that the user can run it to refresh it
      $qt = $ws.QueryTables.Add("ODBC;DSN=$currentName", $ws.Range("A1"), $SQL)
      # and execute it
      if ($qt.Refresh()) #if the routine works OK
            {
            $ws.Activate()
            $ws.Select()
            $excel.Rows.Item(1).HorizontalAlignment = $xlCenter
            $excel.Rows.Item(1).VerticalAlignment = $xlTop
            $excel.Rows.Item(1).Orientation = -90
            $excel.Columns.Item("G:H").NumberFormat = "[Red][=0]û;[Blue][=1]ü"
            $excel.Columns.Item("G:H").Font.Name = "Wingdings"
            $excel.Columns.Item("G:H").Font.Size = 12
              $excel.Rows.Item("1:1").Font.Name = "Calibri"
            $excel.Rows.Item("1:1").Font.Size = 11
            $excel.Rows.Item("1:1").Font.Bold = $true
            $Excel.Columns.Item(1).Font.Bold = $true
            }
      }
$filename=$filename -replace  '[\\\/\:\.]',' ' #remove characters that can cause problems
$filename = "$DirectoryToSaveTo$filename.xlsx" #save it according to its title
if (test-path $filename ) { rm $filename } #delete the file if it already exists
$wb.SaveAs($filename,  $xlOpenXMLWorkbook) #save as an XML Workbook (xslx)
$wb.Saved = $True #flag it as being saved
$wb.Close() #close the document
$Excel.Quit() #and the instance of Excel
$wb = $Null #set all variables that point to Excel objects to null
$ws = $Null #makes sure Excel deflates
$Excel=$Null #let the air out
# Hristo Deshev's Excel trick 'Pro Windows PowerShell' p380
[GC]::Collect()