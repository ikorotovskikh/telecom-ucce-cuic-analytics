# Campaign_Management_Performance

## Historical Report
**Data Source:** `STAT_DB` via optimized cached staging tables `#TCL` (`tContactLog`), `#TCD` (`t_Termination_Call_Detail`), `#TT` (correlated core bridge cache), and `tDRDZ_LoadedRecordsDay`.

*Note: The `tDRDZ_LoadedRecordsDay` staging table is populated and maintained via an automated database job named `pull_DRDZ_LoadedRecordsDay`.*

### Report Filters

| Parameter | Description | Required | Comments |
| :--- | :--- | :---: | :--- |
| `@BeginDate` | Interval Start | Yes | Maps to `:BeginDate`. Minimum boundary constraint for the data selection period. |
| `@EndDate` | Interval End | Yes | Maps to `:EndDate`. Maximum boundary constraint for the data selection period. |
| `@CampaignList` | Campaigns | Yes | Maps to `:CampaignList`. Multi-select allowed. Internally parsed into a numerical collection array (`@CL`). |

---

### Report Fields

| # | SQL Field Name | Report Display Name | Formula / Logic | Comments |
| :---: | :--- | :--- | :--- | :--- |
| 0 | `CampaignName` | Campaign | `tCampaign.CampaignName` | Resolved via database configuration layout match. |
| 1 | `D` | Date | `CONVERT(DATE, tcl.TimeFrom)` | Aggregation date key (timestamp truncated to calendar date). |
| 2 | `NumRecords` | Total Records Loaded | `SUM(NumRecords)` via `tDRDZ_LoadedRecordsDay` | Total customer record profiles uploaded into the dialer campaign. |
| 3 | `NumAgents` | Assigned Agents | `SUM(NumAgents)` via `NumOfAgentsCalc` | Distinct count of active `AgentId` operators logged into the campaign within the day. |
| 4 | `CampaignTime` | Campaign Operation Time | `SUM(CampaignTime)` via `#TT.CampaignCallDuration` | Summary duration of all call interactions initiated by the dialer loop. |
| 5 | `numAttemps` | Attempts | `SUM(numAttemps)` via `NumAttemptsCalc` | Total dial attempts counter where `ClientCallDialingStartTime IS NOT NULL`. |
| 6 | `callsSuccess` | Dialer Success Calls | `SUM(callsSuccess)` via `NumAttemptsCalc` | Outbound contacts delivered to an agent, or unhandled calls with `PhoneResultId = 209`. |
| 7 | `callsLost` | Dialer Lost Calls | `SUM(callsLost)` via `NumAttemptsCalc` | Dialer calls abandoned in queue/dropped where `AgentId IS NULL` and result is `209`. |
| 8 | `callsLostP` | Lost Calls % | `SUM(callsLost) * 1.0 / SUM(callsSuccess)` | **Zero-Division Protected:** Ratio of lost dialer contacts over successful deliveries. |
| 9 | `AgentTime` | Total Agent Work Time | `SUM(TalkTime + HoldTime + WorkTime)` | Total accumulated seconds spent by agents processing connections (Talk + Hold + ACW). |
| 10 | `ManHours` | Average Agent Load | `SUM(AgentTime) * 1.0 / SUM(NumAgents)` | **Zero-Division Protected:** Calculated distribution of work seconds across active assigned operators. |
| 11 | `numTCDVoiceCalls`| Telephony Handled Count | `COUNT(*)` via `AgentTimeCalc` | Total segment record row counter validated inside the `#TT` bridge cache. |
| 12 | `TalkingTime` | Total Talk Time | `SUM(TalkingTime)` via `AgentTimeCalc` | Combined active agent talk duration in seconds. |
| 13 | `awgTalkTime` | Avg Dialer Talk Time | `SUM(TalkingTime) * 1.0 / SUM(calls1s)` | **Zero-Division Protected:** Average conversation duration for calls lasting 1 second or longer. |
| 14 | `talkTimeP` | Talk Time Utilization % | `SUM(TalkingTime) * 1.0 / SUM(CampaignTime)` | **Zero-Division Protected:** Productive conversion ratio of pure talk time against global campaign duration. |
| 15 | `calls1s` | Calls (>= 1s) | `SUM(CASE WHEN TalkTime >= 1 THEN 1 ELSE 0 END)` | Volume of customer contacts lasting 1 second or longer. |
| 16 | `calls1sTime` | Total Time (>= 1s) | `SUM(CASE WHEN TalkTime >= 1 THEN TalkTime ELSE 0 END)` | Aggregated seconds accumulated across connections lasting 1 second or longer. |
| 17 | `calls5s` | Calls (>= 5s) | `SUM(CASE WHEN TalkTime >= 5 THEN 1 ELSE 0 END)` | Volume of customer contacts lasting 5 seconds or longer. |

