BEGIN
SET ANSI_WARNINGS ON
SET NOCOUNT ON

DECLARE  @BeginDate varchar(30), @EndDate varchar(30)

SET @BeginDate = :BeginDate
SET @EndDate = :EndDate


SELECT CL.CampaignID
     , tCampaign.CampaignName
	 , CL.ContactLogId
     , CL.ContactId
	 , tContact.LastName as AccountNumber
	 , tContact.FirstName as Name
	 , tContact.MiddleName as ClientID
	 , CL.PhoneResultId
     , tPhoneResult.PhoneResultName as PhoneResultText
     , CL.PhoneStateId
	 , tPhoneState.PhoneStateName as PhoneStateText
     , CL.ContactStateId
	 , tContactState.ContactStateName as ContactResultText
     , CL.AgentId
     , t_Agent.EnterpriseName as Agent
     , CONVERT(VARCHAR(8), CAST(CL.TimeFrom AS TIME(0)), 108) as TimeFrom
	 , CAST(CL.TimeFrom AS DATE) as DateFrom
	 , CONVERT(VARCHAR(8), CAST(CASE WHEN TCD.Duration IS NOT NULL THEN DATEADD(SECOND, TCD.Duration, CL.TimeTo) ELSE CL.TimeTo END AS TIME(0)), 108) as TimeTo
	 , CAST(CASE WHEN  TCD.Duration IS NOT NULL THEN DATEADD(SECOND, TCD.Duration, CL.TimeTo) ELSE CL.TimeTo END AS DATE) as DateTo
	 , TCD.Duration
     , CL.PhoneNumber
     , CL.ContactDetailId
     , CL.Attempt
     , CL.NextCallTime
     , CL.ClientCallDialingStartTime
     , CL.ClientCallDialingEndTime
     , CL.ClientCallAnswerTime
     , CL.AgentCallDialingStartTime
     , CL.AgentCallDialingEndTime
     , CL.AgentCallApproveTime
     , CL.AgentCallDistributedTime
     , CL.DisconnectReason
     , CL.SkillTargetId
	 , tTimeZone.TimeZoneName
     , tContact.Priority
  FROM tContactLog (nolock) as CL

  LEFT JOIN tContact (nolock) ON CL.ContactId = tContact.ContactId
  LEFT JOIN tCampaign (nolock) ON CL.CampaignID = tCampaign.CampaignId
  LEFT JOIN tPhoneResult (nolock) ON CL.PhoneResultId=tPhoneResult.PhoneResultId 
  LEFT JOIN tPhoneState (nolock) ON CL.PhoneStateId=tPhoneState.PhoneStateId
  LEFT JOIN tContactState (nolock) ON CL.ContactStateId=tContactState.ContactStateId
  LEFT JOIN t_Agent (nolock) ON CL.AgentId=t_Agent.PeripheralNumber  
  LEFT JOIN tTimeZone (nolock) ON tContact.TimeZoneId=tTimeZone.TimeZoneId
  LEFT JOIN t_Termination_Call_Detail TCD (nolock) 
            ON CL.ContactId = CASE WHEN ISNUMERIC(TCD.Variable4) = 1 THEN CAST(TCD.Variable4 AS int) ELSE 0 END 
			AND (CAST(CL.PhoneNumber AS varchar(32)) COLLATE Cyrillic_General_BIN) = TCD.ANI 
  INNER JOIN (
    SELECT 
	   CL.CampaignID
	 , CL.ContactLogId
	 , CL.ContactId
	 , tContact.LastName 
	 , tContact.MiddleName 
	 , MAX(TCD.Duration) as MaxDuration
    FROM tContactLog CL
	LEFT JOIN tContact (nolock) ON CL.ContactId = tContact.ContactId
	LEFT JOIN t_Termination_Call_Detail TCD (nolock) 
            ON CL.ContactId = CASE WHEN ISNUMERIC(TCD.Variable4) = 1 THEN CAST(TCD.Variable4 AS int) ELSE 0 END 
			AND (CAST(CL.PhoneNumber AS varchar(32)) COLLATE Cyrillic_General_BIN) = TCD.ANI
	WHERE CampaignID IN (:CampaignIDs) AND  CL.TimeFrom >= @BeginDate  AND CL.TimeFrom < @EndDate
	GROUP BY CL.CampaignID, CL.ContactLogId, CL.ContactId, tContact.LastName, tContact.MiddleName, CL.AgentId
  ) max_dur ON  (max_dur.MaxDuration = TCD.Duration OR TCD.Duration IS NULL) AND
				max_dur.CampaignID = CL.CampaignID AND max_dur.ContactLogId = CL.ContactLogId AND
				max_dur.ContactId = CL.ContactId AND max_dur.LastName = tContact.LastName AND
				max_dur.MiddleName = tContact.MiddleName  
  
  WHERE CL.CampaignID IN (:CampaignIDs) AND  CL.TimeFrom >= @BeginDate  AND CL.TimeFrom < @EndDate
  ORDER BY CL.TimeFrom, CL.TimeTo ASC
END
