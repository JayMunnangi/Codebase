SELECT  name
       ,is_disabled
       ,CAST(LoginProperty(name, 'IsExpired') AS INT) is_expired
       ,CAST(LoginProperty(name, 'IsLocked') AS INT) is_locked
FROM    sys.server_principals
WHERE   (is_disabled = 0 AND CAST(LoginProperty(name, 'IsExpired') AS INT) = 1)
        OR CAST(LoginProperty(name, 'IsLocked') AS INT) = 1)
ORDER BY name
