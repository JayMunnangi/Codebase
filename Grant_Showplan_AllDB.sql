#### Grant Showplanto multiple Databases ###

EXEC sp_MSforeachdb N’IF EXISTS
(
SELECT 1 FROM sys.databases WHERE name = ”?”
AND Is_read_only <> 1
)
BEGIN
print ”Use [?]; GRANT Showplan TO [DominName\username]”
END’;