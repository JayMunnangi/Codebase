/* Updating External Datbase to match with central spec */

DECLARE @DatabaseName varchar(max) = DB_Name()
DECLARE @CanonDatabase varchar(max) = (SELECT ConfigValue FROM metadata.CCRDatabase WHERE ConfigCode = 'CanonDatabase')
DECLARE @FeedName varchar(max) = (SELECT ConfigValue FROM metadata.CCRDatabase WHERE ConfigCode = 'FeedName')
DECLARE @SQL varchar(max)

EXECUTE library_canon.dbo.Deploy_ExternalDataModel @DatabaseName
EXECUTE library_canon.dbo.Deploy_CanonicalDatabase @CanonDatabase,'CQR'

/*Lineage & Feed */
IF OBJECT_ID('LineageInfo') IS NULL
CREATE TABLE dbo.LineageInfo(
    LineageId varchar(100) NOT NULL, 
    TradingPartnerId varchar(100) NULL, 
    TransmissionId varchar(100) NULL, 
    DataFeedId varchar(100) NULL, 
    FilePath varchar(2000) NULL, 
    CreateDate datetime2 NOT NULL, 
    CONSTRAINT PK_LineageInfo PRIMARY KEY NONCLUSTERED  ( LineageId ASC  )
);
TRUNCATE TABLE LineageInfo

INSERT INTO LineageInfo (LineageId,DataFeedId,CreateDate)
SELECT LineageId,ConfigValue,MAX(RecordExtract_dt)
FROM metadata.LineageId,metadata.CCRDatabase
WHERE ConfigCode = 'FeedId'
GROUP BY LineageId,ConfigValue

EXEC library_canon.dbo.Unus_LoadLineageInfo @DatabaseName, @CanonDatabase

SET @SQL =

'/*Org Id*/

DELETE h
FROM '+@CanonDatabase+'.history.Organization h
WHERE h.lineageId IS NULL

DELETE h
FROM '+@CanonDatabase+'.history.Organization h
INNER JOIN '+@CanonDatabase+'.unus.Lineage lin ON (h.lineageid = lin.lineageid)
INNER JOIN unus.Feed f ON (lin.FeedId = f.FeedId)

INSERT INTO '+@CanonDatabase+'.history.Organization (RecordCreated,RecordModified,LineageId,Name)
	SELECT TOP 1
		GETDATE() AS RecordCreated,
		GETDATE() AS RecordModified,
		LineageId AS LineageId,
		'''+@FeedName+''' AS Name
		FROM metadata.LineageId
		WHERE DataType = ''BusinessUnits''
		AND LineageId IS NOT NULL

INSERT INTO '+@CanonDatabase+'.history.Organization (RecordCreated,RecordModified,lineageid,OrganizationKey,Name)
	SELECT
		GETDATE() AS RecordCreated,
		GETDATE() AS RecordModified,
		LineageId AS LineageId,
		BusinessUnitCode AS OrganizationKey,
		BusinessUnitDescription AS Name
	FROM base.BusinessUnits
	WHERE LineageId IS NOT NULL

UPDATE o
SET ParentOrganizationId = (SELECT
	Id
FROM '+@CanonDatabase+'.history.Organization
WHERE Name = '''+@FeedName+'''
AND OrganizationKey IS NULL)
FROM '+@DatabaseName+'.unus.Feed f
INNER JOIN '+@CanonDatabase+'.unus.Lineage l
	ON f.FeedId = l.FeedId
INNER JOIN '+@CanonDatabase+'.history.Organization o
	ON l.LineageId = o.LineageId
WHERE o.ParentOrganizationId IS NULL
AND o.OrganizationKey IS NOT NULL

'

EXEC (@SQL)

SET @SQL = '
IF OBJECT_ID(''reference.OrgXwalk'') IS NOT NULL DROP TABLE reference.OrgXwalk
CREATE TABLE reference.OrgXwalk (id varchar(max), OrganizationKey varchar(max), LineageId uniqueidentifier)
INSERT INTO reference.OrgXwalk (id,OrganizationKey,LineageId)
SELECT id
	  ,OrganizationKey
	  ,lineageid
FROM '+@CanonDatabase+'.history.Organization h
WHERE EXISTS
	(SELECT DISTINCT LineageId
	 FROM metadata.LineageId m
	 WHERE h.LineageId=m.LineageId)
'
EXEC (@SQL)

PRINT 'Organization Insert Complete'

SET @SQL = '

/*Payer*/

DELETE h
FROM '+@CanonDatabase+'.history.Payer h
WHERE h.LineageId IS NULL

DELETE h
FROM '+@CanonDatabase+'.history.Payer h
INNER JOIN '+@CanonDatabase+'.unus.Lineage lin ON (h.lineageid = lin.lineageid)
INNER JOIN unus.Feed f ON (lin.FeedId = f.FeedId)

