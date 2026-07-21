BEGIN
SET ANSI_WARNINGS ON
SET NOCOUNT ON


DECLARE @BeginDate VARCHAR(30), @EndDate VARCHAR(30)


SET @BeginDate = :start
SET @EndDate = :end


DECLARE @DNL VARCHAR(MAX) = CONCAT('(', :DNID, ')')		
DECLARE @ATL VARCHAR(MAX) = CONCAT('(', :Teams, ')')	



 
DECLARE @dnList table (id bigint)
  INSERT INTO @dnList (id)
  SELECT * FROM STRING_SPLIT(TRANSLATE(REPLACE(@DNL, 'null', ''), '()', '  '), ',')

DECLARE @atList table (id int)
  INSERT INTO @atList (id)
  SELECT * FROM STRING_SPLIT(TRANSLATE(REPLACE(@ATL, 'null', ''), '()', '  '), ',')

DROP TABLE IF EXISTS #TCD
DROP TABLE IF EXISTS #RCD
 
SELECT 
   DateTime
  ,RingTime
  ,Duration
  ,TalkTime
  ,HoldTime
  ,DelayTime
  ,WorkTime
  ,CASE WHEN DigitsDialed IS NULL THEN DNIS ELSE DigitsDialed END AS DN
  ,DNIS
  ,ANI
  ,DigitsDialed
  ,AgentSkillTargetID AS AgentID
  ,InstrumentPortNumber AS AgentNumber
  ,SkillGroupSkillTargetID AS SkillID
  ,CallTypeID
  ,RouterCallKeyDay
  ,RouterCallKey
  ,CAST(RouterCallKey AS varchar(10))+CAST(RouterCallKeyDay AS varchar(10)) AS CallID
INTO #TCD 
FROM t_Termination_Call_Detail tcd WITH (NOLOCK) 
WHERE RouterCallKeyDay != 0 AND RouterCallKeyDay != 0 AND -- Outbound Calls Filter
DATEADD(SECOND, -1*Duration, DateTime) >= @BeginDate AND DATEADD(SECOND, -1*Duration, DateTime) < @EndDate
      AND (InstrumentPortNumber IS NOT NULL OR DNIS IN (SELECT id FROM @dnList) OR DigitsDialed IN (SELECT id FROM @dnList))

  
SELECT DateTime, RouterCallKey, RouterCallKeyDay, Label, RouterQueueTime, DialedNumberString, CallTypeID  
INTO #RCD 
FROM t_Route_Call_Detail RCD WITH (NOLOCK)
WHERE DateTime >= @BeginDate AND DateTime < @EndDate


;WITH

CallsToDNs AS
(SELECT
   DN
  ,MIN(DATEADD(SECOND, -1*Duration, DateTime)) AS StartCall
  ,MAX(DateTime) AS EndCall
  ,ANI
  ,MIN(CallTypeID) AS CallTypeID
  ,RouterCallKeyDay
  ,RouterCallKey
FROM #TCD
WHERE DN IN (SELECT id FROM @dnList)
GROUP BY DN, ANI, RouterCallKeyDay, RouterCallKey
)

