# 1LTP_NSK_HIST_Teams

## Historical Report
**Data Source:** `STAT_DB` (`t_Agent_Event_Detail`, `t_Agent_Skill_Group_Interval`, `t_Agent_Interval`, `t_Termination_Call_Detail`).

### Report Filters

| Parameter | Description | Required | Comments |
| :--- | :--- | :---: | :--- |
| `@StartTime` | Reporting Period Start | Yes | |
| `@EndTime` | Reporting Period End | Yes | |
| `@Teams` | Agent Teams | Yes | Multi-select allowed. |
| `@SkillGroups` | Skill Groups | No* | Multi-select allowed. Skill Groups are nested within regions. Selecting a region automatically selects all underlying Skill Groups. |
| `@Agents` | Agents | No* | Multi-select allowed. Agents are nested within Skill Groups. Selecting a Skill Group automatically selects all associated agents. |

*\* Filtering Logic Notes:*
* If **only Skill Groups** are selected, the report returns all team agents active within those specific Skill Groups during the interval.
* If **only Agents** are selected, the report returns agent metrics across all Skill Groups they participated in.
* If **both** filters are applied, agent activities are strictly scoped to the intersection of selected Agents and selected Skill Groups.

---

### Report Fields

| # | SQL Field Name | Report Display Name | Formula | Summary Formula | Comments |
| :---: | :--- | :--- | :--- | :--- | :--- |
| 0 | `Agent` | Agent | | | Agent Peripheral ID. |
| 1 | `AgentLogin` | Agent Login | | | Operator login credentials. |
| 2 | `AgentName` | Agent Name | | | Rows are grouped by this field. |
| 3 | `Team` | Team | | | Agent row total contains the reporting time interval. |
| 4 | `SkillName` | Skill Group | | | Agent row total contains the reporting time interval. |
| 5 | `CallsHandled` | Handled | | `SUM(CallsHandled_T)` | Handled calls counter. |
| 6 | `CallsAnswered` | Answered | | `SUM(CallsAnswered_T)` | Answered calls counter. |
| 7 | `AbandonRingCalls` | Abandoned on Ring | | `SUM(AbandonRingCalls_T)` | Calls abandoned while ringing the agent. |
| 8 | `rc_count` | Repeated Calls | | `SUM(rc_count_T)` | Repeated interactions count (see Logic section). |
| 9 | `rc_percent` | Repeated Calls % | `rc_count / (CallsAnswered + AbandonRingCalls)` | `rc_count_T / (CallsAnswered_T + AbandonRingCalls_T)` | Percentage of repeated contacts. |
| 10 | `AHT` | AHT | `HandledCallsTime / CallsHandled` | `HandledCallsTime_T / CallsHandled_T` | Average Handle Time. |
| 11 | `OCC` | Occupancy | *See Formula Matrix below* | *See Summary Matrix below* | Agent Occupancy Rate. |
| 12 | `UTZ` | Utilization | `(LogInTime - NotReadyTime) / LogInTime` | `(LogInTime - NotReadyTime) / LogInTime` | Agent Utilization Rate. |
| 13 | `LogInTime` | Logged On Time | `SecondsByEventInPeriod WHEN [Event] = 2` | `LogInTime` | Total agent logged-in time. |
| 14 | `NotReadyTime` | Not Ready Time | `SecondsByEventInPeriod WHEN [Event] = 3` | `NotReadyTime` | Total time spent in Not Ready state. |
| 15 | `HandledCallsTime` | Handled Calls Time | | `SUM(HandledCallsTime_T)` | |
| 16 | `TalkTime` | Talk Time | `TalkInTime + TalkOutTime + TalkOtherTime + TalkAutoOutTime + TalkPreviewTime + TalkReserveTime` | `SUM(TalkTime_T)` | Combined active conversation time. |
| 17 | `HoldTime` | Hold Time | | `SUM(HoldTime_T)` | Total time customers spent on hold. |
| 18 | `ReservedTime` | Reserved Time | | `SUM(ReservedTime_T)` | Time agent spent in Reserved state. |
| 19 | `WrapTime` | Wrap Time | `WorkNotReadyTime + WorkReadyTime` | `SUM(WrapTime_T)` | After Call Work (ACW) duration. |
| 20 | `TechnoBreakTime` | Break | `SecondsByEventInPeriod WHEN [Event] = 3 AND ReasonCode = 10` | `TechnoBreakTime` | Technical/Rest Break. |
| 21 | `LunchTime` | Lunch | `SecondsByEventInPeriod WHEN [Event] = 3 AND ReasonCode = 20` | `LunchTime` | Meal break. |
| 22 | `ToManagerTime` | Call to Supervisor | `SecondsByEventInPeriod WHEN [Event] = 3 AND ReasonCode = 20` | `ToManagerTime` | Meeting with management. |
| 23 | `WorkFromBossTime` | Task from Supervisor | `SecondsByEventInPeriod WHEN [Event] = 3 AND ReasonCode = 20` | `WorkFromBossTime` | Special assignment. |
| 24 | `MentorTime` | Mentoring | `SecondsByEventInPeriod WHEN [Event] = 3 AND ReasonCode = 50` | `MentorTime` | Training/coaching others. |
| 25 | `TechProblemsTime` | Tech Issues | `SecondsByEventInPeriod WHEN [Event] = 3 AND ReasonCode = 60` | `TechProblemsTime` | Hardware/software downtime. |
| 26 | `DiscreteContactsTime` | Discrete Channels | `SecondsByEventInPeriod WHEN [Event] = 3 AND ReasonCode = 70` | `DiscreteContactsTime` | Back-office processing / async chats. |
| 27 | `OutgoingCallTime` | Outbound Call | `SecondsByEventInPeriod WHEN [Event] = 3 AND ReasonCode = 80` | `OutgoingCallTime` | Outbound dialing activity. |
| 28 | `EducationTime` | Training | `SecondsByEventInPeriod WHEN [Event] = 3 AND ReasonCode = 90` | `EducationTime` | Learning activities / tutorials. |
| 29 | `CoachingTime` | Coaching | `SecondsByEventInPeriod WHEN [Event] = 3 AND ReasonCode = 100` | `CoachingTime` | One-on-one professional feedback. |
| 30 | `QCFeedBackTime` | QA Feedback | `SecondsByEventInPeriod WHEN [Event] = 3 AND ReasonCode = 110` | `QCFeedBackTime` | Quality assurance performance review. |
| 31 | `PostProcessTime` | Post-Processing | `SecondsByEventInPeriod WHEN [Event] = 3 AND ReasonCode = 120` | `PostProcessTime` | Extended back-office processing. |
| 32 | `EndOfShiftTime` | End of Shift | `SecondsByEventInPeriod WHEN [Event] = 3 AND ReasonCode = 130` | `EndOfShiftTime` | Shift completion activities. |
| 33 | `MeetingTime` | Meeting | `SecondsByEventInPeriod WHEN [Event] = 3 AND ReasonCode = 140` | `MeetingTime` | Team briefs or assemblies. |
| 34 | `OtherBreakTime` | Other | `SecondsByEventInPeriod WHEN [Event] = 3 AND ReasonCode = all_other_codes` | `OtherBreakTime` | Catch-all for undefined reason codes. |