INSERT INTO '+@CanonDatabase+'.history.Payer (RecordCreated,RecordModified,lineageid,Name,PayerKey)
	SELECT
	MAX(a.RecordCreated) AS RecordCreated,
	MAX(a.RecordModified) AS RecordModified,
	MAX(a.LineageId) AS LineageId,
	a.Name,
	a.PayerKey
FROM
(SELECT DISTINCT
	GETDATE() AS RecordCreated,
	GETDATE() AS RecordModified,
	LineageId AS LineageId,
	PrimaryInsuranceCompanyName AS Name,
	PrimaryInsuranceCompanyName AS PayerKey
FROM base.Demographics
WHERE PrimaryInsuranceCompanyName IS NOT NULL
AND LineageId IS NOT NULL

UNION

SELECT DISTINCT
	GETDATE() AS RecordCreated,
	GETDATE() AS RecordModified,
	LineageId AS LineageId,
	SecondaryInsuranceCompanyName AS Name,
	SecondaryInsuranceCompanyName AS PayerKey
FROM base.Demographics
WHERE SecondaryInsuranceCompanyName IS NOT NULL
AND LineageId IS NOT NULL

UNION

SELECT DISTINCT
	GETDATE() AS RecordCreated,
	GETDATE() AS RecordModified,
	LineageId AS LineageId,
	TertiaryInsuranceCompanyName AS Name,
	TertiaryInsuranceCompanyName AS PayerKey
FROM base.Demographics
WHERE TertiaryInsuranceCompanyName IS NOT NULL
AND LineageId IS NOT NULL) a
GROUP BY	Name,
			a.PayerKey
	'

EXEC(@SQL)

SET @SQL = '
IF OBJECT_ID(''reference.PayerXwalk'') IS NOT NULL DROP TABLE reference.PayerXwalk
CREATE TABLE reference.PayerXwalk (id varchar(max), PayerKey varchar(max), LineageId uniqueidentifier)
INSERT INTO reference.PayerXwalk (id,PayerKey,LineageId)
SELECT id
	  ,PayerKey
	  ,lineageid
FROM '+@CanonDatabase+'.history.Payer h
WHERE EXISTS
	(SELECT DISTINCT LineageId
	 FROM metadata.LineageId m
	 WHERE h.LineageId=m.LineageId)
'
EXEC (@SQL)

PRINT 'Payer Insert Complete'

SET @SQL = '

/*Provider*/

DELETE h
FROM '+@CanonDatabase+'.history.Provider h
WHERE h.lineageId IS NULL

DELETE h
FROM '+@CanonDatabase+'.history.Provider h
INNER JOIN '+@CanonDatabase+'.unus.Lineage lin ON (h.lineageid = lin.lineageid)
INNER JOIN unus.Feed f ON (lin.FeedId = f.FeedId)

INSERT INTO '+@CanonDatabase+'.history.Provider (RecordCreated,RecordModified,lineageid,ProviderKey, FirstName, LastName)
	SELECT DISTINCT
		GETDATE() AS RecordCreated,
		GETDATE() AS RecordModified,
		p.LineageId AS LineageId,
		ProviderNumber AS ProviderKey,
		ProviderFirstName AS FirstName,
		ProviderLastName AS LastName
	FROM base.Providers p
	LEFT JOIN base.BusinessUnits b
		ON p.ProviderClinicId = b.BusinessUnitCode
	WHERE p.LineageId IS NOT NULL'

EXEC (@SQL)

SET @SQL = '
IF OBJECT_ID(''reference.ProviderXwalk'') IS NOT NULL DROP TABLE reference.ProviderXwalk
CREATE TABLE reference.ProviderXwalk (id varchar(max), ProviderKey varchar(max), LineageId uniqueidentifier)
INSERT INTO reference.ProviderXwalk (id,ProviderKey,LineageId)
SELECT id
	  ,ProviderKey
	  ,lineageid
FROM '+@CanonDatabase+'.history.Provider h
WHERE EXISTS
	(SELECT DISTINCT LineageId
	 FROM metadata.LineageId m
	 WHERE h.LineageId=m.LineageId)
'
EXEC (@SQL)

PRINT 'Provider Insert Complete'

SET @SQL = 

'DELETE h
FROM '+@CanonDatabase+'.history.ProviderSpecialty h
WHERE h.lineageId IS NULL

DELETE h
FROM '+@CanonDatabase+'.history.ProviderSpecialty h
INNER JOIN '+@CanonDatabase+'.unus.Lineage lin ON (h.lineageid = lin.lineageid)
INNER JOIN unus.Feed f ON (lin.FeedId = f.FeedId)

INSERT INTO '+@CanonDatabase+'.history.ProviderSpecialty (RecordCreated,RecordModified,lineageid,ProviderId, SpecialtyOriginal, SpecialtyMapped)
	SELECT DISTINCT
		GETDATE() AS RecordCreated,
		GETDATE() AS RecordModified,
		d.LineageId AS LineageId,
		p.Id AS ProviderId,
		''PCP'' AS SpecialtyOriginal,
		1534 AS SpecialtyMapped -- ref.concept.id value for ''Clinic/Center: Primary Care''
	FROM '+@CanonDatabase+'.history.Provider p
	INNER JOIN base.providers b ON (p.providerkey = b.providernumber AND p.LineageId = b.LineageId)
	INNER JOIN base.Demographics d ON (b.ProviderNumber = d.PrimaryCareProviderId)
	WHERE d.LineageId IS NOT NULL'

