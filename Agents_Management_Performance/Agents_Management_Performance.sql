BEGIN
-- 5102
-- MIX.SB.OIO_NSK_Team
SET ANSI_WARNINGS ON
SET NOCOUNT ON


DECLARE @BeginDate DATETIME = :BeginDate
DECLARE @EndDate DATETIME = :EndDate

DECLARE @ATL VARCHAR(MAX) = CONCAT('(', :Teams, ')')	


DECLARE @atList table (id int)
  INSERT INTO @atList (id)
  SELECT * FROM STRING_SPLIT(TRANSLATE(REPLACE(@ATL, 'null', ''), '()', '  '), ',')


DROP TABLE IF EXISTS #TCL
DROP TABLE IF EXISTS #TCD
DROP TABLE IF EXISTS #TT


SELECT a.SkillTargetID AS AgentSkillTargetID, * INTO #TCL 
FROM tContactLog tcl WITH (NOLOCK)
LEFT JOIN t_Agent a ON a.PeripheralNumber = tcl.AgentId

WHERE tcl.TimeFrom >= @BeginDate  AND tcl.TimeFrom < @EndDate AND 
 (SELECT AgentTeamID FROM t_Agent_Team_Member WITH (NOLOCK) WHERE SkillTargetID = a.SkillTargetID) IN (SELECT id FROM @atList)

SELECT * INTO #TCD 
FROM t_Termination_Call_Detail tcd WITH (NOLOCK) 
WHERE DATEADD(HOUR, 3, StartDateTimeUTC) >= @BeginDate AND DATEADD(HOUR, 3, StartDateTimeUTC) <= @EndDate AND
	 (SELECT AgentTeamID FROM t_Agent_Team_Member WITH (NOLOCK) WHERE SkillTargetID = tcd.AgentSkillTargetID) IN (SELECT id FROM @atList)


SELECT
TCD.AgentSkillTargetID,
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

NumAttemptsCalc AS
(
  SELECT 
	 AgentSkillTargetID
	,COUNT(*) AS numAttemps
    ,callsSuccess	= SUM(CASE WHEN AgentId IS NOT NULL OR (AgentId IS NULL AND PhoneResultId = 209) THEN 1 ELSE 0 END)
--	,callsLost	= SUM(CASE WHEN AgentId IS NULL AND PhoneResultId = 209 THEN 1 ELSE 0 END)
  FROM #TCL
  WHERE ClientCallDialingStartTime IS NOT NULL
  GROUP BY AgentSkillTargetID
),

NumCallsCalc AS
(
  SELECT
    AgentSkillTargetID
   ,calls1s 		= SUM(CASE WHEN TalkTime >= 1 THEN 1 ELSE 0 END)
   ,calls1sTime		= SUM(CASE WHEN TalkTime >= 1 THEN TalkTime ELSE 0 END)
   ,calls5s 		= SUM(CASE WHEN TalkTime >= 5 THEN 1 ELSE 0 END)
  FROM #TT
  GROUP BY AgentSkillTargetID
),

AgentTimeCalc AS
(
  SELECT
	 AgentSkillTargetID
--	,SUM(CAST(ISNULL(TalkTime, 0) + ISNULL(HoldTime, 0) + ISNULL(WorkTime, 0) AS DECIMAL(38, 0))) AS AgentTime
	,SUM(TalkTime) AS TalkingTime
    ,COUNT(*) AS numTCDVoiceCalls 
  FROM #TT
  GROUP BY AgentSkillTargetID
),

ManualOutCallsCalc AS
(
  SELECT
	 AgentSkillTargetID
	,COUNT(*) AS numManualOutCalls
	,numManualOutCalls1s = SUM(CASE WHEN TalkTime >= 1 THEN 1 ELSE 0 END)
    ,manualOutCalls1sTalkTime		= SUM(CASE WHEN TalkTime >= 1 THEN TalkTime ELSE 0 END)
    ,numManualOutCalls5s 		= SUM(CASE WHEN TalkTime >= 5 THEN 1 ELSE 0 END)
 	,SUM(TalkTime) AS manualOutTalkingTime
  FROM #TCD
  WHERE PeripheralCallType = 9
  GROUP BY AgentSkillTargetID
),

InboundCallsCalc AS
(
  SELECT
	 AgentSkillTargetID
	,COUNT(*) AS numInboundCalls
	,SUM(TalkTime) AS inboundCallsTalkingTime
	,AVG(TalkTime) AS avgInboundCallTalkingTime
  FROM #TCD
  WHERE PeripheralCallType IN (2,3,4,5,6,12) AND (Variable1 != 'Исходящий' OR Variable1 IS NULL) AND TalkTime > 0
  GROUP BY AgentSkillTargetID
)

