DECLARE @BeginDT DATETIME = :BeginDate
DECLARE @EndDT   DATETIME = :EndDate


DECLARE @NPPL VARCHAR(MAX) = CONCAT('(', :NPPLocations, ')')	



DECLARE @nppLList table (id int)
  INSERT INTO @nppLList (id)
  SELECT * FROM STRING_SPLIT(TRANSLATE(REPLACE(@NPPL, 'null', ''), '()', '  '), ',')
  
DECLARE @dnisListfromLocations table (id varchar(32))
  INSERT INTO @dnisListfromLocations (id)
   SELECT Script_DNIS FROM tNPP_TelNumbers
   WHERE  NPPLocationID IN (SELECT id FROM @nppLList) 

DROP TABLE IF EXISTS #LL
DROP TABLE IF EXISTS #LABELS




SELECT
 cl.startdatetime AS StartDT,
 cl.enddatetime AS EndDT,
 vxed.eventdatetime AS EventDT,
 vxed.varvalue AS Event,
 reg.RegionID AS RegionID,
 reg.Region AS Region,
 vxs.appname AS ScriptName,
 cl.ani AS ANI,
 cl.dnis AS DNIS,
 cl.callguid AS CallGuid,
 vxs.sessionid AS SessionID,
 vxe.elementid AS ElementID
INTO #LL
FROM call cl WITH (NOLOCK)
INNER JOIN vxmlsession vxs WITH (NOLOCK) ON vxs.callguid = cl.callguid AND vxs.callstartdate = cl.callstartdate
INNER JOIN vxmlelement vxe WITH (NOLOCK) ON vxe.callguid = cl.callguid AND vxe.callstartdate = cl.callstartdate AND vxe.sessionid = vxs.sessionid
INNER JOIN vxmlelementdetail vxed WITH (NOLOCK) ON vxed.elementid = vxe.elementid AND vxed.callstartdate = vxe.callstartdate AND vxed.varname IN ('ReportData','EndCall')
LEFT JOIN
 (
 SELECT vxereg.callguid,vxereg.callstartdate, vxedreg.varvalue AS Region, vxedregid.varvalue AS RegionID
 FROM vxmlelement vxereg WITH (NOLOCK)
 INNER JOIN vxmlelementdetail vxedreg WITH (NOLOCK) ON vxedreg.varname = 'RegionAbonent' AND vxedreg.elementid = vxereg.elementid AND vxedreg.callstartdate = vxereg.callstartdate
 INNER JOIN vxmlelementdetail vxedregid WITH (NOLOCK) ON vxedregid.varname = 'RegionIDAbonent' AND vxedregid.elementid = vxereg.elementid AND vxedregid.callstartdate = vxereg.callstartdate
 WHERE vxereg.elementname in ('LOG_Region_City','Database_GetRegion', 'SET_REGION')
	AND vxereg.enterdatetime >= @BeginDT AND vxereg.enterdatetime < @EndDT 
 GROUP BY vxereg.callguid,vxereg.callstartdate, vxedreg.varvalue, vxedregid.varvalue
 ) reg ON reg.callguid = cl.callguid AND reg.callstartdate = cl.callstartdate
 WHERE vxed.eventdatetime >= @BeginDT AND vxed.eventdatetime < @EndDT



SELECT lnpp.ScriptName
      ,lnpp.EventDT
      ,lnpp.Event
	  ,lnpp.DNIS
	  ,l.CallGuid
INTO #LABELS 
FROM #LL l
INNER JOIN #LL lnpp ON l.CallGuid = lnpp.CallGuid AND  lnpp.EventDT >= l.EventDT
WHERE l.EventDT >= @BeginDT AND l.EventDT < @EndDT AND l.Event LIKE 'Begin_NPP_%_Welcome'


;WITH EventsCalc AS
(
SELECT ScriptName, DNIS, Event, COUNT(*) AS Total
FROM #LABELS
GROUP BY ScriptName, DNIS, Event
)