EXEC(@SQL)

PRINT 'ProviderSpecialty Insert Complete'

SET @SQL =

'DELETE h
FROM '+@CanonDatabase+'.history.ProviderOrganizationLocation h
WHERE h.LineageId IS NULL

DELETE h
FROM '+@CanonDatabase+'.history.ProviderOrganizationLocation h
INNER JOIN '+@CanonDatabase+'.unus.Lineage lin ON (h.lineageid = lin.lineageid)
INNER JOIN unus.Feed f ON (lin.FeedId = f.FeedId)

INSERT INTO '+@CanonDatabase+'.history.ProviderOrganizationLocation (RecordCreated,RecordModified,LineageId,ProviderId, OrganizationId)
	SELECT DISTINCT
		GETDATE() AS RecordCreated,
		GETDATE() AS RecordModified,
		p.LineageId AS LineageId,
		p.Id AS ProviderId,
		o.Id AS OrganizationId
	FROM '+@CanonDatabase+'.history.Provider p
	INNER JOIN base.providers b ON (p.ProviderKey = b.ProviderNumber and p.LineageId = b.LineageId)
	INNER JOIN base.BusinessUnits bu ON b.ProviderClinicId = bu.BusinessUnitCode
	INNER JOIN '+@CanonDatabase+'.history.Organization o ON (bu.BusinessUnitCode = o.OrganizationKey AND bu.LineageId = o.LineageId)
	WHERE p.LineageId IS NOT NULL'

EXEC(@SQL)

PRINT 'ProviderOrganizationLocation Insert Complete'

SET @SQL = 

'/*Patient*/

DELETE h
FROM '+@CanonDatabase+'.history.Patient h
WHERE h.LineageId IS NULL

DELETE h
FROM '+@CanonDatabase+'.history.Patient h
INNER JOIN '+@CanonDatabase+'.unus.Lineage lin ON (h.lineageid = lin.lineageid)
INNER JOIN unus.Feed f ON (lin.FeedId = f.FeedId)

INSERT INTO '+@CanonDatabase+'.history.Patient (RecordCreated,RecordModified,lineageid,PatientKey, FirstName, LastName, BirthDate, DeathDate, GenderOriginal, GenderMapped, AddressZip)
	SELECT DISTINCT
		GETDATE() AS RecordCreated,
		GETDATE() AS RecordModified,
		b.LineageId AS LineageId,
		b.PatientId AS PatientKey,
		b.FirstName AS FirstName,
		b.LastName AS LastName,
		b.DateOfBirth AS BirthDate,
		b.DateOfDeath AS DeathDate,
		b.Gender AS GenderOriginal,
		r.id AS GenderMapped,
		b.ZipCode AS AddressZip
	FROM base.demographics b
	LEFT JOIN '+@CanonDatabase+'.ref.Concept r
		ON b.Gender = r.Code
		AND r.CodeSystemId = ''18''
	WHERE b.LineageId IS NOT NULL
'

EXEC(@SQL)

SET @SQL = '
IF OBJECT_ID(''reference.PatientXwalk'') IS NOT NULL DROP TABLE reference.PatientXwalk
CREATE TABLE reference.PatientXwalk (id varchar(max), patientkey varchar(max), LineageId uniqueidentifier)
INSERT INTO reference.PatientXwalk (id,patientkey,LineageId)
SELECT id
	  ,patientkey
	  ,lineageid
FROM '+@CanonDatabase+'.history.patient p
WHERE EXISTS
	(SELECT DISTINCT LineageId
	 FROM metadata.LineageId m
	 WHERE p.LineageId=m.LineageId)
'
EXEC (@SQL)

PRINT 'Patient Insert Complete'

SET @SQL =

'DELETE h
FROM '+@CanonDatabase+'.history.PatientIdentifier h
WHERE h.LineageId IS NULL

DELETE h
FROM '+@CanonDatabase+'.history.PatientIdentifier h
INNER JOIN '+@CanonDatabase+'.unus.Lineage lin ON (h.lineageid = lin.lineageid)
INNER JOIN unus.Feed f ON (lin.FeedId = f.FeedId)

