# Inbound_Calls_Management_Performance

## Historical Report
**Data Source:** `STAT_DB` via base tables `Termination_Call_Detail` (aliased as `TCD_Temp`), `t_Route_Call_Detail` (`RCD`), and `t_Skill_Group`.  
**Optimization Layer:** Utilizes an internal table variable buffer `@RCD` to pre-aggregate and deduplicate routing streams.

### Report Filters

| Parameter | Description | Required | Comments |
| :--- | :--- | :---: | :--- |
| `@start` | Date Range Start | Yes | Maps to `:start` / `@BeginDate`. Lower boundary constraint for the historical interaction timeline. |
| `@end` | Date Range End | Yes | Maps to `:end` / `@EndDate`. Upper boundary constraint for the historical interaction timeline. |
| `@SGID` | Skill Groups | Yes | Maps to `:SGID` / `@SGL`. Multi-select allowed. Internally parsed into a temporal collection array (`@sgList`) using string-split mechanics. |

---

### Report Fields

| # | SQL Field Name | Report Display Name | Formula / Logic | Comments |
| :---: | :--- | :--- | :--- | :--- |
| 0 | `SkillGroup` | Target Skill Group | `t_Skill_Group.EnterpriseName` | Mapped inbound Skill Group name profile. |
| 1 | `EnteredToQueue` | Entered Queue | `COUNT(ID)` where `ID = CAST(RouterCallKey AS VARCHAR) + CAST(RouterCallKeyDay AS VARCHAR)` | **Composite Deduplication:** Total volume of unique, distinct customer call keys matching across routing and termination logs. |
| 2 | `GotToOperator` | Handled by Agent | `SUM(GotToOperator)` where:<br>`AgentSkillTargetID IS NOT NULL`<br>AND `TimeToAband = 0` | Total calls successfully answered and processed by an operator (excludes abandons before connection). |
| 3 | `GotToOperatorIn30Sec` | Handled Within 30 Sec | `SUM(GotToOperatorIn30Sec)` calculated via dynamic second delta boundary lookup | **SLA Segment Tracking:** Number of calls answered by an agent within the designated 30-second Service Level threshold (see Timezone/State validation matrix below). |
| 4 | `TalkTime` | Talk Time (sec) | `SUM(TCD.TalkTime)` | Aggregated customer active conversation duration (excluding hold and wrap states). |
| 5 | `pHandled` | % Handled | `SUM(GotToOperator) * 1.0 / COUNT(ID)` | Handled Rate percentage. Tracks operational efficiency against total inbound queue demand. |
| 6 | `SL30` | Service Level (30s) | `SUM(GotToOperatorIn30Sec) * 1.0 / COUNT(ID)` | Service Level performance indicator evaluated against the baseline 30-second target. |
| 7 | `ATT` | Average Talk Time (sec) | `SUM(TCD.TalkTime) * 1.0 / SUM(GotToOperator)` | ATT (Average Talk Time per single handled customer connection leg). |

---

## Technical Calculations & Underlying Logic

### 1. In-Memory Intermediate Routing Extraction (`@RCD` Buffer)
To optimize query performance across heavily indexed transactional tables, the query isolates data using an explicit in-memory table variable execution pass:
* It maps distinct compound call keys (`RouterCallKey` + `RouterCallKeyDay`) alongside queue holding benchmarks (`RouterQueueTime`) and dialed numbers (`DialedNumberString`).
* Links `t_Route_Call_Detail` directly to `Termination_Call_Detail` within the primary timeline parameters to filter out non-contact center routing steps before running the final aggregate summary.

### 2. Timezone Normalization & SLA Performance Assessment
To accurately evaluate if an interaction met the 30-second organizational Service Level objective, the script bypasses standard pre-calculated counters and performs a real-time interval check:
* **Timezone Offset Calibration:** Since system routing logs store initialization markers under global time definitions, `StartDateTimeUTC` is converted to local operational time (+3) using a 3-hour shift constraint: `DATEADD(HOUR, 3, TCD_Temp.StartDateTimeUTC)`.
* **Connection Handshake Point Resolution:** Reconstructs the exact moment of agent connection by subtracting talk and wrap durations from the final call log timestamp: `DATEADD(SECOND, -(TCD_Temp.TalkTime + TCD_Temp.WorkTime), TCD_Temp.DateTime)`.
* **Delta Interval Comparison:** A definitive date-diff comparison checks if the queue duration falls within the target 30-second limit:
  ```sql
  DATEDIFF(SECOND, 
      DATEADD(HOUR, 3, TCD_Temp.StartDateTimeUTC), 
      DATEADD(SECOND, -(TCD_Temp.TalkTime + TCD_Temp.WorkTime), TCD_Temp.DateTime)
  ) < 30
  ```

### 3. Multi-Variable String Collating Barriers
To prevent data contamination or row multiplication across the dataset loop when processing cross-transfers or call tracking flows, the internal query block enforces double-join matching constraints:
* Compares compound synthetic call tracking identifier keys: `(CAST(TCD_Temp.RouterCallKey AS varchar(10)) + CAST(TCD_Temp.RouterCallKeyDay AS varchar(10))) = id`.
* Validates matching destination identifiers to filter out misaligned records: `dns = TCD_Temp.DigitsDialed`.

### 4. Arithmetic Exception Defense (Zero-Division Safeguards)
For early morning shifts or newly initialized test queues where traffic volume balances at zero, calculated performance ratios incorporate inline conditional handlers:
```sql
pHandled = CASE WHEN COUNT(ID) = 0 THEN 0 ELSE SUM(GotToOperator) * 1.0 / COUNT(ID) END
SL30     = CASE WHEN COUNT(ID) = 0 THEN 0 ELSE SUM(GotToOperatorIn30Sec) * 1.0 / COUNT(ID) END
ATT      = CASE WHEN SUM(GotToOperator) = 0 THEN 0 ELSE SUM(TCD.TalkTime) * 1.0 / SUM(GotToOperator) END
```
This safeguards Cisco CUIC grid dashboards against backend mathematical parsing errors and runtime data model rendering crashes.
