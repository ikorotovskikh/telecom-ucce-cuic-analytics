BEGIN
SET ANSI_WARNINGS ON
SET NOCOUNT ON

DECLARE @RCD AS TABLE (id VARCHAR(20), qtime INT, dns VARCHAR(32))
DECLARE @BeginDate VARCHAR(30), @EndDate VARCHAR(30)


SET @BeginDate = :start
SET @EndDate = :end


DECLARE @SGL VARCHAR(MAX) = CONCAT('(', :SGID, ')')		



DECLARE @sgList table (id int)
  INSERT INTO @sgList (id)
  SELECT * FROM STRING_SPLIT(TRANSLATE(REPLACE(@SGL, 'null', ''), '()', '  '), ',')


INSERT INTO @RCD
SELECT DISTINCT CAST(RCD.RouterCallKey AS VARCHAR(10)) + CAST(RCD.RouterCallKeyDay AS VARCHAR(10)), RouterQueueTime, DialedNumberString
FROM t_Route_Call_Detail RCD (nolock), Termination_Call_Detail TCD
WHERE RCD.DateTime >= @BeginDate AND RCD.DateTime < @EndDate AND 
	  TCD.RouterCallKeyDay = RCD.RouterCallKeyDay AND TCD.RouterCallKey = RCD.RouterCallKey AND TCD.SkillGroupSkillTargetID IN (SELECT id FROM @sgList)



SELECT
	SkillId
	,t_Skill_Group.EnterpriseName AS SkillGroup
	,COUNT(ID) AS EnteredToQueue
	,SUM(GotToOperator) AS GotToOperator
	,SUM(GotToOperatorIn30Sec) AS GotToOperatorIn30Sec
	,SUM(TCD.TalkTime) AS TalkTime
	,pHandled = CASE WHEN COUNT(ID) = 0 THEN 0 ELSE SUM(GotToOperator)*1.0/COUNT(ID) END
	,SL30 = CASE WHEN COUNT(ID) = 0 THEN 0 ELSE SUM(GotToOperatorIn30Sec)*1.0/COUNT(ID) END
	,ATT = CASE WHEN SUM(GotToOperator) = 0 THEN 0 ELSE SUM(TCD.TalkTime)*1.0/SUM(GotToOperator) END
	
FROM (
      SELECT
		 TCD_Temp.DateTime
		 ,GotToOperator = CASE WHEN TCD_Temp.AgentSkillTargetID IS NOT NULL AND TimeToAband = 0 THEN 1 ELSE 0 END
		 ,GotToOperatorIn30Sec = CASE WHEN TCD_Temp.AgentSkillTargetID IS NOT NULL AND TimeToAband = 0 AND DATEDIFF(SECOND, DATEADD(HOUR,3,TCD_Temp.StartDateTimeUTC), DATEADD(SECOND,-(TCD_Temp.TalkTime + TCD_Temp.WorkTime),TCD_Temp.DateTime)) < 30 THEN 1 ELSE 0 END
		,TCD_Temp.TalkTime AS TalkTime
		,TCD_Temp.AgentSkillTargetID AS Agent
		,TCD_Temp.SkillGroupSkillTargetID AS SkillId
		,CAST(TCD_Temp.RouterCallKey AS varchar(10))+CAST(TCD_Temp.RouterCallKeyDay AS varchar(10)) AS ID
		,qtime AS QueueTime
		
      FROM Termination_Call_Detail TCD_Temp (nolock), @RCD

      WHERE TCD_Temp.DateTime>= @BeginDate AND TCD_Temp.DateTime<@EndDate AND
            TCD_Temp.SkillGroupSkillTargetID IN (SELECT id FROM @sgList) AND
            ((CAST(TCD_Temp.RouterCallKey AS varchar(10)) + CAST(TCD_Temp.RouterCallKeyDay AS varchar(10)))=id) AND
			dns = TCD_Temp.DigitsDialed

     ) AS TCD
LEFT JOIN t_Skill_Group (nolock) ON SkillId=t_Skill_Group.SkillTargetID
GROUP BY SkillId, t_Skill_Group.EnterpriseName
END