INSERT INTO '+@CanonDatabase+'.history.PatientIdentifier (RecordCreated,RecordModified,lineageid,PatientId, IdentifierName, Extension)
	SELECT DISTINCT
		GETDATE() AS RecordCreated,
		GETDATE() AS RecordModified,
		d.LineageId AS LineageId,
		p.Id AS PatientId,
		''MRN'' AS IdentifierName,
		d.PatientId AS Extension
	FROM '+@CanonDatabase+'.history.Patient p
	INNER JOIN base.demographics d ON (p.PatientKey = d.PatientId AND p.LineageId = d.LineageId)
	WHERE d.LineageId IS NOT NULL

	UNION

	SELECT DISTINCT
		GETDATE() AS RecordCreated,
		GETDATE() AS RecordModified,
		d.LineageId AS LineageId,
		p.Id AS PatientId,
		''HICNO'' AS IdentifierName,
		d.HICNO AS Extension
	FROM '+@CanonDatabase+'.history.Patient p
	INNER JOIN base.demographics d ON (p.PatientKey = d.PatientId AND p.LineageId = d.LineageId)
	WHERE d.HICNO IS NOT NULL
	AND d.LineageId IS NOT NULL

	UNION

	SELECT DISTINCT
		GETDATE() AS RecordCreated,
		GETDATE() AS RecordModified,
		d.LineageId AS LineageId,
		p.Id AS PatientId,
		''SocialSecurityNumber'' AS IdentifierName,
		d.SocialSecurityNumber AS Extension
	FROM '+@CanonDatabase+'.history.Patient p
	INNER JOIN base.demographics d ON (p.PatientKey = d.PatientId AND p.LineageId = d.LineageId)
	WHERE d.SocialSecurityNumber IS NOT NULL
	AND d.LineageId IS NOT NULL'

EXEC(@SQL)

PRINT 'PatientIdentifier Insert Complete'


SET @SQL =


'/*Visit*/

DELETE h
FROM '+@CanonDatabase+'.history.Visit h
WHERE h.LineageId IS NULL

DELETE h
FROM '+@CanonDatabase+'.history.Visit h
INNER JOIN '+@CanonDatabase+'.unus.Lineage lin ON (h.lineageid = lin.lineageid)
INNER JOIN unus.Feed f ON (lin.FeedId = f.FeedId)

DELETE l
FROM '+@CanonDatabase+'.history.Location l
INNER JOIN '+@CanonDatabase+'.unus.Lineage lin ON (l.lineageid = lin.lineageid)
INNER JOIN unus.Feed f ON (lin.FeedId = f.FeedId)

INSERT INTO '+@CanonDatabase+'.history.Location (RecordCreated, RecordModified, LineageId, TypeOriginal)
	SELECT DISTINCT
		GETDATE() AS RecordCreated,
		GETDATE() AS RecordModified,
		s.LineageId AS LineageId,
		s.PlaceOfServiceCode AS TypeOriginal
		FROM base.schedules s
		WHERE s.PlaceOfServiceCode IS NOT NULL

INSERT INTO '+@CanonDatabase+'.history.Visit (RecordCreated,RecordModified,lineageid,VisitKey, AdmitDtm, OrganizationId, PatientId, AttendingProviderId, PrimaryPayerId,VisitClassOriginal, LocationId)
	SELECT DISTINCT
		GETDATE() AS RecordCreated,
		GETDATE() AS RecordModified,
		s.LineageId AS LineageId,
		ScheduleRecordId AS VisitKey,
		ScheduleDate AS AdmitDtm,
		o.Id AS OrganizationId,
		p.id AS PatientId,
		hprov.id AS AttendingProviderId,
		pay.id AS PrimaryPayerId,
		''Outpatient'' AS VisitClassOriginal,
		hloc.Id AS LocationID
	FROM base.Schedules s
	INNER JOIN reference.OrgXwalk o ON (s.ScheduleClinicId = o.OrganizationKey)
	INNER JOIN reference.PatientXwalk p ON (s.patientid = p.patientkey)
	INNER JOIN base.demographics d ON (d.PatientId = s.PatientId)
	INNER JOIN reference.ProviderXwalk hprov ON (s.ScheduleProviderId = hprov.providerKey)
	LEFT JOIN '+@CanonDatabase+'.history.Location hloc ON (hloc.TypeOriginal = s.PlaceOfServiceCode)
	LEFT JOIN reference.PayerXwalk pay ON (d.primaryinsurancecompanyname = pay.payerkey)
	WHERE s.LineageId IS NOT NULL' 

EXEC(@SQL)

SET @SQL = '
IF OBJECT_ID(''reference.EncounterXwalk'') IS NOT NULL DROP TABLE reference.EncounterXwalk
CREATE TABLE reference.EncounterXwalk (id varchar(max), visitkey varchar(max), LineageId uniqueidentifier)
INSERT INTO reference.EncounterXwalk (id,visitkey,LineageId)
SELECT id
	  ,visitkey
	  ,lineageid
FROM '+@CanonDatabase+'.history.visit p
WHERE EXISTS
	(SELECT DISTINCT LineageId
	 FROM metadata.LineageId m
	 WHERE p.LineageId=m.LineageId)
'
EXEC (@SQL)

PRINT 'Visit Insert Complete'

SET @SQL = '
/*DIAGNOSIS*/

DELETE h
FROM '+@CanonDatabase+'.history.Diagnosis h
WHERE h.LineageId IS NULL

