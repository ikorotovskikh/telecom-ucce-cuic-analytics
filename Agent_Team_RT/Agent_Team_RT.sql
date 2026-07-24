BEGIN
SET ANSI_WARNINGS ON
SET NOCOUNT ON


DECLARE @ATL VARCHAR(MAX) = CONCAT('(', :Teams, ')')	




DECLARE @BeginDate DATETIME = CAST(CAST(GETDATE() AS DATE) AS DATETIME)
DECLARE @EndDate DATETIME = GETDATE()


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
),

LogOnTime AS (
SELECT 
 SkillTargetID  AS AgentSkillTargetID
,LoggedOnTime =sum(ISNULL(AI.LoggedOnTime,0))  
,AvailTime = SUM(ISNULL(AI.AvailTime, 0))
,NotReadyTime = SUM(ISNULL(AI.NotReadyTime, 0))
,BusyTime = sum(ISNULL(AI.LoggedOnTime,0)) - SUM(ISNULL(AI.AvailTime, 0)) - SUM(ISNULL(AI.NotReadyTime, 0))
,TalkOtherTime = SUM(ISNULL(AI.TalkOtherTime, 0))
FROM Agent_Interval AI
WHERE AI.DateTime >= @BeginDate AND AI.DateTime < @EndDate AND
	 (SELECT AgentTeamID FROM t_Agent_Team_Member WITH (NOLOCK) WHERE SkillTargetID = AI.SkillTargetID) IN (SELECT id FROM @atList)
GROUP BY AI.SkillTargetID
)

,ReasonsTime AS (
SELECT 
SkillTargetID AS AgentSkillTargetID,
SUM(case when ReasonCode in (10) then Duration else 0 end) as pBreak,			
SUM(case when ReasonCode in (20) then Duration else 0 end) as pLaunch,			
SUM(case when ReasonCode in (30) then Duration else 0 end) as pBossCall,		
SUM(case when ReasonCode in (40) then Duration else 0 end) as pBossTask,	
SUM(case when ReasonCode in (50) then Duration else 0 end) as pNastavnik,	
SUM(case when ReasonCode in (60) then Duration else 0 end) as pTechIssue,	
SUM(case when ReasonCode in (70) then Duration else 0 end) as pDiscret,
SUM(case when ReasonCode in (80) then Duration else 0 end) as pOut,
AVG(case when ReasonCode in (80) then Duration else 0 end) as pOutAVG,
SUM(case when ReasonCode in (90) then Duration else 0 end) as pLearning,		
SUM(case when ReasonCode in (100) then Duration else 0 end) as	pCouching,	
SUM(case when ReasonCode in (110) then Duration else 0 end) as	pFeedback,		
SUM(case when ReasonCode in (120) then Duration else 0 end) as	pWrap,		
SUM(case when ReasonCode in (130) then Duration else 0 end) as	pEndShift,			
SUM(case when ReasonCode in (140) then Duration else 0 end) as	pMeeting,	
SUM(case when ReasonCode = 0 and Event = 3 then Duration else 0 end) as pFirstLogin,
SUM(case when ReasonCode = 999 then Duration else 0 end) as pSupervisor,
SUM(case when ReasonCode = 20001 then Duration else 0 end) as pForceLogout,
SUM(case when ReasonCode = 20003 then Duration else 0 end) as pAgentLogout,
SUM(case when ReasonCode = 32762 then Duration else 0 end) as pAGT_OFFHOOK,
SUM(case when ReasonCode = 32767 then Duration else 0 end) as pRNA,
SUM(case when ReasonCode = 50002 then Duration else 0 end) as pConnectionFailure,
SUM(case when ReasonCode = 50005 then Duration else 0 end) as pNonACDCall,
SUM(case when ReasonCode = 50006 then Duration else 0 end) as pCallinAvail,
SUM(case when ReasonCode = 50010 then Duration else 0 end) as pOverlap,
SUM(case when ReasonCode = 65534 then Duration else 0 end) as pSysReset,
SUM(case when ReasonCode = 65535 then Duration else 0 end) as pSysReInit
--SUM(Duration) as Duration
FROM Agent_Event_Detail AED
WHERE AED.DateTime >= @BeginDate AND AED.DateTime < @EndDate AND
	 (SELECT AgentTeamID FROM t_Agent_Team_Member WITH (NOLOCK) WHERE SkillTargetID = AED.SkillTargetID) IN (SELECT id FROM @atList)
GROUP BY AED.SkillTargetID
)

