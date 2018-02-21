update pes
	set
		pes.ExternalUrl = 'https://reporting.advisory.com/MicroStrategy/servlet/mstrWeb?evt=3010&src=mstrWeb.3010&Port=34954&Project=Crimson+Care+Management+Reports&Server=ASHADOLMCR-P01&loginReq=true&Member='
	FROM dbo.ProductEnvironmentSettings pes
	where  pes.ProductID = 22 and environmentid = 2 -- Crimson Care Management Reports

update pes
	set
		pes.ExternalUrl = 'https://reporting.advisory.com/MicroStrategy/servlet/mstrWeb?evt=3010&src=mstrWeb.3010&Port=34954&Project=Crimson+Continuum+of+Care+Reports&Server=ASHADOLMCR-P01&loginReq=true&Member='
	FROM dbo.ProductEnvironmentSettings pes
	where  pes.ProductID = 20 and environmentid = 2 -- Crimson Continuum of Care Reports

update pes
	set
		pes.ExternalUrl = 'https://reporting.advisory.com/MicroStrategy/servlet/mstrWeb?evt=3010&src=mstrWeb.3010&Port=34954&Project=Crimson+HealthPost+Reporting&Server=ASHADOLMCR-P01&loginReq=true&Member='
	FROM dbo.ProductEnvironmentSettings pes
	where  pes.ProductID = 48 and environmentid = 2 -- Crimson HealthPost Reporting

update pes
	set
		pes.ExternalUrl = 'https://reporting.advisory.com/MicroStrategy/servlet/mstrWeb?evt=3010&src=mstrWeb.3010&Port=34954&Project=Crimson+Market+Reports&Server=ASHADOLMCR-P01&loginReq=true&Member='
	FROM dbo.ProductEnvironmentSettings pes
	where  pes.ProductID = 23 and environmentid = 2 -- Crimson Market Advantage Reports

update pes
	set
		pes.ExternalUrl = 'https://reporting.advisory.com/MicroStrategy/servlet/mstrWeb?evt=3010&src=mstrWeb.3010&Port=34954&Project=Crimson+Medical+Group+Reports&Server=ASHADOLMCR-P01&loginReq=true&Member='
	FROM dbo.ProductEnvironmentSettings pes
	where  pes.ProductID = 24 and environmentid = 2 -- Crimson Medical Group Reports

update pes
	set
		pes.ExternalUrl = 'https://reporting.advisory.com/MicroStrategy/servlet/mstrWeb?evt=3010&src=mstrWeb.3010&Port=34954&Project=Crimson+Medical+Referrals+Reports&Server=ASHADOLMCR-P01&loginReq=true&Member='
	FROM dbo.ProductEnvironmentSettings pes
	where  pes.ProductID = 32 and environmentid = 2 -- Crimson Medical Referrals Reporting

update pes
	set
		pes.ExternalUrl = 'https://reporting.advisory.com/MicroStrategy/servlet/mstrWeb?evt=3010&src=mstrWeb.3010&Port=34954&Project=Crimson+Population+Risk+Reports&Server=ASHADOLMCR-P01&loginReq=true&Member='
	FROM dbo.ProductEnvironmentSettings pes
	where  pes.ProductID = 21 and environmentid = 2 -- Crimson Population Risk Reports

update pes
	set
		pes.ExternalUrl = 'https://reporting.advisory.com/MicroStrategy/servlet/mstrWeb?evt=3010&src=mstrWeb.3010&Port=34954&Project=Crimson+Quality+Reports&Server=ASHADOLMCR-P01&loginReq=true&Member='
	FROM dbo.ProductEnvironmentSettings pes
	where  pes.ProductID = 37 and environmentid = 2 -- Crimson Quality Reporting

update pes
	set
		pes.ExternalUrl = 'https://reporting.advisory.com/MicroStrategy/servlet/mstrWeb?evt=3010&src=mstrWeb.3010&Port=34954&Project=Data+Workbench&Server=ASHADOLMCR-P01&loginReq=true&Member='
	FROM dbo.ProductEnvironmentSettings pes
	where  pes.ProductID = 41 and environmentid = 2 -- Data Workbench

update pes
	set
		pes.ExternalUrl = 'https://reporting.advisory.com/MicroStrategy/servlet/mstrWeb?evt=3010&src=mstrWeb.3010&Port=34954&Project=Data+Workbench+-+Dashboard&Server=ASHADOLMCR-P01&loginReq=true&Member='
	FROM dbo.ProductEnvironmentSettings pes
	where  pes.ProductID = 46 and environmentid = 2 -- Data Workbench - Dashboard

update pes
	set
		pes.ExternalUrl = 'https://reporting.advisory.com/MicroStrategy/servlet/mstrWeb?evt=3010&src=mstrWeb.3010&Port=34954&Project=RND+Felix&Server=ASHADOLMCR-P01&loginReq=true&Member='
	FROM dbo.ProductEnvironmentSettings pes
	where  pes.ProductID = 43 and environmentid = 2 -- Felix

update pes
	set
		pes.ExternalUrl = 'https://reporting.advisory.com/MicroStrategy/servlet/mstrWeb?evt=3010&src=mstrWeb.3010&Port=34954&Project=PIC+Insights&Server=ASHADOLMCR-P01&loginReq=true&Member='
	FROM dbo.ProductEnvironmentSettings pes
	where  pes.ProductID = 47 and environmentid = 2 -- PIC Insights
