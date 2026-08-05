DECLARE @BeginDate DATETIME = :BeginDT
DECLARE @EndDate DATETIME = :EendDT


DECLARE @ATL VARCHAR(MAX) = CONCAT('(', :Teams, ')')	
DECLARE @AGL VARCHAR(MAX) = CONCAT('(', :Agents, ')')

      
DECLARE @atList table (id int)
  INSERT INTO @atList (id)
  SELECT * FROM STRING_SPLIT(TRANSLATE(REPLACE(@ATL, 'null', ''), '()', '  '), ',')

DECLARE @agList table (id int)
  INSERT INTO @agList (id)
  SELECT * FROM STRING_SPLIT(TRANSLATE(REPLACE(@AGL, 'null', ''), '()', '  '), ',')

DROP TABLE IF EXISTS #AT
DROP TABLE IF EXISTS #TCD


SELECT AgentSkillTargetID, SkillGroupSkillTargetID, DateTime, PeripheralCallType, DigitsDialed, ANI, RingTime, TalkTime, HoldTime, Duration, WorkTime 
INTO #TCD 
FROM t_Termination_Call_Detail TCD WITH (NOLOCK)
LEFT OUTER JOIN t_Agent_Team_Member ATM ON TCD.AgentSkillTargetID = ATM.SkillTargetID
LEFT OUTER JOIN t_Agent_Team TM ON TM.AgentTeamID = ATM.AgentTeamID
WHERE DATEADD(SECOND, -1*Duration, DateTime) >= @BeginDate AND DATEADD(SECOND, -1*Duration, DateTime) <=  @EndDate AND 
	  TM.AgentTeamID IN (SELECT id FROM @atList) AND
     (TCD.AgentSkillTargetID IN (SELECT id FROM @agList) OR (0 IN (SELECT id FROM @agList)))



;WITH Durations AS
(
    SELECT AED.DateTime
      ,AED.SkillTargetID
      ,AED.LoginDateTime
      ,AED.Event
	  ,SUM(ISNULL(TD.Duration, 0)) + AED.Duration AS TD_Duration
      ,AED.ReasonCode
    FROM  t_Agent_Event_Detail AED
    LEFT JOIN (
      SELECT DateTime, SkillTargetID, Event, LoginDateTime, Duration, ReasonCode FROM  t_Agent_Event_Detail
      ) TD ON TD.DateTime < AED.DateTime 
	      AND TD.DateTime > (
								SELECT MAX(DateTime) FROM t_Agent_Event_Detail 
								WHERE DateTime < AED.DateTime AND Event = 3 AND ReasonCode != AED.ReasonCode AND SkillTargetID = AED.SkillTargetID
							)
	      AND TD.SkillTargetID = AED.SkillTargetID 
		  AND TD.LoginDateTime = AED.LoginDateTime AND TD.Event = AED.Event AND TD.ReasonCode = AED.ReasonCode
		  AND (DATEPART(MINUTE, TD.DateTime) % 15) = 0 AND DATEPART(SECOND, TD.DateTime) = 0

	LEFT OUTER JOIN t_Agent_Team_Member ATM ON AED.SkillTargetID = ATM.SkillTargetID
	LEFT OUTER JOIN t_Agent_Team TM ON TM.AgentTeamID = ATM.AgentTeamID
    WHERE AED.DateTime >= @BeginDate AND AED.DateTime < @EndDate AND  TM.AgentTeamID IN (SELECT id FROM @atList) AND
     (AED.SkillTargetID IN (SELECT id FROM @agList) OR (0 IN (SELECT id FROM @agList)))
	 AND (NOT ((DATEPART(MINUTE, AED.DateTime) % 15) = 0 AND DATEPART(SECOND, AED.DateTime) = 0 AND AED.Event = 3)) 
  GROUP BY AED.DateTime, AED.SkillTargetID, AED.LoginDateTime, AED.Event, AED.ReasonCode, AED.Duration
)


