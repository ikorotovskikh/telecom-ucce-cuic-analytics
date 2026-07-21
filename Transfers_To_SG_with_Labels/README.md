# Transfers_To_SG_with_Labels

## Historical Report
**Data Source:** `STAT_DB` via base tables `t_Termination_Call_Detail` (aliased as `TCD`), `tCVP_Labels`, `t_Agent`, `t_Person`, `t_Skill_Group`, and `t_Call_Type`.

### Report Filters

| Parameter | Description | Required | Comments |
| :--- | :--- | :---: | :--- |
| `@StartDate` | Selection Start Date | Yes | Maps to `:StartDate`. Boundary constraints for `TCD.DateTime`. |
| `@EndDate` | Selection End Date | Yes | Maps to `:EndDate`. Boundary constraints for `TCD.DateTime`. |
| `@SG` | Skill Group | Yes | Maps to `:SkillGroups`. Filters data by target `TCD.SkillGroupSkillTargetID` OR implicitly via mapped Peripheral Variable 7 (`SGV7.SkillTargetID`). |

---

### Report Fields

| # | SQL Field Name | Report Display Name | Formula / Logic | Comments |
| :---: | :--- | :--- | :--- | :--- |
| 0 | `TransferDateTime` | Transfer Date/Time | `TCD.DateTime` | Exact timestamp of the transfer leg event. |
| 1 | `ANI` | ANI | `TCD.ANI` | Customer Caller ID. |
| 2 | `TransferToSkill` | Target Skill Group | `CASE WHEN SG.EnterpriseName IS NULL THEN SGV7.EnterpriseName ELSE SG.EnterpriseName END` | Target Skill Group Name. If the configuration mapping via ID is empty, falls back to UCCE Peripheral Variable 7 (`Variable7`). |
| 3 | `TransferToDigitsDialed` | Target DN | `TCD.DigitsDialed` | Directory Number (DN) targeted during the transfer. |
| 4 | `AgentName` | Agent Name | `CASE WHEN TCD.InstrumentPortNumber IS NULL THEN NULL ELSE P.LastName + ' ' + P.FirstName END` | Combined full name of the agent. Evaluates to `NULL` if the call was not delivered to an agent's teleset. |
| 5 | `AgentPhone` | Agent Extension | `TCD.InstrumentPortNumber` | Hardware extension (teleset) number of the handling agent. |
| 6 | `TalkDuration` | Talk Duration | `CASE WHEN TCD.InstrumentPortNumber IS NULL THEN 0 ELSE TCD.Duration END` | Forcefully mapped to `0` if the call leg bypassed active agent interaction (`InstrumentPortNumber = 0`). |
| 7 | `DurationFull` | Total Call Duration | `MAX(TCD.Duration)` grouped by `RouterCallKey`, `RouterCallKeyDay` | Calculated via a separate subquery (`TCD2`) that extracts the maximum duration across all related call segments. |
| 8 | `TransferFrom` | Transferred From | `CASE WHEN XFER_FROM_SGNAME.EnterpriseName IS NULL THEN CVP.ScriptName + '/' + CVP.Event ELSE XFER_FROM_SGNAME.EnterpriseName END` | **Advanced CTE Logic:** Resolves the source Skill Group based on the last segment with a Transfer disposition (28/29). If no prior call segment is found, falls back to the formatted path of the last CVP Script and Event. |
| 9 | `TransferFromRegOrCT` | Region/Call Type | `CASE WHEN CVP.Region IS NULL THEN CT.EnterpriseName ELSE CVP.Region END` | CVP Customer Region entry point mapping. Falls back to the global UCCE Call Type Enterprise Name if the CVP label lacks regional data. |
| 10 | `RouterCallKey` | Router Call Key | `TCD.RouterCallKey` | Technical sequence ID used for unique record sorting (`ORDER BY`). |
| 11 | `RouterCallKeyDay` | Router Call Key Day | `TCD.RouterCallKeyDay` | Part of the composite tracking ID. |

---

## Technical Calculations & Data Relationships

