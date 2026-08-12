# NPP_HIST_Teams_by_Locations

## Historical Report
**Data Source:** `STAT_DB`, which contains replicas of data across core Cisco UCCE database schemas: `t_Agent_Event_Detail`, `t_Agent_Skill_Group_Interval`, `t_Agent_Interval`, and `t_Termination_Call_Detail` [pdf_r0UGPj.pdf].
The report uses stored procedure: `[dbo].[SP_REPORT_NPP_HIST_TEAMS_BY_LOCATIONS_V1]`

To dynamically compile and map the regional location directional matrices, a pre-populated reference mapping table **`tNPP_Locations`** is used:
* `NPPLocationID` (`int`) — Unique geographic/regional site identifier.
* `NPPLocation` (`nvarchar(MAX)`) — Regional site text name or address profile.
* `AgentTeamID` (`int`, PK) — Unique agent team identifier.
* `TeamName` (`nvarchar(MAX)`) — Name of the assigned agent team.

---

## Report Filters

| Parameter | Description | Required | Comments |
| :--- | :--- | :---: | :--- |
| `@StartTime` | Interval Start | Yes | Maps to `@dtBegin`. Lower boundary constraint for the data selection period [pdf_DGf5_p.pdf]. |
| `@EndTime` | Interval End | Yes | Maps to `@dtEnd`. Upper boundary constraint for the data selection period [pdf_DGf5_p.pdf]. |
| `@typeDT` | Interval Sizing | Yes | Maps to `@dtType`. Selection drop-down token containing structural grouping steps:<br>• `0` = **All Period** (Custom range summaries)<br>• `1` = **Daily** (24-hour midnight summaries)<br>• `2` = **Hourly** (60-minute window summaries)<br>• `3` = **15 Minutes** (Standard Cisco quarter-hour slots) [pdf_DGf5_p.pdf, pdf_r0UGPj.pdf] |
| `@Locations` | Locations | Yes | Maps to `@LL`. List of regional directions/sites. Multi-select allowed [pdf_DGf5_p.pdf, pdf_r0UGPj.pdf]. |
| `@Teams` | Agent Teams | No | Maps to `@ATL`. Multi-select allowed [pdf_DGf5_p.pdf, pdf_r0UGPj.pdf]. |
| `@Agents` | Agents | No | Maps to `@AGL`. Multi-select allowed. Operators are structured hierarchically under teams [pdf_DGf5_p.pdf, pdf_r0UGPj.pdf]. |

---

## Report Fields Schema

### Section 1: Core Identifiers & Agent State Durations

| # | SQL Field Name | Report Display Name | Formula / Logic Reference | Comments |
| :---: | :--- | :--- | :--- | :--- |
| 0 | `NPPLocation` | Regional Site | `tNPP_Locations.NPPLocation` | Physical address or name of the operational regional branch office [pdf_r0UGPj.pdf]. |
| 1 | `Team` | Agent Team | `t_Agent_Team.EnterpriseName` | Mapped enterprise name of the assigned agent team [pdf_r0UGPj.pdf]. |
| 2 | `dtPeriodBegin` | Interval Time | Baseline period grouping timestamp | Exact start timestamp of the selected reporting interval block [pdf_r0UGPj.pdf]. |
| 3 | `AgentLogin` | Agent Login | `t_Person.LoginName` | Operator standard system enterprise workspace login credentials [pdf_r0UGPj.pdf]. |
| 4 | `AgentName` | Agent Name | `t_Person.LastName + ' ' + t_Person.FirstName` | Combined operator full name tracking string [pdf_r0UGPj.pdf]. |
| 5 | `LogInTime` | Logged On Time | `SecondsByEventInPeriod WHEN [Event] = 2` | Global workforce session duration spent logged into the platform [pdf_r0UGPj.pdf]. |
| 6 | `NotReadyTime` | Not Ready Time | `SecondsByEventInPeriod WHEN [Event] = 3` | Global accumulated duration spent across all combined non-productive states [pdf_r0UGPj.pdf]. |
| 7 | `TalkTimeIn` | Inbound Talk Time | Aggregated inbound conversation counters | Total active talk duration for incoming queue call segments [pdf_r0UGPj.pdf]. |
| 8 | `TalkTimeOut` | Outbound Talk Time | Aggregated outbound conversation counters | Total active talk duration for placed outbound call segments [pdf_r0UGPj.pdf]. |
| 9 | `HoldTime` | Inbound Hold Time | Aggregated customer inbound hold time | Total duration customers spent on hold during inbound sessions [pdf_r0UGPj.pdf]. |
| 10 | `HoldOutTime` | Outbound Hold Time | Aggregated customer outbound hold time | Total duration clients spent on hold during outbound sessions [pdf_r0UGPj.pdf]. |
| 11 | `WrapTime` | Wrap-Up Time | `WorkNotReadyTime + WorkReadyTime` | Platform default automatic post-call data processing duration (After Call Work) [pdf_DGf5_p.pdf]. |
| 12 | `AvailTime` | Ready Time | Aggregated standby interval metrics | Productive wait time spent in the active Ready state [pdf_DGf5_p.pdf]. |

### Section 2: Telephony Interaction Volumes & Performance Counter KPIs