SELECT
   npptn.NPPLocation
  ,npptn.PSTN_DNIS
  ,DNIS
  ,ScriptName
  ,CallsEntered
  ,CallsDisconnnectedInWelcome
  ,CallsNonWorkingHours
  ,CallsEnterMenuClientEmployee
  ,CallsHangupBeforeChoiceMenu
  ,CallsDidntMakeAChoice
  ,CallsFromClient
  ,CallsDidntListenedToRecord
  ,CallsClientEnteredToSkill
  ,CallsEnteredMenuForInstallers
  ,CallsHangupBeforeInstallersMenu
  ,CallsApplicationRescheduled
  ,CallsApplicationCanceled
  ,CallsReSale
  ,CallsOtherQuestions
  ,CallsTechnicalQuestions
  ,CallsDidntChooseTopic
  ,CallsDidntChooseTopicTwice
  ,CallsDidntListenedToEvaluation
  ,CallsInstallerEnteredToSkill
  ,pCallsWorkingHours = CASE WHEN (ISNULL(CallsEntered, 0) - ISNULL(CallsNonWorkingHours, 0)) = 0 THEN 0 ELSE (ISNULL(CallsClientEnteredToSkill, 0) + ISNULL(CallsInstallerEnteredToSkill, 0))*1.0
																											  /(ISNULL(CallsEntered, 0) - ISNULL(CallsNonWorkingHours, 0)) END
  ,pCallsApplicationRescheduled = CASE WHEN (ISNULL(CallsApplicationRescheduled, 0) + ISNULL(CallsApplicationCanceled, 0) + ISNULL(CallsReSale, 0) 
											+ ISNULL(CallsOtherQuestions, 0) + ISNULL(CallsTechnicalQuestions, 0) + ISNULL(CallsDidntChooseTopicTwice, 0)) = 0 
									   THEN 0 
									   ELSE ISNULL(CallsApplicationRescheduled, 0)*1.0/(ISNULL(CallsApplicationRescheduled, 0) + ISNULL(CallsApplicationCanceled, 0) + ISNULL(CallsReSale, 0) 
											+ ISNULL(CallsOtherQuestions, 0) + ISNULL(CallsTechnicalQuestions, 0) + ISNULL(CallsDidntChooseTopicTwice, 0)) END
  ,pCallsApplicationCanceled = CASE WHEN (ISNULL(CallsApplicationRescheduled, 0) + ISNULL(CallsApplicationCanceled, 0) + ISNULL(CallsReSale, 0) 
											+ ISNULL(CallsOtherQuestions, 0) + ISNULL(CallsTechnicalQuestions, 0) + ISNULL(CallsDidntChooseTopicTwice, 0)) = 0 
									   THEN 0 
									   ELSE ISNULL(CallsApplicationCanceled, 0)*1.0/(ISNULL(CallsApplicationRescheduled, 0) + ISNULL(CallsApplicationCanceled, 0) + ISNULL(CallsReSale, 0) 
											+ ISNULL(CallsOtherQuestions, 0) + ISNULL(CallsTechnicalQuestions, 0) + ISNULL(CallsDidntChooseTopicTwice, 0)) END
  ,pCallsReSale = CASE WHEN (ISNULL(CallsApplicationRescheduled, 0) + ISNULL(CallsApplicationCanceled, 0) + ISNULL(CallsReSale, 0) 
											+ ISNULL(CallsOtherQuestions, 0) + ISNULL(CallsTechnicalQuestions, 0) + ISNULL(CallsDidntChooseTopicTwice, 0)) = 0 
									   THEN 0 
									   ELSE ISNULL(CallsReSale, 0)*1.0/(ISNULL(CallsApplicationRescheduled, 0) + ISNULL(CallsApplicationCanceled, 0) + ISNULL(CallsReSale, 0) 
											+ ISNULL(CallsOtherQuestions, 0) + ISNULL(CallsTechnicalQuestions, 0) + ISNULL(CallsDidntChooseTopicTwice, 0)) END
  ,pCallsOtherQuestions = CASE WHEN (ISNULL(CallsApplicationRescheduled, 0) + ISNULL(CallsApplicationCanceled, 0) + ISNULL(CallsReSale, 0) 
											+ ISNULL(CallsOtherQuestions, 0) + ISNULL(CallsTechnicalQuestions, 0) + ISNULL(CallsDidntChooseTopicTwice, 0)) = 0 
									   THEN 0 
									   ELSE ISNULL(CallsOtherQuestions, 0)*1.0/(ISNULL(CallsApplicationRescheduled, 0) + ISNULL(CallsApplicationCanceled, 0) + ISNULL(CallsReSale, 0) 
											+ ISNULL(CallsOtherQuestions, 0) + ISNULL(CallsTechnicalQuestions, 0) + ISNULL(CallsDidntChooseTopicTwice, 0)) END
  ,pCallsTechnicalQuestions = CASE WHEN (ISNULL(CallsApplicationRescheduled, 0) + ISNULL(CallsApplicationCanceled, 0) + ISNULL(CallsReSale, 0) 
											+ ISNULL(CallsOtherQuestions, 0) + ISNULL(CallsTechnicalQuestions, 0) + ISNULL(CallsDidntChooseTopicTwice, 0)) = 0 
									   THEN 0 
									   ELSE ISNULL(CallsTechnicalQuestions, 0)*1.0/(ISNULL(CallsApplicationRescheduled, 0) + ISNULL(CallsApplicationCanceled, 0) + ISNULL(CallsReSale, 0) 
											+ ISNULL(CallsOtherQuestions, 0) + ISNULL(CallsTechnicalQuestions, 0) + ISNULL(CallsDidntChooseTopicTwice, 0)) END
   ,pCallsDidntChooseTopic = CASE WHEN (ISNULL(CallsApplicationRescheduled, 0) + ISNULL(CallsApplicationCanceled, 0) + ISNULL(CallsReSale, 0) 
											+ ISNULL(CallsOtherQuestions, 0) + ISNULL(CallsTechnicalQuestions, 0) + ISNULL(CallsDidntChooseTopicTwice, 0)) = 0 
									   THEN 0 
									   ELSE ISNULL(CallsDidntChooseTopicTwice, 0)*1.0/(ISNULL(CallsApplicationRescheduled, 0) + ISNULL(CallsApplicationCanceled, 0) + ISNULL(CallsReSale, 0) 
											+ ISNULL(CallsOtherQuestions, 0) + ISNULL(CallsTechnicalQuestions, 0) + ISNULL(CallsDidntChooseTopicTwice, 0)) END 
