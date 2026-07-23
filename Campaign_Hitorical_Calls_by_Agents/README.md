# Campaign_Historical_Calls_by_Agents

## Historical Report
**Data Source:** `STAT_DB` via cached staging tables `#CL` (`tContactLog`), `#TCD` (`t_Termination_Call_Detail`), `tContact`, `tCampaign`, `t_Agent`, `t_Agent_Team`, and `tTimeZone`.

### Report Filters

| Parameter | Description | Required | Comments |
| :--- | :--- | :---: | :--- |
| `@BeginDate` | Interval Start | Yes | Maps to `:BeginDate`. Minimum boundary constraint for logging timestamps. |
| `@EndDate` | Interval End | Yes | Maps to `:EndDate`. Maximum boundary constraint for logging timestamps. |
| `@CampaignList` | Campaigns | Yes | Maps to `:CampaignList`. Multi-select allowed. Internally parsed into a string-split array. |

---

### Report Fields

| # | SQL Field Name | Report Display Name | Formula / Logic | Comments |
| :---: | :--- | :--- | :--- | :--- |
| 0 | `CallType` | Client Type | Always `'Automated'` | Hardcoded static text string denoting outbound dialer traffic. |
| 1 | `CampaignID` | Campaign ID | `CL.CampaignID` | Unique outbound campaign identifier. |
| 2 | `CampaignName` | Campaign Name | `tCampaign.CampaignName` | Target campaign name profile. |
| 3 | `Team` | Operator Team | `tm.EnterpriseName` | Name of the assigned agent team. |
| 4 | `AgentId` | Agent ID | `CL.AgentId` | Dialer unique peripheral agent identifier. |
| 5 | `Agent` | Agent Name | `a.EnterpriseName` | Mapped employee full name username. |
| 7 | `MRF` | Macroregion | `tContact.FirstName` | High-level macroregion geographical cluster. |
| 8 | `RF` | Regional Branch | `tContact.MiddleName` | Local operational regional branch office. |
| 9 | `AccountNumber` | Account Number | `tContact.LastName` | Customer billing or personal account number. |
| 10 | `ContactLogId` | Contact Log ID | `CL.ContactLogId` | Unique sequential identifier of the contact attempt. |
| 11 | `ContactId` | Contact ID | `CL.ContactId` | Internal dialer customer record identifier. |
| 12 | `PhoneResultText` | Dial Attempt Result | `tPhoneResult.PhoneResultName` | Human-readable phone contact outcome text. |
| 13 | `PhoneStateText` | Phone Status | `tPhoneState.PhoneStateName` | Telephony state profile (e.g., ringing, busy). |
| 14 | `ContactResultText` | Contact Status | `tContactState.ContactStateName` | Final processing status text of the campaign contact. |
| 15 | `PhNum` | Phone Number | `' ' + CAST(CL.PhoneNumber AS VARCHAR(11))` | Formatted target telephone string prefixed with a single whitespace anchor. |
| 16 | `NextCallTime` | Next Call Time | `CL.NextCallTime` | Scheduled retry time for subsequent contact attempts. |
| 17 | `AttemptsEKCB2C_2798` | Attempt | `COUNT(Attempts.ContactLogId) + 1` | **Historical Self-Join:** Calculates the progressive attempt sequence number per dialer target phone within the interval. |
| 18 | `ClientCallDialingStartTime` | Dialer Call Start Time | `CL.ClientCallDialingStartTime` | Timestamp when customer trunk line dialing initiated. |
| 19 | `CallPassToAgents` | Queue Entry Time | `CASE WHEN CL.AgentId IS NULL THEN NULL ELSE DATEADD(SECOND, -1*TCD.Duration, TCD.DateTime) END` | Exact moment the active call entered the contact center ACD queue. Resolves to `NULL` for unhandled/dropped dials. |
| 20 | `AgentConnectTime` | Agent Connected | `DATEADD(SECOND, -1*(TCD.WorkTime + TCD.TalkTime + TCD.HoldTime), TCD.DateTime)` | Exact calculated moment the customer call successfully landed on the operator's teleset hardware. |
| 21 | `CallEndDT` | Call End Time | `CASE WHEN (CL.AgentId IS NULL OR TCD.AgentSkillTargetID IS NULL) THEN (CASE WHEN CL.ClientCallDialingEndTime IS NULL THEN CL.TimeTo ELSE CL.ClientCallDialingEndTime END) ELSE DATEADD(SECOND, -1*TCD.WorkTime, TCD.DateTime) END` | Dynamic call wrap anchor. If unhandled, falls back to dialer termination time markers. If handled, maps to conversation disconnect time. |
| 22 | `CallDuration` | Call Duration | `DATEDIFF(SECOND, CL.ClientCallDialingStartTime, [Dynamic End Marker])` | Continuous second delta. Measures duration from dialing inception up to active line abandonment or conversation disconnect. |
| 23 | `DialingDuration` | Dialer Ring Duration | `DATEDIFF(SECOND, CL.ClientCallDialingStartTime, [Dynamic Connection/Timeout Marker])` | Calculated interval measuring total telephony setup and ringing delay until queue delivery, agent pickup, or dialer timeout. |
| 24 | `QueueTime` | Queue Wait Time | `DATEDIFF(SECOND, [CallPassToAgents], [AgentConnectTime])` | The operational holding duration in seconds spent inside the ACD service queue before operator pickup. |
| 25 | `TCD_TalkTime` | Talk Time | `TCD.TalkTime` | Active operator-to-customer conversation duration. |
| 26 | `TCD_HoldTime` | Hold Time | `TCD.HoldTime` | Total time the customer spent on hold during the session. |
| 27 | `WorkTime` | Wrap-Up Time | `TCD.WorkTime` | Post-call processing time (After Call Work). |
| 28 | `InsertDate` | Registry Entry Time | `MIN(CSIncluded.TimeTo)` where `ContactStateId = 1` | Earliest registration timestamp of the active contact within the same calendar day context. |
| 29 | `ExclDateFix` / `ExclDate` | Registry Exclusion Time | `MAX(CSExcluded.TimeTo)` where `ContactStateId BETWEEN 110 AND 115` OR `= 121` | Final closing or exclusion timestamp of the active contact within the same calendar day context. |

