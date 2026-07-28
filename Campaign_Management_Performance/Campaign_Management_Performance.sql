BEGIN
SET ANSI_WARNINGS ON
SET NOCOUNT ON

DECLARE @BeginDate DATETIME = :BeginDate
DECLARE @EndDate DATETIME = :EndDate


DECLARE @CampaignList VARCHAR(MAX) = CONCAT('(', :CampaignList , ')')


DECLARE @CL table (id int)
  INSERT INTO @CL (id)
  SELECT * FROM STRING_SPLIT(TRANSLATE(REPLACE(@CampaignList, 'null', ''), '()', '  '), ',')

DROP TABLE IF EXISTS #TCL
DROP TABLE IF EXISTS #TCD
DROP TABLE IF EXISTS #TT


SELECT CONVERT(DATE, tcl.TimeFrom) AS D, * INTO #TCL 
FROM tContactLog tcl WITH (NOLOCK) 
WHERE tcl.TimeFrom >= @BeginDate  AND tcl.TimeFrom < @EndDate AND tcl.CampaignID IN (SELECT id FROM @CL)


SELECT * INTO #TCD 
FROM t_Termination_Call_Detail tcd WITH (NOLOCK) 
WHERE DATEADD(SECOND, -1*Duration, DateTime) >= @BeginDate AND DATEADD(SECOND, -1*Duration, DateTime) <=  @EndDate

SELECT D,
CL.CampaignID,
CL.AgentId,
CL.PhoneResultId,
TCD.TalkTime,
TCD.HoldTime,
TCD.WorkTime,
CASE WHEN CL.AgentId IS NULL THEN DATEDIFF(SECOND, CL.ClientCallDialingStartTime, 
																	CASE WHEN CL.ClientCallDialingEndTime IS NULL THEN CL.TimeTo ELSE CL.ClientCallDialingEndTime END) 
							 ELSE DATEDIFF(SECOND, CL.ClientCallDialingStartTime, CASE WHEN TCD.DateTime IS NULL 
																					   THEN CL.ClientCallDialingEndTime 
																					   ELSE TCD.DateTime END ) 
	 END AS CampaignCallDuration
  
INTO #TT
FROM #TCL CL WITH (NOLOCK)
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


;WITH

NumOfRecordsCalc AS
(SELECT
	CDay AS D
   ,CampaignId AS CampaignID
   ,NRecords AS NumRecords
   	FROM tDRDZ_LoadedRecordsDay
  WHERE CDay >= CONVERT(DATE, @BeginDate)  AND CDay < @EndDate AND CampaignId IN (SELECT id FROM @CL)
),

NumOfAgentsCalc AS
(
SELECT D, CampaignID, COUNT(DISTINCT AgentId) AS NumAgents FROM #TCL
WHERE AgentId IS NOT NULL
GROUP  BY D, CampaignID
),


NumAttemptsCalc AS
(
  SELECT 
	 D
	,CampaignID
	,COUNT(*) AS numAttemps
    ,callsSuccess	= SUM(CASE WHEN AgentId IS NOT NULL OR (AgentId IS NULL AND PhoneResultId = 209) THEN 1 ELSE 0 END)
	,callsLost	= SUM(CASE WHEN AgentId IS NULL AND PhoneResultId = 209 THEN 1 ELSE 0 END)
  FROM #TCL
  WHERE ClientCallDialingStartTime IS NOT NULL
  GROUP BY D, CampaignID
),

AgentTimeCalc AS
(
  SELECT
	 D
	,CampaignID
	,SUM(CAST(ISNULL(TalkTime, 0) + ISNULL(HoldTime, 0) + ISNULL(WorkTime, 0) AS DECIMAL(38, 0))) AS AgentTime
	,SUM(TalkTime) AS TalkingTime
    ,COUNT(*) AS numTCDVoiceCalls 
  FROM #TT
  GROUP BY D, CampaignID
)

