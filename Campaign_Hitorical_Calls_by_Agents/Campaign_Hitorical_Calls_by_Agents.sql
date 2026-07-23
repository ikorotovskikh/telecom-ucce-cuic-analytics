BEGIN
SET ANSI_WARNINGS ON
SET NOCOUNT ON

DECLARE @BeginDate DATETIME = :BeginDate
DECLARE @EndDate DATETIME = :EndDate


DECLARE @CampaignList VARCHAR(MAX) = CONCAT('(', :CampaignList , ')')



DECLARE @CL table (id int)
  INSERT INTO @CL (id)
  SELECT * FROM STRING_SPLIT(TRANSLATE(REPLACE(@CampaignList, 'null', ''), '()', '  '), ',')

DROP TABLE IF EXISTS #CL
DROP TABLE IF EXISTS #TCD

SELECT * INTO #CL 
FROM tContactLog tcl WITH (NOLOCK) 
WHERE tcl.TimeFrom >= @BeginDate  AND tcl.TimeFrom < @EndDate AND tcl.CampaignID IN (SELECT id FROM @CL) 

SELECT * INTO #TCD 
FROM t_Termination_Call_Detail tcd WITH (NOLOCK) 
WHERE DATEADD(SECOND, -1*Duration, DateTime) >= @BeginDate AND DATEADD(SECOND, -1*Duration, DateTime) <=  @EndDate 


SELECT

 'Автоматический ' AS CallType
 ,CL.CampaignID
 ,tCampaign.CampaignName
 ,tm.EnterpriseName AS Team
 ,tContact.LastName as AccountNumber
 ,tContact.ContactGId AS ClientID
 ,CL.ContactLogId
 ,CL.ContactId
 ,tContact.FirstName AS MRF
 ,tContact.MiddleName AS RF
 ,CL.PhoneResultId
 ,tPhoneResult.PhoneResultName AS PhoneResultText
 ,CL.PhoneStateId
 ,tPhoneState.PhoneStateName AS PhoneStateText
 ,CL.ContactStateId
 ,tContactState.ContactStateName AS ContactResultText
 ,CL.AgentId
 ,a.EnterpriseName AS Agent
 ,a.SkillTargetID
