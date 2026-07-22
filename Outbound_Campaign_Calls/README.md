# Outbound_Campaign_Calls

## Historical Report
**Data Source:** `STAT_DB` via base tables `tContactLog` (aliased as `CL`), `tContact`, `tCampaign`, `tPhoneResult`, `tPhoneState`, `tContactState`, `t_Agent`, `tTimeZone`, and `t_Termination_Call_Detail` (`TCD`).

### Report Filters

| Parameter | Description | Required | Comments |
| :--- | :--- | :---: | :--- |
| `@BeginDate` | Date From | Yes | Maps to `:BeginDate`. Minimum boundary constraint for `CL.TimeFrom`. |
| `@EndDate` | Date To | Yes | Maps to `:EndDate`. Maximum boundary constraint for `CL.TimeFrom`. |
| `@CampaignIDs` | Campaigns | Yes | Maps to `:CampaignIDs`. Multi-select allowed. Filters records by the Outbound Dialer campaign identifier. |

---

### Report Fields

| # | SQL Field Name | Report Display Name | Formula / Logic | Comments |
| :---: | :--- | :--- | :--- | :--- |
| 0 | `CampaignName` | Campaign Name | `tCampaign.CampaignName` | Name of the outbound dialer campaign. |
| 1 | `CampaignID` | Campaign ID | `CL.CampaignID` | Unique campaign identifier. |
| 2 | `ContactLogId` | Contact Log Id | `CL.ContactLogId` | Unique ID of the contact attempt log row. |
| 3 | `ContactId` | Contact Id | `CL.ContactId` | Unique customer record contact identifier. |
| 4 | `AccountNumber` | Account Number | `tContact.LastName` | Customer personal or billing account number. |
| 5 | `Name` | Organization Name | `tContact.FirstName` | Company, account, or business client title. |
| 6 | `ClientID` | Client ID (Deby) | `tContact.MiddleName` | Internal customer reference ID. |
| 7 | `PhoneResultId` | Phone Result Id | `CL.PhoneResultId` | Telephony outcome status code. |
| 8 | `PhoneResultText` | Phone Result Text | `tPhoneResult.PhoneResultName` | Human-readable phone contact outcome description. |
| 9 | `PhoneStateId` | Phone State Id | `CL.PhoneStateId` | Dialing state identification code. |
| 10 | `PhoneStateText` | Phone State Text | `tPhoneState.PhoneStateName` | Telephony state name (e.g., ringing, busy). |
| 11 | `ContactStateId` | Contact State Id | `CL.ContactStateId` | Business record routing state identifier. |
| 12 | `ContactResultText` | Contact Result Text | `tContactState.ContactStateName` | Final processing status text of the campaign contact. |
| 13 | `AgentId` | Agent Id | `CL.AgentId` | Unique key representing the agent peripheral code. |
| 14 | `Agent` | Agent | `t_Agent.EnterpriseName` | Mapped agent enterprise system username (joined via `CL.AgentId = t_Agent.PeripheralNumber`). |
| 15 | `DateFrom` | Date From | `CAST(CL.TimeFrom AS DATE)` | Extracted date component of the call arrival timestamp. |
| 16 | `TimeFrom` | Time From | `CONVERT(VARCHAR(8), CAST(CL.TimeFrom AS TIME(0)), 108)` | Formatted call start timestamp strictly forced to `HH:MM:SS` string structure. |
| 17 | `DateTo` | Date To | `CAST(CASE WHEN TCD.Duration IS NOT NULL THEN DATEADD(SECOND, TCD.Duration, CL.TimeTo) ELSE CL.TimeTo END AS DATE)` | Dynamic date calculator. Appends call conversation duration if telecommunication record mapping is successful. |
| 18 | `TimeTo` | Time To | `CONVERT(VARCHAR(8), CAST(CASE WHEN TCD.Duration IS NOT NULL THEN DATEADD(SECOND, TCD.Duration, CL.TimeTo) ELSE CL.TimeTo END AS TIME(0)), 108)` | Dynamic call completion timestamp forced to `HH:MM:SS` format. Adds `TCD.Duration` onto the base `CL.TimeTo` log marker. |
| - | `Duration` | Duration | `TCD.Duration` | **[New Field]** The raw call duration in seconds tracked inside the Cisco Unified CC environment. |
| 19 | `PhoneNumber` | Phone Number | `CL.PhoneNumber` | The exact target telephone string dialed. |
| 20 | `ContactDetailId` | Contact Detail Id | `CL.ContactDetailId` | System identifier linking to comprehensive record configuration attributes. |
| 21 | `Attempt` | Attempt | `CL.Attempt` | Sequence dial count tracking for this specific record instance. |
| 22 | `NextCallTime` | Next Call Time | `CL.NextCallTime` | Scheduled retry time for subsequent contact attempts. |
| 23 | `ClientCallDialingStartTime` | Client Call Dialing Start Time | `CL.ClientCallDialingStartTime` | Timestamp when customer trunk line dialing initiated. |
| 24 | `ClientCallDialingEndTime` | Client Call Dialing End Time | `CL.ClientCallDialingEndTime` | Timestamp when customer call placement phase completed. |
| 25 | `ClientCallAnswerTime` | Client Call Answer Time | `CL.ClientCallAnswerTime` | Exact moment the customer picked up or accepted the line. |
| 26 | `AgentCallDialingStartTime` | Agent Call Dialing Start Time | `CL.AgentCallDialingStartTime` | Timestamp when the dialer initiated the call leg to the agent. |
| 27 | `AgentCallDialingEndTime` | Agent Call Dialing End Time | `CL.AgentCallDialingEndTime` | Timestamp when agent hardware line configuration allocation ended. |
| 28 | `AgentCallApproveTime` | Agent Call Approve Time | `CL.AgentCallApproveTime` | Timestamp when the agent accepted/acknowledged the connection. |
| 29 | `AgentCallDistributedTime` | Agent Call Distributed Time | `CL.AgentCallDistributedTime` | Timestamp when the platform matched and routed the call to the agent. |
| 30 | `DisconnectReason` | Disconnect Reason | `CL.DisconnectReason` | Call termination root cause flag. |
| 31 | `SkillTargetId` | Skill Target Id | `CL.SkillTargetId` | Platform unique identifier for the targeted agent routing profile. |
| 32 | `TimeZoneName` | Contact Time Zone | `tTimeZone.TimeZoneName` | Mapped geographic time zone boundary of the target customer. |
| 33 | `Priority` | Priority | `tContact.Priority` | Numeric database dialing queue priority rank assigned to the record. |

