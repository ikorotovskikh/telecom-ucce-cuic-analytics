# Inbound_Call_Details_by_DN

## Historical Report
**Data Source:** `STAT_DB` via temporary staging tables `#TCD` (`t_Termination_Call_Detail`) and `#RCD` (`t_Route_Call_Detail`).

To filter by DN list, the Value List `DRDZ_DNs_Collectons` and the mapping table `tDRDZ_DNs` are used.

### Report Filters

| Parameter | Description | Required | Comments |
| :--- | :--- | :---: | :--- |
| `@start` | Reporting Period Start | Yes | Maps to `:start`. Selects calls where call start time (`DateTime - Duration`) falls within the interval. |
| `@end` | Reporting Period End | Yes | Maps to `:end`. Right boundary constraint for selection. |
| `@DNID` | DN List | Yes | Maps to `:DNID`. Comma-separated multi-select. Used to filter initial landing `DNIS` or `DigitsDialed`. |
| `@Teams` | Agent Teams | Yes | Maps to `:Teams`. Comma-separated team IDs. Passing `0` bypasses the filter and selects all teams. |

### Report Fields

| # | SQL Field Name | Report Display Name | Formula / Logic | Comments |
| :---: | :--- | :--- | :--- | :--- |
| 0 | `Direction` | Direction | `dirn.Direction` | OIO, DZO, 3K, or GVAO (from `tDRDZ_DNs`). |
| 1 | `DN` | DN | `DNTCD.DN` | Evaluated via `CASE WHEN DigitsDialed IS NULL THEN DNIS ELSE DigitsDialed END`. CC Extension Number where the call initially landed. |
| - | `Team` | Team | `TM.EnterpriseName` | Name of the Agent Team (`t_Agent_Team`). |
| 2 | `Agent` | Agent | `t_Agent.EnterpriseName` | Operator login / account name. |
| 3 | `AgentNumber` | Agent Number | `TCD.InstrumentPortNumber` | Operator extension. |
| 4 | `ANI` | ANI | `DNTCD.ANI` | Caller ID (Automatic Number Identification). |
| 5 | `StartHour` | Hour | `DATEPART(HOUR, DNTCD.StartCall)` | Extracted hour part of the call arrival timestamp. |
| 6 | `StartCall` | Queued Time | `MIN(DATEADD(SECOND, -1*Duration, DateTime))` | The exact timestamp when the call initially entered the contact center. |
| 7 | `StartOperator` | Agent Connected | `DATEADD(SECOND, -(TalkTime + HoldTime + WorkTime), DateTime)` | Time when the call landed on the agent (Calculated as disconnect time minus active states). |
| - | `StartOperatorRT` | Operator Alerting | `DATEADD(SECOND, -(Duration - RingTime - DelayTime), DateTime)` | *Calculated in SQL (for troubleshooting) but hidden/not mapped to standard column profile.* |
| 14 | `EndCall` | Call End Time | `CASE WHEN AgentID IS NULL THEN DNTCD.EndCall ELSE DATEADD(SECOND, -WorkTime, TCD.DateTime) END` | Dynamic logic: If abandoned, equals `MAX(DateTime)`. If answered, subtracts post-call processing time (`WorkTime`) from disconnect time. |
| 13 | `Duration` | Call Duration | `CASE WHEN AgentID IS NULL THEN DATEDIFF(SECOND, StartCall, EndCall) ELSE DATEDIFF(SECOND, StartCall, TCD.DateTime) END` | Dynamic logic: Total duration from call start up to disconnect (for handled calls) or up to abandonment. |
| 10 | `TalkTime` | Talk Time | `TCD.TalkTime` | Active conversation duration. |
| 11 | `HoldTime` | Hold Time | `TCD.HoldTime` | Total time the call spent on hold during this specific leg. |
| 12 | `WorkTime` | Wrap-Up Time | `TCD.WorkTime` | Post-call processing time (After Call Work). |
| 9 | `RingTime` | Ring Time | `TCD.RingTime` | Agent alerting/ringing time. |
| 8 | `QueueTime` | Queue Wait Time | `CASE WHEN AgentID IS NULL THEN DATEDIFF(...) ELSE COALESCE(QT.RouterQueueTime, DATEDIFF(...)) END` | Fallback logic: If router queue data is missing, falls back to calculating delta between `StartCall` and Agent Connection Time. |
| 15 | `SkillGroup` | Skill Group | `t_Skill_Group.EnterpriseName` | Associated Skill Group name for the handled leg. |
| 16 | `ID` | Call ID | `CAST(RouterCallKey AS varchar) + CAST(RouterCallKeyDay AS varchar)` | Synthetic unique call ID string combining router key and day. |
| 17 | `CTName` | Call Type | `t_Call_Type.EnterpriseName` | Service Name resolved via `COALESCE(TCD.CallTypeID, QT.CallTypeID, DNTCD.CallTypeID)`. |
| 18 | `xferSG` | Transfer to Skill Group | `xferSG.EnterpriseName` | Name of the **next immediate** Skill Group the call was transferred to. Resolved via a subquery looking for the absolute minimum `DateTime` of the next valid leg. |

### Technical Filtering Adjustments (Backend Rules)
* **Outbound Call Suppression:** Ensured by `RouterCallKeyDay != 0` check.
* **Internal Leg Cleanup:** Filter `COALESCE(...) != -1` strictly removes all internal/consult call legs from the final dataset.
* **Double Routing Protection:** `LEFT JOIN #RCD QT` uses strict temporal encapsulation barriers (`QT.DateTime >= ... AND QT.DateTime < ...`) to prevent duplicate calculation on redundant target labels.