FROM
(
  SELECT 
   EventsCalc.DNIS
  ,EventsCalc.ScriptName
  ,CallsEntered = SUM(CASE WHEN Event LIKE 'Begin_NPP_%_Welcome' THEN Total ELSE 0 END)
  ,CallsDisconnnectedInWelcome = SUM(CASE WHEN Event = 'AR_NPP_%_Welcome_EndCall' THEN Total ELSE 0 END)
  ,CallsNonWorkingHours = SUM(CASE WHEN Event LIKE 'AR_NPP_%_NotWork_EndCall' THEN Total ELSE 0 END)
  ,CallsEnterMenuClientEmployee = SUM(CASE WHEN Event LIKE 'NPP_%_Vybor' THEN Total ELSE 0 END)
  ,CallsHangupBeforeChoiceMenu = SUM(CASE WHEN Event LIKE 'AR_NPP_%_Vybor_EndCall' THEN Total ELSE 0 END)
  ,CallsDidntMakeAChoice = SUM(CASE WHEN Event LIKE 'EER_NPP_%_NN_EndCall' THEN Total ELSE 0 END)
  ,CallsFromClient = SUM(CASE WHEN Event LIKE 'NPP_%_Client' THEN Total ELSE 0 END)
  ,CallsDidntListenedToRecord = SUM(CASE WHEN Event LIKE 'AR_NPP_%_Zapisi_EndCall' THEN Total ELSE 0 END)
  ,CallsClientEnteredToSkill = SUM(CASE WHEN Event LIKE 'OER_NPP_%_Client_TransAgent' THEN Total ELSE 0 END)
  ,CallsEnteredMenuForInstallers = SUM(CASE WHEN Event LIKE 'NPP_%_MM' THEN Total ELSE 0 END)
  ,CallsHangupBeforeInstallersMenu = SUM(CASE WHEN Event LIKE 'AR_NPP_%_MM_EndCall' THEN Total ELSE 0 END)
  ,CallsApplicationRescheduled = SUM(CASE WHEN Event LIKE 'NPP_%_Perenos zayavki' THEN Total ELSE 0 END)
  ,CallsApplicationCanceled = SUM(CASE WHEN Event LIKE 'NPP_%_Otmena zayavki' THEN Total ELSE 0 END)
  ,CallsReSale = SUM(CASE WHEN Event LIKE 'NPP_%_Prodazha' THEN Total ELSE 0 END)
  ,CallsOtherQuestions = SUM(CASE WHEN Event LIKE 'NPP_%_Drugie_voprosy' THEN Total ELSE 0 END)
  ,CallsTechnicalQuestions = SUM(CASE WHEN Event = 'OER_NPP_DV_NTPVS_TransAgent' THEN Total ELSE 0 END)
  ,CallsDidntChooseTopic = SUM(CASE WHEN Event LIKE 'NPP_%_NN1_goto_MM_NPP' THEN Total ELSE 0 END)
  ,CallsDidntChooseTopicTwice = SUM(CASE WHEN Event LIKE 'OER_NPP_%_NN2_EndCall' THEN Total ELSE 0 END)
  ,CallsDidntListenedToEvaluation = SUM(CASE WHEN Event LIKE 'AR_NPP_%_Ocenka_EndCall' THEN Total ELSE 0 END)
  ,CallsInstallerEnteredToSkill = SUM(CASE WHEN Event LIKE 'OER_NPP_%_TransAgent' THEN Total ELSE 0 END)
 
  FROM EventsCalc
  GROUP BY EventsCalc.ScriptName, EventsCalc.DNIS
) ec
LEFT JOIN tNPP_TelNumbers npptn ON npptn.Script_DNIS = ec.DNIS
WHERE npptn.NPPLocation IS NOT NULL 
AND ec.ScriptName != 'PCS_NPP_B2C'	
AND ec.DNIS IN (SELECT id FROM @dnisListfromLocations)
