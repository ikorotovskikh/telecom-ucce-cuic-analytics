SET ARITHABORT OFF SET ANSI_WARNINGS OFF SET NOCOUNT ON

DECLARE @start DateTime, @end DateTime
SET @start = :BeginDate
SET @end = :EndDate


DECLARE @ATL VARCHAR(MAX) = CONCAT('(', :Teams, ')')

DECLARE @AGL VARCHAR(MAX) = CONCAT('(', :Agents, ')')
      
      
DECLARE @atList table (id int)
  INSERT INTO @atList (id)
  SELECT * FROM STRING_SPLIT(TRANSLATE(REPLACE(@ATL, 'null', ''), '()', '  '), ',')
  

DECLARE @agList table (id int)
  INSERT INTO @agList (id)
  SELECT * FROM STRING_SPLIT(TRANSLATE(REPLACE(@AGL, 'null', ''), '()', '  '), ',')

;WITH 

AgNames AS(
SELECT DISTINCT 
 AED.SkillTargetID AS AID
,A.EnterpriseName AS AgentLogin
,(P.FirstName + ' ' + P.LastName) AS FullName
FROM Agent_Event_Detail AED, Agent A, Person P 
WHERE AED.DateTime > @start AND AED.DateTime < @end AND 
	  AED.SkillTargetID = A.SkillTargetID AND P.PersonID = A.PersonID AND
	 (SELECT AgentTeamID FROM t_Agent_Team_Member WITH (NOLOCK) 
	  WHERE SkillTargetID = AED.SkillTargetID) IN (SELECT id FROM @atList) AND
	  (AED.SkillTargetID IN (SELECT id FROM @agList) OR (0 IN (SELECT id FROM @agList)))
)


,LogOnTime AS (
SELECT AID
--,(P.FirstName + '' + P.LastName) as FullName
,LoggedOnTime =sum(ISNULL(AI.LoggedOnTime,0))  
,AvailTime = SUM(ISNULL(AI.AvailTime, 0))
,NotReadyTime = SUM(ISNULL(AI.NotReadyTime, 0))
,BusyTime = sum(ISNULL(AI.LoggedOnTime,0)) - SUM(ISNULL(AI.AvailTime, 0)) - SUM(ISNULL(AI.NotReadyTime, 0))
,TalkOtherTime = SUM(ISNULL(AI.TalkOtherTime, 0))
FROM AgNames, Agent_Interval AI
WHERE AI.SkillTargetID = AID AND AI.DateTime > @start and AI.DateTime < @end
GROUP BY AID, AI.SkillTargetID
)

,ReasonsTime AS (
SELECT 
AID, 
SkillTargetID,
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
FROM AgNames, Agent_Event_Detail AED
WHERE AED.SkillTargetID = AID AND AED.DateTime > @start AND AED.DateTime < @end
GROUP BY AID, AED.SkillTargetID
)