---

## Technical Calculations & Underlying Logic

### 1. Cross-Subsystem Metadata Correlation (Dialer vs. ACD)
Because Outbound Campaign Dialer logging (`tContactLog`) runs independently from the core Cisco Call Control Engine (`t_Termination_Call_Detail`), a composite, rule-based text mapping join strategy is applied:
* **Caller ID Normalization:** The telephone sequence string is explicitly cross-referenced using a strict binary collation match condition:
  ```sql
  (CAST(CL.PhoneNumber AS varchar(32)) COLLATE Cyrillic_General_BIN) = TCD.ANI
  ```
* **Contextual Variable Capture:** The Dialer's customer record identifier (`CL.ContactId`) is dynamically mapped from Cisco Call Control's custom Peripheral Variable 4 slot (`TCD.Variable4`), heavily guarded by an explicit numeric validator check:
  ```sql
  CL.ContactId = CASE WHEN ISNUMERIC(TCD.Variable4) = 1 THEN CAST(TCD.Variable4 AS int) ELSE 0 END
  ```

### 2. Multi-Leg Row Multiplication Safeguard (`max_dur` Subquery)
When standard outbound campaign interactions trigger secondary transfers, consultations, or script looping, multiple records can appear in `t_Termination_Call_Detail` with identical `ANI` strings and matching `Variable4` keys within the same time boundary.
* To prevent duplicate row reporting and skewed counters, an `INNER JOIN` links to a localized analytical aggregate block (`max_dur`).
* For every separate log entry (`CL.ContactLogId`), this subquery evaluates all competing matched telephony legs, filters them down to the absolute maximum duration instance (`MAX(TCD.Duration)`), and passes only that single unique session record row forward into the final dataset profile.
