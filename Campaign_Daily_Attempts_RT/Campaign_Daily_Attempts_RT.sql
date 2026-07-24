BEGIN
SET ANSI_WARNINGS ON
SET NOCOUNT ON

-- 1 - Day, 2 - Week, 3 - Month
DECLARE @Period INT = :Period


DECLARE @BeginDate DATETIME =	CASE @Period 
									WHEN 1 THEN DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()),0)
									WHEN 2 THEN DATEADD(WEEK, DATEDIFF(WEEK, 0, GETDATE()),0)
									WHEN 3 THEN DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()),0)
								END

DECLARE @EndDate DATETIME = GETDATE()


DECLARE @CampaignList VARCHAR(MAX) = CONCAT('(', :CampaignList , ')')


DECLARE @CL table (id int)
  INSERT INTO @CL (id)
  SELECT * FROM STRING_SPLIT(TRANSLATE(REPLACE(@CampaignList, 'null', ''), '()', '  '), ',')

DROP TABLE IF EXISTS #TCL


SELECT * INTO #TCL 
FROM tContactLog tcl WITH (NOLOCK) 
WHERE tcl.TimeFrom >= @BeginDate  AND tcl.TimeFrom < @EndDate AND tcl.CampaignID IN (SELECT id FROM @CL)


;WITH
ResultSumCalc AS
(
  SELECT CAST(TimeFrom AS DATE) AS DT, CampaignID,  PhoneResultId, COUNT(*) AS Total
  FROM #TCL
  WHERE ClientCallDialingStartTime IS NOT NULL
  GROUP BY CAST(TimeFrom AS DATE), CampaignID, PhoneResultId 
),


NumAttemptsCalc AS
(
  SELECT
	CAST(TimeFrom AS DATE) AS DT,  
    CampaignID,
	COUNT(*) AS NumAttemps
  FROM #TCL
  WHERE ClientCallDialingStartTime IS NOT NULL
  GROUP BY CAST(TimeFrom AS DATE), CampaignID
)




SELECT
 DT
 ,CampaignID
 ,tCampaign.CampaignName
 ,SUM(NumAttemps) AS NumAttemps
 ,SUM(rVoice) AS rVoice
 ,pVoice = CASE SUM(NumAttemps) WHEN 0 THEN 0 ELSE SUM(rVoice)*1.0/SUM(NumAttemps) END
 ,SUM(rWrongNumber) AS rWrongNumber
 ,pWrongNumber = CASE SUM(NumAttemps) WHEN 0 THEN 0 ELSE SUM(rWrongNumber)*1.0/SUM(NumAttemps) END
 ,SUM(rBusy) AS rBusy
 ,pBusy = CASE SUM(NumAttemps) WHEN 0 THEN 0 ELSE SUM(rBusy)*1.0/SUM(NumAttemps) END
 ,SUM(rNoAnswer) AS rNoAnswer
 ,pNoAnswer = CASE SUM(NumAttemps) WHEN 0 THEN 0 ELSE SUM(rNoAnswer)*1.0/SUM(NumAttemps) END
 ,SUM(rAgentError) AS rAgentError
 ,pAgentError = CASE SUM(NumAttemps) WHEN 0 THEN 0 ELSE SUM(rAgentError)*1.0/SUM(NumAttemps) END
 ,SUM(rTelephonyError) AS rTelephonyError
 ,pTelephonyError = CASE SUM(NumAttemps) WHEN 0 THEN 0 ELSE SUM(rTelephonyError)*1.0/SUM(NumAttemps) END
 ,SUM(rClientReject) AS rClientReject
 ,pClientReject = CASE SUM(NumAttemps) WHEN 0 THEN 0 ELSE SUM(rClientReject)*1.0/SUM(NumAttemps) END 
 ,SUM(rSystemError) AS rSystemError
 ,pSystemError = CASE SUM(NumAttemps) WHEN 0 THEN 0 ELSE SUM(rSystemError)*1.0/SUM(NumAttemps) END 
 ,SUM(rFAX) AS rFAX
 ,pFAX = CASE SUM(NumAttemps) WHEN 0 THEN 0 ELSE SUM(rFAX)*1.0/SUM(NumAttemps) END

FROM
( SELECT
	DT
   ,CampaignID
   ,0 AS NumAttemps
   ,rVoice
   ,rWrongNumber
   ,rBusy
   ,rNoAnswer
   ,rAgentError
   ,rTelephonyError
   ,rClientReject   
   ,rSystemError
   ,rFAX
  FROM (SELECT
	DT
   ,CampaignID
   ,rVoice 		= SUM(CASE WHEN PhoneResultId = 0 OR PhoneResultId = 1 THEN Total ELSE 0 END)
   ,rWrongNumber 	= SUM(CASE WHEN PhoneResultId = 304 THEN Total ELSE 0 END)
   ,rBusy 		= SUM(CASE WHEN PhoneResultId = 301 OR PhoneResultId = 308 THEN Total ELSE 0 END)
   ,rNoAnswer 	= SUM(CASE WHEN PhoneResultId = 303 OR PhoneResultId = 310 OR PhoneResultId = 312 THEN Total ELSE 0 END)
   ,rAgentError = SUM(CASE WHEN (PhoneResultId BETWEEN 200 AND 209) OR PhoneResultId = 299 THEN Total ELSE 0 END)
   ,rTelephonyError = SUM(CASE WHEN (PhoneResultId BETWEEN 210 AND 212) OR (PhoneResultId BETWEEN 313 AND 315) OR PhoneResultId = -2 OR PhoneResultId = 305 THEN Total ELSE 0 END)
   ,rClientReject 	= SUM(CASE WHEN PhoneResultId = 300 OR PhoneResultId = 316 OR (PhoneResultId BETWEEN 306 AND 307) THEN Total ELSE 0 END)
   ,rSystemError 	= SUM(CASE WHEN PhoneResultId = -1 OR (PhoneResultId BETWEEN -3 AND -5) OR (PhoneResultId BETWEEN 213 AND 214) OR 
									(PhoneResultId BETWEEN 317 AND 318) OR (PhoneResultId BETWEEN 100 AND 104) OR PhoneResultId = 399 OR
									(PhoneResultId BETWEEN 400 AND 401) OR PhoneResultId = 500 OR PhoneResultId = 600 OR PhoneResultId = 700 THEN Total ELSE 0 END)
   ,rFAX 			= SUM(CASE WHEN (PhoneResultId BETWEEN 2 AND 3) OR PhoneResultId = 309 OR PhoneResultId = 311 THEN Total ELSE 0 END)
  FROM ResultSumCalc
  GROUP BY DT, CampaignID
  ) res


  UNION ALL 

  SELECT
	DT
   ,CampaignID
   ,NumAttemps
   ,0 AS rVoice
   ,0 AS rWrongNumber
   ,0 AS rBusy
   ,0 AS rNoAnswer
   ,0 AS rAgentError
   ,0 AS rTelephonyError
   ,0 AS rClientReject   
   ,0 AS rSystemError
   ,0 AS rFAX
  FROM NumAttemptsCalc


) res
LEFT JOIN tCampaign (nolock) ON res.CampaignID = tCampaign.CampaignId
GROUP BY DT, CampaignID, tCampaign.CampaignName 
ORDER BY DT, CampaignID

END
