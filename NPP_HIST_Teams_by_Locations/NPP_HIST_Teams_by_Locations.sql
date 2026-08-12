DECLARE @dtBegin DATETIME = :StartTime
DECLARE @dtEnd DATETIME = :EndTime

--@typeDT 0 - Произвольный интервал, 1 - Сутки, 2 - Часы, 3 - 15 минут
DECLARE @dtType INT = :typeDT 


DECLARE @LL VARCHAR(MAX) = CONCAT('(', :Locations, ')')	
DECLARE @ATL VARCHAR(MAX) = CONCAT('(', :Teams, ')')								
DECLARE @AGL VARCHAR(MAX) = CONCAT('(', :Agents, ')')

EXEC [dbo].[SP_REPORT_NPP_HIST_TEAMS_BY_LOCATIONS_V1]  @dtBegin, @dtEnd, @dtType, @LL, @ATL , @AGL;