,ASGStat AS (
SELECT 
SkillTargetID AS AgentSkillTargetID,
AvailTime = SUM(ISNULL(asgi.AvailTime,0)),
WrapTime = SUM(ISNULL(asgi.WorkNotReadyTime + asgi.WorkReadyTime,0))


FROM Agent_Skill_Group_Interval asgi
WHERE asgi.DateTime >= @BeginDate AND asgi.DateTime < @EndDate AND
	 (SELECT AgentTeamID FROM t_Agent_Team_Member WITH (NOLOCK) WHERE SkillTargetID = asgi.SkillTargetID) IN (SELECT id FROM @atList)
GROUP BY asgi.SkillTargetID
)



SELECT
  tm.EnterpriseName AS Team
 ,a.EnterpriseName AS Agent
 ,AgentSkillTargetID
 ,SUM(callsSuccess) AS callsSuccess
 ,SUM(calls1s) AS calls1s
 ,SUM(calls1sTime) AS calls1sTime
 ,awgTalkTime1s = CASE SUM(calls1s) WHEN 0 THEN 0 ELSE SUM(calls1sTime)*1.0/SUM(calls1s) END
 ,SUM(numManualOutCalls) AS numManualOutCalls
 ,SUM(numManualOutCalls1s) AS numManualOutCalls1s 
 ,SUM(manualOutCalls1sTalkTime) AS manualOutCalls1sTalkTime 
 ,SUM(manualOutTalkingTime) AS manualOutTalkingTime
 ,awgManualOutCallsTalkTime = CASE SUM(numManualOutCalls1s) WHEN 0 THEN 0 ELSE SUM(manualOutCalls1sTalkTime)*1.0/SUM(numManualOutCalls1s) END
 ,SUM(numInboundCalls) AS numInboundCalls
 ,SUM(inboundCallsTalkingTime) AS inboundCallsTalkingTime
 ,SUM(avgInboundCallTalkingTime) AS avgInboundCallTalkingTime
 ,SUM(pBreak) AS tBreak
 ,SUM(pLaunch) AS tLaunch 
 ,SUM(pNastavnik) AS tNastavnik
 ,SUM(pWrap) AS tWrap  
 ,SUM(pOut) AS tOut 
 ,SUM(LoggedOnTime) AS LoggedOnTime  
 ,SUM(NotReadyTime) AS NotReadyTime 
 ,pWrap = CASE SUM(LoggedOnTime) WHEN 0 THEN 0 ELSE SUM(pWrap)*1.0/SUM(LoggedOnTime) END 
 ,pOut  = CASE SUM(LoggedOnTime) WHEN 0 THEN 0 ELSE SUM(pOut)*1.0/SUM(LoggedOnTime) END 
 ,pNotReady  = CASE SUM(LoggedOnTime) WHEN 0 THEN 0 ELSE SUM(NotReadyTime)*1.0/SUM(LoggedOnTime) END
 
