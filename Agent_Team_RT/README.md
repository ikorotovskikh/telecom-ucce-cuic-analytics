# Agent_Team_RT

## Real-Time Report
**Data Source:** `STAT_DB` via cached staging tables `#TCL` (`tContactLog`), `#TCD` (`t_Termination_Call_Detail`), `#TT` (bridge cache), `Agent_Interval`, `Agent_Event_Detail`, and `t_Agent_Team`.  
**Timeframe:** Statistics are accumulated from midnight of the current day (`CAST(CAST(GETDATE() AS DATE) AS DATETIME)`).

### Report Filters

| Parameter | Description | Required | Comments |
| :--- | :--- | :---: | :--- |
| `@Teams` | Agent Teams | Yes | Maps to `:Teams`. Multi-select allowed. Internally parsed into a numerical collection array (`@atList`). |

---

### Report Fields

| # | SQL Field Name | Report Display Name | Formula / Logic | Comments |
| :---: | :--- | :--- | :--- | :--- |
| 0 | `Team` | Team | `tm.EnterpriseName` | Mapped agent team name profile (`t_Agent_Team`). |
| 1 | `Agent` | Agent | `a.EnterpriseName` | Operator full name / system username profile. |
| - | `AgentSkillTargetID`| Skill Target ID | `res.AgentSkillTargetID` | Internal unique hardware agent database key used for grouping. |
| - | `callsSuccess` | Dialer Success Calls | `SUM(callsSuccess)` via `NumAttemptsCalc` | Outbound dialer connections that successfully reached an agent line. |
| 2 | `calls1s` | Dialer Calls (>= 1s) | `SUM(calls1s)` via `NumCallsCalc` | Volume of automated outbound campaign contacts lasting 1 second or longer. |
| - | `calls1sTime` | Total Dialer Talk Time | `SUM(calls1sTime)` via `NumCallsCalc` | Total productive seconds accumulated via dialer campaigns. |
| 3 | `awgTalkTime1s` | Avg Dialer Talk Time (sec) | `CASE WHEN calls1s = 0 THEN 0 ELSE calls1sTime * 1.0 / calls1s END` | **Zero-Division Protected:** Average conversation duration for connected dialer legs. |
| 4 | `numManualOutCalls` | Manual Outbound Calls | `SUM(numManualOutCalls)` via `ManualOutCallsCalc` | Total volume of manually dialed outbound call attempts. |
| 5 | `numManualOutCalls1s` | Manual Outbound Calls (>= 1s) | `SUM(numManualOutCalls1s)` via `ManualOutCallsCalc` | Manual outbound calls that successfully connected for 1 second or longer. |
| - | `manualOutCalls1sTalkTime`| Total Manual Talk Time | `SUM(manualOutCalls1sTalkTime)` via `ManualOutCallsCalc` | Total productive seconds accumulated via manual dialing sessions. |
| - | `manualOutTalkingTime`| Raw Manual Talk Time | `SUM(manualOutTalkingTime)` | Complete summary duration of manual talk states. |
| 6 | `awgManualOutCallsTalkTime`| Avg Manual Talk Time (sec)| `CASE WHEN numManualOutCalls1s = 0 THEN 0 ELSE manualOutCalls1sTalkTime * 1.0 / numManualOutCalls1s END` | **Zero-Division Protected:** Average conversation duration for manually dialed contacts. |
| 7 | `numInboundCalls` | Inbound Calls | `SUM(numInboundCalls)` via `InboundCallsCalc` | Total established inbound customer conversations. |
| - | `inboundCallsTalkingTime`| Total Inbound Talk Time| `SUM(inboundCallsTalkingTime)` | Total talk duration in seconds for inbound traffic. |
| 8 | `avgInboundCallTalkingTime`| Avg Inbound Talk Time | `SUM(avgInboundCallTalkingTime)` | Average interaction duration for incoming contacts. |
| 9 | `tBreak` | Rest Break | `SUM(pBreak)` via `ReasonsTime` | Total time spent in standard short rest/technical breaks (Reason Code 10). |
| 10 | `tLaunch` | Lunch | `SUM(pLaunch)` via `ReasonsTime` | Total time spent in the lunch break state (Reason Code 20). |
| 11 | `tNastavnik` | Mentoring | `SUM(pNastavnik)` via `ReasonsTime` | Total time spent in supervisor mentoring or nesting states (Reason Code 50). |
| 12 | `tWrap` | Post-Processing Time | `SUM(pWrap)` via `ReasonsTime` | Raw seconds spent in post-call data processing / After Call Work (Reason Code 120). |
| 13 | `tOut` | Outbound Campaign Time| `SUM(pOut)` via `ReasonsTime` | Raw seconds dedicated strictly to active outbound campaign loops (Reason Code 80). |
| - | `LoggedOnTime` | Logged On Time | `SUM(LoggedOnTime)` via `LogOnTime` | Global accumulated operator workforce session duration. |
| 14 | `NotReadyTime` | Not Ready Time | `SUM(NotReadyTime)` via `LogOnTime` | Global accumulated duration spent across all combined non-productive states. |
| 12b| `pWrap` | Post-Processing % | `CASE WHEN LoggedOnTime = 0 THEN 0 ELSE pWrap * 1.0 / LoggedOnTime END` | Percentage of total logged-on time spent in the Wrap-up / After Call Work state. |
| 13b| `pOut` | Outbound Campaign % | `CASE WHEN LoggedOnTime = 0 THEN 0 ELSE pOut * 1.0 / LoggedOnTime END` | Percentage of total logged-on time spent performing outbound campaign activities. |
| 14b| `pNotReady` | Not Ready % | `CASE WHEN LoggedOnTime = 0 THEN 0 ELSE NotReadyTime * 1.0 / LoggedOnTime END` | Percentage of total logged-on time spent in the global Not Ready state. |