SELECT	DNTCD.DN
        ,dirn.Direction
        --DATEDIFF(SECOND, QT.DateTime,  DATEADD(SECOND,-TCD.Duration,TCD.DateTime)) AS DiffStart
		--,DATEDIFF(SECOND, QT.DateTime,  TCD.DateTime) AS DiffEnd
		,TM.EnterpriseName AS Team
	    ,t_Skill_Group.EnterpriseName AS SkillGroup
	    ,t_Agent.EnterpriseName AS Agent
	    ,DNTCD.StartCall
		,DATEADD(SECOND,-(TCD.Duration - TCD.RingTime - TCD.DelayTime),TCD.DateTime) AS StartOperatorRT
		,DATEADD(SECOND,-(TCD.TalkTime + TCD.HoldTime + TCD.WorkTime),TCD.DateTime) AS StartOperator
		,EndCall = CASE WHEN TCD.AgentID IS NULL THEN DNTCD.EndCall ELSE DATEADD(SECOND,-TCD.WorkTime,TCD.DateTime) END 
		,DATEPART(HOUR, DNTCD.StartCall) AS StartHour
		--,TCD.DateTime
		,DNTCD.ANI 
		,TCD.AgentNumber
		,Duration = CASE WHEN TCD.AgentID IS NULL THEN DATEDIFF(SECOND, DNTCD.StartCall, DNTCD.EndCall) ELSE DATEDIFF(SECOND, DNTCD.StartCall, TCD.DateTime) END 
		,TCD.TalkTime AS TalkTime
		,TCD.DigitsDialed AS DigitsDialed
		,TCD.AgentID
		,TCD.SkillID
		,CallTypeID = COALESCE(TCD.CallTypeID, QT.CallTypeID, DNTCD.CallTypeID)
		,CAST(DNTCD.RouterCallKey AS varchar(10))+CAST(DNTCD.RouterCallKeyDay AS varchar(10)) AS ID
		,DNTCD.RouterCallKey 
		,DNTCD.RouterCallKeyDay
		,TCD.RingTime
		,TCD.HoldTime
		,TCD.WorkTime
		,QueueTime = CASE WHEN TCD.AgentID IS NULL 
						  THEN DATEDIFF(SECOND, DNTCD.StartCall, DNTCD.EndCall) 
						  ELSE CASE WHEN QT.RouterQueueTime IS NULL OR QT.RouterQueueTime = 0 
						            THEN DATEDIFF(SECOND, DNTCD.StartCall, DATEADD(SECOND,-(TCD.TalkTime + TCD.HoldTime + TCD.WorkTime), TCD.DateTime)) 
									ELSE QT.RouterQueueTime 
									END
						  END
		,t_Call_Type.EnterpriseName AS CTName
		,xferSG.EnterpriseName AS xferSG
FROM CallsToDNs DNTCD
LEFT JOIN #TCD TCD ON  DNTCD.RouterCallKey = TCD.RouterCallKey AND DNTCD.RouterCallKeyDay = TCD.RouterCallKeyDay AND TCD.AgentID IS NOT NULL
LEFT JOIN t_Agent (NOLOCK) ON TCD.AgentID = t_Agent.SkillTargetID 
LEFT JOIN t_Skill_Group (NOLOCK) ON TCD.SkillID = t_Skill_Group.SkillTargetID
LEFT JOIN #RCD QT ON QT.RouterCallKey = DNTCD.RouterCallKey AND QT.RouterCallKeyDay = DNTCD.RouterCallKeyDay 
					 AND QT.Label = CAST(TCD.AgentNumber AS varchar(32))
					 -- exclude possible doubles, end of routing should be within the TCD call time
					 AND QT.DateTime >= CASE WHEN TCD.AgentID IS NULL THEN DATEADD(SECOND, -1, DNTCD.StartCall) ELSE DATEADD(SECOND,-(TCD.RingTime + TCD.TalkTime + TCD.HoldTime + TCD.WorkTime + 1),TCD.DateTime) END
					 AND QT.DateTime < CASE WHEN TCD.AgentID IS NULL THEN DNTCD.EndCall ELSE TCD.DateTime END
					 
LEFT JOIN t_Call_Type (NOLOCK) ON COALESCE(TCD.CallTypeID, QT.CallTypeID, DNTCD.CallTypeID) = t_Call_Type.CallTypeID
LEFT JOIN #TCD xfer ON xfer.RouterCallKey = DNTCD.RouterCallKey AND xfer.RouterCallKeyDay = DNTCD.RouterCallKeyDay AND 
										  xfer.AgentID IS NOT NULL AND TCD.DateTime < xfer.DateTime AND 
										  xfer.DateTime = (SELECT MIN(DateTime) FROM #TCD 
															WHERE	xfer.RouterCallKey = RouterCallKey AND
																	xfer.RouterCallKeyDay = RouterCallKeyDay AND
																	AgentID IS NOT NULL AND 
																	TCD.DateTime < DateTime
														  )
														  
LEFT JOIN t_Skill_Group xferSG (nolock) ON xferSG.SkillTargetID = xfer.SkillID
LEFT JOIN tDRDZ_DNs dirn (nolock) ON DNTCD.DN = dirn.DN
LEFT OUTER JOIN t_Agent_Team_Member ATM ON TCD.AgentID = ATM.SkillTargetID
LEFT OUTER JOIN t_Agent_Team TM ON TM.AgentTeamID = ATM.AgentTeamID
WHERE (TCD.AgentID IS NULL OR (TM.AgentTeamID IN (SELECT id FROM @atList) OR (0 IN (SELECT id FROM @atList))))
      AND COALESCE(TCD.CallTypeID, QT.CallTypeID, DNTCD.CallTypeID) != -1 -- Exclude internal call legs
ORDER BY DNTCD.StartCall ASC
END
