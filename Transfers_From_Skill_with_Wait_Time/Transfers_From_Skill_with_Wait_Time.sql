DECLARE @BeginDT DATETIME = :StartDate
DECLARE @EndDT   DATETIME = :EndDate

DROP TABLE IF EXISTS  #TCD

SELECT *  
INTO #TCD
FROM t_Termination_Call_Detail (nolock)
WHERE DateTime >= @BeginDT AND DateTime < @EndDT

;WITH TR AS (
SELECT DISTINCT
TCD.DigitsDialed AS TransferFromDN,
SG.EnterpriseName AS TransferFromSkill,
TCD.ANI,
TCD.DateTime,
RCD.BeganRoutingDateTime AS TransferDateTime,
A.EnterpriseName AS AgentEnterpriseName,
TCD.SkillGroupSkillTargetID AS SkillID,
P.LastName + ' ' + P.FirstName AS AgentName, 
TCD.InstrumentPortNumber AS AgentPhone,
RCD.DialedNumberString AS TransferToDN,
TCD.Duration AS FirstCallDuration,
TDN.Description AS TransferToDescription,
TCD.RouterCallKeyDay,
TCD.RouterCallKey
FROM #TCD TCD

LEFT OUTER JOIN (SELECT * FROM t_Route_Call_Detail (nolock)
   WHERE DateTime >= @BeginDT AND DateTime < @EndDT) RCD 
ON TCD.RouterCallKeyDay = RCD.RouterCallKeyDay
AND TCD.RouterCallKey = RCD.RouterCallKey
AND RCD.RouterCallKeySequenceNumber = TCD.RouterCallKeySequenceNumber + 1
LEFT OUTER JOIN t_Agent A ON A.SkillTargetID = TCD.AgentSkillTargetID
LEFT OUTER JOIN t_Person P ON A.PersonID = P.PersonID
LEFT OUTER JOIN t_Skill_Group SG ON TCD.SkillGroupSkillTargetID = SG.SkillTargetID
LEFT OUTER JOIN t_TransferDialedNumberStrings TDN ON RCD.DialedNumberString = TDN.DialedNumberString
WHERE TCD.CallDisposition IN (28,29)
  AND TCD.AgentSkillTargetID IS NOT NULL
  AND RCD.BeganRoutingDateTime IS NOT NULL
  AND TCD.SkillGroupSkillTargetID IN (:SkillGroups)
  AND SG.EnterpriseName != ISNULL(TDN.Description,'')
)

	
SELECT 
TR.TransferFromDN,
TR.TransferFromSkill,
TR.ANI,
TR.DateTime,
TR.TransferDateTime,
TR.AgentEnterpriseName,
TR.SkillID,
TR.AgentName, 
TR.AgentPhone,
TR.TransferToDN,
TR.FirstCallDuration,
--xFerToSG.SkillGroupSkillTargetID as TransferToSG_ID,
--SG.EnterpriseName as TransferToSG_Name,
--xFerToSG.DateTime as TransferToSG_DateTime,
-- Calculate Connected time after xFer to the SG from the row below the XFerTo TCD record 
WaitTime  = DATEDIFF(SECOND, TR.DateTime, 
								(SELECT  MAX(DateTime) AS ConnectedTime  FROM #TCD CT
								 WHERE CT.DateTime < xFerToSG.DateTime AND 
								       CT.RouterCallKey = TR.RouterCallKey AND 
									   CT.RouterCallKeyDay = TR.RouterCallKeyDay 
				                )
						),
TR.TransferToDescription,
TransferTo_SG_or_Desc = CASE WHEN xFerToSG.SkillGroupSkillTargetID IS NULL THEN TR.TransferToDescription ELSE SG.EnterpriseName END,
TR.RouterCallKeyDay,
TR.RouterCallKey,
TCD_DUR_TOTAL.DurationFull
  

FROM TR
LEFT JOIN
  -- Indentify xFerTo SkillGroup if any
  ( SELECT DateTime, SkillGroupSkillTargetID, RouterCallKeyDay, RouterCallKey FROM #TCD
    WHERE SkillGroupSkillTargetID IS NOT NULL
  ) xFerToSG
  ON TR.RouterCallKey = xFerToSG.RouterCallKey AND TR.RouterCallKeyDay = xFerToSG.RouterCallKeyDay 
  AND xFerToSG.DateTime = (SELECT MIN (DateTime) FROM #TCD 
						  WHERE xFerToSG.RouterCallKey = TR.RouterCallKey and xFerToSG.RouterCallKeyDay = TR.RouterCallKeyDay 
						  AND DateTime = (SELECT  MIN(DateTime) FROM #TCD NextSG
													  WHERE NextSG.DateTime > TR.DateTime AND 
															NextSG.SkillGroupSkillTargetID IS NOT NULL AND 
															NextSG.RouterCallKey = TR.RouterCallKey AND 
															NextSG.RouterCallKeyDay = TR.RouterCallKeyDay 
													  ))
  LEFT JOIN
   -- Calculate summary Duration 
  (SELECT MAX(TCD.Duration) AS DurationFull, TCD.RouterCallKey,TCD.RouterCallKeyDay FROM #TCD TCD 
   GROUP BY RouterCallKey, RouterCallKeyDay
  ) TCD_DUR_TOTAL 
 ON (TR.RouterCallKey = TCD_DUR_TOTAL.RouterCallKey AND TR.RouterCallKeyDay = TCD_DUR_TOTAL.RouterCallKeyDay)

 LEFT OUTER JOIN t_Skill_Group SG ON xFerToSG.SkillGroupSkillTargetID = SG.SkillTargetID
ORDER BY TR.DateTime
