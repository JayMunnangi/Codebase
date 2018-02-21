    SELECT
        [physical_memory_in_bytes] AS [PhysMemKB],
        [physical_memory_in_use_kb] AS [PhysMemInUseKB],
        [available_physical_memory_kb] AS [PhysMemAvailKB],
        [locked_page_allocations_kb] AS [LPAllocKB],
        [max_server_memory] AS [MaxSvrMem],
        [min_server_memory] AS [MinSvrMem]
    FROM
        sys.dm_os_sys_info
    CROSS JOIN
        sys.dm_os_process_memory
    CROSS JOIN
        sys.dm_os_sys_memory
    CROSS JOIN (
        SELECT
            [value_in_use] AS [max_server_memory]
        FROM
            sys.configurations
        WHERE
            [name] = 'max server memory (MB)') AS c
    CROSS JOIN (
        SELECT
            [value_in_use] AS [min_server_memory]
        FROM
            sys.configurations
        WHERE
            [name] = 'min server memory (MB)') AS c2