DELETE h
FROM '+@CanonDatabase+'.history.Diagnosis h
INNER JOIN '+@CanonDatabase+'.unus.Lineage lin ON (h.lineageid = lin.lineageid)
INNER JOIN unus.Feed f ON (lin.FeedId = f.FeedId)

INSERT INTO '+@CanonDatabase+'.history.Diagnosis (RecordCreated,RecordModified,lineageid,DiagnosisOriginal, PatientId, RecordedDtm, StartDtm,EndDtm,VisitId,DiagnosisTypeOriginal,DiagnosisKey)
	SELECT DISTINCT
		GETDATE() AS RecordCreated,
		GETDATE() AS RecordModified,
		b.LineageId AS LineageId,
		b.DiagnosisCode AS DiagnosisOriginal,
		pat.Id AS PatientId,
		b.DiagnosisDate AS RecordedDtm,
		b.DiagnosisDate AS StartDtm,
		CASE WHEN b.ActiveFlag =''0'' AND b.DiagnosisEndDate IS NULL THEN b.DiagnosisDate ELSE b.DiagnosisEndDate END AS EndDtm,
		v.Id AS VisitId,
		''ICD9CM'' AS DiagnosisTypeOriginal,
		convert(varchar,b.PatientId)+convert(varchar,b.DiagnosisCode)+convert(varchar,b.DiagnosisDate) AS DiagnosisKey
	FROM base.Diagnoses b
	INNER JOIN reference.PatientXwalk pat ON (b.PatientId = pat.PatientKey)
	LEFT JOIN reference.EncounterXwalk v ON (b.ScheduleRecordId = v.VisitKey)
	WHERE b.LineageId IS NOT NULL

UPDATE '+@CanonDatabase+'.history.Diagnosis
SET DiagnosisTypeMapped = r.Id
FROM ref.codesystem r
WHERE r.Name = ''ICD-9-CM''
'

EXEC(@SQL)

PRINT 'Diagnosis Insert Complete'

SET @SQL = '

/*MedicationOrder*/

DELETE h
FROM '+@CanonDatabase+'.history.MedicationOrder h
WHERE h.LineageId IS NULL

DELETE h
FROM '+@CanonDatabase+'.history.MedicationOrder h
INNER JOIN '+@CanonDatabase+'.unus.Lineage lin ON (h.lineageid = lin.lineageid)
INNER JOIN unus.Feed f ON (lin.FeedId = f.FeedId)

INSERT INTO '+@CanonDatabase+'.history.MedicationOrder (RecordCreated,RecordModified,LineageId,PatientId, WrittenDtm, StartDtm, EndDtm, MedicationOriginal, MedicationCodeSystem,visitid,MedicationOrderKey)
	SELECT DISTINCT
		GETDATE() AS RecordCreated,
		GETDATE() AS RecordModified,
		b.LineageId AS LineageId,
		pat.Id AS PatientId,
		MedicationStartDate AS WrittenDtm,
		b.MedicationStartDate AS StartDtm,
		b.MedicationStopDate AS EndDtm,
		b.MedicationCode AS MedicationOriginal,
		''NDC'' AS MedicationCodeSystem,
		v.id AS VisitId,
		convert(varchar,b.patientid)+convert(varchar,b.medicationcode)+convert(varchar,b.MedicationStartDate)+convert(varchar,b.MedicationStopDate) AS MedicationOrderKey
	FROM base.medications b
	INNER JOIN reference.PatientXwalk pat ON (b.PatientId = pat.PatientKey)
	LEFT JOIN reference.EncounterXwalk v ON (b.schedulerecordid = v.visitkey)
	WHERE b.LineageId IS NOT NULL
'

EXEC(@SQL)

PRINT 'MedicationOrder Insert Complete'

SET @SQL = '
/*ProcedureEvent*/

DELETE h
FROM '+@CanonDatabase+'.history.ProcedureEvent h
WHERE h.LineageId IS NULL

DELETE h
FROM '+@CanonDatabase+'.history.ProcedureEvent h
INNER JOIN '+@CanonDatabase+'.unus.Lineage lin ON (h.lineageid = lin.lineageid)
INNER JOIN unus.Feed f ON (lin.FeedId = f.FeedId)

INSERT INTO '+@CanonDatabase+'.history.ProcedureEvent (RecordCreated,RecordModified,LineageId,StartDtm, PatientId, ProcedureOriginal, VisitId,ProcedureCodeSystem, ProcedureEventKey)
	SELECT DISTINCT
		GETDATE() AS RecordCreated,
		GETDATE() AS RecordModified,
		b.LineageId AS LineageId,
		ServiceDate AS StartDtm,
		pat.id AS PatientId,
		b.ServiceCode AS ProcedureOriginal,
		v.id AS VisitId,
		''CPT'' AS ProcedureCodeSystem,
		convert(varchar,b.patientid)+convert(varchar,b.servicecode)+convert(varchar,b.servicedate) AS ProcedureEventKey
	FROM base.services b
	INNER JOIN reference.PatientXwalk pat ON (b.PatientId = pat.PatientKey)
	LEFT JOIN reference.EncounterXwalk v ON (b.schedulerecordid = v.VisitKey)
	WHERE b.LineageId IS NOT NULL'

