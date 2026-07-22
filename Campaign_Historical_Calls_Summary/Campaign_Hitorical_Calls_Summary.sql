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

SELECT D, CL.CampaignID, TCD.TalkTime, TCD.HoldTime INTO #TT
FROM #TCL CL WITH (NOLOCK)
LEFT JOIN t_Agent (nolock) a ON CL.AgentId=a.PeripheralNumber  
LEFT JOIN #TCD TCD  
            ON	a.SkillTargetID = TCD.AgentSkillTargetID AND 
				CL.ContactId = CASE WHEN ISNUMERIC(TCD.Variable4) = 1 THEN CAST(TCD.Variable4 AS int) ELSE 0 END AND
				RIGHT((CAST(CL.PhoneNumber AS varchar(32)) COLLATE Cyrillic_General_BIN),10) = RIGHT(TCD.ANI,10) 
				AND DATEADD(SECOND, -2, CL.ClientCallDialingEndTime) <= 
				(SELECT MIN(DateTime) FROM #TCD TCDSTARTS 
				 WHERE TCDSTARTS.RouterCallKey = TCD.RouterCallKey AND TCDSTARTS.RouterCallKeyDay = TCD.RouterCallKeyDay
				)-- 2 seconds adj 'cause might be time difference bw CTI Outbound and ICM times
				AND DATEADD(SECOND, 2, CL.AgentCallDistributedTime)  > (SELECT MIN(DateTime) FROM #TCD TCDSTARTS 
				 WHERE TCDSTARTS.RouterCallKey = TCD.RouterCallKey AND TCDSTARTS.RouterCallKeyDay = TCD.RouterCallKeyDay
				) 
WHERE AgentId IS NOT NULL 


;WITH
ResultSumCalc AS
(
  SELECT D, CampaignID,  PhoneResultId, COUNT(*) AS Total
  FROM #TCL
  WHERE ClientCallDialingStartTime IS NOT NULL
  GROUP BY D, CampaignID, PhoneResultId 
),
NumOfRecordsCalc AS
(SELECT
	CDay AS D
   ,CampaignId AS CampaignID
   ,NRecords AS NumRecords
   	FROM tDRDZ_LoadedRecordsDay
  WHERE CDay >= CONVERT(DATE, @BeginDate)  AND CDay < @EndDate AND CampaignId IN (SELECT id FROM @CL)
),

NumAttemptsCalc AS
(
  SELECT 
	D,
    CampaignID,
	COUNT(*) AS NumAttemps
  FROM #TCL
  WHERE ClientCallDialingStartTime IS NOT NULL
  GROUP BY D, CampaignID
),

TalkingTimeCalc AS
(
  SELECT
	D,
    CampaignID,
	SUM(TalkTime) AS TalkingTime
   ,AwgTalkTime = AVG(TalkTime)+AVG(HoldTime)
   ,COUNT(*) AS TCDVoice 
  FROM #TT
  GROUP BY D, CampaignID
)

SELECT
  D
 ,CampaignID
 ,tCampaign.CampaignName
 ,SUM(NumRecords) AS NumRecords
 ,SUM(NumAttemps) AS NumAttemps
 ,SUM(TalkingTime) AS TalkingTime
 ,SUM(AwgTalkTime) AS AwgTalkTime
 ,SUM(TCDVoice) AS TCDVoice
 ,SUM(rVoice) AS rVoice
 ,SUM(rWrongNumber) AS rWrongNumber
 ,SUM(rBusy) AS rBusy
 ,SUM(rNoAnswer) AS rNoAnswer
 ,SUM(rAgentError) AS rAgentError
 ,SUM(rTelephonyError) AS rTelephonyError
 ,SUM(rClientReject) AS rClientReject 
 ,SUM(rSystemError) AS rSystemError
 ,SUM(rFAX) AS rFAX
 ,pAgent = CASE SUM(NumAttemps) WHEN 0 THEN 0 ELSE SUM(rVoice)*1.0/SUM(NumAttemps) END 
 ,pWrongNumber = CASE SUM(NumAttemps) WHEN 0 THEN 0 ELSE SUM(rWrongNumber)*1.0/SUM(NumAttemps) END
 ,pFAX = CASE SUM(NumAttemps) WHEN 0 THEN 0 ELSE SUM(rFAX)*1.0/SUM(NumAttemps) END