### 1. Transfer Leg Tracking (CTE `XferFromSG`)
The source of the transfer (`TransferFrom`) is determined sequentially by looking backward into the call lifecycle:
* It searches for the closest historical `t_Termination_Call_Detail` row sharing the same `RouterCallKey` and `RouterCallKeyDay` where the timestamp is strictly earlier than the current segment (`XFER_FROM.DateTime < T.DateTime`).
* The source segment must contain a valid transfer state signature defined by UCCE call disposition codes: **`28` (Blind Transfer)** or **`29` (Consultative Transfer)**.

### 2. CVP Label Mapping (CTE `LastLabels`)
To match CVP application details, the logic integrates data using `CallGuid`:
* The query isolates the latest IVR interaction state by extracting the maximum event timestamp (`MAX(EventDT)`) per unique `CallGuid` inside `tCVP_Labels`.
* In cases where multiple labels share duplicate millisecond timestamps, an internal data safety layer wraps the join to select only the highest internal record index ID (`MAX(ID)`), completely preventing row multiplication or cartesian product duplications in the final report display.

### 3. Backend Exclusion Barriers
The final rows are tightly filtered to exclude non-contact center traffic. A record is only eligible for the report if it satisfies at least one of the following criteria:
* `TCD.InstrumentPortNumber IS NOT NULL` — The call successfully connected to an agent's hardware profile.
* `TCD.NetworkSkillGroupQTime > 0 OR TCD.LocalQTime > 0` — The call experienced a holding state within either the network routing queue or the local peripheral ACD queue structure.

---

## Data Synchronization Pipeline (`tCVP_Labels` Ingestion)

The custom `tCVP_Labels` staging table is populated and synchronized via an automated database job. This job performs a remote cross-server data collection using a `MERGE` statement to replicate data from the **CVP Replica Server** (`s66dbmss001pr02` / `10.184.24.79`).

### Sync Architecture Details

* **Lookback Window:** The job utilizes a rolling 3-day window constraint (`DATEADD(DAY, -3, GETDATE())`) optimized to manage transaction log overhead and capture long-running or delayed cross-day call summaries.
* **Granular Extraction Constraints:** 
  * Replicates metadata from source CVP application logs (`call`, `vxmlsession`, `vxmlelement`, and `vxmlelementdetail`).
  * Explicitly extracts execution benchmarks where specific execution variables match `ReportData` or `EndCall`.
  * Selects caller geographic region assignments by isolating records from key system CVP elements (`LOG_Region_City`, `Database_GetRegion`, and `SET_REGION`) using variables `RegionAbonent` and `RegionIDAbonent`.

### Upsert Logic (`MERGE` Execution Matrix)

* **Join Keys:** Records are matched across environments using a composite constraint key: `(TARGET.Event = SOURCE.Event) AND (TARGET.CallGuid = SOURCE.CallGuid) AND (TARGET.ElementID = SOURCE.ElementID)`.
* **`WHEN MATCHED` (Data Updates):** If a record exists but its end timestamp (`EndDT`) is currently `NULL` in the local database while a non-null completion timestamp is detected on the source server, the job updates all execution metrics. This updates entries for active calls that finished after the previous sync cycle.
* **`WHEN NOT MATCHED BY TARGET` (New Ingestion):** Brand new interactions containing verified `CallGuid` references that match the active 3-day time window profile are appended as new entries into `[STAT_DB].[dbo].[tCVP_Labels]`.

---

## Data Retention Policy (Purge Job)

To prevent unbounded storage growth and maintain index performance, historical data in `[STAT_DB].[dbo].[tCVP_Labels]` is managed by an automated maintenance purge script.

### Purge Execution Architecture

* **Retention Window:** Configured to retain **6 months** of historical data. Rows with an `EventDT` older than `DATEADD(MONTH, -6, GETDATE())` are targeted for deletion.
* **Throttled Batching:** The job uses a `WHILE` loop and explicit transaction blocks to drop rows in chunks of **100,000 records at a time** (`DELETE TOP (100000)`). This throttling prevents:
  * Transaction log inflation.
  * Excessive Row-Lock or Page-Lock Escalation, ensuring the table remains fully readable by the active CUIC report queries during the maintenance window.
* **Storage Reclame:** A explicit `CHECKPOINT` command is issued directly after each committed batch. This actively forces dirty pages to disk and truncates the inactive portion of the transaction log, designed explicitly for databases configured under the **Simple Recovery Model**.
