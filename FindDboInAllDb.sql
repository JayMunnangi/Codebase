exec sp_msForEachDb ' use [?]
select db_name() as [database_name], r.[name] as [role], p.[name] as [member] from 
	sys.database_role_members m
join
	sys.database_principals r on m.role_principal_id = r.principal_id
join
	sys.database_principals p on m.member_principal_id = p.principal_id
where
	r.name = ''db_owner'''