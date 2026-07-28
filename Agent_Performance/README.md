# Agent_Performance

## Historical Report
**Data Source:** `STAT_DB` via transactional logging and interval tables `Agent_Event_Detail` (aliased as `AED`), `Agent_Interval` (`AI`), and `Agent_Skill_Group_Interval` (`asgi`).  
**Profile Framework:** Reconciles independent Common Table Expressions (CTEs) through sequential `LEFT JOIN` operations anchored to the agent's baseline session log profile.

### Report Filters

| Parameter | Description | Required | Comments |
| :--- | :--- | :---: | :--- |
| `@BeginDate` | Interval Start | Yes | Maps to `:BeginDate` / `@start`. Lower boundary constraint for database logs execution. |
| `@EndDate` | Interval End | Yes | Maps to `:EndDate` / `@end`. Upper boundary constraint for database logs execution. |
| `@Teams` | Agent Teams | Yes | Maps to `:Teams` / `@ATL`. Multi-select allowed. Cleaned of `null` wrappers and processed into a token table array (`@atList`). |
| `@Agents` | Specific Operators | Yes | Maps to `:Agents` / `@AGL`. Multi-select allowed. Supports a dedicated **`0` index key** loop override condition to fetch all team members. |

---

### Report Fields

| # | SQL Field Name | Report Display Name | Formula / Logic Reference | Comments |
| :---: | :--- | :--- | :--- | :--- |
| 0 | `Team` | Operator Team | `tm.EnterpriseName` | Mapped organization agent team name profile. |
| 1 | `FullName` | Agent | `AN.FullName` | Extracted and concatenated from the base `Person` configuration table. |
| 2 | `AgentLogin` | Agent Login | `AN.AgentLogin` | Operator standard system enterprise workspace login credentials. |
| 3 | `OCC` | Occupancy | `CASE WHEN [Total State Footprint] = 0 THEN 0 ELSE ([Productive Handling Time]) * 1.0 / [Total State Footprint] END` | **Blended Workload Index:** Measures productive engagement against active holding/waiting parameters. Implements strict zero-padded fallback overrides. |
| 4 | `UTZ` | Utilization | `CASE WHEN (LT.LoggedOnTime - LT.NotReadyTime) = 0 THEN 0 ELSE ([Productive Work Seconds] * 1.0) / (LT.LoggedOnTime - RT.pLaunch) END` | Global workforce productive utilization rate. Subtracts meal durations (`pLaunch`) from the baseline session interval. |
| 5 | `LoggedOnTime` | Session Time | `LT.LoggedOnTime` | Total agent logged-in state duration. |
| 6 | `AvailTime` | Ready Time | `LT.AvailTime` | Productive wait time spent in the active Ready state. |
| 7 | `HandledCallsTime`| Handled Time | `AG.HandledCallsTime` | Summary database talk metric tracking completed interactions. |
| 8 | `NotReadyTime` | Not Ready Time | `LT.NotReadyTime` | Global accumulated duration spent across all combined non-productive states. |
| 9 | `BusyTime` | Busy Time | `LT.LoggedOnTime - LT.AvailTime - LT.NotReadyTime` | Calculated interval spent working outside the core Ready parameters. |
| 10 | `TalkOtherTime` | Talk Other Time | `LT.TalkOtherTime` | Time spent on internal or peripheral auxiliary line calls. |
| 11 | `CallsHandled` | Auto Handled Counts | `AG.CallsHandled` | Total volume of automated inbound and outbound calls processed. |
| 12 | `AgentOutCalls` | Manual Call Counts | `AG.AgentOutCalls` | Total volume of manually dialed outbound call attempts. |
| 13 | `HoldTime` | Hold Time | `AG.HoldTime` | Total time the customer spent on hold during the sessions. |
| 14 | `ReservedTime` | Reserved Time | `AG.ReservedTime` | Time agent spent allocated/reserved for an upcoming delivery leg. |
| 15 | `WrapTime` | Auto Wrap-Up Time | `AG.WrapTime` | Platform default automatic After Call Work (ACW) duration. |
| 16 | `TalkTime` | Auto Talk Time (In & Out) | `AG.TalkTime` | Conversation duration inside automated inbound and campaign queues. |
| 17 | `TalkOutTime` | Manual Talk Time (Out) | `AG.TalkOutTime` | Conversation duration accumulated via manual dialing sessions. |
| 18 | `TalkTimeSum` | Total Talk Time | `AG.TalkTime + AG.TalkOutTime` | Blended call duration across all transaction profiles. |
| 19 | `ATT` | Avg Talk Time | `AG.ATT` | Passed directly from the structured intermediate metric aggregate block. |
| 20 | `ATTOut` | Avg Outbound Talk Time | `AG.ATTOut` | Productive average tracking manually placed outbound calls. |
| 21 | `ATTIn` | Avg Inbound Talk Time | `AG.ATTIn` | Productive average tracking automated inbound queue calls. |
| 22 | `AWT` | Average Speed of Answer (ASA) | `CASE WHEN (CallsHandled + AgentOutCalls) = 0 THEN 0 ELSE (AvailTime + ReservedTime) / (CallsHandled + AgentOutCalls) END` | **Zero-Division Protected:** Measures average readiness interval spent before picking up connections. |
| 23 | `AWPPT` | Avg Auto Wrap-Up Time | `AG.AWPPT` | Passed directly from the underlying interval calculations. |
| 24 | `ApWrap` | Avg Post-Processing Time | `CASE WHEN (CallsHandled + AgentOutCalls) = 0 THEN 0 ELSE RT.pWrap / (CallsHandled + AgentOutCalls) END` | **Zero-Division Protected:** Average extended manual wrap time per transaction. |
| 25 | `AOUTT` | Avg Manual Talk Time | `CASE WHEN AgentOutCalls = 0 THEN 0 ELSE AG.TalkOutTime / AgentOutCalls END` | **Zero-Division Protected:** Average conversation duration specifically for manual outbound traffic. |
| 26 | `AG.AHLDT` | Average Hold Time (sec) | `AG.AHLDT` | Passed directly from the structured intermediate metric aggregate block. |

