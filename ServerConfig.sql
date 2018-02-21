--This will check different server configuration settings such as: allow updates, cross --db ownership chaining, clr enabled, SQL Mail XPs, Database Mail XPs, xp_cmdshell and Ad --Hoc Distributed Queries.

SELECT name, value_in_use FROM sys.configurations
 WHERE configuration_id IN (16391, 102, 400, 1562, 16386, 16385, 16390, 16393)