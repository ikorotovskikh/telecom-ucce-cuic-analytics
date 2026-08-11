DECLARE @dtBegin DATETIME = :StartTime
DECLARE @dtEnd DATETIME = :EndTime

DECLARE @ATL VARCHAR(MAX) = CONCAT('(', :Teams, ')')								
DECLARE @SGL VARCHAR(MAX) = CONCAT('(', :SkillGroups, ')')
DECLARE @AGL VARCHAR(MAX) = CONCAT('(', :Agents, ')')


DECLARE @dtBeginPeriod DATETIME = DATEADD(MINUTE, DATEDIFF(MINUTE, 0, DATEADD(MINUTE,  (-1 * (DATEPART(MINUTE, @dtBegin) % 15)), @dtBegin)), 0)

DECLARE @dtEndPeriod DATETIME = CASE WHEN DATEPART(MINUTE, @dtEnd) % 15 = 0 AND DATEPART(SECOND, @dtEnd) = 0
								THEN DATEADD(MINUTE, DATEDIFF(MINUTE, 0, @dtEnd), 0)
								ELSE DATEADD(MINUTE, DATEDIFF(MINUTE, 0, DATEADD(MINUTE, (15 - DATEPART(MINUTE, @dtEnd) % 15), @dtEnd)), 0)
								END

DECLARE @atList table (id int)
  INSERT INTO @atList (id)
  SELECT * FROM STRING_SPLIT(TRANSLATE(REPLACE(@ATL, 'null', ''), '()', '  '), ',')

DECLARE @sgList table (id int)
  INSERT INTO @sgList (id)
  SELECT * FROM STRING_SPLIT(TRANSLATE(REPLACE(@SGL, 'null', ''), '()', '  '), ',')
  
DECLARE @sgListfromTeam table (id int)
  INSERT INTO @sgListfromTeam (id)
   SELECT DISTINCT SkillGroupSkillTargetID from t_Agent_Skill_Group_Interval asgi WITH (NOLOCK)
   LEFT JOIN t_Skill_Group sg on asgi.SkillGroupSkillTargetID  = sg.SkillTargetID
   WHERE  DateTime >= @dtBeginPeriod AND DateTime < @dtEndPeriod 
   AND (SELECT AgentTeamID FROM t_Agent_Team_Member WHERE SkillTargetID = asgi.SkillTargetID) IN (SELECT id FROM @atList)
   AND sg.EnterpriseName NOT LIKE '%Cisco_Voice.default%'

DECLARE @agList table (id int)
  INSERT INTO @agList (id)
  SELECT * FROM STRING_SPLIT(TRANSLATE(REPLACE(@AGL, 'null', ''), '()', '  '), ',')
  
  
