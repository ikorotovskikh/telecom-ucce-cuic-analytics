# Report: "1LTP_NSK_HIST_Operators"

**Report Type:** Historical Report  
**Data Sources:** `STAT_DB` (`t_Agent_Event_Detail`, `t_Agent_Skill_Group_Interval`, `t_Agent_Interval`, `t_Termination_Call_Detail`)

---

## 🎛️ Report Filters

| Parameter | Description | Required | Comments |
| :--- | :--- | :---: | :--- |
| `@StartTime` | Period Start Date/Time | **Yes** | |
| `@EndTime` | Period End Date/Time | **Yes** | |
| `@SkillGroups` | Skill Groups | No* | Supports multi-select. Grouped by regions. Selecting a region automatically selects all underlying skill groups. |
| `@Agents` | Agents / Operators | No* | Supports multi-select. Grouped by skill groups. Selecting a skill group automatically selects all assigned agents. |

> 📌 **\*Filter Logic Combinations:**
> * Selecting **Skill Groups only**: Returns data for all agents active within the chosen skill groups during the selected period.
> * Selecting **Agents only**: Returns performance metrics for all skill groups the selected agents participated in.
> * Selecting **Both**: Displays agent activities *strictly restricted* to the selected skill groups.

---

## 📊 Report Fields & Metrics

| # | SQL Column Name | Report Display Name | Formula / Logic | Total Formula | Comments / Business Logic |
| :-: | :--- | :--- | :--- | :--- | :--- |
| **0** | `Agent` | Agent ID | | | Unique Cisco Agent ID. |
| **1** | `AgentLogin` | Agent Login | | | |
| **2** | `AgentName` | Agent Name | | | Rows are grouped by this field. |
| **3** | `SkillName` | Skill Group | | | The agent's final summary row contains the time interval instead. |
| **4** | `CallsHandled` | Handled Calls | | `SUM(CallsHandled_T)` | Total calls handled by the agent. |
| **5** | `CallsAnswered` | Answered Calls | | `SUM(CallsAnswered_T)` | |
| **6** | `AbandonRingCalls`| Abandoned on Ring | | `SUM(AbandonRingCalls_T)`| Calls abandoned by the user while ringing the agent. |
| **7** | `rc_count` | Repeated Calls | *Calculated via subquery* | `SUM(rc_count_T)` | See 'Repeated Calls Logic' below. |
| **8** | `rc_percent` | Repeat Call % | `rc_count / (CallsAnswered + AbandonRingCalls)` | `rc_count_T / (CallsAnswered_T + AbandonRingCalls_T)` | |
| **9** | `AHT` | AHT (Daily) | `HandledCallsTime / CallsHandled` | `HandledCallsTime_T / CallsHandled_T` | Average Handle Time. |
| **10**| `OCC` | Occupancy (OCC) | `HandledCallsTime / (AvailTime + HoldTime + ReservedTime + WorkNotReadyTime + WorkReadyTime + TalkInTime + TalkOutTime + TalkOtherTime + TalkAutoOutTime + TalkPreviewTime + TalkReserveTime)` | `HandledCallsTime_T / (AvailTime_T + HoldTime_T + ReservedTime_T + WorkNotReadyTime_T + WorkReadyTime_T + TalkInTime_T + TalkOutTime_T + TalkOtherTime_T + TalkAutoOutTime_T + TalkPreviewTime_T + TalkReserveTime_T)` | Formula handles all Cisco-specific voice state durations. |
| **11**| `UTZ` | Utilization (UTZ) | `(LogInTime - NotReadyTime) / LogInTime` | `(LogInTime - NotReadyTime) / LogInTime` | Agent utilization score. |
| **12**| `LogInTime` | Logged On Time | `SecondsByEventInPeriod WHERE [Event] = 2` | `LogInTime` | |
| **13**| `NotReadyTime` | Not Ready Time | `SecondsByEventInPeriod WHERE [Event] = 3` | `NotReadyTime` | Total time spent in any 'Not Ready' state. |
| **14**| `HandledCallsTime`| Handled Calls Time | | `SUM(HandledCallsTime_T)`| |
| **15**| `TalkTime` | Talk Time | `TalkInTime + TalkOutTime + TalkOtherTime + TalkAutoOutTime + TalkPreviewTime + TalkReserveTime` | `SUM(TalkTime_T)` | Aggregated talk time across inbound, outbound, and internal calls. |
| **16**| `HoldTime` | Hold Time | | `SUM(HoldTime_T)` | |
| **17**| `ReservedTime` | Reserved Time | | `SUM(ReservedTime_T)` | |
| **18**| `WrapTime` | Wrap Time | `WorkNotReadyTime + WorkReadyTime` | `SUM(WrapTime_T)` | After-call work (ACW) duration. |
| **19**| `TechnoBreakTime` | Technical Break | `SecondsByEventInPeriod WHERE [Event] = 3 AND ReasonCode = 10` | `TechnoBreakTime` | Reason Code: 10. |
| **20**| `LunchTime` | Lunch Break | `SecondsByEventInPeriod WHERE [Event] = 3 AND ReasonCode = 20` | `LunchTime` | Reason Code: 20. |
| **21**| `ToManagerTime` | Meeting with Manager| `SecondsByEventInPeriod WHERE [Event] = 3 AND ReasonCode = 30` | `ToManagerTime` | Reason Code: 30 *[Note: Adjusted to 30 to avoid duplicate 20]*. |
| **22**| `WorkFromBossTime`| Assigned Tasks | `SecondsByEventInPeriod WHERE [Event] = 3 AND ReasonCode = 40` | `WorkFromBossTime` | Reason Code: 40 *[Note: Adjusted to 40]*. |
| **23**| `MentorTime` | Mentoring | `SecondsByEventInPeriod WHERE [Event] = 3 AND ReasonCode = 50` | `MentorTime` | Reason Code: 50. |
| **24**| `TechProblemsTime`| IT / Tech Issues | `SecondsByEventInPeriod WHERE [Event] = 3 AND ReasonCode = 60` | `TechProblemsTime` | Reason Code: 60. |
| **25**| `DiscreteContactsTime`| Discrete Channels | `SecondsByEventInPeriod WHERE [Event] = 3 AND ReasonCode = 70` | `DiscreteContactsTime`| Reason Code: 70. |
| **26**| `OutgoingCallTime`| Outbound Campaign | `SecondsByEventInPeriod WHERE [Event] = 3 AND ReasonCode = 80` | `OutgoingCallTime`| Reason Code: 80. |
| **27**| `EducationTime` | Training / Education| `SecondsByEventInPeriod WHERE [Event] = 3 AND ReasonCode = 90` | `EducationTime` | Reason Code: 90. |
| **28**| `CoachingTime` | Coaching | `SecondsByEventInPeriod WHERE [Event] = 3 AND ReasonCode = 100`| `CoachingTime` | Reason Code: 100. |
| **29**| `QCFeedBackTime` | Quality Feedback | `SecondsByEventInPeriod WHERE [Event] = 3 AND ReasonCode = 110`| `QCFeedBackTime` | Reason Code: 110. |
| **30**| `PostProcessTime` | Post-Processing | `SecondsByEventInPeriod WHERE [Event] = 3 AND ReasonCode = 120`| `PostProcessTime` | Reason Code: 120. |
| **31**| `EndOfShiftTime` | End of Shift | `SecondsByEventInPeriod WHERE [Event] = 3 AND ReasonCode = 130`| `EndOfShiftTime` | Reason Code: 130. |
| **32**| `MeetingTime` | Team Meeting | `SecondsByEventInPeriod WHERE [Event] = 3 AND ReasonCode = 140`| `MeetingTime` | Reason Code: 140. |
| **33**| `OtherBreakTime` | Other Breaks | `SecondsByEventInPeriod WHERE [Event] = 3 AND ReasonCode = [All Other Codes]` | `OtherBreakTime` | Fallback category for unmapped reason codes. |