--     , CL.TimeFrom
--     , CL.TimeTo
--,CL.AgentCallDialingStartTime
-- ,CL.AgentCallDialingEndTime
--,CL.AgentCallApproveTime
 ,CL.AgentCallDistributedTime
 ,DATEADD(SECOND, -1*(TCD.WorkTime+TCD.TalkTime+TCD.HoldTime), TCD.DateTime) AS AgentConnectTime
 ,CL.ClientCallDialingStartTime
 ,CL.ClientCallAnswerTime
 ,CallDialingEndTime = CASE WHEN CL.ClientCallDialingEndTime IS NULL THEN CL.TimeTo ELSE CL.ClientCallDialingEndTime END
 ,CallPassToAgents = CASE WHEN CL.AgentId IS NULL THEN NULL ELSE DATEADD(SECOND, -1*TCD.Duration, TCD.DateTime) END
 ,DATEADD(SECOND, -1*TCD.WorkTime, TCD.DateTime) AS TCD_AgentCall_End_DT
 ,CallEndDT = CASE WHEN (CL.AgentId IS NULL OR TCD.AgentSkillTargetID IS NULL) THEN CASE WHEN CL.ClientCallDialingEndTime IS NULL THEN CL.TimeTo ELSE CL.ClientCallDialingEndTime END ELSE DATEADD(SECOND, -1*TCD.WorkTime, TCD.DateTime) END
 ,CallDuration = CASE WHEN CL.AgentId IS NULL THEN DATEDIFF(SECOND, CL.ClientCallDialingStartTime, 
																	CASE WHEN CL.ClientCallDialingEndTime IS NULL THEN CL.TimeTo ELSE CL.ClientCallDialingEndTime END) 
											  ELSE DATEDIFF(SECOND, CL.ClientCallDialingStartTime, CASE WHEN TCD.DateTime IS NULL 
																										THEN CL.ClientCallDialingEndTime 
																										ELSE DATEADD(SECOND, -1*TCD.WorkTime, TCD.DateTime) END ) 
				 END
 ,DialingDuration = DATEDIFF(SECOND, CL.ClientCallDialingStartTime, CASE WHEN CL.ClientCallDialingEndTime IS NULL THEN CL.TimeTo 
																		 ELSE CASE WHEN TCD.DateTime IS NULL 
																				   THEN CL.ClientCallDialingEndTime  
																				   ELSE DATEADD(SECOND, -1*TCD.Duration, TCD.DateTime) 
																			  END
																	END
							)		
 ,QueueTime = DATEDIFF(SECOND, CASE WHEN CL.AgentId IS NULL THEN NULL ELSE DATEADD(SECOND, -1*TCD.Duration, TCD.DateTime) END, DATEADD(SECOND, -1*(TCD.WorkTime+TCD.TalkTime+TCD.HoldTime), TCD.DateTime))
 ,TCD.TalkTime AS TCD_TalkTime
 ,TCD.HoldTime AS TCD_HoldTime
 ,TCD.WorkTime
 ,TCD.RouterCallKeyDay
 ,TCD.RouterCallKey
 ,CL.PhoneNumber
 ,' ' + CAST(CL.PhoneNumber AS VARCHAR(11))  AS PhNum
 ,CL.ContactDetailId
 ,CL.Attempt
 ,Attempts.AttemptsEKCB2C_2798
 ,CL.NextCallTime
 ,CL.DisconnectReason
 ,CL.SkillTargetId
 ,tTimeZone.TimeZoneName
 ,tContact.Priority
 ,CSExcluded.TimeTo AS ExclDateFix
 ,CSIncluded.TimeTo AS InsertDate 
 ,CSExcluded.TimeTo AS ExclDate
 
  FROM #CL AS CL

  LEFT JOIN tContact (nolock) ON CL.ContactId = tContact.ContactId
  LEFT JOIN tCampaign (nolock) ON CL.CampaignID = tCampaign.CampaignId
  LEFT JOIN tPhoneResult (nolock) ON CL.PhoneResultId=tPhoneResult.PhoneResultId 
  LEFT JOIN tPhoneState (nolock) ON CL.PhoneStateId=tPhoneState.PhoneStateId
  LEFT JOIN tContactState (nolock) ON CL.ContactStateId=tContactState.ContactStateId
  
  
  LEFT JOIN #CL CSIncluded ON CL.ContactId=CSIncluded.ContactId AND CSIncluded.ContactStateId = 1 
											AND CSIncluded.TimeTo = (SELECT MIN(TimeTo) FROM #CL 
																	 WHERE ContactId=CSIncluded.ContactId AND ContactStateId = 1 AND 
																		   TimeTo >= DATEADD(DAY, DATEDIFF(day, 0, CL.TimeTo), 0) AND
																		   TimeTo <= DATEADD(SECOND, -1, DATEDIFF(DD, 0, CL.TimeTo) +1 )
																	)
  LEFT JOIN #CL CSExcluded ON CL.ContactId=CSExcluded.ContactId AND ((CSExcluded.ContactStateId BETWEEN 110 AND 115) OR CSExcluded.ContactStateId = 121) 
											AND CSExcluded.TimeTo = (SELECT MAX(TimeTo) FROM #CL 
																	 WHERE ContactId=CSExcluded.ContactId AND (ContactStateId BETWEEN 110 AND 115 OR ContactStateId = 121) AND
																		   TimeTo >= DATEADD(DAY, DATEDIFF(day, 0, CL.TimeTo), 0) AND
																		   TimeTo <= DATEADD(SECOND,-1, DATEDIFF(DD, 0, CL.TimeTo) + 1)
																	 )										
											
  LEFT JOIN t_Agent (nolock) a ON CL.AgentId=a.PeripheralNumber  
  LEFT JOIN tTimeZone (nolock) ON tContact.TimeZoneId=tTimeZone.TimeZoneId
  LEFT JOIN #TCD TCD  
            ON	a.SkillTargetID = TCD.AgentSkillTargetID AND 
				CL.ContactId = CASE WHEN ISNUMERIC(TCD.Variable4) = 1 THEN CAST(TCD.Variable4 AS int) ELSE 0 END AND
				RIGHT((CAST(CL.PhoneNumber AS varchar(32)) COLLATE Cyrillic_General_BIN),10) = RIGHT(TCD.ANI,10) 
				AND DATEADD(SECOND, -2, CL.ClientCallDialingEndTime) <= 
				(SELECT MIN(DATEADD(SECOND, -1*Duration, DateTime)) FROM #TCD TCDSTARTS 
				 WHERE TCDSTARTS.RouterCallKey = TCD.RouterCallKey AND TCDSTARTS.RouterCallKeyDay = TCD.RouterCallKeyDay
				)-- 2 seconds adj 'cause might be time difference bw CTI Outbound and ICM times
				AND DATEADD(SECOND, 2, CL.AgentCallDistributedTime)  > (SELECT MIN(DATEADD(SECOND, -1*Duration, DateTime)) FROM #TCD TCDSTARTS 
				 WHERE TCDSTARTS.RouterCallKey = TCD.RouterCallKey AND TCDSTARTS.RouterCallKeyDay = TCD.RouterCallKeyDay
				) 


  LEFT OUTER JOIN t_Agent_Team_Member atm ON a.SkillTargetID = atm.SkillTargetID
  LEFT OUTER JOIN t_Agent_Team tm ON tm.AgentTeamID = atm.AgentTeamID
  LEFT JOIN (
				SELECT COUNT(Attempts.ContactLogId) + 1 AS AttemptsEKCB2C_2798, CL.ContactLogId 
				FROM #CL CL
				LEFT JOIN #CL Attempts ON CL.PhoneNumber = Attempts.PhoneNumber AND CL.ClientCallDialingStartTime > Attempts.ClientCallDialingStartTime
				GROUP BY CL.ContactLogId
		    ) Attempts ON Attempts.ContactLogId = CL.ContactLogId
  
  ORDER BY CL.TimeFrom, CL.TimeTo ASC
END
