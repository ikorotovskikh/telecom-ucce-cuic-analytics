# Agent_Activity_Detail_Historical

## Historical Report
**Data Source:** `STAT_DB` via optimized cached staging tables `#AT` (reconstructed state timeline) and `#TCD` (`t_Termination_Call_Detail`), unified with `t_Agent_Event_Detail` (`AED`), `t_Agent`, `t_Agent_Team`, and `t_Reason_Code` (`RC`).

### Report Description & Profile
This report dynamically reconstructs a precise, second-by-second chronological timeline (an industrial "Day-in-the-Life" or "Agent Activity Trace" audit log) for targeted contact center operators. It merges asynchronous agent state event transitions with core hardware switching telephony sessions.

### Report Filters

| Parameter | Description | Required | Comments |
| :--- | :--- | :---: | :--- |
| `@BeginDate` | Selection Start Date | Yes | Maps to `:BeginDT`. Truncates lower historical boundaries based on call origination timestamps. |
| `@EndDate` | Selection End Date | Yes | Maps to `:EendDT`. Truncates upper historical boundaries based on call origination timestamps. |
| `@Teams` | Agent Teams | Yes | Maps to `:Teams`. Multi-select allowed. Converted into an internal processing integer array (`@atList`). |
| `@Agents` | Specific Operators | No | Maps to `:Agents`. Multi-select allowed. Supports a dedicated **ID `0`** bypass matrix to query all team members simultaneously. |

---

## Report Fields Schema

| # | SQL Field Name | Report Display Name | Formula / Logic Reference | Architectural Comments |
| :---: | :--- | :--- | :--- | :--- |
| 0 | `Team` | Team | `TM.EnterpriseName` | Mapped agent team name profile. |
| 1 | `Agent` | Agent | `A.EnterpriseName` | Operator standard system enterprise workspace login credentials. |
| 2 | `DT` | Timestamp | • **LOGIN/LOGOUT:** `DateTime` truncated to seconds.<br>• **NOT_READY:** `DateTime - TD_Duration` (reconstructed interval entry point).<br>• **CALL START:** `DateTime - Duration - (Ring+Talk+Hold+Wrap)`. | **Dynamic Timeline Synchronization:** Normalizes all transaction events into an unbroken timeline by removing millisecond drift. |
| 3 | `EventDesc` | Event Description | Evaluates state rules maps:<br>• `1` = `'LOGIN'` \| `2` = `'LOGOUT'`<br>• `3` = `'NOT_READY'` \| Native = `'READY'`<br>• Telephony = `'CALLIN'` / `'CALLOUT'` / `'CALLEND'` | **Blended Lifecycle Identity:** Combines standard ACD agent tracking status states with raw call placement markers. |
| 4 | `NR_Reason` | Context / Reason | • **NOT_READY:** `RC.ReasonText`<br>• **CALLIN:** Customer Caller ID (`ANI`) <br>• **CALLOUT:** Target Digits Dialed (`DigitsDialed`) | **Multi-Purpose Descriptive Slot:** Displays human-readable break summaries for auxiliary states, or routing digits/telephony parameters for active connections. |
| - | `EDSort` | Event Sort Priority | `LOGIN` (1) $\rightarrow$ `CALL START` (3) $\rightarrow$ `CALLEND` (4) $\rightarrow$ `NOT_READY` (5) $\rightarrow$ `READY` (6) $\rightarrow$ `LOGOUT` (9) | *Internal sorting metadata sequence used to align overlapping same-second operations.* |

---

## Technical Calculations & Underlying Logic

### 1. 15-Minute Discrete State Reconstruction Loop (CTE `Durations`)
Cisco UCCE forces automated truncation on extended state logs, slicing long non-productive session tasks into default 15-minute intervals. To establish the actual true entry time anchor for a `NOT_READY` block, the backend uses a complex historical evaluation subquery:
* It looks backward in time from the target record to locate the peak grouping marker (`MAX(DateTime)`) where an operative `NOT_READY` state change occurred with a different reason code.
* It selects all fragmented chunks generated inside that window constraint where scheduling intervals meet the standard platform structure barrier:
  ```sql
  AND (DATEPART(MINUTE, TD.DateTime) % 15) = 0 AND DATEPART(SECOND, TD.DateTime) = 0
  ```
* These separate durations are summed up (`SUM(ISNULL(TD.Duration, 0)) + AED.Duration`) into a synthetic interval metric variable named `TD_Duration`. The report then subtracts this value from the active record timestamp to calculate the true starting time of the state: `DATEADD(SECOND, -AED.TD_Duration, AED.DateTime)`.

### 2. Implicit `READY` State Synthesis & Excess Deduplication
The platform's base event structure logs active transitions (`LOGIN`, `LOGOUT`, reason code auxiliary changes) but omits dedicated historical row updates for steady-state `READY` durations.
* **Generation:** The report infers `READY` markers by executing an anti-semi-join via `UNION ALL`. It isolates events from `Durations` where no overlapping conflicting operations exist at that exact timestamp:
  ```sql
  LEFT JOIN Durations DOUBLES ON A.DateTime = DOUBLES.DateTime AND (DOUBLES.Event != 3 OR ...)
  WHERE DOUBLES.DateTime IS NULL
  ```
* **Deduplication Pass:** To prevent overlapping status entries from cluttering grid displays, a secondary deduplication join step filters out redundant `READY` rows if they overlap with a non-ready action within a 1-second time window:
  ```sql
  LEFT JOIN (SELECT DT, DATEADD(SECOND, 1, DT) AS DTP1S ... WHERE EventDesc != 'READY') B 
  ON AST.DT = B.DT OR AST.DT = B.DTP1S
  WHERE B.DT IS NULL
  ```

### 3. Chronological Identity Profiling Sorting Strategy
To keep timeline displays intuitive and organized, the final report data is structured via a unified `UNION ALL` aggregation block pass sorted through a mandatory three-tier sorting priority layer:
```sql
ORDER BY TM.EnterpriseName, A.EnterpriseName, REPORT.DT, REPORT.EDSort
```
1. **`TM.EnterpriseName`**: Clusters employee row sets alphabetically by their assigned Team Name.
2. **`A.EnterpriseName`**: Groups entries alphabetically by the agent's system account login credentials within each team.
3. **`REPORT.DT` + `REPORT.EDSort`**: Arranges all activities in chronological order. If multiple state changes occur within the exact same second, the internal priority weights (`EDSort`) ensure they align logically (e.g., logging a call termination `CALLEND` directly before an agent shifts into a `NOT_READY` break state).