SELECT
   order_id
  ,tm.EnterpriseName AS Team
  ,AgentID
  ,a.EnterpriseName AS Agent
  ,p.LoginName AS AgentLogin
  ,p.LastName + ' ' + p.FirstName AS AgentName
  ,SkillID
  ,SkillName
  ,CallsHandled
  ,CallsHandled_T = CASE WHEN ISNULL(SkillID,0) = 0 THEN 0 ELSE CallsHandled END
  ,CallsAnswered
  ,CallsAnswered_T = CASE WHEN ISNULL(SkillID,0) = 0 THEN 0 ELSE CallsAnswered END
  ,AbandonRingCalls
  ,AbandonRingCalls_T = CASE WHEN ISNULL(SkillID,0) = 0 THEN 0 ELSE AbandonRingCalls END
  ,AvailTime
  ,AvailTime_T = CASE WHEN ISNULL(SkillID,0) = 0 THEN 0 ELSE AvailTime END
  ,HoldTime
  ,HoldTime_T = CASE WHEN ISNULL(SkillID,0) = 0 THEN 0 ELSE HoldTime END
  ,ReservedTime
  ,ReservedTime_T = CASE WHEN ISNULL(SkillID,0) = 0 THEN 0 ELSE ReservedTime END
  ,TalkInTime
  ,TalkInTime_T = CASE WHEN ISNULL(SkillID,0) = 0 THEN 0 ELSE TalkInTime END
  ,TalkOutTime
  ,TalkOutTime_T = CASE WHEN ISNULL(SkillID,0) = 0 THEN 0 ELSE TalkOutTime END
  ,TalkOtherTime
  ,TalkOtherTime_T = CASE WHEN ISNULL(SkillID,0) = 0 THEN 0 ELSE TalkOtherTime END
  ,TalkAutoOutTime
  ,TalkAutoOutTime_T = CASE WHEN ISNULL(SkillID,0) = 0 THEN 0 ELSE TalkAutoOutTime END
  ,TalkPreviewTime
  ,TalkPreviewTime_T = CASE WHEN ISNULL(SkillID,0) = 0 THEN 0 ELSE TalkPreviewTime END  
  ,TalkReserveTime
  ,TalkReserveTime_T = CASE WHEN ISNULL(SkillID,0) = 0 THEN 0 ELSE TalkReserveTime END
  ,HandledCallsTime
  ,HandledCallsTime_T = CASE WHEN ISNULL(SkillID,0) = 0 THEN 0 ELSE HandledCallsTime END  
  ,WorkReadyTime
  ,WorkReadyTime_T = CASE WHEN ISNULL(SkillID,0) = 0 THEN 0 ELSE WorkReadyTime END 
  ,WorkNotReadyTime
  ,WorkNotReadyTime_T = CASE WHEN ISNULL(SkillID,0) = 0 THEN 0 ELSE WorkNotReadyTime END 
  ,LogInTime
  ,LogInTime_T = CASE WHEN ISNULL(SkillID,0) != 0 THEN 0 ELSE LogInTime END   
  ,NotReadyTime
  ,NotReadyTime_T = CASE WHEN ISNULL(SkillID,0) != 0 THEN 0 ELSE NotReadyTime END   
  ,LunchTime
  ,LunchTime_T = CASE WHEN ISNULL(SkillID,0) != 0 THEN 0 ELSE LunchTime END    
  ,TechnoBreakTime
  ,TechnoBreakTime_T = CASE WHEN ISNULL(SkillID,0) != 0 THEN 0 ELSE TechnoBreakTime END   
  ,OutgoingCallTime
  ,OutgoingCallTime_T = CASE WHEN ISNULL(SkillID,0) != 0 THEN 0 ELSE OutgoingCallTime END   
  ,EducationTime
  ,EducationTime_T = CASE WHEN ISNULL(SkillID,0) != 0 THEN 0 ELSE EducationTime END  
  ,ToManagerTime
  ,ToManagerTime_T = CASE WHEN ISNULL(SkillID,0) != 0 THEN 0 ELSE ToManagerTime END  
  ,DiscreteContactsTime
  ,DiscreteContactsTime_T = CASE WHEN ISNULL(SkillID,0) != 0 THEN 0 ELSE DiscreteContactsTime END  
  ,MentorTime
  ,MentorTime_T = CASE WHEN ISNULL(SkillID,0) != 0 THEN 0 ELSE MentorTime END  
  ,WorkFromBossTime
  ,WorkFromBossTime_T = CASE WHEN ISNULL(SkillID,0) != 0 THEN 0 ELSE WorkFromBossTime END  
  ,PostProcessTime
  ,PostProcessTime_T = CASE WHEN ISNULL(SkillID,0) != 0 THEN 0 ELSE PostProcessTime END  
  ,CoachingTime
  ,CoachingTime_T = CASE WHEN ISNULL(SkillID,0) != 0 THEN 0 ELSE CoachingTime END 
  ,QCFeedBackTime
  ,QCFeedBackTime_T = CASE WHEN ISNULL(SkillID,0) != 0 THEN 0 ELSE QCFeedBackTime END 
  ,EndOfShiftTime
  ,EndOfShiftTime_T = CASE WHEN ISNULL(SkillID,0) != 0 THEN 0 ELSE EndOfShiftTime END 
  ,MeetingTime
  ,MeetingTime_T = CASE WHEN ISNULL(SkillID,0) != 0 THEN 0 ELSE MeetingTime END 
  ,TechProblemsTime
  ,TechProblemsTime_T = CASE WHEN ISNULL(SkillID,0) != 0 THEN 0 ELSE TechProblemsTime END 
  ,OtherBreakTime
  ,OtherBreakTime_T = CASE WHEN ISNULL(SkillID,0) != 0 THEN 0 ELSE OtherBreakTime END  
  ,rc_count = ISNULL(rc_num,0)
  ,rc_count_T = CASE WHEN ISNULL(SkillID,0) = 0 THEN 0 ELSE ISNULL(rc_num,0) END   
  ,rc_percent = CASE WHEN ISNULL(rc_num,0) = 0 OR (CallsAnswered + AbandonRingCalls) = 0 
					 THEN 0
					 ELSE ISNULL(rc_num,0)*1.0/(CallsAnswered + AbandonRingCalls)
					 END
  ,AHT = (CASE (ISNULL(CallsHandled,0)) 
							WHEN 0 THEN 0
							ELSE ISNULL(HandledCallsTime,0)/CallsHandled
							END)
  ,OCC = (CASE WHEN (ISNULL(AvailTime,0) + 
					ISNULL(HoldTime,0) + 
					ISNULL(ReservedTime,0) + 
					ISNULL(WorkNotReadyTime + WorkReadyTime,0) + 
					ISNULL(TalkInTime,0) + 
					ISNULL(TalkOutTime,0) + 
					ISNULL(TalkOtherTime,0) + 
					ISNULL(TalkAutoOutTime,0) + 
					ISNULL(TalkPreviewTime,0) + 
					ISNULL(TalkReserveTime,0)) = 0 
			   THEN NULL
			   ELSE ISNULL(HandledCallsTime,0)*1.0/
								(
									ISNULL(AvailTime,0) + 
									ISNULL(HoldTime,0) + 
									ISNULL(ReservedTime,0) + 
									ISNULL(WorkNotReadyTime + WorkReadyTime,0) + 
									ISNULL(TalkInTime,0) + 
									ISNULL(TalkOutTime,0) + 
									ISNULL(TalkOtherTime,0) + 
									ISNULL(TalkAutoOutTime,0) + 
									ISNULL(TalkPreviewTime,0) + 
									ISNULL(TalkReserveTime,0)
								)
			   END)
  ,UTZ = (CASE WHEN (ISNULL(LogInTime,0) = 0 OR LogInTime = 0) THEN NULL
								ELSE
							    (							
								  ISNULL(LogInTime,0) -
								  ISNULL(NotReadyTime,0)
							    )*1.0
								/ISNULL(LogInTime,1) 
							 END)
  ,TalkTime = ISNULL(TalkInTime,0) + ISNULL(TalkOutTime,0) + ISNULL(TalkOtherTime,0) + 
			  ISNULL(TalkAutoOutTime,0) +	ISNULL(TalkPreviewTime,0) + ISNULL(TalkReserveTime,0)
  ,TalkTime_T = CASE WHEN ISNULL(SkillID,0) = 0 THEN 0 ELSE ISNULL(TalkInTime,0) + ISNULL(TalkOutTime,0) + ISNULL(TalkOtherTime,0) + 
			  ISNULL(TalkAutoOutTime,0) +	ISNULL(TalkPreviewTime,0) + ISNULL(TalkReserveTime,0) END
  ,WrapTime = ISNULL(WorkNotReadyTime + WorkReadyTime,0)
  ,WrapTime_T = CASE WHEN ISNULL(SkillID,0) = 0 THEN 0 ELSE ISNULL(WorkNotReadyTime + WorkReadyTime,0) END 
