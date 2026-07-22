# Campaign_Historical_Calls_Summary

## Historical Report
**Data Source:** `STAT_DB` via optimized staging tables `#TCL` (`tContactLog`), `#TCD` (`t_Termination_Call_Detail`), `#TT` (correlated bridge table), and `tDRDZ_LoadedRecordsDay`.

*Note: The `tDRDZ_LoadedRecordsDay` staging table is populated and maintained via an automated database job named `pull_DRDZ_LoadedRecordsDay`.*

### Report Filters

| Parameter | Description | Required | Comments |
| :--- | :--- | :---: | :--- |
| `@BeginDate` | Interval Start | Yes | Minimum boundary constraint for data selection |
| `@EndDate` | Interval End | Yes | Maximum boundary constraint for data selection |
| `@CampaignList` | Campaigns | Yes | Multi-select allowed. Converted into an internal string-split table array (`@CL`). |

---

### Report Fields

| # | SQL Field Name | Report Display Name | Formula / Logic | Comments |
| :---: | :--- | :--- | :--- | :--- |
| 0 | `D` | Date | `CONVERT(DATE, tcl.TimeFrom)` | Truncates timestamp to date only. |
| 1 | `CampaignName` | Campaign Name | `tCampaign.CampaignName` | Resolved via configuration layer map. |
| 2 | `CampaignID` | Campaign ID | `res.CampaignID` | Unique outbound campaign identifier. |
| 3 | `NumRecords` | Total Records Loaded | `SUM(NumRecords)` via `tDRDZ_LoadedRecordsDay` | Total customer record profiles uploaded into the dialer database. |
| 4 | `NumAttemps` | Attempts | `SUM(NumAttemps)` via `NumAttemptsCalc` | Count of records where `ClientCallDialingStartTime IS NOT NULL`. |
| 5 | `rVoice` | Calls Connected to Agent | `PhoneResultId IN (0, 1)` | Successful live voice connections routed to an operator. |
| 6 | `rBusy` | Busy | `PhoneResultId IN (301, 308)` | Destination target returned a busy signal. |
| 7 | `rWrongNumber` | Wrong Number | `PhoneResultId = 304` | Invalid target directory number. |
| 8 | `rNoAnswer` | No Answer | `PhoneResultId IN (303, 310, 312)` | Dialer timeout or ring-no-answer. |
| 9 | `rAgentError` | Agent Delivery Error | `PhoneResultId BETWEEN 200 AND 209` OR `299` | Call dropped during delivery to an operator hardware profile. |
| 10 | `rTelephonyError` | Telephony Error | `PhoneResultId BETWEEN 210-212`, `313-315`, OR `IN (-2, 305)` | Telecommunication network transit or hardware failures. |
| 11 | `rClientReject` | Client Disconnect | `PhoneResultId IN (300, 316)` OR `BETWEEN 306 AND 307` | Active customer hang-up or immediate call rejection. |
| 12 | `rSystemError` | System Error | `PhoneResultId IN (-1, 399, 500, 600, 700)` OR `BETWEEN -3/-5`, `213/214`, `317/318`, `100/104`, `400/401` | Contact center platform internal execution and processing exceptions. |
| 13 | `rFAX` | Fax / Answering Machine | `PhoneResultId BETWEEN 2 AND 3` OR `IN (309, 311)` | Machine/Automated answering system detection. |
| 14 | `pAgent` | % Connected to Agent | `SUM(rVoice) * 1.0 / SUM(NumAttemps)` | Percent of active attempts that successfully connected to an agent. |
| 15 | `pWrongNumber` | % Wrong Number | `SUM(rWrongNumber) * 1.0 / SUM(NumAttemps)` | Ratio of invalid destination records over total attempts. |
| 16 | `pFAX` | % Fax / Answering Machine | `SUM(rFAX) * 1.0 / SUM(NumAttemps)` | Ratio of machine responses over total attempts. |
| 17 | `TalkingTime` | Total Talk Time | `SUM(TalkTime)` via `#TT` cache | Combined active agent talk duration in seconds. |
| 18 | `AwgTalkTime` | Average Handle Time (AHT) | `AVG(TalkTime) + AVG(HoldTime)` | Average interaction session duration (Talk Time + Customer Hold Time). |
| - | `TCDVoice` | Telephony Verified Handled | `COUNT(*)` across verified connected legs | *Internal verification metric mapping standard telephony handled calls counter.* |

---

## Technical Calculations & Underlying Logic

### 1. Advanced Asynchronous Subsystem Bridge (`#TT` Assembly)
Since Outbound Campaign logs and Call Control data streams operate in asynchronous architectural spaces, a highly specific correlation algorithm is applied to construct the temporary bridge dataset `#TT`:
* **Caller ID Normalization (10-Digit Right Alignment):** To bypass prefix variance (e.g., country codes `+7`, `7`, trunk code `8`), phone values are compared via a 10-digit right-aligned string substring lookup protected by a binary collation constraint:
  ```sql
  RIGHT((CAST(CL.PhoneNumber AS varchar(32)) COLLATE Cyrillic_General_BIN), 10) = RIGHT(TCD.ANI, 10)
  ```
* **Contextual Token Resolution:** The internal campaign contact pointer (`CL.ContactId`) is dynamically cross-referenced from Cisco Unified CC Call Control's custom Peripheral Variable 4 parameter slot (`TCD.Variable4`), heavily guarded by a numeric format validator:
  ```sql
  CL.ContactId = CASE WHEN ISNUMERIC(TCD.Variable4) = 1 THEN CAST(TCD.Variable4 AS int) ELSE 0 END
  ```
* **Time Drift Buffer (2-Second Adjacency Window):** To compensate for clock synchronization discrepancies between the Outbound Dialer engine and the central ICM Call Control servers, an execution window adjustment is enforced:
  ```sql
  DATEADD(SECOND, -2, CL.ClientCallDialingEndTime) <= MIN(TCDSTARTS.DateTime)
  AND DATEADD(SECOND, 2, CL.AgentCallDistributedTime) > MIN(TCDSTARTS.DateTime)
  ```
  This guarantees that telephony records are accurately linked to the dialer attempt, even if their database timestamps differ by up to 2 seconds.

### 2. Multi-Layer Aggregate Rollup (`UNION ALL` Pattern)
To maximize query performance and eliminate data distortion or missing row records caused by temporal discrepancies in `LEFT JOIN` structures, the final dataset employs a vertical consolidation pipeline:
* Separate pre-aggregated layers (`ResultSumCalc`, `NumOfRecordsCalc`, `NumAttemptsCalc`, and `TalkingTimeCalc`) isolate specific calculations.
* These layers are unified via a `UNION ALL` block under a virtualized zero-padded mask template.
* The outer statement applies a final grouping pass (`GROUP BY D, CampaignID, tCampaign.CampaignName`), flattening the consolidated stacks into a single, clean historical performance row per day and campaign.
