DECLARE @MaxMemoryPercent DECIMAL(10,2),
@PhysicalMemoryInMBytes DECIMAL(10,2),
@MemoryToBeAllocatedInMBytes INT,
@CurrentMemoryToBeAllocatedInMBytes INT
 
--SET MEMORY IN %

SET @MaxMemoryPercent = 80
SELECT @PhysicalMemoryInMBytes = physical_memory_kb/(1024) FROM sys.dm_os_sys_info
 
SELECT @PhysicalMemoryInMBytes,@MaxMemoryPercent

SELECT @MemoryToBeAllocatedInMBytes = CAST(((@MaxMemoryPercent/100)*@PhysicalMemoryInMBytes) AS INT)

--PRINT THE VALUE STORED 
SELECT @MemoryToBeAllocatedInMBytes

EXEC SP_CONFIGURE 'SHOW ADV',1
RECONFIGURE WITH OVERRIDE

-- CONFIG THE MEMORY 
EXEC SP_CONFIGURE 'MAX SERVER MEMORY',@MemoryToBeAllocatedInMBytes
RECONFIGURE WITH OVERRIDE
GO