,ASGStat AS (
SELECT 
AID,
CallsHandled = SUM(ISNULL(asgi.CallsHandled,0)),
AgentOutCalls = SUM(ISNULL(asgi.AgentOutCalls,0)),
AvailTime = SUM(ISNULL(asgi.AvailTime,0)),
HoldTime = SUM(ISNULL(asgi.HoldTime,0)),
ReservedTime = SUM(ISNULL(asgi.ReservedStateTime,0)),
WrapTime = SUM(ISNULL(asgi.WorkNotReadyTime + asgi.WorkReadyTime,0)),
TalkTime = SUM(ISNULL(asgi.TalkInTime,0)) + SUM(ISNULL(asgi.TalkOtherTime,0)) +	SUM(ISNULL(asgi.TalkReserveTime,0)),
TalkOutTime = 	SUM(ISNULL(asgi.TalkOutTime,0)) +
				SUM(ISNULL(asgi.TalkAutoOutTime,0)) +
				SUM(ISNULL(asgi.TalkPreviewTime,0)),
HandledCallsTime = SUM(ISNULL(asgi.HandledCallsTime,0)),

ATT	=   (CASE 					(SUM(ISNULL(asgi.CallsHandled,0)) + SUM(ISNULL(asgi.AgentOutCalls,0)))
							
		WHEN 0 THEN 0
		ELSE 				(	SUM(ISNULL(asgi.TalkInTime,0)) + 
								SUM(ISNULL(asgi.TalkOtherTime,0)) + 
								SUM(ISNULL(asgi.TalkReserveTime,0))+
								SUM(ISNULL(asgi.TalkOutTime,0)) +
								SUM(ISNULL(asgi.TalkAutoOutTime,0)) +
								SUM(ISNULL(asgi.TalkPreviewTime,0))
								
							)
							/(SUM(ISNULL(asgi.CallsHandled,0)) + SUM(ISNULL(asgi.AgentOutCalls,0)))
		END),
ATTOut	=   (CASE 				SUM(ISNULL(asgi.AgentOutCalls,0))
							
		WHEN 0 THEN 0
		ELSE 				(	SUM(ISNULL(asgi.TalkOutTime,0)) + 
								SUM(ISNULL(asgi.TalkAutoOutTime,0)) + 
								SUM(ISNULL(asgi.TalkPreviewTime,0))
							)
							/SUM(ISNULL(asgi.AgentOutCalls,0))
		END),
		
ATTIn	=   (CASE 				SUM(ISNULL(asgi.CallsHandled,0))
							
		WHEN 0 THEN 0
		ELSE 				(	SUM(ISNULL(asgi.TalkInTime,0)) + 
								SUM(ISNULL(asgi.TalkOtherTime,0)) + 
								SUM(ISNULL(asgi.TalkReserveTime,0))
							)
							/SUM(ISNULL(asgi.CallsHandled,0))
		END),
		
		
AWPPT=(CASE 					(SUM(ISNULL(asgi.CallsHandled,0)) + SUM(ISNULL(asgi.AgentOutCalls,0)))
							
		WHEN 0 THEN 0
		ELSE 					SUM(ISNULL(asgi.WorkNotReadyTime + asgi.WorkReadyTime,0)) 
							
							/	(SUM(ISNULL(asgi.CallsHandled,0)) + SUM(ISNULL(asgi.AgentOutCalls,0)))
		END),


AHLDT=(CASE 					(SUM(ISNULL(asgi.CallsHandled,0)) + SUM(ISNULL(asgi.AgentOutCalls,0)))
							
		WHEN 0 THEN 0
		ELSE 					SUM(ISNULL(asgi.HoldTime,0)) 
							
							/	(SUM(ISNULL(asgi.CallsHandled,0)) + SUM(ISNULL(asgi.AgentOutCalls,0)))
		END)



FROM AgNames, Agent_Skill_Group_Interval asgi
WHERE asgi.SkillTargetID = AID
AND asgi.DateTime >= @start AND asgi.DateTime < @end
GROUP BY AID, asgi.SkillTargetID
)

SELECT 
 tm.EnterpriseName AS Team
,LT.AID
,FullName
,AgentLogin
,LT.LoggedOnTime
,LT.AvailTime
,AG.HandledCallsTime
,LT.NotReadyTime
,LT.BusyTime
,LT.TalkOtherTime
,AG.CallsHandled
,AG.AgentOutCalls
,AG.HoldTime
,AG.ReservedTime
,AG.WrapTime
,AG.TalkTime
,AG.TalkOutTime
,TalkTimeSum = AG.TalkTime + TalkOutTime
,AG.ATT
,AG.ATTOut
,AG.ATTIn
,AWT = (CASE 					(ISNULL(AG.CallsHandled,0) + ISNULL(AG.AgentOutCalls,0))
							
		WHEN 0 THEN 0
		ELSE 				(	
								ISNULL(LT.AvailTime,0) + 
								ISNULL(AG.ReservedTime,0) 
							)
							/(ISNULL(AG.CallsHandled,0) + ISNULL(AG.AgentOutCalls,0))
		END)