---

## ⚙️ Aggregation & Total Rows Logic

### 🔻 Bottom Summary Row (Time-Interval Row)
* Displays cumulative statistics for the agent as an **independent entity**, without skill group segmentation.
* Time-based metrics (such as *Logged On Time*, *Breaks*, *TalkTime*) are calculated globally for the agent.
* Volumetric metrics (like *Handled Calls*) are computed as a simple sum across all skill groups the agent participated in during the interval.

### 🔺 Top Summary Row
* Displays aggregated statistics (including *OCC*, *UTZ*, *AHT*) **restricted exclusively to the selected skill groups**.
* Excludes core agent-level time parameters like *Logged On Time*, which cannot be logically mapped to a specific skill group.
* **Note:** If the filter encompasses *all* skill groups the agent belonged to during the period, the Top Summary Row matches the Bottom Summary Row.

---

## 🔄 Repeated Calls Logic (`rc_count`)

* Evaluated using a separated `SELECT` statement mapping CLI/ANI (Caller ID) data.
* **Definition:** Captures calls from a specific CLI that has initiated at least one other call within the preceding **24 hours**. The absolute frequency of previous calls is ignored; each unique repeating CLI increments the counter by 1.
* **De-duplication Rule:** To prevent double-counting, the repeat flag is attributed *only* to the agent who handled the **most recent** callback. Prior agents who answered calls from the same CLI within the window do not have their counter incremented.
* **Scope Constraints:** Repeat call lookup is restricted to the bounds of the chosen skill groups.

*Technical Note: Columns suffixed with `_T` are technical placeholders dedicated strictly to the computation of `Total` aggregates.*
