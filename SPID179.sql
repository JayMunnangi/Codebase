    UPDATE d  
    SET    CannotLoadBecause = COALESCE(CannotLoadBecause,'')+'; ERROR: PatientID is NULL'  
    FROM CCR_BB_BMG01_STG.diagnostics.Services d  
    WHERE   PatientId IS NULL  AND d.recordkey BETWEEN 9059311 AND 9359311    
    UPDATE d  SET    CannotLoadBecause = COALESCE(CannotLoadBecause,'')+'; ERROR: PatientID is Unknown'  
    FROM CCR_BB_BMG01_STG.diagnostics.Services d  
    WHERE   d.PatientID IS NOT NULL   AND NOT EXISTS 
    (    SELECT *    FROM CCR_BB_BMG01_STG.base.Demographics b    
    WHERE d.PatientId = b.PatientId)  AND d.recordkey BETWEEN 9059311 AND 9359311    
    UPDATE d  SET    CannotLoadBecause = COALESCE(CannotLoadBecause,'')+'; ERROR: EncounterId points to different patients in Services vs Encounters'  
    FROM CCR_BB_BMG01_STG.diagnostics.Services d  INNER JOIN CCR_BB_BMG01_STG.base.Schedules m ON d.ScheduleRecordId = m.ScheduleRecordId  
    WHERE   d.PatientId <> m.PatientId  AND d.recordkey BETWEEN 9059311 AND 9359311      
    UPDATE d  SET    CannotLoadBecause = COALESCE(CannotLoadBecause,'')+'; ERROR: ServiceCode is NULL'  
    FROM CCR_BB_BMG01_STG.diagnostics.Services d  
    WHERE   ServiceCode IS NULL  AND d.recordkey BETWEEN 9059311 AND 9359311   
    UPDATE d  SET    CannotLoadBecause = COALESCE(CannotLoadBecause,'')+'; ERROR: ServiceDate is NULL'  
    FROM CCR_BB_BMG01_STG.diagnostics.Services d  
    WHERE   ServiceDate IS NULL  AND d.recordkey BETWEEN 9059311 AND 9359311    
    UPDATE d  SET    CannotLoadBecause = COALESCE(CannotLoadBecause,'')+'; ERROR: ServiceDate is not recognized'  
    FROM CCR_BB_BMG01_STG.diagnostics.Services d  
    WHERE   isdate(ServiceDate) = 0   and ServiceDate is not NULL  AND d.recordkey BETWEEN 9059311 AND 9359311    
    UPDATE d  SET    CannotLoadBecause = COALESCE(CannotLoadBecause,'')+'; ERROR: ServiceCode is not a valid code'  
    FROM CCR_BB_BMG01_STG.diagnostics.Services d  WHERE   ServiceCode IS NOT NULL   AND NOT EXISTS
    (    SELECT *     FROM library_model_ccr.integrity.CQRCodes i    
    WHERE    d.ServiceCode = i.Code   )  AND d.recordkey BETWEEN 9059311 AND 9359311    
    UPDATE d  SET CannotLoadBecause = SUBSTRING(CannotLoadBecause,3,LEN(CannotLoadBecause))  
    FROM CCR_BB_BMG01_STG.diagnostics.Services d  WHERE   CannotLoadBecause IS NOT NULL  AND d.recordkey BETWEEN 9059311 AND 9359311    
    DELETE d   FROM CCR_BB_BMG01_STG.diagnostics.Services d  WHERE CannotLoadBecause IS NULL  AND d.recordkey BETWEEN 9059311 AND 9359311    
    DELETE bd  FROM CCR_BB_BMG01_STG.staging.Services bd  INNER JOIN CCR_BB_BMG01_STG.diagnostics.Services d  ON d.RecordKey = bd.Recordkey  
    AND d.recordkey BETWEEN 9059311 AND 9359311  AND d.CannotLoadBecause like '%ERROR:%'  