FROM
( SELECT
    D
   ,CampaignID
   ,0 AS NumRecords
   ,0 AS NumAttemps
   ,0 AS TalkingTime
   ,0 AS AwgTalkTime
   ,0 AS TCDVoice
   ,rVoice
   ,rWrongNumber
   ,rBusy
   ,rNoAnswer
   ,rAgentError
   ,rTelephonyError
   ,rClientReject   
   ,rSystemError
   ,rFAX
  FROM (SELECT
    D
   ,CampaignID
   ,rVoice 		= SUM(CASE WHEN PhoneResultId = 0 OR PhoneResultId = 1 THEN Total ELSE 0 END)
   ,rWrongNumber 	= SUM(CASE WHEN PhoneResultId = 304 THEN Total ELSE 0 END)
   ,rBusy 		= SUM(CASE WHEN PhoneResultId = 301 OR PhoneResultId = 308 THEN Total ELSE 0 END)
   ,rNoAnswer 	= SUM(CASE WHEN PhoneResultId = 303 OR PhoneResultId = 310 OR PhoneResultId = 312 THEN Total ELSE 0 END)
   ,rAgentError = SUM(CASE WHEN (PhoneResultId BETWEEN 200 AND 209) OR PhoneResultId = 299 THEN Total ELSE 0 END)
   ,rTelephonyError = SUM(CASE WHEN (PhoneResultId BETWEEN 210 AND 212) OR (PhoneResultId BETWEEN 313 AND 315) OR PhoneResultId = -2 OR PhoneResultId = 305 THEN Total ELSE 0 END)
   ,rClientReject 	= SUM(CASE WHEN PhoneResultId = 300 OR PhoneResultId = 316 OR (PhoneResultId BETWEEN 306 AND 307) THEN Total ELSE 0 END)
   ,rSystemError 	= SUM(CASE WHEN PhoneResultId = -1 OR (PhoneResultId BETWEEN -3 AND -5) OR (PhoneResultId BETWEEN 213 AND 214) OR 
									(PhoneResultId BETWEEN 317 AND 318) OR (PhoneResultId BETWEEN 100 AND 104) OR PhoneResultId = 399 OR
									(PhoneResultId BETWEEN 400 AND 401) OR PhoneResultId = 500 OR PhoneResultId = 600 OR PhoneResultId = 700 THEN Total ELSE 0 END)
   ,rFAX 			= SUM(CASE WHEN (PhoneResultId BETWEEN 2 AND 3) OR PhoneResultId = 309 OR PhoneResultId = 311 THEN Total ELSE 0 END)
  FROM ResultSumCalc
  GROUP BY D, CampaignID
  ) res

  UNION ALL 

  SELECT 
    D
   ,CampaignID
   ,NumRecords
   ,0 AS NumAttemps
   ,0 AS TalkingTime
   ,0 AS AwgTalkTime
   ,0 AS TCDVoice
   ,0 AS rVoice
   ,0 AS rWrongNumber
   ,0 AS rBusy
   ,0 AS rNoAnswer
   ,0 AS rAgentError
   ,0 AS rTelephonyError
   ,0 AS rClientReject   
   ,0 AS rSystemError
   ,0 AS rFAX
  FROM NumOfRecordsCalc

  UNION ALL 

  SELECT
    D  
   ,CampaignID
   ,0 As NumRecords
   ,NumAttemps
   ,0 AS TalkingTime
   ,0 AS AwgTalkTime
   ,0 AS TCDVoice
   ,0 AS rVoice
   ,0 AS rWrongNumber
   ,0 AS rBusy
   ,0 AS rNoAnswer
   ,0 AS rAgentError
   ,0 AS rTelephonyError
   ,0 AS rClientReject   
   ,0 AS rSystemError
   ,0 AS rFAX
  FROM NumAttemptsCalc

  UNION ALL 

  SELECT
    D  
   ,CampaignID
   ,0 AS NumRecords
   ,0 AS NumAttemps
   ,TalkingTime
   ,AwgTalkTime
   ,TCDVoice
   ,0 AS rVoice
   ,0 AS rWrongNumber
   ,0 AS rBusy
   ,0 AS rNoAnswer
   ,0 AS rAgentError
   ,0 AS rTelephonyError
   ,0 AS rClientReject   
   ,0 AS rSystemError
   ,0 AS rFAX
  FROM TalkingTimeCalc
) res
LEFT JOIN tCampaign (nolock) ON res.CampaignID = tCampaign.CampaignId
GROUP BY D,CampaignID, tCampaign.CampaignName
ORDER BY D

END
