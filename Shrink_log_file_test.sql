--ServerName : ATXEDMWMDB-P02.CRIMSONAD.LOCAL
--SQL Server Version : 2014 SP1 CU3
-- Database under test : CCI_CHCBowlingGreen_PRD



use master
go


-- PRE-TEST STEPS : BEGIN

-- take a FULL BACKUP so the DIFF doesn't take too much time
backup database [CCI_CHCBowlingGreen_PRD] to disk = 'D:\backup\CCI_CHCBowlingGreen_PRD_FULL_2016612.bak'
with COMPRESSION, STATS=1
go

use CCI_CHCBowlingGreen_PRD
go

--Shrink the file to 10 KB so we can clearly verify the file growth process
DBCC SHRINKFILE ('Commonwealth_BowlingGreen_STG_log', 10)
go

-- PRE-TEST STEPS : END

sp_helpdb CCI_CHCBowlingGreen_PRD
go
-- verfiy if the size of log file = 10424 KB

-- ACTUAL TEST : BEGIN

-- this is the table we use to bloat up the log file
sp_help TEMP_SegmentedHospitalBenchmarks
go

-- UPDATE statement to expand the log file. This would take about 5 minutes, better get some coffee meanwhile :-)
update TEMP_SegmentedHospitalBenchmarks
set Measure = Measure + 'temp_test',
GroupName = GroupName + 'temp_test'
go


-- Lets verify the log file size
sp_helpdb CCI_CHCBowlingGreen_PRD
go
-- It would have grown to a size ~11GB

-- Now, lets take a DIFF backup.
backup database [CCI_CHCBowlingGreen_PRD] to disk = 'D:\backup\CCI_CHCBowlingGreen_PRD_DIFF_2016612.bak'
with DIFFERENTIAL, COMPRESSION, STATS=1
go


-- ACTUAL TEST : END

-- Verify if the log file size has shrunk after the DIFF.
sp_helpdb CCI_CHCBowlingGreen_PRD
go

-- I still see the same value that I saw before the DIFF backup