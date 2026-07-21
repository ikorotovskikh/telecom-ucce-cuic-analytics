DECLARE @BeginDT DATETIME = :StartDate
DECLARE @EndDT   DATETIME = :EndDate 


;WITH 

LastLabels AS 
(
   SELECT L.Event, Region, ScriptName, L.CallGuid, L.ID  FROM tCVP_Labels L
   INNER JOIN (SELECT MAX(EventDT) AS MaxEventDT, CallGuid FROM tCVP_Labels
			   GROUP BY CallGuid
			  ) ML
   ON ML.MaxEventDT = L.EventDT AND  ML.CallGuid = L.CallGuid AND L.Event IS NOT NULL
   GROUP BY L.EventDT, L.CallGuid, L.Event,  L.ScriptName, L.Region, L.ID
),

XferFromSG AS 
(-- Find the skill groups the call is transferred from if any
  SELECT MAX(XFER_FROM.DateTime) AS MaxDT, XFER_FROM.SkillGroupSkillTargetID, T.SkillGroupSkillTargetID AS FindForSkillGroupSkillTargetID,  T.RouterCallKeyDay, T.RouterCallKey FROM t_Termination_Call_Detail T
  INNER JOIN (SELECT DateTime, SkillGroupSkillTargetID, RouterCallKeyDay, RouterCallKey FROM t_Termination_Call_Detail 
			 WHERE SkillGroupSkillTargetID is not NULL AND CallDisposition IN (28,29)
		    ) XFER_FROM
  ON T.RouterCallKeyDay = XFER_FROM.RouterCallKeyDay and T.RouterCallKey = XFER_FROM.RouterCallKey and XFER_FROM.DateTime < T.DateTime
  WHERE T.SkillGroupSkillTargetID IS NOT NULL AND T.DateTime >= @BeginDT AND T.DateTime < @EndDT
  GROUP BY XFER_FROM.SkillGroupSkillTargetID,  T.SkillGroupSkillTargetID, T.RouterCallKeyDay, T.RouterCallKey
),


