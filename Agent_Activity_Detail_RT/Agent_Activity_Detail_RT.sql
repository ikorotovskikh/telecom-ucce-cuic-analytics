SET ARITHABORT OFF SET ANSI_WARNINGS OFF SET NOCOUNT ON




DECLARE @ATL VARCHAR(MAX) = CONCAT('(', :Teams, ')')	

DECLARE @AGL VARCHAR(MAX) = CONCAT('(', :Agents, ')')

      
      
DECLARE @atList table (id int)
  INSERT INTO @atList (id)
  SELECT * FROM STRING_SPLIT(TRANSLATE(REPLACE(@ATL, 'null', ''), '()', '  '), ',')

DECLARE @agList table (id int)
  INSERT INTO @agList (id)
  SELECT * FROM STRING_SPLIT(TRANSLATE(REPLACE(@AGL, 'null', ''), '()', '  '), ',')




SELECT 
  ASGRT.DateTime
 ,A.EnterpriseName AS AgentLogin
 ,AgentName = P.FirstName + ' ' + P.LastName
 ,TM.EnterpriseName AS Team
 ,SG.EnterpriseName AS SGName
 ,Event = 
		  CASE ASGRT.AgentState
               WHEN 0  THEN 'LOGGED_OFF'
               WHEN 1  THEN 'LOGGED_ON'
               WHEN 2  THEN 'NOT_READY'
               WHEN 3  THEN 'READY'
               WHEN 4  THEN 'TALKING'
               WHEN 5  THEN 'WORK_NOT_READY'
               WHEN 6  THEN 'WORK_READY'
               WHEN 7  THEN 'BUSY_OTHER'
               WHEN 8  THEN 'RESERVED'
               WHEN 9  THEN 'CALL_INITIATED'
               WHEN 10 THEN 'CALL_HELD'
               WHEN 11 THEN 'CALL_RETRIEVED'
               WHEN 12 THEN 'CALL_TRANSFERRED'
               WHEN 13 THEN 'CALL_CONFERENCED'
               WHEN 14 THEN 'UNKNOWN'
               WHEN 15 THEN 'OFFER_TASK'
               WHEN 16 THEN 'OFFER_APPLICATION_TASK'
               WHEN 17 THEN 'START_TASK'
               WHEN 18 THEN 'START_APPLICATION_TASK'
               WHEN 19 THEN 'PAUSE_TASK'
               WHEN 20 THEN 'RESUME_TASK'
               WHEN 21 THEN 'WRAPUP_TASK'
               WHEN 22 THEN 'END_TASK'
               WHEN 23 THEN 'INTERRUPT_TASK'
               WHEN 24 THEN 'INTERRUPT_DONE'
               WHEN 25 THEN 'INTERRUPT_UNACCEPTED'
               WHEN 26 THEN 'MAKE_AGENT_READY'
               WHEN 27 THEN 'MAKE_AGENT_NOT_READY'
               WHEN 28 THEN 'TASK_INIT_REQ'
               WHEN 29 THEN 'TASK_INIT_IND'
               WHEN 30 THEN 'ROUTER_ASSIGNED_TASK'
               WHEN 31 THEN 'PRE_CALL_TIMEOUT '
          END
 ,NR_Reason = CASE ASGRT.ReasonCode WHEN 0 THEN '' ELSE RC.ReasonText END


FROM t_Agent_Skill_Group_Real_Time ASGRT
 LEFT OUTER JOIN t_Skill_Group SG ON ASGRT.SkillGroupSkillTargetID = SG.SkillTargetID
 LEFT OUTER JOIN t_Reason_Code RC ON ASGRT.ReasonCode = RC.ReasonCode
 LEFT OUTER JOIN t_Agent A ON ASGRT.SkillTargetID = A.SkillTargetID
 LEFT OUTER JOIN t_Person P ON A.PersonID = P.PersonID
 LEFT OUTER JOIN t_Agent_Team_Member ATM ON ASGRT.SkillTargetID = ATM.SkillTargetID
 LEFT OUTER JOIN t_Agent_Team TM ON TM.AgentTeamID = ATM.AgentTeamID
WHERE TM.AgentTeamID IN (SELECT id FROM @atList) AND
     (ASGRT.SkillTargetID IN (SELECT id FROM @agList) OR (0 IN (SELECT id FROM @agList)))
 ORDER BY P.LastName, P.FirstName, ASGRT.DateTime