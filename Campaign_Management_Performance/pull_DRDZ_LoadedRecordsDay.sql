DECLARE @BeginOfDay DATETIME = CAST(GETDATE() AS DATE)

--Synchronize the target table with refreshed data 
MERGE [STAT_DB].[dbo].[tDRDZ_LoadedRecordsDay] AS TARGET
USING
(
-- Select contains loaded records for the every campaign during the day 
SELECT @BeginOfDay AS CDay, CampaignId, COUNT(DISTINCT ContactId) AS NRecords
FROM tContact
WHERE InsertDate >= @BeginOfDay OR LastReturnToWork >= @BeginOfDay
GROUP BY CampaignId
) AS SOURCE 
ON (TARGET.CDay = SOURCE.CDay) AND (TARGET.CampaignId = SOURCE.CampaignId) 

-- When records on source DB are matched and NRecords inceased then update the record
WHEN MATCHED AND  (TARGET.NRecords < SOURCE.NRecords)
  THEN 
    UPDATE SET TARGET.CDay = SOURCE.CDay, TARGET.CampaignId = SOURCE.CampaignId, TARGET.NRecords = SOURCE.NRecords
	

--When no records on the source DB are matched, then insert the incoming records from the source table to the target table
WHEN NOT MATCHED BY TARGET 
  THEN INSERT (CDay, CampaignId, NRecords) 
	VALUES (SOURCE.CDay, SOURCE.CampaignId, SOURCE.NRecords);