---

### Formula Matrices (OCC Metrics)

#### 11. OCC Base Formula:
```text
HandledCallsTime / (AvailTime + HoldTime + ReservedTime + WorkNotReadyTime + WorkReadyTime + TalkInTime + TalkOutTime + TalkOtherTime + TalkAutoOutTime + TalkPreviewTime + TalkReserveTime)
```

#### 11. OCC Summary Formula:
```text
HandledCallsTime_T / (AvailTime_T + HoldTime_T + ReservedTime_T + WorkNotReadyTime_T + WorkReadyTime_T + TalkInTime_T + TalkOutTime_T + TalkOtherTime_T + TalkAutoOutTime_T + TalkPreviewTime_T + TalkReserveTime_T)
```

---

## Technical Calculations & Underlying Logic

### Repeated Calls (`rc_count`)
Repeated calls are processed via a separated `SELECT` query subroutines using the following criteria:
* **Definition:** Tracks metrics from an ANI (Caller ID) that generated at least one other interaction within the preceding 24 hours. 
* **Aggregation:** The absolute volume of previous calls from the same ANI does not scale the counter; each unique ANI increments the value by exactly 1, regardless of how many repeated attempts were made.
* **De-duplication Barrier:** To avoid double-counting across operators, a repeated call is strictly allocated to the agent who handled the **final (most recent)** repeated interaction leg. The counter remains unchanged for any agents who accepted earlier calls from that same ANI.
* **Scope:** The lookup boundaries are constrained strictly within the selected Skill Groups (either explicitly defined via parameters or dynamically resolved based on the historical team agent allocations).

### Field Suffix Resolutions (`_T`)
* Fields appended with the **`_T` suffix** are internal variables isolated strictly for grand total aggregation calculations (`Total` footer calculations).
* For metrics dependent on Skill Group configurations, individual row summations query their respective Skill Group datasets.
* For parameters independent of Skill Group constraints (e.g., `Logged On Time`), totals are computed directly using the lower boundary rollup row summary profile.
```

Если вам потребуется дописать сам **SQL-код для вычисления блока повторных звонков (`rc_count`)** с учетом этой логики дедупликации по последнему агенту, дайте знать. Мы сможем спроектировать его оптимально через оконные функции `ROW_NUMBER()`.
