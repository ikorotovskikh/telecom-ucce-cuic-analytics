# Agent_Activity_Detail_Real_Time

## Real-Time Report
**Data Source:** `STAT_DB` via transactional real-time table `t_Agent_Skill_Group_Real_Time` (aliased as `ASGRT`), integrated with platform configuration entities `t_Skill_Group` (`SG`), `t_Reason_Code` (`RC`), `t_Agent` (`A`), `t_Person` (`P`), and `t_Agent_Team` (`TM`).  
**Timeframe:** Statistics track live current daily cumulative state events updated in real-time.

### Report Filters

| Parameter | Description | Required | Comments |
| :--- | :--- | :---: | :--- |
| `@Teams` | Agent Teams | Yes | Maps to `:Teams` / `@ATL`. Multi-select allowed. Internally stripped of `null` string literals and split into a temporary key index table array (`@atList`). |
| `@Agents` | Agents | No | Maps to `:Agents` / `@AGL`. Multi-select allowed. Operators are structured hierarchically under teams. Supports a custom bypass rule where passing **ID `0`** overrides selection barriers to output logs for all team members. |

---

## Report Fields Schema

| # | SQL Field Name | Report Display Name | Formula / Logic Reference | Architectural Comments |
| :---: | :--- | :--- | :--- | :--- |
| 0 | `DateTime` | Timestamp | `ASGRT.DateTime` | Exact log event date and time when the agent changed state. |
| 1 | `AgentLogin` | Agent Login | `A.EnterpriseName` | Operator standard system enterprise workspace login credentials. |
| 2 | `AgentName` | Agent Name | `P.FirstName + ' ' + P.LastName` | Combined operator full name tracking string extracted from configuration. |
| 3 | `Team` | Team | `TM.EnterpriseName` | **[New Field]** Mapped organizational naming profile of the assigned agent team. |
| 4 | `SGName` | Skill Group | `SG.EnterpriseName` | Name of the active target Skill Group associated with the state change. |
| 5 | `Event` | Agent State | `CASE ASGRT.AgentState WHEN 0 THEN 'LOGGED_OFF' ... WHEN 31 THEN 'PRE_CALL_TIMEOUT'` | **Decoder Matrix:** Translates raw platform status numbers (0–31) into human-readable industrial call center lifecycle markers (see Lookup Key Index below). |
| 6 | `NR_Reason` | Reason Code | `CASE ASGRT.ReasonCode WHEN 0 THEN '' ELSE RC.ReasonText END` | **Text Reference Override:** Maps numeric indicators onto formal configuration definitions. Suppresses baseline default codes (`0`) into clean empty strings (`''`). |

---

## Technical Calculations & Underlying Logic

### 1. Unified Real-Time State Decoder Matrix (`AgentState` Lookups)
Raw numeric inputs extracted from the operational routing layer `ASGRT.AgentState` are dynamically translated on the backend to match standard CTI engineering states:
* `0` = **LOGGED_OFF** | `1` = **LOGGED_ON**
* `2` = **NOT_READY** (Global auxiliary or break state)
* `3` = **READY** (Available productive standby queue wait state)
* `4` = **TALKING** (Active line interaction connection established)
* `5` = **WORK_NOT_READY** (Wrap-up / After Call Work blocking routing lines)
* `6` = **WORK_READY** (Wrap-up / After Call Work allowing upcoming calls)
* `7` = **BUSY_OTHER** (Engaged in an active secondary task or desktop process)
* `8` = **RESERVED** (Platform allocation block prior to an inbound delivery handshake)
* `9` = **CALL_INITIATED** | `10` = **CALL_HELD** | `11` = **CALL_RETRIEVED**
* `12` = **CALL_TRANSFERRED** | `13` = **CALL_CONFERENCED** | `14` = **UNKNOWN**
* `15`–`23` = **TASK_MANAGEMENT** (Isolated entries handling multi-channel task states)
* `31` = **PRE_CALL_TIMEOUT** (Failsafe state triggered if call allocation handshakes expire)

### 2. Multi-Table Outer Consolidation Framework (`JOIN` Hierarchy)
To guarantee real-time record delivery without throwing execution data exceptions if an operator's desktop loses sync or configuration mappings change, the pipeline anchors to `t_Agent_Skill_Group_Real_Time` via explicit non-destructive outer linkages:
* Resolves employee directory keys via `LEFT OUTER JOIN t_Agent A` and `t_Person P`.
* Maps active team structural references via `t_Agent_Team_Member ATM` and `t_Agent_Team TM`.
* Extracts human-readable descriptive break summaries via `LEFT OUTER JOIN t_Reason_Code RC`.

### 3. Chronological Identity Profiling Sorting Strategy
The reporting grid presents data grouped by individuals, tracking their sequential activities over time:
```sql
ORDER BY P.LastName, P.FirstName, ASGRT.DateTime
```
This forces a two-tier database layout: it alpha-sorts operators by their legal Last Name first, then sequentially charts every state transition row chronologically (`DateTime` ascending), capturing a precise activity timeline.
