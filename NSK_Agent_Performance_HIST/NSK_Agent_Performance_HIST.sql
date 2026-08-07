DECLARE @dtBegin DATETIME = :StartTime
DECLARE @dtEnd DATETIME = :EndTime
DECLARE @SGL VARCHAR(MAX) = CONCAT('(', :SkillGroups, ')')
DECLARE @AGL VARCHAR(MAX) = CONCAT('(', :Agents, ')')

exec [dbo].[SP_REPORT_1LTP_NSK_HIST_OPERATORS_V1]   @dtBegin, @dtEnd, @SGL, @AGL;