| # | SQL Field Name | Report Display Name | Formula / Logic Reference | Comments |
| :---: | :--- | :--- | :--- | :--- |
| 13 | `CallsEntered` | Total Inbound Offered | `CallsAnswered + AbandonRingCalls` | Total volume of incoming interactions hitting the agent's line profile [pdf_DGf5_p.pdf]. |
| 14 | `CallsAnswered` | Inbound Calls Answered | Core telephony pickup counter | Total incoming call queue sessions successfully answered by the operator [pdf_DGf5_p.pdf]. |
| 15 | `AgentOutCallsTCD` | Outbound Calls Placed | Total outbound segment log count | Comprehensive counter tracking all manual or automated dialer outbound attempts [pdf_DGf5_p.pdf]. |
| 16 | `AgentOutCallsSuccess` | Successful Outbound Calls| Connected outbound line counter | Outbound call attempts that successfully established a connection with a remote end [pdf_DGf5_p.pdf]. |
| 17 | `AnswerWaitTime` | Total Ring Time (In) | Summary alerting duration | Cumulative seconds customers spent ringing this agent before an inbound pickup [pdf_DGf5_p.pdf]. |
| 18 | `AnswerWaitOutTime`| Total Dialing Time (Out) | Summary ringback duration | Cumulative network transit and remote destination ringing delay seconds for outbound legs [pdf_DGf5_p.pdf]. |
| 19 | `AHT_In_wout_WrapUp`| Avg Inbound Talk Time | `InboundTalkTime / CallsAnswered` | Average pure inbound customer conversation duration (excluding hold and wrap states) [pdf_DGf5_p.pdf]. |
| 20 | `AHT_In` | Inbound AHT | `(InboundTalkTime + HoldTime + WrapTimeIn) / CallsAnswered` | Average Inbound Handle Time (Blended summary tracking complete incoming transaction processing) [pdf_DGf5_p.pdf]. |
| 21 | `AHT_Out_wout_WrapUp`| Avg Outbound Talk Time | `OutboundTalkTime / AgentOutCallsSuccess` | Average pure outbound conversation duration (excluding hold and wrap states) [pdf_DGf5_p.pdf]. |
| 22 | `AHT_Out` | Outbound AHT | `(OutboundTalkTime + HoldOutTime + WrapTimeOut) / AgentOutCallsSuccess` | Average Outbound Handle Time tracking complete manually placed or dialer call processing loops [pdf_DGf5_p.pdf]. |
| 23 | `AVG_WrapUpIn` | Avg Inbound Wrap Time | `InboundWrapTime / CallsAnswered` | Average default system post-call wrap processing time per inbound interaction [pdf_DGf5_p.pdf]. |
| 24 | `AVG_WrapUpOut` | Avg Outbound Wrap Time | `OutboundWrapTime / AgentOutCallsSuccess` | Average default system post-call wrap processing time per successful outbound leg [pdf_DGf5_p.pdf]. |
| 25 | `FirstLoginDateTime`| First Login Timestamp | `MIN(LoginDateTime)` context pass | Earliest moment the employee initiated a platform login session within the day [pdf_DGf5_p.pdf]. |
| 26 | `LastLogoutDateTime` | Last Logout Timestamp | `MAX(LogoutDateTime)` context pass | Final moment the employee executed a workspace logoff sequence within the day [pdf_DGf5_p.pdf]. |
| 27 | `AgentUniqOutCalls` | Unique Outbound Attempts | Distinct count of target numbers | Total outbound attempts placed toward completely unique destination directory numbers [pdf_DGf5_p.pdf]. |
| 28 | `AgentOutCallsSuccess`| Unique Successful Outbound| Connected distinct target numbers | Outbound calls successfully connected to completely unique destination directory numbers [pdf_DGf5_p.pdf]. |
| 29 | `AgentUniqOutCallsPercent`| Unique Number Contact Rate %| `UniqueOutCallsSuccess / UniqueOutCalls` | **Penetration Ratio:** Percentage efficiency tracking successful contacts over unique target record lists [pdf_DGf5_p.pdf]. |

---

## Technical Calculations & Stored Procedure Pre-Processing

Before passing execution down into the internal compilation engine of the stored procedure `SP_REPORT_NPP_HIST_TEAMS_BY_LOCATIONS_V1`, the execution block executes precise string parsing and security filters [pdf_DGf5_p.pdf]:

### 1. Cascade Location-to-Team Parameter Resolution
To secure high front-end responsiveness inside Cisco CUIC when selectors are submitted, the backend code parses inputs via isolated intermediate array queries [pdf_DGf5_p.pdf]:
* **String Input Cleanup Isolation:** Formats the input parameters using string cleaners `REPLACE(@LL, 'null', '')` and text transformers `TRANSLATE` to split raw comma-separated inputs into distinct numerical token data arrays: `@lList` (Locations) and `@atList` (Teams) [pdf_DGf5_p.pdf].
* **Cascaded Inheritance Loop:** If a user selects specific geographical regions but passes an empty or full-period catch-all flag (`0`) inside the Team parameter, a background mapping script automatically resolves and inherits the underlying business structural layout [pdf_DGf5_p.pdf]:
  ```sql
  INSERT INTO @tmListfromLocations (id)
  SELECT AgentTeamID FROM tNPP_Locations WHERE NPPLocationID IN (SELECT id FROM @lList)
  
  IF 0 IN (SELECT id FROM @atList) 
      INSERT INTO @atList(id) SELECT id FROM @tmListfromLocations;
  ```
  This forces an automated, implicit cascade selection: selecting a location dynamically extracts and targets every single underlying operational agent team profile assigned to that region [pdf_DGf5_p.pdf].

### 2. Microsecond and Quarter-Hour Time Window Alignments
Inside the stored procedure runtime, variable bounds `@dtBeginPeriod` and `@dtEndPeriod` undergo precise mathematical rounding routines to avoid microsecond or transaction boundary data loss [pdf_DGf5_p.pdf]:
* **Lower Boundary Anchor:** Uses time delta formulas to round down the input `@dtBegin` timestamp to the exact nearest 15-minute operational interval block, stripping millisecond and trailing second anomalies [pdf_DGf5_p.pdf]:
  ```sql
