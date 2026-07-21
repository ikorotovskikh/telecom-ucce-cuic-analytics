DECLARE @Since datetime
SELECT @Since = DATEADD(DAY,-3,getDate());

--Synchronize the target table with refreshed data from source table on s66dbmss001pr02 (10.184.24.79, CVP Replica)
MERGE [STAT_DB].[dbo].[tCVP_Labels] AS TARGET
USING
(
-- Select contains all labels for calls from @Since
SELECT DISTINCT
 cl.startdatetime AS StartDT,
 cl.enddatetime AS EndDT,
 vxed.eventdatetime AS EventDT,
 LEFT(vxed.varvalue, 255) AS Event,
 LEFT(reg.RegionID, 4) AS RegionID,
 LEFT(reg.Region, 255) AS Region,
 LEFT(vxs.appname,51) AS ScriptName,
 LEFT(cl.ani,32) AS ANI,
 LEFT(cl.dnis,32) AS DNIS,
 cl.callguid AS CallGuid,
 vxs.sessionid AS SessionID,
 vxe.elementid AS ElementID
FROM [s66dbmss001pr02].[CVP].[dbo].[call] cl WITH (NOLOCK)
INNER JOIN [s66dbmss001pr02].[CVP].[dbo].[vxmlsession] vxs WITH (NOLOCK) ON vxs.callguid = cl.callguid AND vxs.callstartdate = cl.callstartdate
INNER JOIN [s66dbmss001pr02].[CVP].[dbo].[vxmlelement] vxe WITH (NOLOCK) ON vxe.callguid = cl.callguid AND vxe.callstartdate = cl.callstartdate AND vxe.sessionid = vxs.sessionid
INNER JOIN [s66dbmss001pr02].[CVP].[dbo].[vxmlelementdetail] vxed WITH (NOLOCK) ON vxed.elementid = vxe.elementid AND vxed.callstartdate = vxe.callstartdate AND vxed.varname IN ('ReportData','EndCall')
LEFT JOIN
 (
 SELECT vxereg.callguid,vxereg.callstartdate, vxedreg.varvalue AS Region, vxedregid.varvalue AS RegionID
 FROM [s66dbmss001pr02].[CVP].[dbo].[vxmlelement] vxereg WITH (NOLOCK)
 INNER JOIN [s66dbmss001pr02].[CVP].[dbo].[vxmlelementdetail] vxedreg WITH (NOLOCK) ON vxedreg.varname = 'RegionAbonent' AND vxedreg.elementid = vxereg.elementid AND vxedreg.callstartdate = vxereg.callstartdate
 INNER JOIN [s66dbmss001pr02].[CVP].[dbo].[vxmlelementdetail] vxedregid WITH (NOLOCK) ON vxedregid.varname = 'RegionIDAbonent' AND vxedregid.elementid = vxereg.elementid AND vxedregid.callstartdate = vxereg.callstartdate
 WHERE vxereg.elementname in ('LOG_Region_City','Database_GetRegion', 'SET_REGION')
	AND (vxereg.enterdatetime) >= @Since
 GROUP BY vxereg.callguid,vxereg.callstartdate, vxedreg.varvalue, vxedregid.varvalue
 ) reg ON reg.callguid = cl.callguid AND reg.callstartdate = cl.callstartdate
 WHERE (cl.startdatetime) >= @Since
) AS SOURCE 
ON (TARGET.Event = SOURCE.Event) AND (TARGET.CallGuid = SOURCE.CallGuid) AND (TARGET.ElementID = SOURCE.ElementID) 

-- When records on source DB are matched and above select contains newer EndDT (the call can be not finished yet at the time of an import), update the record
WHEN MATCHED AND  (TARGET.EndDT IS NULL AND SOURCE.EndDT IS NOT NULL)
  THEN 
    UPDATE SET TARGET.StartDT = SOURCE.StartDT, TARGET.EndDT = SOURCE.EndDT, TARGET.EventDT = SOURCE.EventDT, 
	TARGET.Event = SOURCE.Event, TARGET.RegionID = SOURCE.RegionID, TARGET.Region = SOURCE.Region, TARGET.ScriptName = SOURCE.ScriptName, 
	TARGET.ANI = SOURCE.ANI, TARGET.CallGuid = SOURCE.CallGuid, TARGET.SessionID = SOURCE.SessionID, TARGET.ElementID = SOURCE.ElementID, TARGET.DNIS = SOURCE.DNIS
	

--When no records on the source DB are matched, then insert the incoming records from the source table to the target table
WHEN NOT MATCHED BY TARGET AND (SOURCE.CallGuid IS NOT NULL) AND (SOURCE.StartDT >= @Since) 
  THEN INSERT (StartDT, EndDT, EventDT, Event, RegionID, Region, ScriptName, ANI, CallGuid, SessionID, ElementID, DNIS) 
	VALUES (SOURCE.StartDT, SOURCE.EndDT, SOURCE.EventDT, SOURCE.Event, SOURCE.RegionID, SOURCE.Region, SOURCE.ScriptName, SOURCE.ANI, SOURCE.CallGuid, SOURCE.SessionID, SOURCE.ElementID, SOURCE.DNIS);
