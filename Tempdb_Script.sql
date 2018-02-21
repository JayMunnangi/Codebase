-- Shrink the file size

USE master
 GO
 ALTER DATABASE tempdb
 MODIFY FILE
 (NAME = tempdev,
 SIZE = 81920MB)  –Reduce to the size you want
 GO


USE master
 GO
 ALTER DATABASE tempdb
 MODIFY FILE
 (NAME = tempdev2,
 SIZE = 81920MB)  –Reduce to the size you want
 GO


-- Create new datafiles

ALTER DATABASE tempdb
ADD FILE (NAME = tempdev3, FILENAME = 'G:\TempDB\tempdev3.ndf', SIZE = 81920MB);
ALTER DATABASE tempdb
ADD FILE (NAME = tempdev4, FILENAME = 'G:\TempDB\tempdev4.ndf', SIZE = 81920MB);