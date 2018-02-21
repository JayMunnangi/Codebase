Declare @SchemaId Int, @SchemaName Varchar(128), @TableId Int, @TableName Varchar(128), @ColumnId Int, @ColumnName Varchar(128)
Declare @strSQL NVarchar(4000), @CDCTableLoopNo SmallInt, @CountCDCTables SmallInt 
Declare @CDCTableName Varchar(128), @CDCSchemaName Varchar(128), @CDCCaptureInstance Varchar(128)
Declare @PrimaryKeyFields Varchar(Max), @PrimaryKeyFieldsForValues Varchar(Max)

Set @CDCTableLoopNo = 0 

Declare @CDCTables Table (CDCObjectId Int, TableObjectId Int, Capture_Instance Varchar(128), Role_Name Varchar(128), Index_Name Varchar(128), TableName Varchar(128), SchemaId Int, SchemaName Varchar(128), RN SmallInt)
Insert Into @CDCTables 
Select 
	CDC_CT.Object_Id As CDCObjectId 
	,CDC_CT.Source_Object_Id As TableObjectId 
	,QuoteName(CDC_CT.Capture_Instance + '_CT')  As Capture_Instance
	,CDC_CT.Role_Name 
	,CDC_CT.Index_Name 
	,QuoteName(SysTbl.name) As TableName 
	,SysSchem.schema_id 
	,QuoteName(SysSchem.name) As SchemaName 
	,ROW_NUMBER() Over (Order By CDC_CT.Object_Id) As RN 
From 
	CDC.change_tables CDC_CT 
	Inner Join Sys.tables As SysTbl On CDC_CT.Source_Object_Id = SysTbl.object_id 
	Inner Join Sys.schemas As SysSchem On SysTbl.schema_id = SysSchem.schema_id 
Where 
	1 = 1


Set @CountCDCTables = @@ROWCOUNT 

Declare @IndexColumns Table (TableObjectId Int, TableName Varchar(128), SchemaId Int, SchemaName Varchar(128), IndexId Int, ColumnId Int, ColumnName Varchar(128))
Insert Into @IndexColumns 
Select 
	sysTbls.object_id As TableObjectId 
	,QuoteName(sysTbls.name) As TableName 
	,SysSchem.schema_id As SchemaId 
	,QuoteName(SysSchem.name) As SchemaName 
	,SysIndex.index_id 
	,SysIndexCols.column_id 
	,QuoteName(SysCols.name) 
From 
	sys.tables As sysTbls 
	Inner Join sys.schemas As SysSchem On sysTbls.schema_id = SysSchem.schema_id 
	Inner Join sys.indexes As SysIndex On sysTbls.object_id = SysIndex.object_id 
	Inner Join sys.index_columns As SysIndexCols On SysIndex.object_id = SysIndexCols.object_id And SysIndex.index_id = SysIndexCols.index_id 
	Inner Join sys.columns As SysCols On SysIndexCols.column_id = SysCols.column_id And SysIndexCols.object_id = SysCols.object_id 
Where 
	SysIndex.type = 1 
	And SysSchem.name <> 'CDC'
Order By 
	sysTbls.object_id
	

