declare @startdate date ='2016-01-01'
declare @enddate date = '2016-05-31'

(select 'Change' as 'Type', '2016' as 'Year', 'May' as Month,      'Database Operations and Enterprise Reporting' as 'Team', a.UDF_CHAR1 as 'Platform/Product',a.[Ticket Number], a.Description, a.Environment,
CONCAT(SUBSTRING(a.Resource, CHARINDEX(' ', a.Resource, 1) + 1, LEN(a.Resource)), ', ', SUBSTRING(a.Resource, 1, CHARINDEX(' ', a.Resource, 1))) as Resource, 
a.[Open Date], a.[Closed Date], a.[Created], a.[Closed], (a.[Created]- a.[Closed]) as 'Backlog' from (
SELECT ticket.UDF_CHAR1,chdt.CHANGEID "Ticket Number",chdt.TITLE "Description",NULL "Environment",ownaaa.FIRST_NAME "Resource",ctdef.NAME "Change Type",catadef.CATEGORYNAME "Category"
,(dateadd(s,datediff(s,GETUTCDATE() ,getdate()) + (chdt.CREATEDTIME/1000),'1970-01-01 00:00:00')) "Open Date",
(dateadd(s,datediff(s,GETUTCDATE() ,getdate()) + (chdt.COMPLETEDTIME/1000),'1970-01-01 00:00:00')) "Closed Date" ,
(dateadd(s,datediff(s,GETUTCDATE() ,getdate()) + (chdt.SCHEDULEDENDTIME/1000),'1970-01-01 00:00:00')) "Schedule Date" ,
1 as "Created",
case when ( cast((dateadd(s,datediff(s,GETUTCDATE() ,getdate()) + (chdt.COMPLETEDTIME/1000),'1970-01-01 00:00:00')) as Date) between @startdate and @enddate) then 0 else 1 end as "Closed"
FROM ChangeDetails chdt LEFT JOIN SDUser ownsd ON chdt.TECHNICIANID=ownsd.USERID 
LEFT JOIN AaaUser ownaaa ON ownsd.USERID=ownaaa.USER_ID 
LEFT JOIN PriorityDefinition priodef1 ON chdt.PRIORITYID=priodef1.PRIORITYID 
LEFT JOIN ChangeTypeDefinition ctdef ON chdt.CHANGETYPEID=ctdef.CHANGETYPEID 
LEFT JOIN CategoryDefinition catadef ON chdt.CATEGORYID=catadef.CATEGORYID 
LEFT JOIN Change_StageDefinition stageDef ON chdt.WFSTAGEID=stageDef.WFSTAGEID 
LEFT JOIN Change_StatusDefinition statusDef ON chdt.WFSTATUSID=statusDef.WFSTATUSID 
LEFT JOIN [Change_Fields] ticket ON ticket.CHANGEID= chdt.CHANGEID
WHERE ((((stageDef.DISPLAYNAME = N'Close' COLLATE SQL_Latin1_General_CP1_CI_AS) OR (stageDef.DISPLAYNAME IS NULL)) 
OR (((statusDef.STATUSDISPLAYNAME != N'Canceled' COLLATE SQL_Latin1_General_CP1_CS_AS) 
AND (statusDef.STATUSDISPLAYNAME = N'Completed' COLLATE SQL_Latin1_General_CP1_CS_AS)) 
OR (statusDef.STATUSDISPLAYNAME IS NULL))) 
AND ((ownaaa.FIRST_NAME in ('Saj Amin', 'Pranjal Kesharwani', 'Mahendra Kumar', 'Sandhya Naradasu', 'Dheeraj Reddy Thupalli', 'Parthasarathy Logaiyan'))))) as a
where --cast(a."Closed Date" as Date) between '2016-05-01' and '2016-05-31' 
    cast(a."Open Date" as Date) between @startdate and @enddate 
--ORDER BY 'Open Date'


UNION


select 'Change' as 'Type', '2016' as 'Year', 'May' as Month,      'Database Administration' as 'Team', a.UDF_CHAR1  as 'Platform/Product',a.[Ticket Number], a.Description, a.Environment, 
CONCAT(SUBSTRING(a.Resource, CHARINDEX(' ', a.Resource, 1) + 1, LEN(a.Resource)), ', ', SUBSTRING(a.Resource, 1, CHARINDEX(' ', a.Resource, 1))) as Resource,
a.[Open Date], a.[Closed Date], a.[Created], a.[Closed], (a.[Created]- a.[Closed]) as 'Backlog' from (
SELECT ticket.UDF_CHAR1,chdt.CHANGEID "Ticket Number",chdt.TITLE "Description",NULL "Environment",ownaaa.FIRST_NAME "Resource",ctdef.NAME "Change Type",catadef.CATEGORYNAME "Category"
,(dateadd(s,datediff(s,GETUTCDATE() ,getdate()) + (chdt.CREATEDTIME/1000),'1970-01-01 00:00:00')) "Open Date",
(dateadd(s,datediff(s,GETUTCDATE() ,getdate()) + (chdt.COMPLETEDTIME/1000),'1970-01-01 00:00:00')) "Closed Date" ,
(dateadd(s,datediff(s,GETUTCDATE() ,getdate()) + (chdt.SCHEDULEDENDTIME/1000),'1970-01-01 00:00:00')) "Schedule Date" ,
1 as "Created",
case when (cast((dateadd(s,datediff(s,GETUTCDATE() ,getdate()) + (chdt.COMPLETEDTIME/1000),'1970-01-01 00:00:00'))as Date) between @startdate and @enddate) then 0 else 1 end as "Closed"
FROM ChangeDetails chdt LEFT JOIN SDUser ownsd ON chdt.TECHNICIANID=ownsd.USERID 
LEFT JOIN AaaUser ownaaa ON ownsd.USERID=ownaaa.USER_ID 
LEFT JOIN PriorityDefinition priodef1 ON chdt.PRIORITYID=priodef1.PRIORITYID 
LEFT JOIN ChangeTypeDefinition ctdef ON chdt.CHANGETYPEID=ctdef.CHANGETYPEID 
LEFT JOIN CategoryDefinition catadef ON chdt.CATEGORYID=catadef.CATEGORYID 
LEFT JOIN Change_StageDefinition stageDef ON chdt.WFSTAGEID=stageDef.WFSTAGEID 
LEFT JOIN Change_StatusDefinition statusDef ON chdt.WFSTATUSID=statusDef.WFSTATUSID 
LEFT JOIN [Change_Fields] ticket ON ticket.CHANGEID= chdt.CHANGEID
WHERE ((((stageDef.DISPLAYNAME = N'Close' COLLATE SQL_Latin1_General_CP1_CI_AS) OR (stageDef.DISPLAYNAME IS NULL)) 
OR (((statusDef.STATUSDISPLAYNAME != N'Canceled' COLLATE SQL_Latin1_General_CP1_CS_AS) 
AND (statusDef.STATUSDISPLAYNAME = N'Completed' COLLATE SQL_Latin1_General_CP1_CS_AS)) 
OR (statusDef.STATUSDISPLAYNAME IS NULL))) 
AND ((ownaaa.FIRST_NAME in ('Adarsh Madineni', 'Srinivas Mallapuram', 'Shekhar Negi', 'Neelakanta Prasad Jasti', 'Daniel Doiron', 'Raghu Ram', 'Jay Munnangi', 'Sudeep Chathilingath'))))) as a
where --cast(a."Closed Date" as Date) between '2016-05-01' and '2016-05-31' 
   cast(a."Open Date" as Date) between @startdate and @enddate 
--ORDER BY 'Open Date'


UNION 



select 'Change' as 'Type', '2016' as 'Year', 'May' as Month,      'Application Support' as 'Team', a.UDF_CHAR1 as 'Platform/Product',a.[Ticket Number], a.Description, a.Environment, 
CONCAT(SUBSTRING(a.Resource, CHARINDEX(' ', a.Resource, 1) + 1, LEN(a.Resource)), ', ', SUBSTRING(a.Resource, 1, CHARINDEX(' ', a.Resource, 1))) as Resource,
a.[Open Date], a.[Closed Date], a.[Created], a.[Closed], (a.[Created]- a.[Closed]) as 'Backlog' from (
SELECT ticket.UDF_CHAR1,chdt.CHANGEID "Ticket Number",chdt.TITLE "Description",NULL "Environment",ownaaa.FIRST_NAME "Resource",ctdef.NAME "Change Type",catadef.CATEGORYNAME "Category"
,(dateadd(s,datediff(s,GETUTCDATE() ,getdate()) + (chdt.CREATEDTIME/1000),'1970-01-01 00:00:00')) "Open Date",
(dateadd(s,datediff(s,GETUTCDATE() ,getdate()) + (chdt.COMPLETEDTIME/1000),'1970-01-01 00:00:00')) "Closed Date" ,
(dateadd(s,datediff(s,GETUTCDATE() ,getdate()) + (chdt.SCHEDULEDENDTIME/1000),'1970-01-01 00:00:00')) "Schedule Date" ,
1 as "Created",
case when ( cast((dateadd(s,datediff(s,GETUTCDATE() ,getdate()) + (chdt.COMPLETEDTIME/1000),'1970-01-01 00:00:00')) as Date) between @startdate and @enddate) then 0 else 1 end as "Closed"
FROM ChangeDetails chdt LEFT JOIN SDUser ownsd ON chdt.TECHNICIANID=ownsd.USERID 
LEFT JOIN AaaUser ownaaa ON ownsd.USERID=ownaaa.USER_ID 
LEFT JOIN PriorityDefinition priodef1 ON chdt.PRIORITYID=priodef1.PRIORITYID 
LEFT JOIN ChangeTypeDefinition ctdef ON chdt.CHANGETYPEID=ctdef.CHANGETYPEID 
LEFT JOIN CategoryDefinition catadef ON chdt.CATEGORYID=catadef.CATEGORYID 
LEFT JOIN Change_StageDefinition stageDef ON chdt.WFSTAGEID=stageDef.WFSTAGEID 
LEFT JOIN Change_StatusDefinition statusDef ON chdt.WFSTATUSID=statusDef.WFSTATUSID 
LEFT JOIN [Change_Fields] ticket ON ticket.CHANGEID= chdt.CHANGEID
WHERE ((((stageDef.DISPLAYNAME = N'Close' COLLATE SQL_Latin1_General_CP1_CI_AS) OR (stageDef.DISPLAYNAME IS NULL)) 
OR (((statusDef.STATUSDISPLAYNAME != N'Canceled' COLLATE SQL_Latin1_General_CP1_CS_AS) 
AND (statusDef.STATUSDISPLAYNAME = N'Completed' COLLATE SQL_Latin1_General_CP1_CS_AS)) 
OR (statusDef.STATUSDISPLAYNAME IS NULL))) 
AND ((ownaaa.FIRST_NAME in ('Pandian Ganesan', 'Srinivas Kuniki', 'Dan Nichols', 'Kumbwi Chongo', 'Aravind Ananthanathan', 'Kevin Blackwell', 'Zach Draper', 'Anandakrishnan Kannan', 'Navaneethan Gunasekaran',  'Nantha Kumar', 'Sean Castruita', 'Gayathri Murugeshan', 'Nantha Kumar', 'Navaneethan Gunasekaran', 'Rakesh Manidasan'))))) as a
where --cast(a."Closed Date" as Date) between '2016-05-01' and '2016-05-31'
     cast(a."Open Date" as Date) between @startdate and @enddate 
--ORDER BY "Open Date"

)
Order by Team,[Open Date]
