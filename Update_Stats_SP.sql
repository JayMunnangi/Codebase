USE [library]
GO

/****** Object:  StoredProcedure [dbo].[sUpdateStats]    Script Date: 1/5/2017 10:51:52 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/*###CommentStart
Author: Rizwan Khan
Date:	11/30/2015
Desc:	This is generic procedure to update stats based user provided value for @UpdateThreshold, default value is 2% of data changed, this procedure takes 3 argument, @DB (required) @UpdateThreshold (optional) and @PrintDebug (optional)
Version:	1.00
Usage:		if you want to take default value of 2% data change, you can run this procedure by simply providing just DB name
			exec Library.dbo.sUpdateStats 'YourDBName' or exec Library.dbo.sUpdateStats @DB='YourDBName'
			
			if you want to override default 2% data change threshold, lets say to 10% then you can provide DB name and new threshold values as following
			exec Library.dbo.sUpdateStats 'YourDBName' ,20 or exec Library.dbo.sUpdateStats @DB='YourDBName' ,@UpdateThreshold=20
			
			if you also want to print debug information, you can pass 3rd argument as well
			exec Library.dbo.sUpdateStats 'YourDBName' ,20, 1 or exec Library.dbo.sUpdateStats @DB='YourDBName' ,@UpdateThreshold=20, @PrintDebug=1
CollisionProof:	Yes
SafelyRerun:	Yes
CanUnitTest:	Yes

CommentEnd###*/
Create Proc [dbo].[sUpdateStats]
@DB Varchar(200),
@UpdateThreshold Decimal(18,8)=2,
@PrintDebug bit=0
as
Declare 
@ID Int=1,
@Cmd Varchar(max)=''
Create Table #T (Id Int Identity(1,1), Cmd Varchar(max))
Select @CMD=' 
;With UpdateList as (
Select	O.Object_id,
		SS.Name Sch,
		O.Name Tbl, 
		SI.indid ,
		SI.name StatName,
		SI.rowmodctr
From	['+@DB+'].Sys.objects O
Inner Join
		['+@DB+'].Sys.sysindexes SI
On		SI.id=O.object_id
Inner Join
		['+@DB+'].Sys.Schemas SS
On		SS.Schema_id=O.Schema_id
Where	O.Type=''U'' 
		and SI.rowmodctr<>0
		and SI.Indid<>0
		),
TotalRows as
	(
Select	O.Object_id,
		SI.rowcnt
From	['+@DB+'].Sys.objects O
Inner Join
		['+@DB+'].Sys.sysindexes SI
On		SI.id=O.object_id
Where	O.Type=''U'' 
		and SI.Indid<2)
Select	''UPDATE STATISTICS ['+@DB+'].[''+A.Sch+''].[''+A.Tbl+'']  [''+StatName+ ''] With FullScan''
From UpdateList A
Inner Join 
		TotalRows B
On		A.Object_ID=B.Object_ID
Where	RowCnt>0 and (((rowModCtr*1.00)/rowCnt)*100)>='+Convert(Varchar,@UpdateThreshold)

insert #T (Cmd)
Exec (@Cmd)
If @PrintDebug=1
Begin
	Print @Cmd
End
While @ID<=(Select max(ID) from #T)
Begin
	Select @CMD=CMD from #T where ID=@ID
	Exec (@CMD)
	If @PrintDebug=1
	Begin
		Print @Cmd
	End
	Select @ID+=1
End
GO