While @CDCTableLoopNo < @CountCDCTables 
Begin 

	Select @CDCTableName = '', @CDCSchemaName = '', @CDCCaptureInstance = '', @PrimaryKeyFields = '', @PrimaryKeyFieldsForValues = ''

	Select @CDCTableName = TableName, @CDCSchemaName = SchemaName, @CDCCaptureInstance = Capture_Instance From @CDCTables Where RN = @CDCTableLoopNo + 1 
	
	Select 
		@PrimaryKeyFields = STUFF((Select ',' + SubQry.ColumnName From @IndexColumns As SubQry Where SubQry.TableObjectId = MainQry.TableObjectId And SubQry.SchemaId = MainQry.SchemaId For XML Path('')), 1, 1, '')
		,@PrimaryKeyFieldsForValues = STUFF((Select ', Convert(Varchar(Max), SubQry.' + SubQry.ColumnName + ') +' + ''',''' From @IndexColumns As SubQry Where SubQry.TableObjectId = MainQry.TableObjectId And SubQry.SchemaId = MainQry.SchemaId For XML Path('')), 1, 1, '')
	From 
		@IndexColumns As MainQry 
	Where 
		MainQry.SchemaName = @CDCSchemaName 
		And MainQry.TableName = @CDCTableName 
	Group By 
		MainQry.SchemaId 
		,MainQry.TableObjectId 
		,MainQry.TableName
		
	If @PrimaryKeyFields = '' 
	Begin 
		Set @PrimaryKeyFields = '''-'''
		Set @PrimaryKeyFieldsForValues = '''-'''
	End 
	
	
	Declare mySysCursor Cursor For 
	Select 
		SysSchem.schema_id As SchemaId 
		,QuoteName(SysSchem.name) As SchemaName 
		,SysTbls.object_id As TableId 
		,QuoteName(SysTbls.name) As TableName 
		,SysCols.column_id As ColumnId 
		,QuoteName(SysCols.name) As ColumnName 
	From 
		sys.schemas As SysSchem 
		Inner Join sys.tables As SysTbls 
			On SysSchem.schema_id = SysTbls.schema_id 
		Inner Join Sys.columns As SysCols 
			On SysTbls.object_id = SysCols.object_id 
	Where 
		QuoteName(SysTbls.name) = @CDCTableName 
		And QuoteName(SysSchem.name) = @CDCSchemaName 
	

	Open mySysCursor;
	Fetch Next From mySysCursor 
	Into @SchemaId, @SchemaName, @TableId, @TableName, @ColumnId, @ColumnName 

	While @@FETCH_STATUS = 0 
	Begin 
		Begin Try 
		
			Set @strSQL = '
			Select 
				Convert(DateTime, TimeMapping.tran_end_time, 101) As AuditDate
				,(Case MAX(CDC_Tbl.__$operation) When 1 Then ' + '''D''' + ' When 2 Then ' + '''I''' + ' When 3 Then ' + '''U''' + ' When 4 Then ' + '''U''' + ' End) As AuditType
				,(''' + @SchemaName + ''') As SchemaName 
				,(''' + @TableName + ''') As TableName 
			'
				If @PrimaryKeyFields = '''-''' 
				Begin 
					Set @strSQL = @strSQL + '	,''-'' As PrimaryKeyFields'
					Set @strSQL = @strSQL + '	,''-'' As PrimaryKeyValues'
				End
				Else
				Begin
					Set @strSQL = @strSQL + '	,''' + @PrimaryKeyFields + ''' As PrimaryKeyFields'
					Set @strSQL = @strSQL + '   ,(Select Stuff((Select Distinct '','' + ' + @PrimaryKeyFieldsForValues + ' From cdc.' + @CDCCaptureInstance + ' As SubQry Where SubQry.__$start_lsn = CDC_Tbl.__$start_lsn And SubQry.__$seqval = CDC_Tbl.__$seqval For XML Path('''')), 1, 1, '''')) As PrimaryKeyValues '
				End
			Set @strSQL = @strSQL + 
			'			
				,(''' + @ColumnName + ''') As FieldName 
				,Max(Case CDC_Tbl.__$operation When 2 Then '''' When 3 Then Convert(Varchar(Max), ' + @ColumnName + ') When 4 Then '''' When 1 Then Convert(Varchar(Max), ' + @ColumnName + ') End) As OldValue 
				,Max(Case CDC_Tbl.__$operation When 2 Then Convert(Varchar(Max), ' + @ColumnName + ') When 3 Then '''' When 4 Then Convert(Varchar(Max), ' + @ColumnName + ') When 1 Then '''' End) As NewValue 			
			From 
				cdc.' + @CDCCaptureInstance + ' As CDC_Tbl 
				Left Outer Join cdc.lsn_time_mapping As TimeMapping On CDC_Tbl.__$start_lsn = TimeMapping.start_lsn 
			Where 
				TimeMapping.tran_end_time Between DATEADD(Day, -1, GetDate()) And DATEADD(Day, 0, GetDate()) 
			Group By 
				Convert(DateTime, TimeMapping.tran_end_time, 101)
				,CDC_Tbl.__$start_lsn
				,CDC_Tbl.__$seqval
				'
				If @PrimaryKeyFields <> '''-'''
				Begin 
				 Set @strSQL = @strSQL + ',' + @PrimaryKeyFields + ''
				End
				Set @strSQL = @strSQL + '			
			Having 
				Max(Case CDC_Tbl.__$operation When 2 Then '''' When 3 Then Convert(Varchar(Max), ' + @ColumnName + ') When 4 Then '''' When 1 Then Convert(Varchar(Max), ' + @ColumnName + ') End)
				<> Max(Case CDC_Tbl.__$operation When 2 Then Convert(Varchar(Max), ' + @ColumnName + ') When 3 Then '''' When 4 Then Convert(Varchar(Max), ' + @ColumnName + ') When 1 Then '''' End)
			Order By 
				__$start_lsn
			'
			Exec sp_ExecuteSQL @strSQL 
			
			Print(@TableName)
		End Try 
		Begin Catch 
			--catch errors which are happening 
			Select 
				GETDATE() As ErrorDate 
				,@SchemaName 
				,@TableName 
				,@ColumnName
			    ,ERROR_NUMBER() AS ErrorNumber
				,ERROR_SEVERITY() AS ErrorSeverity
				,ERROR_STATE() AS ErrorState
				,ERROR_PROCEDURE() AS ErrorProcedure
				,ERROR_LINE() AS ErrorLine
				,ERROR_MESSAGE() AS ErrorMessage;

		End Catch 
		
		Fetch Next From mySysCursor 
		Into @SchemaId, @SchemaName, @TableId, @TableName, @ColumnId, @ColumnName 
		
		
	End	

	Close mySysCursor 
	DeAllocate mySysCursor 
	
	Set @CDCTableLoopNo = @CDCTableLoopNo + 1 	
End