---

## Technical Calculations & Underlying Logic

### 1. UTC-to-Local Timezone Transformation Layer
Because the internal contact center database stores core switching transaction markers under strict universal time, a persistent inline calculation adjusts the timeline window bounds to align with the local MSK timezone (+3):
```sql
WHERE DATEADD(HOUR, 3, StartDateTimeUTC) >= @BeginDate 
  AND DATEADD(HOUR, 3, StartDateTimeUTC) <= @EndDate
```

### 2. Multi-Subsystem Handshaking (`#TT` Assembly)
Outbound campaign logs and ACD switching events are bound on the backend using an advanced multi-variable validation criteria framework:
* **Caller ID Truncation Alignment:** Eliminates international and local routing prefix variances (`+7`, `8`, `7`) by validating only the trailing 10-digit character string array using strict binary collation:
  ```sql
  RIGHT((CAST(CL.PhoneNumber AS varchar(32)) COLLATE Cyrillic_General_BIN), 10) = RIGHT(TCD.ANI, 10)
  ```
* **CRM Token Verification:** Cross-references the dialer context token (`CL.ContactId`) against Cisco Call Control's custom Peripheral Variable 4 parameter slot (`TCD.Variable4`), heavily guarded by an inline `ISNUMERIC` layout validator condition.
* **2-Second Time Drift Buffer:** Incorporates a dual-edge temporal adjacency barrier constraint to compensate for server clock drifts between localized Outbound application nodes and central ICM servers.

### 3. Agent Not-Ready Reason Code Mapping Matrix (`ReasonsTime`)
To extract precise behavioral performance diagnostics, the `Agent_Event_Detail` state logs are systematically decomposed based on operational `ReasonCode` assignments:
* `10` = **pBreak** (Rest Break)
* `20` = **pLaunch** (Lunch Break)
* `30` / `40` = **pBossCall / pBossTask** (Supervisor Interaction / Task Assignment)
* `50` = **pNastavnik** (Mentoring and Nesting)
* `60` = **pTechIssue** (Technical IT/Software Issues)
* `70` = **pDiscret** (Discrete Channel Async Processing)
* `80` = **pOut** (Manual Outbound Campaign Activity)
* `90` = **pLearning** (Training/Tutorials)
* `100` / `110` = **pCouching / pFeedback** (Professional QA Feedback Sessions)
* `120` = **pWrap** (Extended Post-Call Processing / ACW)
* `130` / `140` = **pEndShift / pMeeting** (Shift Completion / Team Briefings)

### 4. High-Performance Dataset Flattening Framework (`UNION ALL` Strategy)
To optimize execution speed and prevent row-dropping side effects caused by temporal mismatches during standard `LEFT JOIN` operations across different tables, the report architecture employs a specialized vertical stacking pattern:
* Separate pre-aggregated layers (`NumCallsCalc`, `NumAttemptsCalc`, `ManualOutCallsCalc`, `InboundCallsCalc`, `ReasonsTime`, and `LogOnTime`) isolate specific telemetry metrics, using 0-padded masks to maintain identical schema alignment.
* These isolated layers are concatenated via a high-performance `UNION ALL` block.
* The outer statement applies a final `GROUP BY tm.EnterpriseName, AgentSkillTargetID, a.EnterpriseName` clause to dynamically compress the unified stacks into a single, comprehensive real-time tracking row per operator.
* **Arithmetic Exception Defense:** All calculated percentages (`pWrap`, `pOut`, `pNotReady`) are wrapped in `CASE WHEN SUM(LoggedOnTime) = 0` clauses to actively bypass zero-division calculation crashes during early shifts or empty metrics.
