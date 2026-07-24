# Campaign_Daily_Attempts_RT

## Real-Time Report
**Data Source:** `STAT_DB` via optimized caching table `#TCL` (`tContactLog`) and `tCampaign`.

### Report Filters

| Parameter | Description | Required | Comments |
| :--- | :--- | :---: | :--- |
| `@Period` | Period Selector | Yes | Maps to `:Period`. Numeric evaluation index:<br>• `1` = **Day** (Current date from midnight)<br>• `2` = **Week** (Current week from Monday midnight)<br>• `3` = **Month** (Current month from 1st day midnight) |
| `@CampaignList` | Campaigns | Yes | Maps to `:CampaignList`. Multi-select allowed. Internally cleaned of `null` tokens and parsed via custom string-split mechanics into an ID array (`@CL`). |

---

### Report Fields

| # | SQL Field Name | Report Display Name | Formula / Logic | Comments |
| :---: | :--- | :--- | :--- | :--- |
| 0 | `CampaignName` | Campaign | `tCampaign.CampaignName` | Resolved via database configuration layout match. |
| 1 | `DT` | Date | `CAST(TimeFrom AS DATE)` | Aggregation date key (timestamp truncated to calendar date). |
| 2 | `NumAttemps` | Attempts | `COUNT(*)` / `SUM(NumAttemps)` | Combined volume of dialing records where `ClientCallDialingStartTime IS NOT NULL`. |
| 3 | `pVoice` | % Connected to Agent | `SUM(rVoice) * 1.0 / SUM(NumAttemps)` | Percentage of total dialing attempts successfully routed to an operator. |
| 4 | `pBusy` | % Busy | `SUM(rBusy) * 1.0 / SUM(NumAttemps)` | Percentage of attempts where target returned a busy signal profile. |
| 5 | `pWrongNumber` | % Wrong Number | `SUM(rWrongNumber) * 1.0 / SUM(NumAttemps)` | Percentage of attempts targeting an invalid destination entry. |
| 6 | `pNoAnswer` | % No Answer | `SUM(rNoAnswer) * 1.0 / SUM(NumAttemps)` | Percentage of attempts terminating via dialer ring-no-answer timeout. |
| 9 | `pAgentError` | % Agent Connection Error | `SUM(rAgentError) * 1.0 / SUM(NumAttemps)` | Percentage of calls dropped during agent allocation/delivery phase. |
| 10 | `pTelephonyError` | % Telephony Error | `SUM(rTelephonyError) * 1.0 / SUM(NumAttemps)` | Percentage of network transit drops or trunk line hardware exceptions. |
| 11 | `pClientReject` | % Client Disconnect | `SUM(rClientReject) * 1.0 / SUM(NumAttemps)` | Percentage of calls actively rejected or hung up immediately by the customer. |
| 12 | `pSystemError` | % System Error | `SUM(rSystemError) * 1.0 / SUM(NumAttemps)` | Percentage of infrastructure processing or software-level execution failures. |
| 13 | `pFAX` | % Fax / Answering Machine | `SUM(rFAX) * 1.0 / SUM(NumAttemps)` | Percentage of connections handled by automated machines or fax greetings. |

*Note: All fields from index 4 to 13 utilize raw volume counters (`rBusy`, `rWrongNumber`, etc.) aggregated from the underlying `PhoneResultId` rules described in the logic matrix below.*

---

## Technical Calculations & Underlying Logic

### 1. Dynamic Real-Time Time Frame Anchoring
To evaluate live, cumulative rolling metrics with minimal platform maintenance overhead, the execution script calculates the snapshot timeline window inside the SQL runtime layer:
* **Start Anchor (`@BeginDate`):** Computed using relative date deltas against the active execution clock (`GETDATE()`) according to the selected `@Period` index:
  ```sql
  CASE @Period 
      WHEN 1 THEN DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)   -- Truncates to current day midnight
      WHEN 2 THEN DATEADD(WEEK, DATEDIFF(WEEK, 0, GETDATE()), 0) -- Truncates to current week Monday midnight
      WHEN 3 THEN DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0)-- Truncates to current month 1st midnight
  END
  ```
* **End Anchor (`@EndDate`):** Dynamically set to `GETDATE()`, capturing transactions up to the exact millisecond the CUIC report grid is refreshed.

### 2. Zero-Division Core Exception Safeguard
To guarantee system stability within early execution shifts or when initializing empty campaign structures, all percentage metrics implement defensive mathematical barriers:
```sql
pVoice = CASE SUM(NumAttemps) WHEN 0 THEN 0 ELSE SUM(rVoice)*1.0/SUM(NumAttemps) END
```
If `NumAttemps` equals `0`, the logic forcefully returns `0` instead of letting SQL Server throw an arithmetic division exception, avoiding standard UI rendering crashes in Cisco CUIC.

### 3. Multi-Layer Dataset Flattening Framework (`UNION ALL` Strategy)
To ensure optimal execution speed and prevent row-dropping side effects caused by temporal mismatches during standard `LEFT JOIN` operations across different aggregated datasets, the code employs a specialized vertical stacking pattern:
* **Layer 1 (`ResultSumCalc`):** Groups data by day, campaign, and `PhoneResultId` to generate specific execution counters. The internal select applies a 0-padded structural template to isolate phone results while keeping the schema consistent.
* **Layer 2 (`NumAttemptsCalc`):** Simultaneously extracts total call attempts from the cached staging table `#TCL`.
* **Consolidation Pass:** The rows are concatenated via a high-performance `UNION ALL` script and passed to an outer aggregation statement. This final pass uses a unified `GROUP BY DT, CampaignID, tCampaign.CampaignName` clause to flatten the multi-layer rows into a single clean record line per day and campaign.