SELECT RESULT.* 
INTO #AT
FROM
(

SELECT CASE AED.Event
			   WHEN 1  THEN DATEADD(MS, -DATEPART(MS, AED.DateTime), AED.DateTime)
               WHEN 2  THEN DATEADD(MS, -DATEPART(MS, AED.DateTime), AED.DateTime)
			   WHEN 3  THEN DATEADD(SECOND, -AED.TD_Duration, AED.DateTime)
           END AS DT
      ,AED.SkillTargetID
	  ,EventDesc = 
		  CASE AED.Event
               WHEN 1  THEN 'LOGIN'
               WHEN 2  THEN 'LOGOUT'
               WHEN 3  THEN 'NOT_READY'
           END
	  ,NR_Reason = CASE ISNULL(AED.ReasonCode, 0) WHEN 0 THEN '' ELSE RC.ReasonText END
  FROM Durations AED
  LEFT OUTER JOIN t_Reason_Code RC ON AED.ReasonCode = RC.ReasonCode


  UNION ALL 

  SELECT
    DATEADD(MS, -DATEPART(MS, A.DateTime), A.DateTime) AS DT
   ,A.SkillTargetID
   ,'READY' AS EventDesc
   ,'' AS NR_Reason
  FROM Durations A
  LEFT JOIN Durations DOUBLES ON A.DateTime = DOUBLES.DateTime AND A.DateTime = DOUBLES.DateTime AND 
  (DOUBLES.Event != 3  OR (DOUBLES.Event = 3 AND A.ReasonCode != DOUBLES.ReasonCode)) 
  WHERE NOT ((DATEPART(MINUTE, A.DateTime) % 15) = 0 AND DATEPART(SECOND, A.DateTime) = 0 AND A.Event = 3) AND A.Event = 3
  AND DOUBLES.DateTime IS NULL
 

  ) RESULT


SELECT TM.EnterpriseName AS Team, A.EnterpriseName AS Agent, REPORT.*
FROM(
SELECT 
   AST.DT
  ,AST.SkillTargetID
  ,AST.EventDesc
  ,AST.NR_Reason
  ,CASE AST.EventDesc
			   WHEN 'LOGIN'  THEN 1
               WHEN 'NOT_READY'  THEN 5
               WHEN 'READY'  THEN 6
               WHEN 'LOGOUT'  THEN 9
           END AS EDSort
FROM #AT AST
LEFT JOIN ( -- Filter for excess READY
   SELECT DT, DATEADD(SECOND, 1, DT) AS DTP1S, SkillTargetID, EventDesc FROM #AT WHERE EventDesc != 'READY'
  ) B ON AST.EventDesc = 'READY' AND AST.SkillTargetID = B.SkillTargetID AND B.EventDesc != 'READY' AND (AST.DT = B.DT OR AST.DT = B.DTP1S)
  WHERE B.DT IS NULL

UNION ALL

SELECT 
  DATEADD(MS, -DATEPART(MS, DATEADD(SECOND, -(RingTime+TalkTime+HoldTime+WorkTime), DateTime)), DATEADD(SECOND, -Duration, DateTime))  AS DT
 ,AgentSkillTargetID AS SkillTargetID
 ,CASE PeripheralCallType
			   WHEN 9  THEN 'CALLOUT'
               WHEN 2  THEN 'CALLIN'
               ELSE 'CALLOTHER'
           END AS EventDesc
 ,CASE PeripheralCallType
			   WHEN 9  THEN DigitsDialed
               WHEN 2  THEN ANI
               ELSE CAST(DigitsDialed AS varchar) + '/' + CAST(ANI AS varchar)
           END AS NR_Reason
 ,3 AS EDSort
FROM #TCD

UNION All


SELECT 
  DATEADD(MS, -DATEPART(MS, DATEADD(SECOND, -WorkTime, DateTime)), DATEADD(SECOND, -WorkTime, DateTime))  AS DT
 ,AgentSkillTargetID AS SkillTargetID
 ,'CALLEND' AS EventDesc
 ,CASE PeripheralCallType
			   WHEN 9  THEN DigitsDialed
               WHEN 2  THEN ANI
               ELSE CAST(DigitsDialed AS varchar) + '/' + CAST(ANI AS varchar)
           END AS NR_Reason
 ,4 AS EDSort
FROM #TCD
) REPORT

LEFT JOIN t_Agent (nolock) A ON REPORT.SkillTargetID=A.SkillTargetID
LEFT OUTER JOIN t_Agent_Team_Member ATM ON REPORT.SkillTargetID = ATM.SkillTargetID
LEFT OUTER JOIN t_Agent_Team TM ON TM.AgentTeamID = ATM.AgentTeamID

ORDER BY TM.EnterpriseName, A.EnterpriseName, REPORT.DT, REPORT.EDSort