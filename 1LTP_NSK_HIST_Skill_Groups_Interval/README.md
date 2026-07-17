# Report: "1LTP_NSK_HIST_Skill_Groups_Interval"

**Report Type:** Historical Report  
**Data Source:** `STAT_DB` (`Skill_Group_Interval`)

---

## 🎛️ Report Filters

| Parameter | Description | Required | Comments |
| :--- | :--- | :---: | :--- |
| `@startTime` | Period Start Date/Time | **Yes** | |
| `@endTime` | Period End Date/Time | **Yes** | |
| `@typeDT` | Interval Size | **Yes** | Options include: "Daily", "Hourly", "15-Minute", and "For the entire period". Only a single selection is allowed. |
| `@SkillTargetID` | Skill Group | **Yes** | Supports multi-select. Skill groups are aggregated by regions. Selecting a region automatically selects all underlying skill groups. |

---

## 📊 Report Fields & Metrics

| # | SQL Column Name | Report Display Name | Formula / Logic | Total Formula | Comments / Business Logic |
| :-: | :--- | :--- | :--- | :--- | :--- |
| **0** | `SgName` | Skill Group | | | |
| **1** | `Interval` | Interval | | | 15-minute interval baseline. |
| **2** | `CallsOffered` | Offered Calls | | `SUM` | Total volume of incoming calls. |
| **3** | `CallsAnswered` | Answered Calls | | `SUM` | Total calls handled. |
| **4** | `RouterMaxCallsQueued` | Max Queue Count | | `MAX` | Peak concurrent call load in queue. |
| **5** | `avgAnswerWaitTime` | Average Speed of Answer (ASA) | `AnswerWaitTime / CallsAnswered` | `SUM(AnswerWaitTime) / SUM(CallsAnswered)` | Average time users spent waiting for an answer. |
| **6** | `avgAbandWaitTime` | Avg Abandon Wait Time | `(AbandonRingTime + RouterDelayQAbandTime) / (RouterCallsAbandQ + RouterCallsAbandToAgent)` | `SUM(AbandWaitTime) / (SUM(RouterCallsAgentAbandons) + SUM(RouterCallsAbandQ))` | Average time callers waited in queue before dropping off. |
| **7** | `LCR` | Lost Call Rate (LCR) | `(AbandonRingCalls + RouterCallsAbandQ) / (CallsAnswered + RouterCallsAbandQ + AbandonRingCalls + RedirectNoAnsCalls)` | `((SUM(RouterCallsAgentAbandons) + SUM(RouterCallsAbandQ)) / (SUM(RouterCallsAgentAbandons) + SUM(RouterCallsAbandQ) + SUM(CallsAnswered))` | Total call abandonment rate across all routing phases. |
| **8** | `SL30` | Service Level (SL30) | `ServiceLevelCalls / (CallsAnswered + RouterCallsAbandToAgent + RouterCallsAbandQ)` | `(SUM(RouterCallsAgentAbandons) + SUM(RouterCallsAbandQ)) / (SUM(RouterCallsAgentAbandons) + SUM(RouterCallsAbandQ) + SUM(CallsAnswered))` | Standard Service Level math calculated per interval. |
| **9** | `AHT` | Average Handle Time (AHT) | `(TalkInTime + TalkOtherTime + TalkOutTime + HoldTime + WorkReadyTime + WorkNotReadyTime + ReservedStateTime + ConferencedInCallsTime) / CallsAnswered` | `SUM(HT) / SUM(CallsAnswered)` | Comprehensive calculation including all Cisco state durations. `HT = HandledCallsTime + ReservedStateTime`. |
| **10**| `HT` | Handle Time (HT) | `HandledCallsTime + ReservedStateTime` | `SUM` | Total cumulative raw handling time. |