SELECT
  tm.EnterpriseName AS Team
 ,a.EnterpriseName AS Agent
 ,AgentSkillTargetID
 ,SUM(numTCDVoiceCalls) AS numTCDVoiceCalls
 ,SUM(callsSuccess) AS callsSuccess
 ,SUM(calls1s) AS calls1s
 ,SUM(calls1sTime) AS calls1sTime
 ,SUM(calls5s) AS calls5s
 ,SUM(TalkingTime) AS TalkingTime
 ,awgTalkTime = CASE SUM(calls1s) WHEN 0 THEN 0 ELSE SUM(TalkingTime)*1.0/SUM(calls1s) END
 ,SUM(numManualOutCalls) AS numManualOutCalls
 ,SUM(numManualOutCalls1s) AS numManualOutCalls1s 
 ,SUM(manualOutCalls1sTalkTime) AS manualOutCalls1sTalkTime 
 ,SUM(numManualOutCalls5s) AS numManualOutCalls5s
 ,SUM(manualOutTalkingTime) AS manualOutTalkingTime
 ,awgManualOutCallsTalkTime = CASE SUM(numManualOutCalls1s) WHEN 0 THEN 0 ELSE SUM(manualOutTalkingTime)*1.0/SUM(numManualOutCalls1s) END
 ,totalCalls1s = SUM(calls1s) + SUM(numManualOutCalls1s)
 ,totalCalls5s = SUM(calls5s) + SUM(numManualOutCalls5s)
 ,totalTalkingTime = SUM(TalkingTime) + SUM(manualOutTalkingTime)
 ,awgTotalTalkTime = CASE (SUM(calls1s) + SUM(numManualOutCalls1s)) WHEN 0 THEN 0 ELSE (SUM(TalkingTime)+SUM(manualOutTalkingTime))*1.0/(SUM(calls1s) + SUM(numManualOutCalls1s)) END
 ,SUM(numInboundCalls) AS numInboundCalls
 ,SUM(inboundCallsTalkingTime) AS inboundCallsTalkingTime
 ,SUM(avgInboundCallTalkingTime) AS avgInboundCallTalkingTime

FROM
( SELECT
    AgentSkillTargetID
   ,0 AS numAttemps
   ,0 AS callsSuccess
--   ,0 AS callsLost   
--   ,0 AS AgentTime
   ,0 AS TalkingTime
   ,0 AS numTCDVoiceCalls
   ,calls1s
   ,calls1sTime
   ,calls5s
   ,0 AS numManualOutCalls
   ,0 AS numManualOutCalls1s
   ,0 AS manualOutCalls1sTalkTime
   ,0 AS numManualOutCalls5s
   ,0 AS manualOutTalkingTime
   ,0 AS numInboundCalls
   ,0 AS inboundCallsTalkingTime
   ,0 AS avgInboundCallTalkingTime

  FROM NumCallsCalc

  UNION ALL 

  SELECT
    AgentSkillTargetID
   ,numAttemps
   ,callsSuccess
--   ,callsLost
--   ,0 AS AgentTime
   ,0 AS TalkingTime
   ,0 AS numTCDVoiceCalls
   ,0 AS calls1s
   ,0 AS calls1sTime
   ,0 AS calls5s
   ,0 AS numManualOutCalls
   ,0 AS numManualOutCalls1s
   ,0 AS manualOutCalls1sTalkTime
   ,0 AS numManualOutCalls5s
   ,0 AS manualOutTalkingTime
   ,0 AS numInboundCalls
   ,0 AS inboundCallsTalkingTime
   ,0 AS avgInboundCallTalkingTime

  FROM NumAttemptsCalc

  UNION ALL 

  SELECT
    AgentSkillTargetID
   ,0 AS numAttemps
   ,0 AS callsSuccess
 --  ,0 AS callsLost   
 --  ,AgentTime
   ,TalkingTime
   ,numTCDVoiceCalls
   ,0 AS calls1s
   ,0 AS calls1sTime
   ,0 AS calls5s
   ,0 AS numManualOutCalls
   ,0 AS numManualOutCalls1s
   ,0 AS manualOutCalls1sTalkTime
   ,0 AS numManualOutCalls5s
   ,0 AS manualOutTalkingTime
   ,0 AS numInboundCalls
   ,0 AS inboundCallsTalkingTime
   ,0 AS avgInboundCallTalkingTime

  FROM AgentTimeCalc
  
  UNION ALL 

  SELECT
    AgentSkillTargetID
   ,0 AS numAttemps
   ,0 AS callsSuccess
 --  ,0 AS callsLost   
 --  ,AgentTime
   ,0 AS TalkingTime
   ,0 AS numTCDVoiceCalls
   ,0 AS calls1s
   ,0 AS calls1sTime
   ,0 AS calls5s
   ,numManualOutCalls
   ,numManualOutCalls1s
   ,manualOutCalls1sTalkTime
   ,numManualOutCalls5s
   ,manualOutTalkingTime
   ,0 AS numInboundCalls
   ,0 AS inboundCallsTalkingTime
   ,0 AS avgInboundCallTalkingTime
  FROM ManualOutCallsCalc
  
  UNION ALL 

  SELECT
    AgentSkillTargetID
   ,0 AS numAttemps
   ,0 AS callsSuccess
 --  ,0 AS callsLost   
 --  ,AgentTime
   ,0 AS TalkingTime
   ,0 AS numTCDVoiceCalls
   ,0 AS calls1s
   ,0 AS calls1sTime
   ,0 AS calls5s
   ,0 AS numManualOutCalls
   ,0 AS numManualOutCalls1s
   ,0 AS manualOutCalls1sTalkTime
   ,0 AS numManualOutCalls5s
   ,0 AS manualOutTalkingTime
   ,numInboundCalls
   ,inboundCallsTalkingTime
   ,avgInboundCallTalkingTime
  FROM InboundCallsCalc
) res
LEFT JOIN t_Agent (nolock) a ON res.AgentSkillTargetID=a.SkillTargetID
LEFT OUTER JOIN t_Agent_Team_Member atm ON a.SkillTargetID = atm.SkillTargetID
LEFT OUTER JOIN t_Agent_Team tm ON tm.AgentTeamID = atm.AgentTeamID
WHERE AgentSkillTargetID IS NOT NULL
  
GROUP BY tm.EnterpriseName, AgentSkillTargetID, a.EnterpriseName
ORDER BY tm.EnterpriseName, a.EnterpriseName

END