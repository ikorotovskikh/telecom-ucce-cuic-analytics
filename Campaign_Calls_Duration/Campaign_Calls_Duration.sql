BEGIN
SET ANSI_WARNINGS ON
SET NOCOUNT ON

DECLARE @BeginDate DATETIME = :BeginDate
DECLARE @EndDate DATETIME = :EndDate


DECLARE @CampaignList VARCHAR(MAX) = CONCAT('(', :CampaignList , ')')


DECLARE @CL table (id int)
  INSERT INTO @CL (id)
  SELECT * FROM STRING_SPLIT(TRANSLATE(REPLACE(@CampaignList, 'null', ''), '()', '  '), ',')

DROP TABLE IF EXISTS #CL
DROP TABLE IF EXISTS #TCD

SELECT * INTO #CL 
FROM tContactLog tcl WITH (NOLOCK) 
WHERE tcl.TimeFrom >= @BeginDate  AND tcl.TimeFrom < @EndDate AND tcl.CampaignID IN (SELECT id FROM @CL) 

SELECT * INTO #TCD 
FROM t_Termination_Call_Detail tcd WITH (NOLOCK) 
WHERE DATEADD(SECOND, -1*Duration, DateTime) >= @BeginDate AND DATEADD(SECOND, -1*Duration, DateTime) <=  @EndDate 

SELECT 
MRF,
RF,
ClientType,
COUNT (SingleCall) AS NumCalls,
REPLACE(CONVERT (VARCHAR(50), CAST(ROUND(SUM(TalkTime)/60.0, 2) AS DECIMAL(38,2)),3),'.',',') AS CallsTalkTime
FROM
(SELECT

  tContact.FirstName AS MRF
 ,tContact.MiddleName AS RF
, CASE WHEN CHARINDEX('MIX', tCampaign.CampaignName) != 0 OR CHARINDEX('B2C', tCampaign.CampaignName) != 0 
			THEN 'ФЛ' 
			ELSE CASE WHEN CHARINDEX('B2B', tCampaign.CampaignName) != 0 OR CHARINDEX('В2В', tCampaign.CampaignName) != 0 THEN 'ЮЛ' ELSE '' END 
			END AS ClientType
 ,CL.ContactLogId AS SingleCall
 ,ISNULL(TCD.TalkTime, 0) AS TalkTime
 
 
  FROM #CL AS CL

  LEFT JOIN tContact (nolock) ON CL.ContactId = tContact.ContactId
  LEFT JOIN tCampaign (nolock) ON CL.CampaignID = tCampaign.CampaignId
  LEFT JOIN t_Agent (nolock) a ON CL.AgentId=a.PeripheralNumber  
  LEFT JOIN #TCD TCD  
            ON	a.SkillTargetID = TCD.AgentSkillTargetID AND 
				CL.ContactId = CASE WHEN ISNUMERIC(TCD.Variable4) = 1 THEN CAST(TCD.Variable4 AS int) ELSE 0 END AND
				RIGHT((CAST(CL.PhoneNumber AS varchar(32)) COLLATE Cyrillic_General_BIN),10) = RIGHT(TCD.ANI,10) 
				AND DATEADD(SECOND, -2, CL.ClientCallDialingEndTime) <= 
				(SELECT MIN(DATEADD(SECOND, -1*Duration, DateTime)) FROM #TCD TCDSTARTS 
				 WHERE TCDSTARTS.RouterCallKey = TCD.RouterCallKey AND TCDSTARTS.RouterCallKeyDay = TCD.RouterCallKeyDay
				)-- 2 seconds adj 'cause might be time difference bw CTI Outbound and ICM times
				AND DATEADD(SECOND, 2, CL.AgentCallDistributedTime)  > (SELECT MIN(DATEADD(SECOND, -1*Duration, DateTime)) FROM #TCD TCDSTARTS 
				 WHERE TCDSTARTS.RouterCallKey = TCD.RouterCallKey AND TCDSTARTS.RouterCallKeyDay = TCD.RouterCallKeyDay
				)
  WHERE TCD.TalkTime > 0
) c
GROUP BY RF, MRF, ClientType
END
