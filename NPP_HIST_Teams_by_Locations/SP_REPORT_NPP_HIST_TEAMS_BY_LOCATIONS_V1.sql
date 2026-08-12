USE [STAT_DB]
GO

/****** Object:  StoredProcedure [dbo].[SP_REPORT_NPP_HIST_TEAMS_BY_LOCATIONS_V1]    Script Date: 11.08.2026 23:07:42 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





CREATE PROCEDURE [dbo].[SP_REPORT_NPP_HIST_TEAMS_BY_LOCATIONS_V1]

      @dtBegin DATETIME = '2024-08-21 00:00:00'
	, @dtEnd DATETIME = '2024-08-22 00:00:00'
	, @dtType INT = 3
	, @LL VARCHAR(MAX) = '(1, 2, 3, 4, 5)'	
	, @ATL VARCHAR(MAX) = '()'								
	, @AGL VARCHAR(MAX) = '()'

AS
BEGIN

DECLARE @dtBeginPeriod DATETIME = DATEADD(MINUTE, DATEDIFF(MINUTE, 0, DATEADD(MINUTE,  (-1 * (DATEPART(MINUTE, @dtBegin) % 15)), @dtBegin)), 0)

DECLARE @dtEndPeriod DATETIME = CASE WHEN DATEPART(MINUTE, @dtEnd) % 15 = 0 AND DATEPART(SECOND, @dtEnd) = 0
								THEN DATEADD(MINUTE, DATEDIFF(MINUTE, 0, @dtEnd), 0)
								ELSE DATEADD(MINUTE, DATEDIFF(MINUTE, 0, DATEADD(MINUTE, (15 - DATEPART(MINUTE, @dtEnd) % 15), @dtEnd)), 0)
							END

DECLARE @lList table (id int)
  INSERT INTO @lList (id)
  SELECT * FROM STRING_SPLIT(TRANSLATE(REPLACE(@LL, 'null', ''), '()', '  '), ',')

DECLARE @atList table (id int)
  INSERT INTO @atList (id)
  SELECT * FROM STRING_SPLIT(TRANSLATE(REPLACE(@ATL, 'null', ''), '()', '  '), ',')

DECLARE @tmListfromLocations table (id int)
  INSERT INTO @tmListfromLocations (id)
   SELECT AgentTeamID FROM tNPP_Locations
   WHERE  NPPLocationID IN (SELECT id FROM @lList) 
   
IF 0 IN (SELECT id FROM @atList) INSERT INTO @atList(id) SELECT id FROM @tmListfromLocations; DELETE FROM @atList WHERE id = 0

  
DECLARE @agList table (id int)
  INSERT INTO @agList (id)
  SELECT * FROM STRING_SPLIT(TRANSLATE(REPLACE(@AGL, 'null', ''), '()', '  '), ',')

DROP TABLE IF EXISTS #AED
DROP TABLE IF EXISTS #ASGI
DROP TABLE IF EXISTS #AI
DROP TABLE IF EXISTS #TCD
				
SELECT *
INTO #AED 
FROM t_Agent_Event_Detail WITH (NOLOCK)
WHERE DateTime >= @dtBeginPeriod AND DATEADD(MINUTE,15,DateTime) <= @dtEndPeriod

SELECT *
INTO #ASGI 
FROM t_Agent_Skill_Group_Interval asgi WITH (NOLOCK)
WHERE DateTime >= @dtBeginPeriod AND DATEADD(MINUTE,15,DateTime) <= @dtEndPeriod AND
      (SELECT AgentTeamID FROM t_Agent_Team_Member WITH (NOLOCK) WHERE SkillTargetID = asgi.SkillTargetID) IN (SELECT id FROM @atList)



SELECT *
INTO #AI 
FROM t_Agent_Interval ai WITH (NOLOCK)
WHERE DateTime >= @dtBeginPeriod AND DATEADD(MINUTE,15,DateTime) <= @dtEndPeriod AND
      (SELECT AgentTeamID FROM t_Agent_Team_Member WITH (NOLOCK) WHERE SkillTargetID = ai.SkillTargetID) IN (SELECT id FROM @atList)


SELECT *
INTO #TCD 
FROM t_Termination_Call_Detail tcd WITH (NOLOCK) 
WHERE DateTime >= @dtBeginPeriod AND DATEADD(MINUTE,15,DateTime) <= @dtEndPeriod AND
	 (SELECT AgentTeamID FROM t_Agent_Team_Member WITH (NOLOCK) WHERE SkillTargetID = tcd.AgentSkillTargetID) IN (SELECT id FROM @atList)

;WITH tPeriods
(
	dtPeriodBegin,--Начало периода
	dtPeriodEnd, --Окончание периода
	dtPeriodEndLast--Последние значение выборки
) 
AS
(
	SELECT 
		(CASE @dtType 
			WHEN 0 THEN @dtBegin
			WHEN 1 THEN CAST(@dtBegin AS DATE)--обнуляем время
			WHEN 2 THEN DATEADD(MINUTE,DATEDIFF(MINUTE,0,DATEADD(SECOND,30*1*60,@dtBegin))/60*60,0)--округление до часа в сторону меньшего
			WHEN 3 THEN DATEADD(MINUTE,DATEDIFF(MINUTE,0,DATEADD(SECOND,30*1*15,@dtBegin))/15*15,0)--округление до 15 минут в сторону ближайшего меньшего
			ELSE @dtBegin 
		END) as dtPeriodBegin,--Начало периода
		(CASE @dtType 
			WHEN 0 THEN @dtEnd
			WHEN 1 THEN DATEADD(dd,1,CAST(@dtBegin AS DATE))
			WHEN 2 THEN DATEADD(HOUR,1,DATEADD(MINUTE,DATEDIFF(MINUTE,0,DATEADD(SECOND,30*1*60,@dtBegin))/60*60,0))--Округление до часа в сторону большего
			WHEN 3 THEN DATEADD(MINUTE,15,DATEADD(MINUTE,DATEDIFF(MINUTE,0,DATEADD(SECOND,30*1*15,@dtBegin))/15*15,0))--Округление до 15 минут в сторону большего
			ELSE @dtEnd 
		END) AS dtPeriodEnd,--Окончание периода
		(CASE @dtType 
			WHEN 0 THEN @dtEnd
			WHEN 1 THEN DATEADD(dd,1,CAST(@dtEnd AS DATE))
			WHEN 2 THEN DATEADD(MINUTE,DATEDIFF(MINUTE,0,DATEADD(SECOND,30*2*60,@dtEnd))/60*60,0)
			WHEN 3 THEN DATEADD(MINUTE,DATEDIFF(MINUTE,0,DATEADD(SECOND,30*2*15,@dtEnd))/15*15,0)
			ELSE @dtEnd 
		END) as dtPeriodEndLast
	UNION ALL
	SELECT dtPeriodEnd as dtPeriodBegin,
		(CASE @dtType 
			WHEN 0 THEN dtPeriodEnd
			WHEN 1 THEN DATEADD(dd,1,dtPeriodEnd)
			WHEN 2 THEN DATEADD(HOUR,1,dtPeriodEnd)
			WHEN 3 THEN DATEADD(MINUTE,15,dtPeriodEnd)
			ELSE @dtEnd 
		END) AS dtPeriodEnd,
		dtPeriodEndLast
	FROM tPeriods
	WHERE dtPeriodEnd < dtPeriodEndLast
),

tDays
(
	BeginOfDay, --Начало дня
	EndOfDay,   --Окончание дня
	EndOfPeriod --Последнее значение выборки
) 
AS
(

SELECT 
	CAST(@dtBegin AS DATE) AS BeginOfDay,
	EndOfDay = DATEADD(dd,1,CAST(@dtBegin AS DATE)),
    EndOfPeriod = DATEADD(dd,1,CAST(DATEADD(SECOND, -1, @dtEnd) AS DATE)) 
UNION ALL

SELECT
    EndOfDay AS BeginOfDay,
	EndOfDay = DATEADD(dd,1,EndOfDay),
	EndOfPeriod
FROM tDays
WHERE EndOfDay < EndOfPeriod
)

SELECT
   dtPeriodBegin
  ,l.NPPLocation
  ,tm.AgentTeamID AS TeamID
  ,tm.EnterpriseName AS Team
  ,AgentID
  ,a.EnterpriseName AS Agent
  ,p.LoginName AS AgentLogin
  ,p.LastName + ' ' + p.FirstName AS AgentName
  ,CallsEntered = CallsAnswered + AbandonRingCalls
  ,CallsHandled
  ,CallsAnswered
  ,AgentOutCalls
  ,AbandonRingCalls
  ,AvailTime
  ,HoldTime
  ,HoldOutTime
  ,ReservedTime
  ,TalkInTime
  ,TalkOutTime
  ,TalkOtherTime
  ,TalkAutoOutTime
  ,TalkPreviewTime
  ,TalkReserveTime
  ,HandledCallsTime
  ,HandledCallsTalkTime
  ,IncomingCallsOnHoldTime
  ,HandledCallsOutTime = ISNULL(TalkOutTime,0) + ISNULL(HoldOutTime,0) + ISNULL(WorkOutTime,0)  
  ,AnswerWaitTime
  ,AnswerWaitOutTime
  ,WorkReadyTime
  ,WorkNotReadyTime
  ,WorkOutTime
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
  ,AHT_In = (CASE (ISNULL(CallsHandled,0)) 
							WHEN 0 THEN 0
							ELSE ISNULL(HandledCallsTime,0)/CallsHandled
							END)
  ,AHT_In_wout_WrapUp = (CASE (ISNULL(CallsHandled,0)) 
							WHEN 0 THEN 0
							ELSE ISNULL(HandledCallsTalkTime + IncomingCallsOnHoldTime,0)/CallsHandled
							END)
  ,AHT_Out = (CASE (ISNULL(AgentOutCallsTCD,0)) 
							WHEN 0 THEN 0
							ELSE (ISNULL(TalkOutTime,0) + ISNULL(HoldOutTime,0) + ISNULL(WorkOutTime,0))/AgentOutCallsTCD
							END)
  ,AHT_Out_wout_WrapUp = (CASE (ISNULL(AgentOutCallsTCD,0)) 
							WHEN 0 THEN 0
							ELSE (ISNULL(TalkOutTime,0) + ISNULL(HoldOutTime,0))/AgentOutCallsTCD
							END)
  ,AVG_WrapUpIn = (CASE (ISNULL(CallsHandled,0)) 
							WHEN 0 THEN 0
							ELSE ISNULL(ISNULL(WorkNotReadyTime + WorkReadyTime,0),0)/CallsHandled
							END)
  ,AVG_WrapUpOut = (CASE (ISNULL(AgentOutCalls,0)) 
							WHEN 0 THEN 0
							ELSE ISNULL(ISNULL(WorkNotReadyTime + WorkReadyTime,0),0)/AgentOutCalls
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
  ,TalkTimeIn = ISNULL(TalkInTime,0) + ISNULL(TalkOtherTime,0) + 
			  ISNULL(TalkAutoOutTime,0) +	ISNULL(TalkPreviewTime,0) + ISNULL(TalkReserveTime,0)
  ,TalkTimeOut = ISNULL(TalkOutTime,0)
  ,WrapTime_In = ISNULL(HandledCallsTime - HandledCallsTalkTime - IncomingCallsOnHoldTime,0)
  ,WrapTime = ISNULL(WorkNotReadyTime + WorkReadyTime,0)
  ,agLogins.FirstLoginDateTime
  ,agLogouts.LastLogoutDateTime
  ,AgentOutCallsTCD = ISNULL(AgentOutCallsTCD,0)
  ,AgentUniqOutCalls = ISNULL(AgentUniqOutCalls,0)
  ,AgentOutCallsSuccess = ISNULL(AgentOutCallsSuccess,0)
  ,AgentUniqOutCallsSuccess = ISNULL(AgentUniqOutCallsSuccess,0)
  ,AgentUniqOutCallsPercent = (CASE WHEN (ISNULL(AgentUniqOutCalls,0) = 0) THEN NULL
								ELSE
							    (							
								  ISNULL(AgentUniqOutCallsSuccess,0)
							    )*1.0
								/ISNULL(AgentUniqOutCalls,1) 
							 END)
  
FROM  
( 	
  SELECT
     asgi.dtPeriodBegin
	,asgi.dtPeriodEnd
	,asgi.AgentID
	,asgi.CallsHandled
	,asgi.CallsAnswered
	,asgi.AgentOutCalls	
	,asgi.AbandonRingCalls
	,asgi.AvailTime
	,asgi.HoldTime
	,HoldOutTime
	,asgi.ReservedTime
	,asgi.TalkInTime
	,asgi.TalkOutTime
	,asgi.TalkOtherTime
	,asgi.TalkAutoOutTime
	,asgi.TalkPreviewTime 
	,asgi.TalkReserveTime
	,asgi.HandledCallsTime
	,asgi.HandledCallsTalkTime
	,asgi.IncomingCallsOnHoldTime
	,asgi.AnswerWaitTime
	,asgi.AnswerWaitOutTime	
	,asgi.WorkReadyTime
	,asgi.WorkNotReadyTime
	,asgi.WorkOutTime
	,aed.LogInTime
	,aed.NotReadyTime
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
	,AgentOutCallsTCD
	,AgentUniqOutCalls							   
	,AgentOutCallsSuccess							   
	,AgentUniqOutCallsSuccess
  FROM (
    SELECT
	  dtPeriodBegin
	 ,dtPeriodEnd	
	 ,AgentID
	 ,SUM(ISNULL(CallsHandled, 0)) AS CallsHandled
	 ,SUM(ISNULL(CallsAnswered, 0)) AS CallsAnswered
	 ,SUM(ISNULL(AgentOutCalls, 0)) AS AgentOutCalls		
	 ,SUM(ISNULL(AbandonRingCalls, 0)) AS AbandonRingCalls
	 ,SUM(ISNULL(AvailTime, 0)) AS AvailTime
	 ,SUM(ISNULL(HoldTime, 0)) AS HoldTime
	 ,SUM(ISNULL(HoldOutTime, 0)) AS HoldOutTime
	 ,SUM(ISNULL(ReservedTime, 0)) AS ReservedTime
	 ,SUM(ISNULL(TalkInTime, 0)) AS TalkInTime
	 ,SUM(ISNULL(TalkOutTime, 0)) AS TalkOutTime
	 ,SUM(ISNULL(TalkOtherTime, 0)) AS TalkOtherTime
	 ,SUM(ISNULL(TalkAutoOutTime, 0)) AS TalkAutoOutTime
	 ,SUM(ISNULL(TalkPreviewTime, 0)) AS TalkPreviewTime 
	 ,SUM(ISNULL(TalkReserveTime, 0)) AS TalkReserveTime
	 ,SUM(ISNULL(HandledCallsTime, 0)) AS HandledCallsTime
	 ,SUM(ISNULL(HandledCallsTalkTime, 0)) AS HandledCallsTalkTime
	 ,SUM(ISNULL(IncomingCallsOnHoldTime, 0)) AS IncomingCallsOnHoldTime 
	 ,SUM(ISNULL(AnswerWaitTime, 0)) AS AnswerWaitTime
	 ,SUM(ISNULL(AnswerWaitOutTime, 0)) AS AnswerWaitOutTime
	 ,SUM(ISNULL(WorkReadyTime, 0)) AS WorkReadyTime
	 ,SUM(ISNULL(WorkNotReadyTime, 0)) AS WorkNotReadyTime
	 ,SUM(ISNULL(WorkOutTime, 0)) AS WorkOutTime
	 ,SUM(ISNULL(NotReadyTime, 0)) AS NotReadyTime
	 ,COUNT(DigitsDialed) AS AgentOutCallsTCD	 							   
	 ,COUNT(DISTINCT DigitsDialed) AS AgentUniqOutCalls							   
	 ,COUNT(DigitsDialedSuccess) AS AgentOutCallsSuccess							   
	 ,COUNT(DISTINCT DigitsDialedSuccess) AS AgentUniqOutCallsSuccess
	 FROM
       (SELECT 
		 dtPeriodBegin
		,dtPeriodEnd	
		,ASGI.SkillTargetID AS AgentID
		,CallsHandled
		,CallsAnswered
		,AgentOutCalls		
		,AbandonRingCalls
		,0 AS AvailTime
		,HoldTime
		,0 AS HoldOutTime	
		,ReservedStateTime AS ReservedTime 
		,TalkInTime
		,0 AS TalkOutTime
		,TalkOtherTime
		,TalkAutoOutTime
		,TalkPreviewTime 
		,TalkReserveTime
		,HandledCallsTime
		,HandledCallsTalkTime
		,IncomingCallsOnHoldTime
		,AnswerWaitTime
		,0 AS AnswerWaitOutTime
		,WorkReadyTime
		,WorkNotReadyTime
		,0 AS WorkOutTime
		,NotReadyTime
		,NULL AS DigitsDialed
		,NULL AS DigitsDialedSuccess
		FROM tPeriods tP
		INNER JOIN #ASGI ASGI ON DateTime >= tP.dtPeriodBegin AND DateTime < tP.dtPeriodEnd
		
		UNION ALL
		
		SELECT
		dtPeriodBegin
		,dtPeriodEnd
		,SkillTargetID AS AgentID
		,0 AS CallsHandled
		,0 AS CallsAnswered
		,0 AS AgentOutCalls
		,0 AS AbandonRingCalls
		,SUM(AvailTime) as AvailTime
		,0 AS HoldTime
		,0 AS HoldOutTime
		,0 AS ReservedTime
		,0 AS TalkInTime
		,0 AS TalkOutTime
		,0 AS TalkOtherTime
		,0 AS TalkAutoOutTime
		,0 AS TalkPreviewTime 
		,0 AS TalkReserveTime
		,0 AS HandledCallsTime
		,0 AS HandledCallsTalkTime
		,0 AS IncomingCallsOnHoldTime
		,0 AS AnswerWaitTime
		,0 AS AnswerWaitOutTime			
		,0 AS WorkReadyTime
		,0 AS WorkNotReadyTime
		,0 AS WorkOutTime
		,0 AS NotReadyTime
		,NULL AS DigitsDialed
		,NULL AS DigitsDialedSuccess
		FROM tPeriods tP
		INNER JOIN #AI AI ON DateTime >= tP.dtPeriodBegin AND DateTime < tP.dtPeriodEnd
		GROUP BY  dtPeriodBegin, dtPeriodEnd, SkillTargetID
		
		UNION ALL
		
		SELECT 
		 dtPeriodBegin
		,dtPeriodEnd	
		,ASGI.SkillTargetID AS AgentID
		,0 AS CallsHandled
		,0 AS CallsAnswered
		,0 AS AgentOutCalls		
		,0 AS AbandonRingCalls
		,0 AS AvailTime
		,0 AS HoldTime
		,TCDOUTTimes.HoldTime AS HoldOutTime		
		,0 AS ReservedTime
		,0 AS TalkInTime
		,TCDOUTTimes.TalkTime AS TalkOutTime	
		,0 AS TalkOtherTime
		,0 AS TalkAutoOutTime
		,0 AS TalkPreviewTime 
		,0 AS TalkReserveTime
		,0 AS HandledCallsTime
		,0 AS HandledCallsTalkTime
		,0 AS IncomingCallsOnHoldTime
		,0 AS AnswerWaitTime
		,TCDOUTTimes.DelayTime AS AnswerWaitOutTime
		,0 AS WorkReadyTime
		,0 AS WorkNotReadyTime
		,TCDOUTTimes.WorkTime AS WorkOutTime		
		,0 AS NotReadyTime
		,NULL AS DigitsDialed
		,NULL AS DigitsDialedSuccess
		FROM tPeriods tP
		INNER JOIN #ASGI ASGI ON DateTime >= tP.dtPeriodBegin AND DateTime < tP.dtPeriodEnd AND ASGI.AgentOutCallsTime > 0
		LEFT JOIN #TCD TCDOUTTimes ON TCDOUTTimes.DateTime >= ASGI.DateTime AND TCDOUTTimes.DateTime < DATEADD (MINUTE , 15 , ASGI.DateTime) AND 
							(TCDOUTTimes.PeripheralCallType = 9 OR (TCDOUTTimes.PeripheralCallType = 10 AND LEN(TCDOUTTimes.DigitsDialed)>=10)) AND 
							 ASGI.SkillTargetID = TCDOUTTimes.AgentSkillTargetID AND ASGI.SkillGroupSkillTargetID = TCDOUTTimes.SkillGroupSkillTargetID
							   
		UNION ALL
		
		SELECT 
		 dtPeriodBegin
		,dtPeriodEnd	
		,ASGI.SkillTargetID AS AgentID
		,0 AS CallsHandled
		,0 AS CallsAnswered
		,0 AS AgentOutCalls		
		,0 AS AbandonRingCalls
		,0 AS AvailTime
		,0 AS HoldTime
		,0 AS HoldOutTime		
		,0 AS ReservedTime
		,0 AS TalkInTime
		,0 AS TalkOutTime
		,0 AS TalkOtherTime
		,0 AS TalkAutoOutTime
		,0 AS TalkPreviewTime 
		,0 AS TalkReserveTime
		,0 AS HandledCallsTime
		,0 AS HandledCallsTalkTime
		,0 AS IncomingCallsOnHoldTime
		,0 AS AnswerWaitTime
		,0 AS AnswerWaitOutTime
		,0 AS WorkReadyTime
		,0 AS WorkNotReadyTime
		,0 AS WorkOutTime
		,0 AS NotReadyTime
		,TCDOUT.DigitsDialed AS DigitsDialed
		,NULL AS DigitsDialedSuccess
		FROM tPeriods tP
		INNER JOIN #ASGI ASGI ON DateTime >= tP.dtPeriodBegin AND DateTime < tP.dtPeriodEnd -- AND ASGI.AgentOutCallsTime > 0
		INNER JOIN #TCD TCDOUT ON TCDOUT.DateTime >= ASGI.DateTime AND TCDOUT.DateTime < DATEADD (MINUTE , 15 , ASGI.DateTime) AND 
							(TCDOUT.PeripheralCallType = 9 OR (TCDOUT.PeripheralCallType = 10 AND LEN(TCDOUT.DigitsDialed)>=10)) AND 
							 ASGI.SkillTargetID = TCDOUT.AgentSkillTargetID AND ASGI.SkillGroupSkillTargetID = TCDOUT.SkillGroupSkillTargetID
	
		UNION ALL
		
		SELECT 
		 dtPeriodBegin
		,dtPeriodEnd	
		,ASGI.SkillTargetID AS AgentID
		,0 AS CallsHandled
		,0 AS CallsAnswered
		,0 AS AgentOutCalls		
		,0 AS AbandonRingCalls
		,0 AS AvailTime
		,0 AS HoldTime
		,0 AS HoldOutTime		
		,0 AS ReservedTime
		,0 AS TalkInTime
		,0 AS TalkOutTime
		,0 AS TalkOtherTime
		,0 AS TalkAutoOutTime
		,0 AS TalkPreviewTime 
		,0 AS TalkReserveTime
		,0 AS HandledCallsTime
		,0 AS HandledCallsTalkTime
		,0 AS IncomingCallsOnHoldTime
		,0 AS AnswerWaitTime
		,0 AS AnswerWaitOutTime
		,0 AS WorkReadyTime
		,0 AS WorkNotReadyTime
		,0 AS WorkOutTime
		,0 AS NotReadyTime
		,NULL AS DigitsDialed
		,TCDOUTSUCCESS.DigitsDialed AS DigitsDialedSuccess
		FROM tPeriods tP
		INNER JOIN #ASGI ASGI ON DateTime >= tP.dtPeriodBegin AND DateTime < tP.dtPeriodEnd AND ASGI.AgentOutCallsTime > 0
		INNER JOIN #TCD TCDOUTSUCCESS ON TCDOUTSUCCESS.DateTime >= ASGI.DateTime AND TCDOUTSUCCESS.DateTime < DATEADD (MINUTE , 15 , ASGI.DateTime) AND TCDOUTSUCCESS.TalkTime != 0 AND 
								(TCDOUTSUCCESS.PeripheralCallType = 9 OR (TCDOUTSUCCESS.PeripheralCallType = 10 AND LEN(TCDOUTSUCCESS.DigitsDialed)>=10)) AND 
							     ASGI.SkillTargetID = TCDOUTSUCCESS.AgentSkillTargetID AND ASGI.SkillGroupSkillTargetID = TCDOUTSUCCESS.SkillGroupSkillTargetID
	  ) asgi_no_aggr
	  GROUP BY  dtPeriodBegin, dtPeriodEnd, AgentID
  ) asgi
  INNER JOIN(
		SELECT 
		 tA.dtPeriodBegin
		,tA.dtPeriodEnd
	    ,tA.SkillTargetID
		,SUM(CASE WHEN tA.[Event] = 2 THEN tA.SecondsByEventInPeriod else 0 END ) as LogInTime
		,0 as AvailTime
		,SUM(CASE WHEN tA.[Event] = 3 THEN tA.SecondsByEventInPeriod else 0 END ) as NotReadyTime
		,SUM(CASE WHEN tA.[Event] = 3 and tA.ReasonCode = 20 THEN tA.SecondsByEventInPeriod else 0 END ) as LunchTime
		,SUM(CASE WHEN tA.[Event] = 3 and tA.ReasonCode = 10 THEN tA.SecondsByEventInPeriod else 0 END ) as TechnoBreakTime
		,SUM(CASE WHEN tA.[Event] = 3 and tA.ReasonCode = 80 THEN tA.SecondsByEventInPeriod else 0 END ) as OutgoingCallTime
		,SUM(CASE WHEN tA.[Event] = 3 and tA.ReasonCode = 90 THEN tA.SecondsByEventInPeriod else 0 END ) as EducationTime
		,SUM(CASE WHEN tA.[Event] = 3 and tA.ReasonCode = 30 THEN tA.SecondsByEventInPeriod else 0 END ) as ToManagerTime
		,SUM(CASE WHEN tA.[Event] = 3 and tA.ReasonCode = 70 THEN tA.SecondsByEventInPeriod else 0 END ) as DiscreteContactsTime
		,SUM(CASE WHEN tA.[Event] = 3 and tA.ReasonCode = 50 THEN tA.SecondsByEventInPeriod else 0 END ) as MentorTime
		,SUM(CASE WHEN tA.[Event] = 3 and tA.ReasonCode = 40 THEN tA.SecondsByEventInPeriod else 0 END ) as WorkFromBossTime
		,SUM(CASE WHEN tA.[Event] = 3 and tA.ReasonCode = 120 THEN tA.SecondsByEventInPeriod else 0 END ) as PostProcessTime
		,SUM(CASE WHEN tA.[Event] = 3 and tA.ReasonCode = 100 THEN tA.SecondsByEventInPeriod else 0 END ) as CoachingTime
		,SUM(CASE WHEN tA.[Event] = 3 and tA.ReasonCode = 110 THEN tA.SecondsByEventInPeriod else 0 END ) as QCFeedBackTime
		,SUM(CASE WHEN tA.[Event] = 3 and tA.ReasonCode = 130 THEN tA.SecondsByEventInPeriod else 0 END ) as EndOfShiftTime
		,SUM(CASE WHEN tA.[Event] = 3 and tA.ReasonCode = 140 THEN tA.SecondsByEventInPeriod else 0 END ) as MeetingTime
		,SUM(CASE WHEN tA.[Event] = 3 and tA.ReasonCode = 60 THEN tA.SecondsByEventInPeriod else 0 END ) as TechProblemsTime
		,SUM(CASE WHEN tA.[Event] = 3 and tA.ReasonCode not in (20,10,80,90,30,70,50,40,120,100,110,130,140,60) THEN tA.SecondsByEventInPeriod else 0 END ) as OtherBreakTime
		FROM
		(
			SELECT
			 dtPeriodBegin
			,dtPeriodEnd
			,SkillTargetID
			,Event = (CASE 
			           WHEN Event = 1 
			           THEN 2
			           ELSE Event
	  		           END
			         )
			,ReasonCode
			,SecondsByEventInPeriod = SUM(DATEDIFF(SECOND, IIF(dtPeriodBegin >= EventDtFrom,dtPeriodBegin,EventDtFrom), 
														   IIF(dtPeriodEnd <= EventDtTo, dtPeriodEnd, EventDtTo)))
			FROM
			(
				SELECT
				 tP.dtPeriodBegin
				,tP.dtPeriodEnd
				,SkillTargetID
				,Event
				,ReasonCode
				,EventDtFrom = 
				     (CASE 
			          WHEN Event = 1 
			          THEN LoginDateTime
			           ELSE DATEADD(SECOND,(-1)*Duration,DATEADD(MILLISECOND, -1*DATEPART(MILLISECOND, DateTime), DateTime))
	  		           END
			         )
				,EventDtTo = 
				     (CASE 
			          WHEN Event = 1 
			          THEN GETDATE()
			           ELSE DATEADD(MILLISECOND, -1*DATEPART(MILLISECOND, DateTime), DateTime)
	  		           END
			         )
				FROM tPeriods tP
				INNER JOIN #AED AED ON
				( -- do not use milliseconds for time comparison
					 (Event = 3
					  AND DATEADD(MILLISECOND, -1*DATEPART(MILLISECOND, DateTime), DateTime) >= tP.dtPeriodBegin
					  AND DATEADD(MILLISECOND, -1*DATEPART(MILLISECOND, LoginDateTime), LoginDateTime) < tP.dtPeriodEnd
					  AND DATEADD(SECOND,(-1)*Duration,DATEADD(MILLISECOND, -1*DATEPART(MILLISECOND, DateTime), DateTime)) < tP.dtPeriodEnd
					 )
					 OR
					 (Event = 2
					  AND DATEADD(MILLISECOND, -1*DATEPART(MILLISECOND, DateTime), DateTime) >= tP.dtPeriodBegin
					  AND DATEADD(MILLISECOND, -1*DATEPART(MILLISECOND, LoginDateTime), LoginDateTime) < tP.dtPeriodEnd
					  AND DATEADD(SECOND,(-1)*Duration,DATEADD(MILLISECOND, -1*DATEPART(MILLISECOND, DateTime), DateTime)) < tP.dtPeriodEnd
					 )
					 OR
					  -- only for cases when there is an active login until the current time
					 (Event = 1 AND tP.dtPeriodEnd > GETDATE() AND DateTime >= tP.dtPeriodBegin AND DateTime < tP.dtPeriodEnd  
					  AND NOT EXISTS (SELECT Event FROM #AED WHERE SkillTargetID = AED.SkillTargetID AND Event = 2 AND DateTime > AED.DateTime)  
					 )
				)
			) tAED
			GROUP BY  dtPeriodBegin, dtPeriodEnd, SkillTargetID, Event, ReasonCode
	    ) tA 
		GROUP BY tA.dtPeriodBegin, tA.dtPeriodEnd, tA.SkillTargetID
		
  ) aed ON asgi.AgentID = aed.SkillTargetID AND aed.dtPeriodBegin = asgi.dtPeriodBegin AND aed.dtPeriodEnd = asgi.dtPeriodEnd
) tRES

LEFT JOIN t_Agent a ON tRES.AgentID = a.SkillTargetID
LEFT JOIN t_Person p ON a.PersonID = p.PersonID
LEFT JOIN t_Agent_Team_Member atm ON tRES.AgentID = atm.SkillTargetID
LEFT JOIN t_Agent_Team tm ON atm.AgentTeamID = tm.AgentTeamID
LEFT JOIN tNPP_Locations l ON tm.AgentTeamID = l.AgentTeamID
LEFT JOIN (
     SELECT 
       MIN(aed.LoginDateTime) AS FirstLoginDateTime,
	   BeginOfDay,
       EndOfDay,
	   aed.SkillTargetID
     FROM tDays
     INNER JOIN #AED aed ON DateTime >= tDays.BeginOfDay AND DateTime < tDays.EndOfDay AND aed.Event = 1
     GROUP BY BeginOfDay, EndOfDay, aed.SkillTargetID
  ) agLogins ON CONVERT(DATE, tRES.dtPeriodBegin) = CONVERT(DATE, agLogins.FirstLoginDateTime)  AND tRES.AgentID = agLogins.SkillTargetID
LEFT JOIN (
     SELECT 
       MAX(DATEADD(SECOND, aed.Duration, aed.LoginDateTime)) AS LastLogoutDateTime,
	   BeginOfDay,
       EndOfDay,
	   aed.SkillTargetID
     FROM tDays
     INNER JOIN #AED aed ON DateTime >= tDays.BeginOfDay AND DateTime < tDays.EndOfDay AND aed.Event = 2
     GROUP BY BeginOfDay, EndOfDay, aed.SkillTargetID
  ) agLogouts ON CONVERT(DATE, tRES.dtPeriodBegin) = CONVERT(DATE, agLogouts.LastLogoutDateTime)  AND tRES.AgentID = agLogouts.SkillTargetID

WHERE tm.AgentTeamID IN (SELECT id FROM @atList) 
      AND (AgentID IN (SELECT id FROM @agList) OR (0 IN (SELECT id FROM @agList)))

ORDER BY l.NPPLocation, tm.EnterpriseName, dtPeriodBegin, tRES.AgentID
	

OPTION (maxrecursion 0)

END

GO


