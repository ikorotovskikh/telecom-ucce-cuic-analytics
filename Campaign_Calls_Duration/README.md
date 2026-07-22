# Campaign_Calls_Duration

## Historical Report
**Data Source:** `STAT_DB` via cached staging tables `#CL` (`tContactLog`), `#TCD` (`t_Termination_Call_Detail`), `tContact`, `tCampaign`, and `t_Agent`.

### Report Filters

| Parameter | Description | Required | Comments |
| :--- | :--- | :---: | :--- |
| `@BeginDate` | Interval Start | Yes | Maps to `:BeginDate`. Minimum boundary constraint for logging timestamps. |
| `@EndDate` | Interval End | Yes | Maps to `:EndDate`. Maximum boundary constraint for logging timestamps. |
| `@CampaignList` | Campaigns | Yes | Maps to `:CampaignList`. Multi-select allowed. Internally parsed using a string-split processing array (`@CL`). |

---

### Report Fields

| # | SQL Field Name | Report Display Name | Formula / Logic | Comments |
| :---: | :--- | :--- | :--- | :--- |
| 0 | `RF` | Regional Branch | `tContact.MiddleName` | Local operational regional office directory. |
| 1 | `MRF` | Macroregion | `tContact.FirstName` | High-level geographical macroregion cluster. |
| 2 | `ClientType` | Client Type | `CASE WHEN CHARINDEX('MIX'...) OR CHARINDEX('B2C'...) THEN 'B2C'`<br>`ELSE CASE WHEN CHARINDEX('B2B'...) OR CHARINDEX('В2В' [Cyrillic]...) THEN 'B2B'`<br>`ELSE '' END END` | **Defensive Logic:** Maps name tokens to business sectors (Retail vs. Corporate). Explicitly handles both **Latin** `'B2B'` and **Cyrillic** `'В2В'` structural campaign naming typos. |
| 3 | `CallsTalkTime` | Talk Time (Min) | `REPLACE(CONVERT(..., ROUND(SUM(TalkTime)/60.0, 2)...), '.', ',')` | Total talk duration in minutes. Formatted into a regional string format where decimal point markers are actively replaced by commas. |
| 4 | `NumCalls` | Call Count | `COUNT(CL.ContactLogId)` | Total established voice connections filtered strictly by the constraint: `TCD.TalkTime > 0`. |

---

## Technical Calculations & Underlying Logic

### 1. Cross-Subsystem Multi-Token Telephony Mapping (`JOIN` Algorithm)
Because Outbound Campaign activity records and Call Control detail entries belong to independent database logging engines, records are linked using a specialized multi-layer validation join matrix:
* **Caller ID Truncation Alignment:** Telephone numbers are unified and verified by isolating their **last 10 digits** (`RIGHT(..., 10)`) combined with a strict binary collation lookup restriction to override varying system country prefixes:
  ```sql
  RIGHT((CAST(CL.PhoneNumber AS varchar(32)) COLLATE Cyrillic_General_BIN), 10) = RIGHT(TCD.ANI, 10)
  ```
* **CRM Account Context Resolution:** The internal dialer customer token (`CL.ContactId`) is dynamically cross-validated against Cisco CC's custom Peripheral Variable 4 parameter slot (`TCD.Variable4`), heavily guarded by an inline format numeric validator rule:
  ```sql
  CL.ContactId = CASE WHEN ISNUMERIC(TCD.Variable4) = 1 THEN CAST(TCD.Variable4 AS int) ELSE 0 END
  ```
* **Asynchronous Time Drift Buffer (2-Second Window):** To compensate for clock synchronization drifts between the localized Outbound Dialer application nodes and the central core ICM Call Control servers, an operational window offset constraint is actively enforced:
  ```sql
  DATEADD(SECOND, -2, CL.ClientCallDialingEndTime) <= MIN(DATEADD(SECOND, -1*Duration, DateTime))
  AND DATEADD(SECOND, 2, CL.AgentCallDistributedTime) > MIN(DATEADD(SECOND, -1*Duration, DateTime))
  ```

### 2. Localization Formatting Strategy (`CallsTalkTime`)
To meet target corporate spreadsheet and interface localization requirements for Cisco CUIC presentation layers, raw interaction durations are passed through an inline data transformation pipeline:
* **Mathematical Reduction:** Total aggregated active voice seconds are divided by `60.0` to calculate fractional minute values.
* **Precision Constraints:** The minutes are rounded to a maximum of 2 decimal places using `ROUND(..., 2)` and forcefully cast to a static precise numeric data profile: `DECIMAL(38,2)`.
* **Delimiter Substitution:** The system converts the numeric string using style `3` and performs an inline character swap using `REPLACE(..., '.', ',')` to dynamically substitute standard SQL periods with commas as fractional separators.
