WITH

        CTE AS

        (

                SELECT  database_name

                        , last_backup_start_date_time

                        , physical_device_name

                        , backup_size / (1024 * 1024) AS backup_size_MB

                        , compressed_backup_size / (1024 * 1024)  AS compressed_backup_size_MB

                        , CAST(backup_size / compressed_backup_size AS decimal(5,2)) AS compression_ratio

                        , key_algorithm

                        , encryptor_thumbprint

                        , encryptor_type

                FROM    (

                                SELECT          S.database_name

                                                , MAX(S.backup_start_date) AS last_backup_start_date_time

                                                , MF.physical_device_name

                                                , S.backup_size

                                                , S.compressed_backup_size

                                                , S.key_algorithm

                                                , S.encryptor_thumbprint

                                                , S.encryptor_type

                                FROM            msdb.dbo.backupset AS S

                                INNER JOIN      msdb.dbo.backupmediafamily AS MF

                                                        ON S.media_set_id = MF.media_set_id

                                GROUP BY                S.database_name

                                                , S.type

                                                , MF.physical_device_name

                                                , S.backup_size

                                                , S.compressed_backup_size

                                                , S.key_algorithm

                                                , S.encryptor_thumbprint

                                                , S.encryptor_type

                        ) AS BH

        )

SELECT          D.name AS database_name

                , C.last_backup_start_date_time

                , C.physical_device_name

                , CAST(C.backup_size_MB AS decimal(15,2)) AS backup_size_MB

                , CAST(C.compressed_backup_size_MB AS decimal(15,2)) AS compressed_backup_size_MB

                , compression_ratio

                , C.key_algorithm

                , C.encryptor_thumbprint

                , C.encryptor_type

FROM            sys.databases AS D

INNER JOIN      CTE AS C

                        ON D.name = C.database_name
						Where c.database_name like 'QA-ASE-03'
						--where key_algorithm is not null

ORDER BY                C.last_backup_start_date_time