# Transfers_From_Skill_with_Wait_Time

## Historical Report
**Data Source:** `STAT_DB` via cached staging table `#TCD` (`t_Termination_Call_Detail`), `t_Route_Call_Detail` (`RCD`), `t_Agent`, `t_Person`, `t_Skill_Group`, and `t_TransferDialedNumberStrings` (`TDN`).

### Report Filters

| Parameter | Description | Required | Comments |
| :--- | :--- | :---: | :--- |
| `@StartDate` | Selection Start Date | Yes | Maps to `:StartDate`. Minimum boundary for `DateTime` filters. |
| `@EndDate` | Selection End Date | Yes | Maps to `:EndDate`. Maximum boundary for `DateTime` filters. |
| `@SkillGroups` | Skill Group | Yes | Maps to `:SkillGroups`. Multi-select allowed. Filters records by the initial source Skill Group. |

---

### Report Fields

| # | SQL Field Name | Report Display Name | Formula / Logic | Comments |
| :---: | :--- | :--- | :--- | :--- |
| 0 | `TransferDateTime` | Transfer Date/Time | `RCD.BeganRoutingDateTime` where:<br>`RCD.RouterCallKeySequenceNumber = TCD.RouterCallKeySequenceNumber + 1` | Exact timestamp when the target transfer routing process was triggered. |
| 1 | `ANI` | ANI | `TR.ANI` | Customer Caller ID (Automatic Number Identification). |
| 2 | `TransferFromSkill` | Transferred From Skill | `SG.EnterpriseName` (Source leg join) | Name of the source Skill Group that initially handled the call before the transfer. |
| 3 | `TransferFromDN` | Source DN | `TCD.DigitsDialed` | Directory Number (DN) associated with the originating Skill Group. |
| 4 | `AgentName` | Agent Name | `P.LastName + ' ' + P.FirstName` | Full name of the agent who executed the transfer. |
| 5 | `AgentPhone` | Agent Extension | `TCD.InstrumentPortNumber` | Hardware extension (teleset) number of the transferring agent. |
| 6 | `DurationFull` | Total Call Duration | `MAX(TCD.Duration)` grouped by call keys | Calculated via the `TCD_DUR_TOTAL` subquery, fetching the absolute maximum duration across all call segments. |
| 7 | `FirstCallDuration` | Talk Time (First Leg) | `TCD.Duration` | Active talk time duration of the call leg before the transfer occurred. |
| 8 | `TransferToDN` | Target DN | `RCD.DialedNumberString` where sequence increments by `1` | The dialed target digits/extension where the call was transferred. |
| 9 | `TransferTo_SG_or_Desc` | Target Destination | `CASE WHEN xFerToSG.SkillGroupSkillTargetID IS NULL THEN TR.TransferToDescription ELSE SG.EnterpriseName END` | Conditional logic: If the call lands on an internal Skill Group, displays the `SG.EnterpriseName`. If it is routed externally, falls back to `TDN.Description`. |
| 10 | `WaitTime` | Queue Wait Time | `DATEDIFF(SECOND, TR.DateTime, (SELECT MAX(DateTime) FROM #TCD CT WHERE CT.DateTime < xFerToSG.DateTime ...))` | The delta in seconds between the transfer initiation point and the absolute connection timestamp of the next immediate segment profile. |
| 11 | `RouterCallKey` | Router Call Key | `TR.RouterCallKey` | Technical sequence ID. |
| 12 | `RouterCallKeyDay` | Router Call Key Day | `TR.RouterCallKeyDay` | Technical date sequence index. |

---

## Technical Calculations & Data Relationships

### 1. Advanced Transfer Sequence Matching (CTE `TR`)
The core routing profile strictly isolates transfer transactions by evaluating backend platform constraints:
* **Call Dispositions:** Tightly filtered by UCCE disposition statuses: **`28` (Blind Transfer)** and **`29` (Consultative Transfer)**.
* **Agent Context:** The agent ID must be verified (`TCD.AgentSkillTargetID IS NOT NULL`) and the routing step must have a valid execution stamp (`RCD.BeganRoutingDateTime IS NOT NULL`).
* **Loop Deflection:** Loop-transfers back to the same service queue are explicitly suppressed via the filter logic: `SG.EnterpriseName != ISNULL(TDN.Description, '')`.

### 2. Next-Leg Skill Group Identification (`xFerToSG`)
To determine the receiving Skill Group target, a nested subquery looks forward in the timeline of the `RouterCallKey` / `RouterCallKeyDay`:
* It isolates the absolute earliest (`MIN(DateTime)`) subsequent row where a valid `SkillGroupSkillTargetID` exists.
* The search window anchor begins immediately after the current transfer timestamp (`NextSG.DateTime > TR.DateTime`).

### 3. Queue Wait Time Analytics (`WaitTime`)
The holding duration is dynamically extracted by matching the chronological handover:
* **Start Anchor:** The disconnect timestamp of the agent leg initiating the transfer (`TR.DateTime`).
* **End Anchor:** A correlated subquery locates the maximum `DateTime` segment that occurred *prior* to the next Skill Group's official registration time (`CT.DateTime < xFerToSG.DateTime`).
