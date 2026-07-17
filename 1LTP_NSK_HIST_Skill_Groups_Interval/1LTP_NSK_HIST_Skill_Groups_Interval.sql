DECLARE @pDateFrom DATETIME = :StartTime
DECLARE @pDateTo DATETIME = :EndTime

DECLARE @typeDT VARCHAR(2) = :typeDT


--@typeDT 0 - Произвольный интервал, 1 - Сутки, 2 - Часы, 3 - 15 минут
DECLARE @pTypeDT 	int 	 = CASE ISNUMERIC(@typeDT) WHEN 1 THEN CAST(@typeDT AS INT) ELSE 3 END

DROP TABLE IF EXISTS #SGI

SELECT * 
INTO #SGI
FROM Skill_Group_Interval WITH (NOLOCK)
WHERE DateTime >= @pDateFrom AND DateTime <= @pDateTo AND SkillTargetID IN (:SgID)

;WITH tPeriods
(
dtPeriodBegin,  -- Начало периода
dtPeriodEnd,    -- Окончание периода
dtPeriodEndLast -- Последние значение выборки
) 
AS
(
SELECT 
(CASE @pTypeDT 
WHEN 0 THEN @pDateFrom
WHEN 1 THEN CAST(@pDateFrom AS DATE)-- обнуляем время (полночь)
-- округление до часа в сторону ближайшего меньшего, отбрасываем миллисекунды
WHEN 2 THEN DATEADD(MINUTE, DATEDIFF(MINUTE, 0, DATEADD(MINUTE,  (-1 * (DATEPART(MINUTE, @pDateFrom) % 60)), @pDateFrom)), 0)
-- округление до 15 минут в сторону ближайшего меньшего, отбрасываем миллисекунды
WHEN 3 THEN DATEADD(MINUTE, DATEDIFF(MINUTE, 0, DATEADD(MINUTE,  (-1 * (DATEPART(MINUTE, @pDateFrom) % 15)), @pDateFrom)), 0)
ELSE @pDateFrom 
END) as dtPeriodBegin,--Начало периода
(CASE @pTypeDT 
WHEN 0 THEN @pDateTo
WHEN 1 THEN DATEADD(dd,1,CAST(@pDateFrom AS DATE))
WHEN 2 THEN DATEADD(HOUR,1,DATEADD(MINUTE,DATEDIFF(MINUTE,0,DATEADD(SECOND,30*1*60-1,@pDateFrom))/60*60,0))--Округление до часа в сторону большего
WHEN 3 THEN DATEADD(MINUTE,15,DATEADD(MINUTE,DATEDIFF(MINUTE,0,DATEADD(SECOND,30*1*15-1,@pDateFrom))/15*15,0))--Округление до 15 минут в сторону большего
ELSE @pDateTo 
END) AS dtPeriodEnd,--Окончание первого периода 
(CASE @pTypeDT 
WHEN 0 THEN @pDateTo
WHEN 1 THEN CAST(DATEADD(dd,1,DATEADD(SECOND, -1, CAST(CAST(@pDateTo AS DATE) AS DATETIME))) AS DATE)
-- округление до часа в сторону ближайшего большего, , отбрасываем миллисекунды; если 00_00 - то не округляем
WHEN 2 THEN CASE WHEN DATEPART(MINUTE, @pDateTo) % 60 = 0 AND DATEPART(SECOND, @pDateTo) = 0
								THEN DATEADD(MINUTE, DATEDIFF(MINUTE, 0, @pDateTo), 0)
								ELSE DATEADD(MINUTE, DATEDIFF(MINUTE, 0, DATEADD(MINUTE, (60 - DATEPART(MINUTE, @pDateTo) % 60), @pDateTo)), 0)
								END
-- округление до 15 минут в сторону ближайшего большего, , отбрасываем миллисекунды; если 00_00, 15_00, 30_00 или 45_00 - то не округляем
WHEN 3 THEN CASE WHEN DATEPART(MINUTE, @pDateTo) % 15 = 0 AND DATEPART(SECOND, @pDateTo) = 0
								THEN DATEADD(MINUTE, DATEDIFF(MINUTE, 0, @pDateTo), 0)
								ELSE DATEADD(MINUTE, DATEDIFF(MINUTE, 0, DATEADD(MINUTE, (15 - DATEPART(MINUTE, @pDateTo) % 15), @pDateTo)), 0)
								END
ELSE @pDateTo 
END) as dtPeriodEndLast	--Окончание периода
UNION ALL
SELECT dtPeriodEnd as dtPeriodBegin,
(CASE @pTypeDT 
WHEN 0 THEN dtPeriodEnd
WHEN 1 THEN DATEADD(dd,1,dtPeriodEnd)
WHEN 2 THEN DATEADD(HOUR,1,dtPeriodEnd)
WHEN 3 THEN DATEADD(MINUTE,15,dtPeriodEnd)
ELSE @pDateTo 
END) AS dtPeriodEnd,
dtPeriodEndLast
FROM tPeriods
WHERE dtPeriodEnd < dtPeriodEndLast
)