FROM
( SELECT
    AgentSkillTargetID
   ,0 AS numAttemps
   ,0 AS callsSuccess
    ,calls1s
   ,calls1sTime
   ,0 AS numManualOutCalls
   ,0 AS numManualOutCalls1s
   ,0 AS manualOutCalls1sTalkTime
   ,0 AS manualOutTalkingTime
   ,0 AS numInboundCalls
   ,0 AS inboundCallsTalkingTime
   ,0 AS avgInboundCallTalkingTime
   ,0 AS pBreak
   ,0 AS pLaunch
   ,0 AS pNastavnik
   ,0 AS pWrap
   ,0 AS pOut
   ,0 AS LoggedOnTime
   ,0 AS NotReadyTime

  FROM NumCallsCalc

  UNION ALL 

  SELECT
    AgentSkillTargetID
   ,numAttemps
   ,callsSuccess
   ,0 AS calls1s
   ,0 AS calls1sTime
   ,0 AS numManualOutCalls
   ,0 AS numManualOutCalls1s
   ,0 AS manualOutCalls1sTalkTime
   ,0 AS manualOutTalkingTime
   ,0 AS numInboundCalls
   ,0 AS inboundCallsTalkingTime
   ,0 AS avgInboundCallTalkingTime
   ,0 AS pBreak
   ,0 AS pLaunch
   ,0 AS pNastavnik
   ,0 AS pWrap
   ,0 AS pOut
   ,0 AS LoggedOnTime
   ,0 AS NotReadyTime

  FROM NumAttemptsCalc

  UNION ALL 


  SELECT
    AgentSkillTargetID
   ,0 AS numAttemps
   ,0 AS callsSuccess
   ,0 AS calls1s
   ,0 AS calls1sTime
   ,numManualOutCalls
   ,numManualOutCalls1s
   ,manualOutCalls1sTalkTime
   ,manualOutTalkingTime
   ,0 AS numInboundCalls
   ,0 AS inboundCallsTalkingTime
   ,0 AS avgInboundCallTalkingTime
   ,0 AS pBreak
   ,0 AS pLaunch
   ,0 AS pNastavnik
   ,0 AS pWrap
   ,0 AS pOut
   ,0 AS LoggedOnTime
   ,0 AS NotReadyTime
   
  FROM ManualOutCallsCalc
  
  UNION ALL 

  SELECT
    AgentSkillTargetID
   ,0 AS numAttemps
   ,0 AS callsSuccess
   ,0 AS calls1s
   ,0 AS calls1sTime
   ,0 AS numManualOutCalls
   ,0 AS numManualOutCalls1s
   ,0 AS manualOutCalls1sTalkTime
   ,0 AS manualOutTalkingTime
   ,numInboundCalls
   ,inboundCallsTalkingTime
   ,avgInboundCallTalkingTime
   ,0 AS pBreak
   ,0 AS pLaunch
   ,0 AS pNastavnik
   ,0 AS pWrap
   ,0 AS pOut
   ,0 AS LoggedOnTime
   ,0 AS NotReadyTime
   
  FROM InboundCallsCalc
  
  UNION ALL 

  SELECT
    AgentSkillTargetID
   ,0 AS numAttemps
   ,0 AS callsSuccess
   ,0 AS calls1s
   ,0 AS calls1sTime
   ,0 AS numManualOutCalls
   ,0 AS numManualOutCalls1s
   ,0 AS manualOutCalls1sTalkTime
   ,0 AS manualOutTalkingTime
   ,0 AS numInboundCalls
   ,0 AS inboundCallsTalkingTime
   ,0 AS avgInboundCallTalkingTime
   ,pBreak
   ,pLaunch
   ,pNastavnik
   ,pWrap
   ,pOut
   ,0 AS LoggedOnTime
   ,0 AS NotReadyTime
   
  FROM ReasonsTime
  
  UNION ALL 

  SELECT
    AgentSkillTargetID
   ,0 AS numAttemps
   ,0 AS callsSuccess
   ,0 AS calls1s
   ,0 AS calls1sTime
   ,0 AS numManualOutCalls
   ,0 AS numManualOutCalls1s
   ,0 AS manualOutCalls1sTalkTime
   ,0 AS manualOutTalkingTime
   ,0 AS numInboundCalls
   ,0 AS inboundCallsTalkingTime
   ,0 AS avgInboundCallTalkingTime
   ,0 AS pBreak
   ,0 AS pLaunch
   ,0 AS pNastavnik
   ,0 AS pWrap
   ,0 AS pOut
   ,LoggedOnTime
   ,NotReadyTime

  FROM LogOnTime


) res
LEFT JOIN t_Agent (nolock) a ON res.AgentSkillTargetID=a.SkillTargetID
LEFT OUTER JOIN t_Agent_Team_Member atm ON a.SkillTargetID = atm.SkillTargetID
LEFT OUTER JOIN t_Agent_Team tm ON tm.AgentTeamID = atm.AgentTeamID
WHERE AgentSkillTargetID IS NOT NULL
  
GROUP BY tm.EnterpriseName, AgentSkillTargetID, a.EnterpriseName
ORDER BY tm.EnterpriseName, a.EnterpriseName

END