SELECT
  D
 ,CampaignID
 ,tCampaign.CampaignName
 ,SUM(NumRecords) AS NumRecords
 ,SUM(NumAgents) AS NumAgents
 ,SUM(CampaignTime) AS CampaignTime
 ,SUM(numAttemps) AS numAttemps
 ,SUM(callsSuccess) AS callsSuccess
 ,SUM(callsLost) AS callsLost
 ,callsLostP = CASE SUM(callsSuccess) WHEN 0 THEN 0 ELSE SUM(callsLost)*1.0/SUM(callsSuccess) END 
 ,SUM(AgentTime) AS AgentTime
 ,ManHours = CASE SUM(NumAgents) WHEN 0 THEN 0 ELSE SUM(AgentTime)*1.0/SUM(NumAgents) END
 ,SUM(numTCDVoiceCalls) AS numTCDVoiceCalls
 ,SUM(TalkingTime) AS TalkingTime
 ,awgTalkTime = CASE SUM(calls1s) WHEN 0 THEN 0 ELSE SUM(TalkingTime)*1.0/SUM(calls1s) END
 ,talkTimeP = CASE SUM(CampaignTime) WHEN 0 THEN 0 ELSE SUM(TalkingTime)*1.0/SUM(CampaignTime) END
 ,SUM(calls1s) AS calls1s
 ,SUM(calls1sTime) AS calls1sTime
 ,SUM(calls5s) AS calls5s
FROM
( SELECT
    D
   ,CampaignID
   ,0 AS NumRecords
   ,0 AS NumAgents
   ,0 AS CampaignTime
   ,0 AS numAttemps
   ,0 AS callsSuccess
   ,0 AS callsLost   
   ,0 AS AgentTime
   ,0 AS TalkingTime
   ,0 AS numTCDVoiceCalls
   ,calls1s
   ,calls1sTime
   ,calls5s
  FROM (
  SELECT
    D
   ,CampaignID
   ,calls1s 		= SUM(CASE WHEN TalkTime >= 1 THEN 1 ELSE 0 END)
   ,calls1sTime		= SUM(CASE WHEN TalkTime >= 1 THEN TalkTime ELSE 0 END)
   ,calls5s 		= SUM(CASE WHEN TalkTime >= 5 THEN 1 ELSE 0 END)
  FROM #TT
  GROUP BY D, CampaignID
  ) c

  UNION ALL 

  SELECT 
    D
   ,CampaignID
   ,NumRecords
   ,0 AS NumAgents
   ,0 AS numAttemps
   ,0 AS callsSuccess
   ,0 AS callsLost   
   ,0 AS AgentTime
   ,0 AS CampaignTime
   ,0 AS TalkingTime
   ,0 AS numTCDVoiceCalls
   ,0 AS calls1s
   ,0 AS calls1sTime
   ,0 AS calls5s
  FROM NumOfRecordsCalc

  UNION ALL 
  
    SELECT 
    D
   ,CampaignID
   ,0 AS NumRecords
   ,NumAgents
   ,0 AS CampaignTime
   ,0 AS numAttemps
   ,0 AS callsSuccess
   ,0 AS callsLost   
   ,0 AS AgentTime
   ,0 AS TalkingTime
   ,0 AS numTCDVoiceCalls
   ,0 AS calls1s
   ,0 AS calls1sTime
   ,0 AS calls5s
  FROM NumOfAgentsCalc

  UNION ALL 
  
    SELECT 
    D
   ,CampaignID
   ,0 AS NumRecords
   ,0 AS NumAgents
   ,CampaignTime
   ,0 AS numAttemps
   ,0 AS callsSuccess
   ,0 AS callsLost   
   ,0 AS AgentTime
   ,0 AS TalkingTime
   ,0 AS numTCDVoiceCalls
   ,0 AS calls1s
   ,0 AS calls1sTime
   ,0 AS calls5s
  FROM (
  SELECT
    D
   ,CampaignID
   ,SUM(CAST(ISNULL(CampaignCallDuration, 0) AS DECIMAL(38, 0))) AS CampaignTime
  FROM #TT
  GROUP BY D, CampaignID
  ) c

  UNION ALL 

  SELECT
    D  
   ,CampaignID
   ,0 As NumRecords
   ,0 AS NumAgents
   ,0 AS CampaignTime
   ,numAttemps
   ,callsSuccess
   ,callsLost
   ,0 AS AgentTime
   ,0 AS TalkingTime
   ,0 AS numTCDVoiceCalls
   ,0 AS calls1s
   ,0 AS calls1sTime
   ,0 AS calls5s
  FROM NumAttemptsCalc

  UNION ALL 

  SELECT
    D  
   ,CampaignID
   ,0 AS NumRecords
   ,0 AS NumAgents
   ,0 AS CampaignTime
   ,0 AS numAttemps
   ,0 AS callsSuccess
   ,0 AS callsLost   
   ,AgentTime
   ,TalkingTime
   ,numTCDVoiceCalls
   ,0 AS calls1s
   ,0 AS calls1sTime
   ,0 AS calls5s
  FROM AgentTimeCalc
) res
LEFT JOIN tCampaign (nolock) ON res.CampaignID = tCampaign.CampaignId
GROUP BY D,CampaignID, tCampaign.CampaignName
ORDER BY D

END