TR AS 
(SELECT
	TCD.DigitsDialed AS TransferToDigitsDialed,
	TransferToSkill = (CASE ISNULL(SG.EnterpriseName,'')
								WHEN '' THEN SGV7.EnterpriseName
								ELSE SG.EnterpriseName
								END),
	TCD.ANI,
	TCD.DateTime AS TransferDateTime,
	TCD.SkillGroupSkillTargetID AS SkillID,
	AgentEnterpriseName = (CASE ISNULL(TCD.InstrumentPortNumber,0)
								WHEN 0 THEN NULL
								ELSE A.EnterpriseName
								END),
	AgentName = (CASE ISNULL(TCD.InstrumentPortNumber,0)
								WHEN 0 THEN NULL
								ELSE P.LastName + ' ' + P.FirstName
								END),
	TCD.InstrumentPortNumber AS AgentPhone,
	TCD.CallDisposition,
	TCD.AgentSkillTargetID,
	TCD.RoutedAgentSkillTargetID,
	TalkDuration = (CASE ISNULL(TCD.InstrumentPortNumber,0)
								WHEN 0 THEN 0
								ELSE TCD.Duration
								END),
	XFER_FROM_SG.SkillGroupSkillTargetID as TransferFromSkill,
	CASE WHEN XFER_FROM_SGNAME.EnterpriseName IS NULL 
			THEN CVP.ScriptName + '/' + CVP.Event
            ELSE XFER_FROM_SGNAME.EnterpriseName END AS TransferFrom,
	CASE WHEN CVP.Region IS NULL 
			THEN CT.EnterpriseName
            ELSE CVP.Region END AS TransferFromRegOrCT,
	TCD.RouterCallKeyDay,
	TCD.RouterCallKey,
    CVP.Event,
    CVP.Region,
	CVP.ScriptName
FROM t_Termination_Call_Detail TCD
LEFT OUTER JOIN t_Agent A ON A.SkillTargetID = TCD.AgentSkillTargetID
LEFT OUTER JOIN t_Person P ON A.PersonID = P.PersonID
LEFT OUTER JOIN t_Skill_Group SG ON TCD.SkillGroupSkillTargetID = SG.SkillTargetID
LEFT OUTER JOIN t_Skill_Group SGV7 ON TCD.Variable7 = SGV7.EnterpriseName
LEFT OUTER JOIN t_Call_Type CT ON TCD.CallTypeID = CT.CallTypeID
LEFT JOIN (-- Find the skill group the call is transferred from if any
		   SELECT * FROM XferFromSG XF
		   WHERE NOT EXISTS (
						     SELECT * FROM XferFromSG WHERE XF.FindForSkillGroupSkillTargetID = FindForSkillGroupSkillTargetID AND XF.RouterCallKeyDay = RouterCallKeyDay
														   AND XF.RouterCallKey = RouterCallKey AND MaxDT > XF.MaxDT
						    )
		  ) XFER_FROM_SG
ON TCD.RouterCallKeyDay = XFER_FROM_SG.RouterCallKeyDay AND TCD.RouterCallKey = XFER_FROM_SG.RouterCallKey AND TCD.SkillGroupSkillTargetID = XFER_FROM_SG.FindForSkillGroupSkillTargetID
LEFT JOIN t_Skill_Group XFER_FROM_SGNAME ON XFER_FROM_SG.SkillGroupSkillTargetID = XFER_FROM_SGNAME.SkillTargetID
LEFT JOIN (-- Find all CVP CallGUIDs within a call with corresponding labels data (not null)
		   SELECT MIN(DateTime) AS DT, RouterCallKeyDay, RouterCallKey, CVP.Event, CVP.Region, CVP.ScriptName FROM t_Termination_Call_Detail TCDCVPGUIDs
           INNER JOIN (-- some labels have the same max timestamp even for milliseconds. In this case select only one of them.
					   SELECT L.Event, L.Region, L.ScriptName, L.CallGuid FROM LastLabels L
					   INNER JOIN (SELECT MAX(ID) AS MaxID, CallGuid FROM tCVP_Labels
								   GROUP BY CallGuid
					   		      ) ML 
					   ON L.CallGuid = ML.CallGuid
					  ) CVP 
		   ON TCDCVPGUIDs.CallGUID = CVP.CallGuid AND CVP.CallGuid IS NOT NULL
		   GROUP BY  RouterCallKeyDay, RouterCallKey, CVP.Event, CVP.Region, CVP.ScriptName
		 ) CVP 
ON CVP.RouterCallKeyDay = TCD.RouterCallKeyDay AND CVP.RouterCallKey = TCD.RouterCallKey

WHERE TCD.DateTime >= @BeginDT AND TCD.DateTime < @EndDT
  AND (TCD.SkillGroupSkillTargetID IN (:SkillGroups) OR SGV7.SkillTargetID IN (:SkillGroups)) 
  AND (TCD.InstrumentPortNumber is NOT NULL OR  TCD.InstrumentPortNumber is NULL AND (TCD.NetworkSkillGroupQTime > 0 OR TCD.LocalQTime > 0))
)

SELECT DISTINCT TR.*, TCD2.DurationFull FROM TR
LEFT JOIN (
		   SELECT MAX(TCD.Duration) AS DurationFull, TCD.RouterCallKey,TCD.RouterCallKeyDay
		   FROM t_Termination_Call_Detail TCD 
		   WHERE TCD.DateTime >= @BeginDT AND TCD.DateTime < @EndDT 
		   GROUP BY RouterCallKey, RouterCallKeyDay
		  ) TCD2 
ON (TR.RouterCallKey = TCD2.RouterCallKey and TR.RouterCallKeyDay = TCD2.RouterCallKeyDay)
ORDER BY TR.RouterCallKey