### Section: Not Ready Codes (Reason Code Breakdown via `ReasonsTime RT`)

| # | SQL Field Name | Report Display Name | Formula / Logic Reference | Comments |
| :---: | :--- | :--- | :--- | :--- |
| 27 | `pCallinAvail` | Call in Avail | `RT.pCallinAvail` | Internal switching line indicator code (Reason Code 50006). |
| 28 | `pBreak` | Rest Break | `RT.pBreak` | Short rest or technical break window (Reason Code 10). |
| 29 | `pLaunch` | Lunch | `RT.pLaunch` | Scheduled meal break time allocation (Reason Code 20). |
| 30 | `pBossCall` | Call to Supervisor | `RT.pBossCall` | Conversation with a team manager/supervisor (Reason Code 30). |
| 31 | `pBossTask` | Task from Supervisor | `RT.pBossTask` | Administrative or custom back-office assignment (Reason Code 40). |
| 32 | `pNastavnik` | Mentoring | `RT.pNastavnik` | Nesting phase supervision or coaching other operators (Reason Code 50). |
| 33 | `pTechIssue` | Technical Issues | `RT.pTechIssue` | Hardware downtime or software infrastructure failures (Reason Code 60). |
| 34 | `pDiscret` | Discrete Channels | `RT.pDiscret` | Processing asynchronous chat or email client lines (Reason Code 70). |
| 35 | `pOut` | Outbound Campaign | `RT.pOut` | Status reserved for dialer auxiliary executions (Reason Code 80). |
| 36 | `pOutAVG` | Avg Campaign Duration | `RT.pOutAVG` | Calculated average duration spent inside outbound campaign loops. |
| 37 | `pLearning` | Training | `RT.pLearning` | Learning loops or internal tutorial activities (Reason Code 90). |
| 38 | `pCouching` | Coaching | `RT.pCouching` | One-on-one professional development loop (Reason Code 100). |
| 39 | `pFeedback` | QA Feedback | `RT.pFeedback` | Performance review based on Quality Assurance evaluations (Reason Code 110). |
| 40 | `pWrap` | Post-Processing Time | `RT.pWrap` | Extended manual post-call data processing state (Reason Code 120). |
| 41 | `pAGT_OFFHOOK` | Agent Off-Hook | `RT.pAGT_OFFHOOK` | Headset lifted outside an active routing leg (Reason Code 32762). |
| 42 | `pEndShift` | End of Shift | `RT.pEndShift` | End-of-shift cleanup and logging-out checks (Reason Code 130). |
| 43 | `pMeeting` | Meeting | `RT.pMeeting` | Team brief or general corporate assembly intervals (Reason Code 140). |
| 44 | `pFirstLogin` | First Login Profile | `RT.pFirstLogin` | Initial session startup sequence tracking (Event 3 AND Reason Code 0). |
| 45 | `pSupervisor` | Supervisor State | `RT.pSupervisor` | Management-level executive override tracking (Reason Code 999). |
| 46 | `pForceLogout` | Forced Logout | `RT.pForceLogout` | Administrative automated remote session truncation (Reason Code 20001). |
| 47 | `pAgentLogout` | Agent Logout | `RT.pAgentLogout` | Active user logout sequence confirmation state (Reason Code 20003). |
| 48 | `pRNA` | Ring No Answer (pRNA) | `RT.pRNA` | System auto Not Ready state when a call pickup is missed (Reason Code 32767). |
| 49 | `pConnectionFailure`| Connection Failure | `RT.pConnectionFailure` | CTI link drop or peripheral connection timeout (Reason Code 50002). |
| 50 | `pOverlap` | Overlapping Session | `RT.pOverlap` | Multiple session synchronization conflict state (Reason Code 50010). |
| 51 | `pSysReset` | System Reset | `RT.pSysReset` | Peripheral interface controller reset line trace (Reason Code 65534). |
| 52 | `pSysReInit` | System Re-Initialization | `RT.pSysReInit` | Platform node software restart execution sequence (Reason Code 65535). |

---

## Technical Calculations & Underlying Logic

### 1. Primary Consolidation Pass (`FROM` Data Assembly)
The final report records are systematically structured using a sequence of non-destructive `LEFT JOIN` operations anchored to the operational interval data container table `LogOnTime LT`:
* **`LEFT JOIN ReasonsTime RT`**: Appends the pivoted 24-column reason code state duration data.
* **`LEFT JOIN AgNames AN`**: Maps verified full human names and system profile user identifiers.
* **`LEFT JOIN ASGStat AG`**: Ingests call count totals and productive handling time analytics.
* **`LEFT OUTER JOIN t_Agent_Team_Member atm` / `t_Agent_Team tm`**: Resolves the exact organizational business branch hierarchy.

### 2. Double-Tier Sorting Schema
The dataset is returned with strict corporate structure alignment rules:
```sql
ORDER BY tm.EnterpriseName, FullName
```
This clusters data blocks alphabetically by Team Name first, then sequentially sorts rows inside individual team profiles alphabetically by the agent's Full Name.