SELECT
  tP.dtPeriodBegin AS Interval
 ,SGI.SkillTargetID AS SgID
 ,SG.EnterpriseName AS SgName
 ,(SUM(ISNULL(SGI.CallsAnswered,0)) + SUM(ISNULL(SGI.RouterCallsAbandToAgent,0)) + SUM(ISNULL(SGI.RouterCallsAbandQ,0))) AS CallsOffered
 ,SUM(ISNULL(SGI.CallsAnswered,0)) AS CallsAnswered
 ,SUM(ISNULL(SGI.CallsHandled,0)) AS CallsHandled
 ,SUM(ISNULL(SGI.AnswerWaitTime,0)) AS AnswerWaitTime
 ,SUM(ISNULL(SGI.AnswerWaitTime,0))/(CASE SUM(ISNULL(SGI.CallsAnswered,0)) WHEN 0 THEN 1 ELSE SUM(ISNULL(SGI.CallsAnswered,0)) END) AS avgAnswerWaitTime
 ,SUM(ISNULL(SGI.RouterCallsAbandQ,0)) AS RouterCallsAbandQ
 ,SUM(ISNULL(SGI.RouterCallsAbandToAgent,0)) AS RouterCallsAgentAbandons
 ,SUM(ISNULL(SGI.AbandonRingCalls,0)) AS AbandonRingCalls
 ,SUM(ISNULL(SGI.AbandonHoldCalls,0)) AS AbandonHoldCalls
 ,(SUM(ISNULL(SGI.AbandonRingTime,0)) + SUM(ISNULL(SGI.RouterDelayQAbandTime, 0)))
  /(
	 CASE (SUM(ISNULL(SGI.RouterCallsAbandQ,0)) + SUM(ISNULL(SGI.RouterCallsAbandToAgent,0))) 
	 WHEN 0 THEN 1 
	 ELSE (SUM(ISNULL(SGI.RouterCallsAbandQ,0)) + SUM(ISNULL(SGI.RouterCallsAbandToAgent,0))) 
	 END) AS avgAbandWaitTime
 ,(SUM(ISNULL(SGI.AbandonRingTime,0)) + SUM(ISNULL(SGI.RouterDelayQAbandTime, 0))) AS AbandWaitTime
 ,SUM(ISNULL(SGI.ServiceLevelCalls, 0)) * 1.0 AS SL30Numerator
 ,(SUM(ISNULL(SGI.CallsAnswered,0)) + SUM(ISNULL(SGI.RouterCallsAbandToAgent,0)) + SUM(ISNULL(SGI.RouterCallsAbandQ,0))) * 1.0 AS SL30Denominator
 ,SUM(ISNULL(SGI.ServiceLevelCalls, 0)) * 1.0
  /(
	 CASE (SUM(ISNULL(SGI.CallsAnswered,0)) + SUM(ISNULL(SGI.RouterCallsAbandToAgent,0)) + SUM(ISNULL(SGI.RouterCallsAbandQ,0))) 
	 WHEN 0 THEN 1
	 ELSE (SUM(ISNULL(SGI.CallsAnswered,0)) + SUM(ISNULL(SGI.RouterCallsAbandToAgent,0)) + SUM(ISNULL(SGI.RouterCallsAbandQ,0)))
	 END) AS SL30
 ,(SUM(ISNULL(SGI.RouterCallsAbandToAgent,0)) + SUM(ISNULL(SGI.RouterCallsAbandQ, 0))) * 1.0
  /(
     CASE  (SUM(ISNULL(SGI.CallsAnswered,0)) + SUM(ISNULL(SGI.RouterCallsAbandQ,0)) + SUM(ISNULL(SGI.RouterCallsAbandToAgent,0)))
	 WHEN 0 THEN 1 
	 ELSE  (SUM(ISNULL(SGI.CallsAnswered,0)) + SUM(ISNULL(SGI.RouterCallsAbandQ,0)) + SUM(ISNULL(SGI.RouterCallsAbandToAgent,0)))
	 END) AS LCR

 ,(
	SUM(ISNULL(SGI.HandledCallsTime,0)) +
	SUM(ISNULL(SGI.ReservedStateTime,0))
  ) * 1.0
  /(
    CASE SUM(ISNULL(SGI.CallsHandled,0))
    WHEN 0 THEN 1
	ELSE SUM(ISNULL(SGI.CallsHandled,0))
	END) AS AHT
 ,(
	SUM(ISNULL(SGI.HandledCallsTime,0)) +
	SUM(ISNULL(SGI.ReservedStateTime,0))
  ) AS HT
 ,MAX(RouterMaxCallsQueued) AS RouterMaxCallsQueued

FROM tPeriods tP
INNER JOIN #SGI SGI WITH (NOLOCK) ON
	SGI.[DateTime] >= tP.dtPeriodBegin
	AND DATEADD(MINUTE,15,SGI.[DateTime]) <= tP.dtPeriodEnd
LEFT JOIN Skill_Group SG WITH (NOLOCK) ON
	SGI.SkillTargetID = SG.SkillTargetID
GROUP BY tP.dtPeriodBegin, SGI.SkillTargetID, SG.EnterpriseName
ORDER BY SGI.SkillTargetID, tP.dtPeriodBegin
OPTION(MAXRECURSION 0)
