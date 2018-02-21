DECLARE @KeyFieldMatches INT

SET @KeyFieldMatches = 3 --Number of key fields to match in order

IF object_id('tempdb..#IndexList') IS NOT NULL BEGIN
    DROP TABLE #IndexList
END

IF object_id('tempdb..#IndexListShort') IS NOT NULL BEGIN
    DROP TABLE #IndexListShort
END

CREATE TABLE #IndexList (
      object_id    bigint not null
    , table_name varchar(150) not null
    , index_id int not null
    , index_name varchar(150) not null
    , index_column int not null
    , included bit not null
    , column_name varchar(150) not null
    , index_type int not null
)

CREATE CLUSTERED INDEX IndexList_Clu ON #IndexList (object_id, index_id, index_column, included)

CREATE TABLE #IndexListShort (
      object_id bigint not null
    , table_name varchar(150) not null
    , index_id int not null
    , index_name varchar(150) not null
    , column_names_first_n varchar(450) not null
    , column_names_key varchar(4000) not null
    , column_names_included varchar(4000) not null
)

DECLARE @object_id bigint
DECLARE @index_id int
DECLARE @List varchar(4000)
DECLARE @ListIncl varchar(4000)
DECLARE @ListShort varchar(450)

INSERT INTO #IndexList
SELECT o.object_id
    , table_name = o.name
    , i.index_id
    , index_name = i.name
    , index_column = ic.index_column_id
    , included = ic.is_included_column
    , column_name = c.name
    , index_type = i.type
FROM sys.objects o
    INNER JOIN sys.indexes i ON o.object_id = i.object_id
    INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
    INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id

SET @object_id = (SELECT TOP 1 object_id FROM #IndexList)
SET @index_id = (SELECT TOP 1 index_id FROM #IndexList WHERE object_id = @object_id)

WHILE @object_id IS NOT NULL BEGIN
    SET @List = ''
    SET @ListIncl = ''
    SET @ListShort = ''

    SELECT @List = @List + COALESCE(i.column_name + ', ', '') FROM #IndexList i WHERE i.object_id = @object_id and i.index_id = @index_id and i.included = 0 ORDER BY i.index_column
    SELECT @List = substring(@List, 0, Len(@List))

    SELECT @ListIncl = @ListIncl + COALESCE(i.column_name + ', ', '') FROM #IndexList i WHERE i.object_id = @object_id and i.index_id = @index_id and i.included = 1 ORDER BY i.index_column
    SELECT @ListIncl = substring(@ListIncl, 0, Len(@ListIncl))

    SELECT @ListShort = @ListShort + COALESCE(i.column_name + ', ', '') FROM #IndexList i WHERE i.object_id = @object_id and i.index_id = @index_id and i.included = 0 and index_column <= @KeyFieldMatches ORDER BY i.index_column
    SELECT @ListShort = substring(@ListShort, 0, Len(@ListShort))

    INSERT INTO #IndexListShort 
    SELECT TOP 1 i.object_id
        , i.table_name
        , i.index_id
        , i.index_name
        , @ListShort
        , @List
        , CASE i.index_type --Clustered indexes include everything
            WHEN 1 THEN '*'
            ELSE @ListIncl
            END
    FROM #IndexList i
    WHERE i.object_id = @object_id and i.index_id = @index_id

    DELETE #IndexList WHERE object_id = @object_id and index_id = @index_id

    SET @object_id = (SELECT TOP 1 object_id FROM #IndexList)
    SET @index_id = (SELECT TOP 1 index_id FROM #IndexList WHERE object_id = @object_id)
END

SELECT table_name, index_name, column_names_key, column_names_included
FROM #IndexListShort i
WHERE EXISTS (SELECT * FROM #IndexListShort i2 WHERE i.object_id = i2.object_id AND i.column_names_first_n = i2.column_names_first_n GROUP BY object_id, column_names_first_n HAVING Count(*) > 1)
ORDER BY table_name, column_names_key

DROP TABLE #IndexList
DROP TABLE #IndexListShort