---

## Technical Calculations & Underlying Logic

### 1. Progressive Attempt Counter (`Attempts` Subquery)
The sequence tracking field `AttemptsEKCB2C_2798` does not fetch a pre-calculated index field; it processes a historical lookup array:
* A localized self-join matches records sharing an identical `PhoneNumber`.
* It counts all preceding contact attempt row markers where the timestamp is strictly earlier than the current record event loop:
  ```sql
  CL.ClientCallDialingStartTime > Attempts.ClientCallDialingStartTime
  ```
* The query applies a baseline increment coefficient (`+ 1`) to assign a progressive attempt index starting at 1.

### 2. Intra-Day Workflow Tracking (CTE `CSIncluded` / `CSExcluded`)
To isolate record loading and lifecycle modifications within exact 24-hour business operational blocks, the script implements localized date boundary truncation subqueries:
* **Lower Constraint Anchor:** `TimeTo >= DATEADD(DAY, DATEDIFF(day, 0, CL.TimeTo), 0)` – Resets the target boundary profile to midnight (`00:00:00`) of the logging instance day.
* **Upper Constraint Anchor:** `TimeTo <= DATEADD(SECOND, -1, DATEDIFF(DD, 0, CL.TimeTo) + 1)` – Seals the evaluation barrier at exactly `23:59:59` of that same calendar date, ensuring no cross-day data spills into the localized `MIN/MAX` aggregates.

### 3. Asynchronous Subsystem Handshaking (Dialer vs. Call Control)
Data streams generated inside the Dialer log clusters (`#CL`) are mapped onto core ICM Telephony records (`#TCD`) via a multi-variable validation engine:
* **10-Digit Phone Normalization:** Prefix structural variances are handled by validating only the trailing 10-character string array using a strict binary collation key:
  ```sql
  RIGHT((CAST(CL.PhoneNumber AS varchar(32)) COLLATE Cyrillic_General_BIN), 10) = RIGHT(TCD.ANI, 10)
  ```
* **Token Passing Validation:** The dialer context index (`CL.ContactId`) is extracted from Cisco's central interaction parameter `TCD.Variable4`, guarded by an explicit layout validator condition:
  ```sql
  CL.ContactId = CASE WHEN ISNUMERIC(TCD.Variable4) = 1 THEN CAST(TCD.Variable4 AS int) ELSE 0 END
  ```
* **2-Second Time Drift Buffer:** To eliminate timing mismatch exceptions between separate platform log nodes, a dual-edge temporal adjacency barrier checks the minimum routing segment execution time:
  ```sql
  DATEADD(SECOND, -2, CL.ClientCallDialingEndTime) <= MIN(TCDSTARTS.DateTime)
  AND DATEADD(SECOND, 2, CL.AgentCallDistributedTime) > MIN(TCDSTARTS.DateTime)
  ```
