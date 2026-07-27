# Manual_Outbound_Calls

## Historical Report
**Data Source:** `STAT_DB` via optimized cached staging table `#TCD` (`t_Termination_Call_Detail`), integrated with configuration tables `t_Agent`, `t_Skill_Group`, `t_Agent_Team_Member`, and `t_Agent_Team`.

### Report Filters

| Parameter | Description | Required | Comments |
| :--- | :--- | :---: | :--- |
| `@BeginDate` | Interval Start | Yes | Maps to `:BeginDate`. Minimum boundary constraint for call event timestamps. |
| `@EndDate` | Interval End | Yes | Maps to `:EndDate`. Maximum boundary constraint for call event timestamps. |
| `@Teams` | Agent Teams | Yes | Maps to `:Teams`. Multi-select allowed. Internally parsed into a clean ID lookup table array (`@atList`). |

---

### Report Fields

| # | SQL Field Name | Report Display Name | Formula / Logic | Comments |
| :---: | :--- | :--- | :--- | :--- |
| 0 | `CallType` | Call Type | Always `'Ручной'` | Hardcoded static text string denoting manual outbound traffic. |
| 1 | `Team` | Operator Team | `tm.EnterpriseName` | Mapped agent team name profile. |
| 2 | `SkillGroup` | Skill Group | `sg.EnterpriseName` | Mapped Skill Group name profile through which the agent was logged in. |
| 3 | `Agent` | Agent Name | `a.EnterpriseName` | Operator full name / system username profile. |
| 4 | `AgentID` | Agent ID | `a.SkillTargetID` | Internal unique hardware agent database key. |
| 5 | `PhoneNumberPrefix` | Phone Number Prefix | `CASE WHEN LEN(TCD.DigitsDialed) > 10 THEN LEFT(TCD.DigitsDialed, LEN(TCD.DigitsDialed)-10) ELSE '' END` | **Defensive Padding Logic:** Dynamically extracts country/area routing codes located to the left of the core 10 digits. Safe against short numbers. |
| 6 | `PhoneNumber` | Phone Number | `RIGHT(TCD.DigitsDialed, 10)` | Isolates the standard trailing 10 digits representing the destination customer number. |
| 7 | `CallID` | Call ID | `TCD.CallReferenceID` | Unique call block session reference identifier. |
| 8 | `OutCallBegin` | Call Start Time | `DATEADD(SECOND, -1*TCD.Duration, TCD.DateTime)` | Precise calculated timestamp when the network trunk line dialing leg initiated. |
| 9 | `OutCallConnect` | Agent Connected | `DATEADD(SECOND, TCD.DelayTime, [OutCallBegin])` | Exact timestamp when the outbound line was successfully established and connected to a live customer. |
| 10 | `OutCallDisconnect` | Call End Time | `DATEADD(SECOND, -1*TCD.WorkTime, TCD.DateTime)` | Precise conversation disconnect timestamp captured directly before the agent enters the wrap state. |
| 11 | `Duration` | Call Duration | `TCD.Duration - TCD.WorkTime` | **Custom Calculation:** Overrides the standard platform duration by explicitly subtracting post-call processing time (`WorkTime`). Matches active line occupation. |
| 12 | `DialingTime` | Dialing Time | `TCD.DelayTime` | Telephony network transit and remote destination ring-time duration in seconds. |
| 13 | `TalkTime` | Talk Time | `TCD.TalkTime` | Active operator-to-customer conversation duration. |
| 14 | `HoldTime` | Hold Time | `TCD.HoldTime` | Total time the customer spent on hold during this manual outbound session. |
| 15 | `WorkTime` | Wrap-Up Time | `TCD.WorkTime` | Post-call data processing duration (After Call Work / ACW). |

---

## Technical Calculations & Underlying Logic

### 1. Manual Outbound Telephony Isolation (`#TCD` Ingestion)
To strictly isolate manual actions from automated dialer or inbound routing scripts, the backend filter layer restricts the staging table cache block using core Cisco peripheral definitions:
* **Call Profile Constraints:** `PeripheralCallType = 9` isolates standard manual call legs generated directly from an operator's workspace.
* **Temporal Safety Buffer:** The right-hand time filter applies an internal 30-minute structural alignment window:
  ```sql
  WHERE DateTime >= @BeginDate AND DATEADD(MINUTE, 30, DateTime) <= @EndDate
  ```

### 2. Team-Based Organization Scoping
The data mapping structure filters active agent interactions strictly by team hierarchies (`@atList`) at the ingestion layer using subqueries directly against organization routing schemas:
```sql
(SELECT AgentTeamID FROM t_Agent_Team_Member WHERE SkillTargetID = tcd.AgentSkillTargetID) IN (SELECT id FROM @atList)
```
This reduces transaction processing footprints across historical logs by instantly suppressing records from non-targeted operational business branches.