,AG.AWPPT
,ApWrap=(CASE 					(ISNULL(AG.CallsHandled,0) + ISNULL(AG.AgentOutCalls,0))
							
		WHEN 0 THEN 0
		ELSE 					ISNULL(RT.pWrap,0) 
							
							/	(ISNULL(AG.CallsHandled,0) + ISNULL(AG.AgentOutCalls,0))
		END),
		
AOUTT=(CASE 					ISNULL(AG.AgentOutCalls,0)
							
		WHEN 0 THEN 0
		ELSE 				(
								AG.TalkOutTime
							)
							
							/	ISNULL(AG.AgentOutCalls,0)
		END)
,AG.AHLDT
,OCC =   (CASE 				(
								ISNULL(LT.AvailTime,0) + 
								ISNULL(AG.HoldTime,0) + 
								ISNULL(AG.ReservedTime,0) + 
								ISNULL(AG.WrapTime,0) +
								ISNULL(RT.pWrap,0) +
								ISNULL(RT.pOut,0) + 
								ISNULL(AG.TalkTime,0) +
								ISNULL(AG.TalkOutTime,0)
							)

		 WHEN 0 THEN 0
		 ELSE 				(
								ISNULL(AG.HoldTime,0) +  
								ISNULL(AG.WrapTime,0) + 
								ISNULL(RT.pWrap,0) +	
								ISNULL(RT.pOut,0) +
								ISNULL(AG.TalkTime,0) + 
								ISNULL(AG.TalkOutTime,0) 
							)
							*1.0/
							(
								ISNULL(LT.AvailTime,0) + 
								ISNULL(AG.HoldTime,0) + 
								ISNULL(AG.ReservedTime,0) + 
								ISNULL(AG.WrapTime,0) + 
								ISNULL(RT.pWrap,0) +	
								ISNULL(RT.pOut,0) + 
								ISNULL(AG.TalkTime,0) + 
								ISNULL(AG.TalkOutTime,0) 								
							)
		END)
								
								
								
								
,UTZ = (CASE ISNULL(LT.LoggedOnTime,0) - ISNULL(LT.NotReadyTime,0)
		WHEN 0 THEN 0
		ELSE
							((							
							ISNULL(LT.AvailTime,0) +
							ISNULL(AG.HoldTime,0) +
							ISNULL(AG.ReservedTime,0) +
							ISNULL(AG.WrapTime,0) +
							ISNULL(RT.pWrap,0) +
							ISNULL(AG.TalkTime,0) +
							ISNULL(AG.TalkOutTime,0) +
							ISNULL(RT.pOut,0)
							)*1.0)/(
							ISNULL(LT.LoggedOnTime,0) -
							ISNULL(RT.pLaunch,0)
							)
		END)
,RT.pCallinAvail
--,RT.Duration
,RT.pBreak
,RT.pLaunch
,RT.pBossCall
,RT.pBossTask
,RT.pNastavnik
,RT.pTechIssue
,RT.pDiscret
,RT.pOut
,RT.pOutAVG
,RT.pLearning
,RT.pCouching
,RT.pFeedback
,RT.pWrap
,RT.pAGT_OFFHOOK
,RT.pEndShift
,RT.pMeeting
,RT.pFirstLogin
,RT.pSupervisor
,RT.pForceLogout
,RT.pAgentLogout
,RT.pRNA
,RT.pConnectionFailure
,RT.pOverlap
,RT.pSysReset
,RT.pSysReInit

FROM LogOnTime LT
 LEFT JOIN ReasonsTime RT ON RT.AID = LT.AID
 LEFT JOIN AgNames AN ON AN.AID = LT.AID
 LEFT JOIN ASGStat AG ON AN.AID = AG.AID
 LEFT OUTER JOIN t_Agent_Team_Member atm ON LT.AID = atm.SkillTargetID
 LEFT OUTER JOIN t_Agent_Team tm ON tm.AgentTeamID = atm.AgentTeamID
 ORDER BY tm.EnterpriseName, FullName