EXEC(@SQL)

PRINT 'ProcedureEvent Insert Complete'

SET @SQL = '

/*ObservationResult*/

DELETE h
FROM '+@CanonDatabase+'.history.ObservationResult h
WHERE h.LineageId IS NULL

DELETE h
FROM '+@CanonDatabase+'.history.ObservationResult h
INNER JOIN '+@CanonDatabase+'.unus.Lineage lin ON (h.lineageid = lin.lineageid)
INNER JOIN unus.Feed f ON (lin.FeedId = f.FeedId)

INSERT INTO '+@CanonDatabase+'.history.ObservationResult (RecordCreated,RecordModified,LineageId,StartDtm, PatientId, ValueQuantityNumeric, ValueQuantityUnit,VisitId,ObservationResultOriginal,ObservationResultCodeSystem,ObservationResultKey)
	SELECT DISTINCT
		GETDATE() AS RecordCreated,
		GETDATE() AS RecordModified,
		b.LineageId AS LineageId,
		ServiceDate AS StartDtm,
		pat.Id AS PatientId,
		REPLACE(TestResult,''%'','''') AS ValueQuantityNumeric,
		TestUnit AS ValueQuantityUnit,
		v.Id AS VisitId,
		b.ServiceCode AS ObservationResultOriginal,
		''LOINC'' AS ObservationResultCodeSystem,
		convert(varchar,b.patientid)+convert(varchar,b.servicecode)+convert(varchar,b.servicedate) AS ObservationResultKey
	FROM base.services b
	INNER JOIN reference.PatientXwalk pat ON (b.PatientId = pat.PatientKey)
	LEFT JOIN reference.EncounterXwalk v ON (b.schedulerecordid = v.VisitKey)
	WHERE b.LineageId IS NOT NULL

INSERT INTO '+@CanonDatabase+'.history.ObservationResult (RecordCreated,RecordModified,LineageId,StartDtm, PatientId, ValueQuantityNumeric, ValueQuantityUnit,VisitId,ObservationResultOriginal,ObservationResultCodeSystem, ObservationResultKey)
	SELECT DISTINCT
		GETDATE() AS RecordCreated,
		GETDATE() AS RecordModified,
		b.LineageId AS LineageId,
		b.VitalsDate AS StartDtm,
		pat.Id AS PatientId,
		b.BodyMassIndex AS ValueQuantityNumeric,
		NULL AS ValueQuantityUnit,
		v.Id AS VisitId,
		''39156-5'' AS ObservationResultOriginal,
		''LOINC'' AS ObservationResultCodeSystem,
		convert(varchar,b.PatientId)+convert(varchar,b.vitalsdate)+convert(varchar,b.bodymassindex) AS ObservationResultKey
	FROM base.vitals b
	INNER JOIN reference.PatientXwalk pat ON (b.PatientId = pat.PatientKey)
	LEFT JOIN reference.EncounterXwalk v ON (b.schedulerecordid = v.VisitKey)
	WHERE b.BodyMassIndex IS NOT NULL
	AND b.LineageId IS NOT NULL

INSERT INTO '+@CanonDatabase+'.history.ObservationResult (RecordCreated,RecordModified,LineageId,StartDtm, PatientId, ValueQuantityNumeric, ValueQuantityUnit,VisitId,ObservationResultOriginal,ObservationResultCodeSystem, ObservationResultKey)
	SELECT DISTINCT
		GETDATE() AS RecordCreated,
		GETDATE() AS RecordModified,
		b.LineageId AS LineageId,
		b.VitalsDate AS StartDtm,
		pat.Id AS PatientId,
		b.SystolicBloodPressure AS ValueQuantityNumeric,
		NULL AS ValueQuantityUnit,
		v.Id AS VisitId,
		''8480-6'' AS ObservationResultOriginal,
		''LOINC'' AS ObservationResultCodeSystem,
		convert(varchar,b.PatientId)+convert(varchar,b.vitalsdate)+convert(varchar,b.systolicbloodpressure) AS ObservationResultKey
	FROM base.vitals b
	INNER JOIN reference.PatientXwalk pat ON (b.PatientId = pat.PatientKey)
	LEFT JOIN reference.EncounterXwalk v ON (b.schedulerecordid = v.VisitKey)
	WHERE b.SystolicBloodPressure IS NOT NULL
	AND b.LineageId IS NOT NULL

INSERT INTO '+@CanonDatabase+'.history.ObservationResult (RecordCreated,RecordModified,LineageId,StartDtm, PatientId, ValueQuantityNumeric, ValueQuantityUnit,VisitId,ObservationResultOriginal,ObservationResultCodeSystem, ObservationResultKey)
	SELECT DISTINCT
		GETDATE() AS RecordCreated,
		GETDATE() AS RecordModified,
		b.LineageId AS LineageId,
		b.VitalsDate AS StartDtm,
		pat.Id AS PatientId,
		b.DiastolicBloodPressure AS ValueQuantityNumeric,
		NULL AS ValueQuantityUnit,
		v.Id AS VisitId,
		''8462-4'' AS ObservationResultOriginal,
		''LOINC'' AS ObservationResultCodeSystem,
		convert(varchar,b.PatientId)+convert(varchar,b.vitalsdate)+convert(varchar,b.DiastolicBloodPressure) AS ObservationResultKey
	FROM base.vitals b
	INNER JOIN reference.PatientXwalk pat ON (b.PatientId = pat.PatientKey)
	LEFT JOIN reference.EncounterXwalk v ON (b.schedulerecordid = v.VisitKey)
	WHERE b.DiastolicBloodPressure IS NOT NULL
	AND b.LineageId IS NOT NULL

INSERT INTO '+@CanonDatabase+'.history.ObservationResult (RecordCreated,RecordModified,LineageId,StartDtm, PatientId, ValueQuantityNumeric, ValueQuantityUnit,VisitId,ObservationResultOriginal,ObservationResultCodeSystem, ObservationResultKey)
	SELECT DISTINCT
		GETDATE() AS RecordCreated,
		GETDATE() AS RecordModified,
		b.LineageId AS LineageId,
		b.EncounterDate AS StartDtm,
		pat.Id AS PatientId,
		b.SmokeStatus AS ValueQuantityNumeric,
		NULL AS ValueQuantityUnit,
		v.Id AS VisitId,
		''68536-2'' AS ObservationResultOriginal,
		''LOINC'' AS ObservationResultCodeSystem,
		convert(varchar,b.patientid)+convert(varchar,b.smokestatus)+convert(varchar,b.encounterdate) AS ObservationResultKey
	FROM base.Lifestyle b
	INNER JOIN reference.PatientXwalk pat ON (b.PatientId = pat.PatientKey)
	LEFT JOIN reference.EncounterXwalk v ON (b.schedulerecordid = v.VisitKey)
	WHERE b.LineageId IS NOT NULL


INSERT INTO '+@CanonDatabase+'.history.ObservationResult (RecordCreated,RecordModified,LineageId,StartDtm, PatientId, ValueQuantityNumeric, ValueQuantityUnit,VisitId,ObservationResultOriginal,ObservationResultCodeSystem, ObservationResultKey)
	SELECT DISTINCT
		GETDATE() AS RecordCreated,
		GETDATE() AS RecordModified,
		b.LineageId AS LineageId,
		b.EncounterDate AS StartDtm,
		pat.Id AS PatientId,
		NULL AS ValueQuantityNumeric,
		NULL AS ValueQuantityUnit,
		v.Id AS VisitId,
		l.SnomedCode AS ObservationResultOriginal,
		''SNOMED'' AS ObservationResultCodeSystem,
		convert(varchar,b.patientid)+convert(varchar,l.SnomedCode)+convert(varchar,b.encounterdate) AS ObservationResultKey
	FROM base.Lifestyle b
	INNER JOIN reference.PatientXwalk pat ON (b.PatientId = pat.PatientKey)
	LEFT JOIN reference.EncounterXwalk v ON (b.schedulerecordid = v.VisitKey)
	LEFT JOIN library_model_ccr.integrity.Lifestyle_SmokeStatus l
		ON (l.smokestatuscode = b.smokestatus)
	WHERE b.LineageId IS NOT NULL
	AND l.SnomedCode IS NOT NULL'

EXEC(@SQL)

PRINT 'ObservationResult Insert Complete'

SET @SQL = '

/*ProviderIdentifier*/

DELETE h
FROM '+@CanonDatabase+'.history.ProviderIdentifier h
WHERE h.LineageId IS NULL

DELETE h
FROM '+@CanonDatabase+'.history.ProviderIdentifier h
INNER JOIN '+@CanonDatabase+'.unus.Lineage lin ON (h.lineageid = lin.lineageid)
INNER JOIN unus.Feed f ON (lin.FeedId = f.FeedId)

INSERT INTO '+@CanonDatabase+'.history.ProviderIdentifier (RecordCreated,RecordModified,LineageId,ProviderId, IdentifierName, Extension)
	SELECT DISTINCT
		GETDATE() AS RecordCreated,
		GETDATE() AS RecordModified,
		p.LineageId AS LineageId,
		Id AS ProviderId,
		''NPI'' AS IdentifierName,
		p.ProviderNationalProviderId AS Extension
	FROM '+@CanonDatabase+'.history.Provider h
	LEFT JOIN base.Providers p
		ON h.ProviderKey = p.ProviderNumber
	WHERE p.ProviderNationalProviderId IS NOT NULL
	AND p.LineageId IS NOT NULL
	AND LEN(p.ProviderNationalProviderId)=10
	AND LEFT(p.ProviderNationalProviderId,1)=1
		
		UNION
		
	SELECT DISTINCT
		GETDATE() AS RecordCreated,
		GETDATE() AS RecordModified,
		p.LineageId AS LineageId,
		Id AS ProviderId,
		''TIN'' AS IdentifierName,
		p.ProviderTaxId AS Extension
	FROM '+@CanonDatabase+'.history.Provider h
	LEFT JOIN base.Providers p
		ON h.ProviderKey = p.ProviderNumber
	WHERE p.ProviderTaxId IS NOT NULL
	AND p.LineageId IS NOT NULL'

EXEC(@SQL)

PRINT 'ProviderIdentifier Insert Complete'

SET @SQL = '

/*Patient Attribution*/

DELETE h
FROM '+@CanonDatabase+'.history.PatientAttribution h
WHERE h.LineageId IS NULL

DELETE h
FROM '+@CanonDatabase+'.history.PatientAttribution h
INNER JOIN '+@CanonDatabase+'.unus.Lineage lin ON (h.lineageid = lin.lineageid)
INNER JOIN unus.Feed f ON (lin.FeedId = f.FeedId)

INSERT INTO '+@CanonDatabase+'.history.PatientAttribution (RecordCreated,RecordModified,LineageId,PatientId, ProviderId, OrganizationId, AttributedRoleOriginal, PatientAttributionKey)
	SELECT
		GETDATE() AS RecordCreated,
		GETDATE() AS RecordModified,
		d.LineageId AS LineageId,
		pat.Id AS PatientId,
		prov.Id AS ProviderId,
		org.OrganizationId AS OrganizationId,
		''PCP'' AS AttributedOriginal,
		convert(varchar,d.patientid)+convert(varchar,d.PrimaryCareProviderId)+convert(varchar,org.OrganizationId)+convert(varchar,''PCP'') AS PatientAttributionKey
	FROM base.Demographics d
	INNER JOIN reference.PatientXwalk pat ON (d.PatientId = pat.PatientKey)
	LEFT JOIN reference.ProviderXwalk prov ON (d.PrimaryCareProviderId = prov.ProviderKey)
	LEFT JOIN '+@CanonDatabase+'.history.ProviderOrganizationLocation org ON (prov.id = org.ProviderId)
	WHERE d.LineageId IS NOT NULL'

EXEC(@SQL)

PRINT 'PatientAttribution Insert Complete'

DROP TABLE reference.OrgXwalk
DROP TABLE reference.PatientXwalk
DROP TABLE reference.ProviderXwalk
DROP TABLE reference.PayerXwalk
DROP TABLE reference.EncounterXwalk

/*Diagnoses*/
SET @SQL = 'EXEC library_canon.dbo.Load_CodesFromColumn	@MemberDatabase_canon ='''+@CanonDatabase+''', @tbl_FQ = '''+@CanonDatabase+'.history.diagnosis'',	@ColumnCd = ''DiagnosisCd'', @ColumnOriginal = ''DiagnosisOriginal'', @CodeSystemTreatment = NULL,@HardCodedCodeSystemName = ''ICD-9-CM'',@ColumnCodeSystem = NULL'
EXEC(@SQL)

/*Procedures*/
SET @SQL = 'EXEC library_canon.dbo.Load_CodesFromColumn	@MemberDatabase_canon ='''+@CanonDatabase+''', @tbl_FQ = '''+@CanonDatabase+'.history.ProcedureEvent'', @ColumnCd = ''ProcedureCd'', @ColumnOriginal = ''ProcedureOriginal'', @CodeSystemTreatment = NULL, @HardCodedCodeSystemName= ''CPT'', @ColumnCodeSystem = NULL'
EXEC(@SQL)

/*ObservationResult*/
SET @SQL = 'EXEC library_canon.dbo.Load_CodesFromColumn	@MemberDatabase_canon ='''+@CanonDatabase+''', @tbl_FQ = '''+@CanonDatabase+'.history.ObservationResult'', @ColumnCd = ''ObservationResultCd'', @ColumnOriginal = ''ObservationResultOriginal'', @CodeSystemTreatment = NULL, @HardCodedCodeSystemName= ''LOINC'', @ColumnCodeSystem = NULL'
EXEC(@SQL)

/*Medications*/
SET @SQL = 'EXEC library_canon.dbo.Load_CodesFromColumn	@MemberDatabase_canon ='''+@CanonDatabase+''', @tbl_FQ = '''+@CanonDatabase+'.history.MedicationOrder'', @ColumnCd = ''MedicationCd'', @ColumnOriginal = ''MedicationOriginal'', @CodeSystemTreatment = NULL,  @HardCodedCodeSystemName= ''NDC'', @ColumnCodeSystem = NULL'
EXEC(@SQL)

EXEC library_canon.mdm.LoadProviderMaster @CanonDatabase

EXEC library.dbo.sUpdateStats @CanonDatabase