---

## Technical Calculations & Underlying Logic

### 1. Asynchronous Subsystem Handshaking (`#TT` Assembly)
Since Outbound Campaign Dialer logs (`#TCL`) and core Call Control switching streams (`#TCD`) operate on separate database layer contexts, records are linked using a specialized multi-variable validation criteria matrix:
* **Caller ID Normalization (10-Digit Right Alignment):** To bypass telephony routing prefix variances (`+7`, `8`, `7`), phone values are compared via a 10-digit right-aligned character string lookup protected by a binary collation constraint:
  ```sql
  RIGHT((CAST(CL.PhoneNumber AS varchar(32)) COLLATE Cyrillic_General_BIN), 10) = RIGHT(TCD.ANI, 10)
  ```
* **Contextual Token Resolution:** The internal campaign contact pointer (`CL.ContactId`) is dynamically cross-referenced from Cisco Unified CC Call Control's custom Peripheral Variable 4 parameter slot (`TCD.Variable4`), heavily guarded by an inline format validator:
  ```sql
  CL.ContactId = CASE WHEN ISNUMERIC(TCD.Variable4) = 1 THEN CAST(TCD.Variable4 AS int) ELSE 0 END
  ```
* **Asynchronous Time Drift Buffer (2-Second Window):** To compensate for clock synchronization discrepancies between the Outbound application nodes and central core ICM routing servers, a dual-edge temporal adjacency barrier checks the minimum segment execution time:
  ```sql
  DATEADD(SECOND, -2, CL.ClientCallDialingEndTime) <= MIN(DATEADD(SECOND, -1*Duration, DateTime))
  AND DATEADD(SECOND, 2, CL.AgentCallDistributedTime) > MIN(DATEADD(SECOND, -1*Duration, DateTime))
  ```

### 2. Multi-Layer Dataset Flattening Framework (`UNION ALL` Strategy)
To optimize execution profiles across deep historical logs and eliminate data distortion caused by temporal mismatches during standard `LEFT JOIN` operations, the code employs a specialized vertical stacking pattern:
* Separate pre-aggregated layers (`NumOfRecordsCalc`, `NumOfAgentsCalc`, `NumAttemptsCalc`, `AgentTimeCalc`, and specialized `#TT` duration extractions) isolate specific mathematical scopes.
* These individual layers are unified via a `UNION ALL` block under a virtualized zero-padded mask template.
* The outer statement applies a final grouping pass (`GROUP BY D, CampaignID, tCampaign.CampaignName`), flattening the consolidated stacks into a single, clean operational tracking row per day and campaign.

### 3. Progressive Arithmetic Division Exception Defense
To guarantee high grid stability inside Cisco CUIC presentation dashboards during early shifts or empty metrics intervals, all percentage/average metrics implement defensive conditional barriers:
```sql
callsLostP = CASE SUM(callsSuccess) WHEN 0 THEN 0 ELSE SUM(callsLost)*1.0/SUM(callsSuccess) END 
ManHours   = CASE SUM(NumAgents)    WHEN 0 THEN 0 ELSE SUM(AgentTime)*1.0/SUM(NumAgents) END
awgTalkTime = CASE SUM(calls1s)     WHEN 0 THEN 0 ELSE SUM(TalkingTime)*1.0/SUM(calls1s) END
talkTimeP  = CASE SUM(CampaignTime)  WHEN 0 THEN 0 ELSE SUM(TalkingTime)*1.0/SUM(CampaignTime) END
```
If the denominator yields `0`, the logic forcefully overrides standard SQL runtime behaviors to return `0` instead of throwing a critical division exception error, avoiding dashboard execution failures.