FROM
(
  SELECT
	1 AS order_id, 
	SkillTargetID AS AgentID,
	NULL AS SkillID,
	CONVERT(VARCHAR, @dtBeginPeriod, 20)  + ' — ' + CONVERT(VARCHAR, @dtEndPeriod, 20) AS SkillName,
	SUM(CallsHandled) CallsHandled,
	SUM(CallsAnswered) CallsAnswered,
	SUM(AbandonRingCalls) AbandonRingCalls,
	SUM(AvailTime) AvailTime,
	SUM(HoldTime) HoldTime,
	SUM(ReservedTime) ReservedTime,
	SUM(TalkInTime) TalkInTime,
	SUM(TalkOutTime) TalkOutTime,
	SUM(TalkOtherTime) TalkOtherTime,
	SUM(TalkAutoOutTime) TalkAutoOutTime,
	SUM(TalkPreviewTime) TalkPreviewTime, 
	SUM(TalkReserveTime) TalkReserveTime,
	SUM(HandledCallsTime) HandledCallsTime,
	SUM(WorkReadyTime) WorkReadyTime,
	SUM(WorkNotReadyTime) WorkNotReadyTime,
	SUM(LogInTime) LogInTime,
	SUM(NotReadyTime) NotReadyTime,
	SUM(LunchTime) LunchTime,
	SUM(TechnoBreakTime) TechnoBreakTime,
	SUM(OutgoingCallTime) OutgoingCallTime,
	SUM(EducationTime) EducationTime,
	SUM(ToManagerTime) ToManagerTime,
	SUM(DiscreteContactsTime) DiscreteContactsTime,
	SUM(MentorTime) MentorTime,
	SUM(WorkFromBossTime) WorkFromBossTime,
	SUM(PostProcessTime) PostProcessTime,
	SUM(CoachingTime) CoachingTime,
	SUM(QCFeedBackTime) QCFeedBackTime,
	SUM(EndOfShiftTime) EndOfShiftTime,
	SUM(MeetingTime) MeetingTime,
	SUM(TechProblemsTime) TechProblemsTime,
	SUM(OtherBreakTime) OtherBreakTime,
    SUM(rc_num) rc_num 	
	FROM
	(
		SELECT 
	     t.SkillTargetID
		,0 AS CallsHandled
		,0 AS CallsAnswered
		,0 AS AbandonRingCalls
		,0 AS HoldTime
		,0 AS ReservedTime
		,0 AS TalkInTime
		,0 AS TalkOutTime
		,0 AS TalkOtherTime
		,0 AS TalkAutoOutTime
		,0 AS TalkPreviewTime 
		,0 AS TalkReserveTime
		,0 AS HandledCallsTime
		,0 AS WorkReadyTime
		,0 AS WorkNotReadyTime
		,SUM(CASE WHEN t.[Event] = 2 THEN t.SecondsByEventInPeriod else 0 END ) as LogInTime
		,0 as AvailTime
		,SUM(CASE WHEN t.[Event] = 3 THEN t.SecondsByEventInPeriod else 0 END ) as NotReadyTime
		,SUM(CASE WHEN t.[Event] = 3 and t.ReasonCode = 20 THEN t.SecondsByEventInPeriod else 0 END ) as LunchTime
		,SUM(CASE WHEN t.[Event] = 3 and t.ReasonCode = 10 THEN t.SecondsByEventInPeriod else 0 END ) as TechnoBreakTime
		,SUM(CASE WHEN t.[Event] = 3 and t.ReasonCode = 80 THEN t.SecondsByEventInPeriod else 0 END ) as OutgoingCallTime
		,SUM(CASE WHEN t.[Event] = 3 and t.ReasonCode = 90 THEN t.SecondsByEventInPeriod else 0 END ) as EducationTime
		,SUM(CASE WHEN t.[Event] = 3 and t.ReasonCode = 30 THEN t.SecondsByEventInPeriod else 0 END ) as ToManagerTime
		,SUM(CASE WHEN t.[Event] = 3 and t.ReasonCode = 70 THEN t.SecondsByEventInPeriod else 0 END ) as DiscreteContactsTime
		,SUM(CASE WHEN t.[Event] = 3 and t.ReasonCode = 50 THEN t.SecondsByEventInPeriod else 0 END ) as MentorTime
		,SUM(CASE WHEN t.[Event] = 3 and t.ReasonCode = 40 THEN t.SecondsByEventInPeriod else 0 END ) as WorkFromBossTime
		,SUM(CASE WHEN t.[Event] = 3 and t.ReasonCode = 120 THEN t.SecondsByEventInPeriod else 0 END ) as PostProcessTime
		,SUM(CASE WHEN t.[Event] = 3 and t.ReasonCode = 100 THEN t.SecondsByEventInPeriod else 0 END ) as CoachingTime
		,SUM(CASE WHEN t.[Event] = 3 and t.ReasonCode = 110 THEN t.SecondsByEventInPeriod else 0 END ) as QCFeedBackTime
		,SUM(CASE WHEN t.[Event] = 3 and t.ReasonCode = 130 THEN t.SecondsByEventInPeriod else 0 END ) as EndOfShiftTime
		,SUM(CASE WHEN t.[Event] = 3 and t.ReasonCode = 140 THEN t.SecondsByEventInPeriod else 0 END ) as MeetingTime
		,SUM(CASE WHEN t.[Event] = 3 and t.ReasonCode = 60 THEN t.SecondsByEventInPeriod else 0 END ) as TechProblemsTime
		,SUM(CASE WHEN t.[Event] = 3 and t.ReasonCode not in (20,10,80,90,30,70,50,40,120,100,110,130,140,60) THEN t.SecondsByEventInPeriod else 0 END ) as OtherBreakTime
		,0 AS rc_num
		FROM
		(

			SELECT 
			rT.SkillTargetID
			,rT.[Event]
			,rT.[ReasonCode]
			,SUM(
			DATEDIFF(second,   

			IIF(@dtBeginPeriod >= EventDtFrom,@dtBeginPeriod,EventDtFrom)

			,IIF(@dtEndPeriod <= EventDtTo, @dtEndPeriod, EventDtTo)
			)) as SecondsByEventInPeriod
			FROM
			(
				SELECT 
				 SkillTargetID
				,Event
				,ReasonCode
				,DATEADD(SECOND,(-1)*Duration,DATEADD(MILLISECOND, -1*DATEPART(MILLISECOND, DateTime), DateTime)) as EventDtFrom
				,DATEADD(MILLISECOND, -1*DATEPART(MILLISECOND, DateTime), DateTime) as EventDtTo
				FROM t_Agent_Event_Detail WITH (NOLOCK)
				WHERE
					Event in (2,3)
					AND DATEADD(MILLISECOND, -1*DATEPART(MILLISECOND, DateTime), DateTime) >= @dtBeginPeriod
					AND DATEADD(MILLISECOND, -1*DATEPART(MILLISECOND, LoginDateTime), LoginDateTime) < @dtEndPeriod
					AND DATEADD(SECOND,(-1)*Duration,DATEADD(MILLISECOND, -1*DATEPART(MILLISECOND, DateTime), DateTime)) < @dtEndPeriod
			)rT
			GROUP BY  rT.SkillTargetID, rT.[Event], rT.[ReasonCode]
		) t
		WHERE 
			(SELECT AgentTeamID FROM t_Agent_Team_Member WHERE SkillTargetID = t.SkillTargetID) IN (SELECT id FROM @atList)
		GROUP BY t.SkillTargetID
		
		UNION ALL

		SELECT 
			 SkillTargetID
			,0 AS CallsHandled
			,0 AS CallsAnswered
			,0 AS AbandonRingCalls
			,0 AS HoldTime
			,0 AS ReservedTime
			,0 AS TalkInTime
			,0 AS TalkOutTime
			,0 AS TalkOtherTime
			,0 AS TalkAutoOutTime
			,0 AS TalkPreviewTime 
			,0 AS TalkReserveTime
			,0 AS HandledCallsTime
			,0 AS WorkReadyTime
			,0 AS WorkNotReadyTime
			,0 AS LogInTime
			,SUM(AvailTime) as AvailTime
			,0 AS NotReadyTime
			,0 AS LunchTime
			,0 AS TechnoBreakTime
			,0 AS OutgoingCallTime
			,0 AS EducationTime
			,0 AS ToManagerTime
			,0 AS DiscreteContactsTime
			,0 AS MentorTime
			,0 AS WorkFromBossTime
			,0 AS PostProcessTime
			,0 AS CoachingTime
			,0 AS QCFeedBackTime
			,0 AS EndOfShiftTime
			,0 AS MeetingTime
			,0 AS TechProblemsTime
			,0 AS OtherBreakTime
			,0 AS rc_num
		FROM t_Agent_Interval t WITH (NOLOCK)
		WHERE
			(SELECT AgentTeamID FROM t_Agent_Team_Member WHERE SkillTargetID = t.SkillTargetID) IN (SELECT id FROM @atList)
			AND DateTime >= @dtBeginPeriod
			AND DateTime < @dtEndPeriod
		GROUP BY  SkillTargetID
		
		UNION ALL
		SELECT 
			 AgentSkillTargetID
			,0 AS CallsHandled
			,0 AS CallsAnswered
			,0 AS AbandonRingCalls
			,0 AS HoldTime
			,0 AS ReservedTime
			,0 AS TalkInTime
			,0 AS TalkOutTime
			,0 AS TalkOtherTime
			,0 AS TalkAutoOutTime
			,0 AS TalkPreviewTime 
			,0 AS TalkReserveTime
			,0 AS HandledCallsTime
			,0 AS WorkReadyTime
			,0 AS WorkNotReadyTime
			,0 AS LogInTime
			,0 AS AvailTime
			,0 AS NotReadyTime
			,0 AS LunchTime
			,0 AS TechnoBreakTime
			,0 AS OutgoingCallTime
			,0 AS EducationTime
			,0 AS ToManagerTime
			,0 AS DiscreteContactsTime
			,0 AS MentorTime
			,0 AS WorkFromBossTime
			,0 AS PostProcessTime
			,0 AS CoachingTime
			,0 AS QCFeedBackTime
			,0 AS EndOfShiftTime
			,0 AS MeetingTime
			,0 AS TechProblemsTime
			,0 AS OtherBreakTime
			,COUNT(DISTINCT ANI) AS rc_num
		FROM 
          ( 
  	        SELECT MAX(DateTime) as DT, ANI, SkillGroupSkillTargetID, AgentSkillTargetID FROM t_Termination_Call_Detail t WITH (NOLOCK)
            WHERE DateTime >= @dtBeginPeriod AND DateTime < DATEADD(MINUTE, 480, @dtEndPeriod) AND
                   (SELECT AgentTeamID FROM t_Agent_Team_Member WHERE SkillTargetID = t.AgentSkillTargetID) IN (SELECT id FROM @atList)
			        AND ANI IN 
                               (
                                 SELECT ANI FROM t_Termination_Call_Detail t WITH (NOLOCK)
		                         WHERE DateTime >= @dtBeginPeriod AND DateTime < DATEADD(MINUTE, 480, @dtEndPeriod) AND AgentSkillTargetID IS NOT NULL AND
								 (SELECT AgentTeamID FROM t_Agent_Team_Member WHERE SkillTargetID = t.AgentSkillTargetID) IN (SELECT id FROM @atList)
                                 GROUP BY ANI, RouterCallKeyDay, RouterCallKey  
		                         HAVING (COUNT(*) > 1 
			                     AND MAX(DATEDIFF(MINUTE,{d '1970-01-01'},DateTime)) - MIN(DATEDIFF(MINUTE,{d '1970-01-01'},DateTime))  < 1440
			                     AND MAX(DATEDIFF(MINUTE,{d '1970-01-01'},DateTime)) - MIN(DATEDIFF(MINUTE,{d '1970-01-01'},DateTime))  > 0) 
                                ) 
            GROUP BY ANI, SkillGroupSkillTargetID, AgentSkillTargetID

	      ) rc
		WHERE
			(SELECT AgentTeamID FROM t_Agent_Team_Member WHERE SkillTargetID = rc.AgentSkillTargetID) IN (SELECT id FROM @atList) AND @dtBeginPeriod < @dtEndPeriod
			
		GROUP BY  AgentSkillTargetID
		
		UNION ALL
		SELECT 
			 SkillTargetID
			,SUM(ISNULL(CallsHandled, 0)) AS CallsHandled
			,SUM(ISNULL(CallsAnswered, 0)) AS CallsAnswered
			,SUM(ISNULL(AbandonRingCalls, 0)) AS AbandonRingCalls
			,SUM(ISNULL(HoldTime, 0)) AS HoldTime
			,SUM(ISNULL(ReservedStateTime, 0)) AS ReservedTime
			,SUM(ISNULL(TalkInTime, 0)) AS TalkInTime
			,SUM(ISNULL(TalkOutTime, 0)) AS TalkOutTime
			,SUM(ISNULL(TalkOtherTime, 0)) AS TalkOtherTime
			,SUM(ISNULL(TalkAutoOutTime, 0)) AS TalkAutoOutTime
			,SUM(ISNULL(TalkPreviewTime, 0)) AS TalkPreviewTime 
			,SUM(ISNULL(TalkReserveTime, 0)) AS TalkReserveTime
			,SUM(ISNULL(HandledCallsTime, 0)) AS HandledCallsTime
			,SUM(ISNULL(WorkReadyTime, 0)) AS WorkReadyTime
			,SUM(ISNULL(WorkNotReadyTime, 0)) AS WorkNotReadyTime
			,0 AS LogInTime
			,0 AS AvailTime
			,0 AS NotReadyTime
			,0 AS LunchTime
			,0 AS TechnoBreakTime
			,0 AS OutgoingCallTime
			,0 AS EducationTime
			,0 AS ToManagerTime
			,0 AS DiscreteContactsTime
			,0 AS MentorTime
			,0 AS WorkFromBossTime
			,0 AS PostProcessTime
			,0 AS CoachingTime
			,0 AS QCFeedBackTime
			,0 AS EndOfShiftTime
			,0 AS MeetingTime
			,0 AS TechProblemsTime
			,0 AS OtherBreakTime
			,0 AS rc_num
		FROM t_Agent_Skill_Group_Interval t WITH (NOLOCK)
		WHERE
			(SELECT AgentTeamID FROM t_Agent_Team_Member WHERE SkillTargetID = t.SkillTargetID) IN (SELECT id FROM @atList)
			AND DateTime >= @dtBeginPeriod
			AND DateTime < @dtEndPeriod
		GROUP BY  SkillTargetID
			
	) agSummary
	GROUP BY agSummary.SkillTargetID  
  
  UNION ALL
  SELECT
	0 AS order_id
	,AgentID
	,SkillID
	,sg.EnterpriseName AS SkillName
	,CallsHandled
	,CallsAnswered
	,AbandonRingCalls
	,AvailTime
	,HoldTime
	,ReservedTime
	,TalkInTime
	,TalkOutTime
	,TalkOtherTime
	,TalkAutoOutTime
	,TalkPreviewTime 
	,TalkReserveTime
	,HandledCallsTime
	,WorkReadyTime
	,WorkNotReadyTime
	,LogInTime
	,NotReadyTime
	,LunchTime
	,TechnoBreakTime
	,OutgoingCallTime
	,EducationTime
	,ToManagerTime
	,DiscreteContactsTime
	,MentorTime
	,WorkFromBossTime
	,PostProcessTime
	,CoachingTime
	,QCFeedBackTime
	,EndOfShiftTime
	,MeetingTime
	,TechProblemsTime
	,OtherBreakTime
	,rc.rc_num
	FROM (
		SELECT 
		 SkillTargetID AS AgentID
		,SkillGroupSkillTargetID AS SkillID
		,SUM(ISNULL(CallsHandled, 0)) AS CallsHandled
		,SUM(ISNULL(CallsAnswered, 0)) AS CallsAnswered
		,SUM(ISNULL(AbandonRingCalls, 0)) AS AbandonRingCalls
		,SUM(ISNULL(AvailTime, 0)) AS AvailTime
		,SUM(ISNULL(HoldTime, 0)) AS HoldTime
		,SUM(ISNULL(ReservedStateTime, 0)) AS ReservedTime
		,SUM(ISNULL(TalkInTime, 0)) AS TalkInTime
		,SUM(ISNULL(TalkOutTime, 0)) AS TalkOutTime
		,SUM(ISNULL(TalkOtherTime, 0)) AS TalkOtherTime
		,SUM(ISNULL(TalkAutoOutTime, 0)) AS TalkAutoOutTime
		,SUM(ISNULL(TalkPreviewTime, 0)) AS TalkPreviewTime 
		,SUM(ISNULL(TalkReserveTime, 0)) AS TalkReserveTime
		,SUM(ISNULL(HandledCallsTime, 0)) AS HandledCallsTime
		,SUM(ISNULL(WorkReadyTime, 0)) AS WorkReadyTime
		,SUM(ISNULL(WorkNotReadyTime, 0)) AS WorkNotReadyTime
		,SUM(ISNULL(LoggedOnTime, 0)) AS LogInTime
		,SUM(ISNULL(NotReadyTime, 0)) AS NotReadyTime
		
		FROM t_Agent_Skill_Group_Interval t
		WHERE DateTime >= @dtBeginPeriod AND DateTime < @dtEndPeriod 
		AND (SELECT AgentTeamID FROM t_Agent_Team_Member WHERE SkillTargetID = t.SkillTargetID) IN (SELECT id FROM @atList)
		GROUP BY SkillGroupSkillTargetID, SkillTargetID
  ) asgi
  LEFT JOIN t_Skill_Group sg on asgi.SkillID = sg.SkillTargetID
  INNER JOIN(
		SELECT 
			br.SkillTargetID
			,SUM(CASE WHEN br.[Event] = 3 and br.ReasonCode = 20 THEN br.SecondsByEventInPeriod else 0 END ) as LunchTime
			,SUM(CASE WHEN br.[Event] = 3 and br.ReasonCode = 10 THEN br.SecondsByEventInPeriod else 0 END ) as TechnoBreakTime
			,SUM(CASE WHEN br.[Event] = 3 and br.ReasonCode = 80 THEN br.SecondsByEventInPeriod else 0 END ) as OutgoingCallTime
			,SUM(CASE WHEN br.[Event] = 3 and br.ReasonCode = 90 THEN br.SecondsByEventInPeriod else 0 END ) as EducationTime
			,SUM(CASE WHEN br.[Event] = 3 and br.ReasonCode = 30 THEN br.SecondsByEventInPeriod else 0 END ) as ToManagerTime
			,SUM(CASE WHEN br.[Event] = 3 and br.ReasonCode = 70 THEN br.SecondsByEventInPeriod else 0 END ) as DiscreteContactsTime
			,SUM(CASE WHEN br.[Event] = 3 and br.ReasonCode = 50 THEN br.SecondsByEventInPeriod else 0 END ) as MentorTime
			,SUM(CASE WHEN br.[Event] = 3 and br.ReasonCode = 40 THEN br.SecondsByEventInPeriod else 0 END ) as WorkFromBossTime
			,SUM(CASE WHEN br.[Event] = 3 and br.ReasonCode = 120 THEN br.SecondsByEventInPeriod else 0 END ) as PostProcessTime
			,SUM(CASE WHEN br.[Event] = 3 and br.ReasonCode = 100 THEN br.SecondsByEventInPeriod else 0 END ) as CoachingTime
			,SUM(CASE WHEN br.[Event] = 3 and br.ReasonCode = 110 THEN br.SecondsByEventInPeriod else 0 END ) as QCFeedBackTime
			,SUM(CASE WHEN br.[Event] = 3 and br.ReasonCode = 130 THEN br.SecondsByEventInPeriod else 0 END ) as EndOfShiftTime
			,SUM(CASE WHEN br.[Event] = 3 and br.ReasonCode = 140 THEN br.SecondsByEventInPeriod else 0 END ) as MeetingTime
			,SUM(CASE WHEN br.[Event] = 3 and br.ReasonCode = 60 THEN br.SecondsByEventInPeriod else 0 END ) as TechProblemsTime
			,SUM(CASE WHEN br.[Event] = 3 and br.ReasonCode not in ( 20
																	,10
																	,80
																	,90
																	,30
																	,70
																	,50
																	,40	
																	,120
																	,100
																	,110
																	,130
																	,140
																	,60
																														
							) THEN br.SecondsByEventInPeriod else 0 END ) as OtherBreakTime
		FROM
		(
			SELECT 
			rT.SkillTargetID
			,rT.[Event]
			,rT.[ReasonCode]
			,SUM(
			DATEDIFF(second,   
			IIF(@dtBeginPeriod >= EventDtFrom,@dtBeginPeriod,EventDtFrom)
			,IIF(@dtEndPeriod <= EventDtTo, @dtEndPeriod, EventDtTo)
			)) as SecondsByEventInPeriod
			FROM
			(
				SELECT 
				SkillTargetID
				,Event
				,ReasonCode
				,DATEADD(SECOND,(-1)*Duration,DATEADD(MILLISECOND, -1*DATEPART(MILLISECOND, DateTime), DateTime)) as EventDtFrom
				,DATEADD(MILLISECOND, -1*DATEPART(MILLISECOND, DateTime), DateTime) as EventDtTo
				FROM t_Agent_Event_Detail t WITH (NOLOCK)
				WHERE
					(SELECT AgentTeamID FROM t_Agent_Team_Member WHERE SkillTargetID = t.SkillTargetID) IN (SELECT id FROM @atList)
					AND Event in (2,3)
					AND DATEADD(MILLISECOND, -1*DATEPART(MILLISECOND, DateTime), DateTime) >= @dtBeginPeriod
					AND DATEADD(MILLISECOND, -1*DATEPART(MILLISECOND, LoginDateTime), LoginDateTime) < @dtEndPeriod
					AND DATEADD(SECOND,(-1)*Duration,DATEADD(MILLISECOND, -1*DATEPART(MILLISECOND, DateTime), DateTime)) < @dtEndPeriod
			)rT
			GROUP BY  rT.SkillTargetID, rT.[Event], rT.[ReasonCode]
		) br
		GROUP BY br.SkillTargetID
		
  ) aed ON asgi.AgentID = aed.SkillTargetID
 		
  LEFT JOIN 
  (
    SELECT COUNT(DISTINCT ANI) AS rc_num, AgentSkillTargetID, SkillGroupSkillTargetID FROM
    ( 
  	        SELECT MAX(DateTime) as DT, ANI, SkillGroupSkillTargetID, AgentSkillTargetID FROM t_Termination_Call_Detail 
            WHERE DateTime >= @dtBeginPeriod AND DateTime < DATEADD(MINUTE, 480, @dtEndPeriod) AND
		          ((AgentSkillTargetID IS NOT NULL AND 
			      (SkillGroupSkillTargetID IN (SELECT id FROM @sgList)) OR
			      (0 IN (SELECT id FROM @sgList)) AND SkillGroupSkillTargetID IN (SELECT id FROM @sgListfromTeam)))
                    AND ANI IN 
                               (
                                 SELECT ANI FROM t_Termination_Call_Detail WITH (NOLOCK)
		                         WHERE DateTime >= @dtBeginPeriod AND DateTime < DATEADD(MINUTE, 480, @dtEndPeriod) AND
								       ((AgentSkillTargetID IS NOT NULL AND 
									   (SkillGroupSkillTargetID IN (SELECT id FROM @sgList)) 
									   OR 
			                           (0 IN (SELECT id FROM @sgList)) AND SkillGroupSkillTargetID IN (SELECT id FROM @sgListfromTeam)))
                                 GROUP BY ANI, RouterCallKeyDay, RouterCallKey  
		                         HAVING (COUNT(*) > 1 
			                     AND MAX(DATEDIFF(MINUTE,{d '1970-01-01'},DateTime)) - MIN(DATEDIFF(MINUTE,{d '1970-01-01'},DateTime))  < 1440
			                     AND MAX(DATEDIFF(MINUTE,{d '1970-01-01'},DateTime)) - MIN(DATEDIFF(MINUTE,{d '1970-01-01'},DateTime))  > 0) 
                                ) 
            GROUP BY ANI, SkillGroupSkillTargetID, AgentSkillTargetID
    ) RC
    GROUP BY AgentSkillTargetID, SkillGroupSkillTargetID
  ) rc ON  asgi.AgentID = rc.AgentSkillTargetID AND asgi.SkillID = rc.SkillGroupSkillTargetID
 ) t

LEFT JOIN t_Agent a ON t.AgentID = a.SkillTargetID
LEFT JOIN t_Person p ON a.PersonID = p.PersonID
LEFT JOIN t_Agent_Team_Member atm ON t.AgentID = atm.SkillTargetID
LEFT JOIN t_Agent_Team tm ON atm.AgentTeamID = tm.AgentTeamID

WHERE tm.AgentTeamID IN (SELECT id FROM @atList) AND SkillName  NOT LIKE '%Cisco_Voice.default%'
      AND (SkillID IS NULL OR SkillID IN (SELECT id FROM @sgList) OR 0 IN (SELECT id FROM @sgList))
      AND (AgentID IN (SELECT id FROM @agList) OR (0 IN (SELECT id FROM @agList)))

ORDER BY AgentID, order_id, SkillName, tm.EnterpriseName
