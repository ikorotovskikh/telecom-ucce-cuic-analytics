BEGIN
SET ANSI_WARNINGS ON
SET NOCOUNT ON

DECLARE @BeginDate DATETIME = :BeginDate
DECLARE @EndDate DATETIME = :EndDate


DECLARE @ATL VARCHAR(MAX) = CONCAT('(', :Teams, ')')	


DECLARE @atList table (id int)
  INSERT INTO @atList (id)
  SELECT * FROM STRING_SPLIT(TRANSLATE(REPLACE(@ATL, 'null', ''), '()', '  '), ',')



DROP TABLE IF EXISTS #TCD

SELECT *
INTO #TCD 
FROM t_Termination_Call_Detail tcd WITH (NOLOCK) 
WHERE DateTime >= @BeginDate AND DATEADD(MINUTE,30,DateTime) <= @EndDate AND PeripheralCallType = 9 AND
	 (SELECT AgentTeamID FROM t_Agent_Team_Member WITH (NOLOCK) WHERE SkillTargetID = tcd.AgentSkillTargetID) IN (SELECT id FROM @atList)
	 




SELECT

  'Ручной' AS CallType
  ,tm.EnterpriseName AS Team
  ,sg.EnterpriseName AS SkillGroup
  ,a.EnterpriseName AS Agent
  ,a.SkillTargetID AS AgentID
  ,PhoneNumberPrefix = CASE WHEN LEN(TCD.DigitsDialed) > 10 THEN LEFT(TCD.DigitsDialed,LEN(TCD.DigitsDialed)-10) ELSE '' END   ,RIGHT(TCD.DigitsDialed,10) AS PhoneNumber  
  ,TCD.CallReferenceID AS CallID
  ,DATEADD(SECOND, -1*TCD.Duration, TCD.DateTime) AS OutCallBegin
  ,DATEADD(SECOND, TCD.DelayTime, DATEADD(SECOND, -1*TCD.Duration, TCD.DateTime)) AS OutCallConnect 
  ,DATEADD(SECOND, -1*TCD.WorkTime, TCD.DateTime) AS OutCallDisconnect 
  ,TCD.Duration - TCD.WorkTime AS Duration
  ,TCD.DelayTime AS DialingTime
  ,TCD.TalkTime
  ,TCD.HoldTime
  ,TCD.WorkTime
 
 
  FROM #TCD AS TCD
  LEFT JOIN t_Agent (nolock) a ON TCD.AgentSkillTargetID=a.SkillTargetID
  LEFT JOIN t_Skill_Group (nolock) sg ON TCD.SkillGroupSkillTargetID =sg.SkillTargetID   
  LEFT OUTER JOIN t_Agent_Team_Member atm ON a.SkillTargetID = atm.SkillTargetID
  LEFT OUTER JOIN t_Agent_Team tm ON tm.AgentTeamID = atm.AgentTeamID
  
  ORDER BY TCD.DateTime, a.EnterpriseName ASC
END