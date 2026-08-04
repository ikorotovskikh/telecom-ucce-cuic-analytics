# IVR_Labels_by_Regions

## Historical Report
**Data Source:** `STAT_DB` via transactional IVR platform logging tables: `call`, `vxmlsession`, `vxmlelement`, `vxmlelementdetail`, and `vxmlcustomcontent`.  
**Optimization Layer:** Pre-aggregates metrics inside a specialized inner query subroutine (`EventsCalc` grouped as alias `ec`), utilizing temporary table variables for isolated regional domain scoping.

### Report Deployment Variations in CUIC
The configuration logic remains identical across reporting layouts, separating execution environments strictly by the underlying database instance mapping parameters:

| Database Name | Database Type | Server Address | Report Variation Name in CUIC |
| :--- | :--- | :--- | :--- |
| `CVP` | MS SQL | 10.184.24.79:1433 | CVP Detail Report - UR |
| `CVP_SZ` | MS SQL | 10.184.24.79:1433 | CVP Detail Report - SZ |

---

## Report Filters

| Parameter | Description | Required | Comments |
| :--- | :--- | :---: | :--- |
| `@StartDate` | Selection Start Date | Yes | Maps to `:BeginDate` / `@BeginDT`. Truncates lower execution timeline boundaries (MSK). |
| `@EndDate` | Selection End Date | Yes | Maps to `:EndDate` / `@EndDT`. Truncates upper execution timeline boundaries (MSK). |
| `@NPP_Locations`| Regional Sites Selection | Yes | Maps to `:NPPLocations` / `@NPPL`. Multi-select allowed. Internally isolates the routing array through an automated string-split function. |

*Note: Dropping the report filter dependencies onto the front-end dropdown interface utilizes a pre-populated system lookup metadata mapping sheet called **`tNPP_Locations`** containing schema profiles: `[int NPPLocationID, nvarchar(MAX) NPPLocation, pk int AgentTeamID, nvarchar(MAX) TeamName]`.*

---

## Data Schema & Fields Profile

### Section 1: Initial Inbound Inception & IVR Gatekeeping Metrics

| # | SQL Field Name | Report Display Name | Backend Target Event Mapping (`SUM(CASE WHEN...)`) | Comments |
| :---: | :--- | :--- | :--- | :--- |
| 0 | `NPPLocation` | Regional Site | Derived via `npptn.NPPLocation` reference lookup | Identifies the physical/operational region branch office handling the leg. |
| 1 | `PSTN_DNIS` | IVR Number | Derived via `npptn.PSTN_DNIS` reference lookup | Public switched telephony network dialed digits routing token. |
| 2 | `DNIS` | Internal Extension | `ec.DNIS` (reconciled from core `call.DNIS` log) | Internal Directory Number tracking the active target application script. |
| 3 | `ScriptName` | Application Name | `ec.ScriptName` (reconciled from `vxmlsession.appname`) | Name of the active Cisco CVP interaction workflow blueprint script. |
| 4 | `CallsEntered` | Total Calls Entered | `Event LIKE 'Begin_NPP_%_Welcome'` | Total volume of user session interactions successfully reaching the IVR boundary. |
| 5 | `CallsDisconnnectedInWelcome` | Abandoned on Welcome | `Event = 'AR_NPP_%_Welcome_EndCall'` | Total interactions dropping lines prematurely inside the opening greeting layout block. |
| 6 | `CallsNonWorkingHours` | Out of Hours Calls | `Event LIKE 'AR_NPP_%_NotWork_EndCall'` | Interaction load hitting the platform outside defined business shift hours. |
| 7 | `CallsEnterMenuClientEmployee` | Customer/Staff Menu | `Event LIKE 'NPP_%_Vybor'` | Volume reaching the client vs. internal operator segregation routing branch menu. |
| 8 | `CallsHangupBeforeChoiceMenu` | Hangup Before Selection | `Event LIKE 'AR_NPP_%_Vybor_EndCall'` | Customer sessions abandoning right during prompt playback before any key input is logged. |
| 9 | `CallsDidntMakeAChoice` | Selection Timeout | `Event LIKE 'EER_NPP_%_NN_EndCall'` | Interactions dropped because the system reached maximum timeout loops without input. |
| 10 | `CallsFromClient` | Verified Customer Calls | `Event LIKE 'NPP_%_Client'` | Session volume transferring down into specific customer transaction branches. |
| 11 | `CallsDidntListenedToRecord` | Prompt Bypassed | `Event LIKE 'AR_NPP_%_Zapisi_EndCall'` | Sessions abandoned or disconnected while bypassing automated announcement tracks. |
| 12 | `CallsClientEnteredToSkill` | Customer Agent Transfers| `Event LIKE 'OER_NPP_%_Client_TransAgent'` | Core count of validated consumer sessions routed directly to live agent queues. |
| 13 | `CallsEnteredMenuForInstallers` | Installer Menu Inception | `Event LIKE 'NPP_%_MM'` | Sessions logging transitions down into field operations/engineer IVR nodes. |
| 14 | `CallsHangupBeforeInstallersMenu`| Installer Menu Abandon | `Event LIKE 'AR_NPP_%_MM_EndCall'` | Engineer/Installer phone interactions dropping line before hitting operational branches. |

### Section 2: Core Menu Routing Conversions (Target Label Traps)

| # | SQL Field Name | Report Display Name | Backend Target Event Mapping (`SUM(CASE WHEN...)`) | Comments |
| :---: | :--- | :--- | :--- | :--- |
| 15 | `CallsApplicationRescheduled` | App Rescheduled | `Event LIKE 'NPP_%_Perenos zayavki'` | Volume of sessions completing an automated application reschedule tracking step. |
| 16 | `CallsApplicationCanceled` | App Canceled | `Event LIKE 'NPP_%_Otmena zayavki'` | Volume of sessions initiating an automated application cancellation tracking step. |
| 17 | `CallsReSale` | Sales / Cross-Sales | `Event LIKE 'NPP_%_Prodazha'` | Share of interactions targeting internal commercial upsell/cross-sale sub-nodes. |
| 18 | `CallsOtherQuestions` | General Inquiries | `Event LIKE 'NPP_%_Drugie_voprosy'` | Fallback routing bucket covering undefined generic query allocations. |
| 19 | `CallsTechnicalQuestions` | Tech Support Transfers | `Event = 'OER_NPP_DV_NTPVS_TransAgent'` | High-priority infrastructure triggers transferring users to technical engineering helpdesks. |
| 20 | `CallsDidntChooseTopic` | No Input Loop 1 | `Event LIKE 'NPP_%_NN1_goto_MM_NPP'` | Callers missing a topic selection and looping backward to the primary Main Menu node. |
| 21 | `CallsDidntChooseTopicTwice` | No Input Drop 2 | `Event LIKE 'OER_NPP_%_NN2_EndCall'` | Total termination drops enforced by successive silent interaction timeouts. |
| 22 | `CallsDidntListenedToEvaluation` | Survey Abandoned | `Event LIKE 'AR_NPP_%_Ocenka_EndCall'` | Callers dropping line connectivity mid-way through the post-call satisfaction survey tracking block. |
| 23 | `CallsInstallerEnteredToSkill` | Installer Agent Transfers| `Event LIKE 'OER_NPP_%_TransAgent'` | Engineer support sessions successfully routed to specialized routing skill lines. |

### Section 3: Ratio Conversions & Core Performance Analytics (KPIs)

| # | SQL Field Name | Report Display Name | Formula / Logic Reference (Zero-Division Protected) | Operational Metrics Impact |
| :---: | :--- | :--- | :--- | :--- |
| 24 | `pCallsWorkingHours` | % Working Hours Handled | `(CallsClientEnteredToSkill + CallsInstallerEnteredToSkill) * 1.0 / (CallsEntered - CallsNonWorkingHours)` | Measures the net conversion efficiency of real-time agent delivery legs during working hours. |
| 25 | `pCallsApplicationRescheduled`| % App Rescheduled | `CallsApplicationRescheduled * 1.0 / [Layer Denominator Formula Summary]*` | Percentage of active menu selections resulting in an application reschedule path. |
| 26 | `pCallsApplicationCanceled` | % App Canceled | `CallsApplicationCanceled * 1.0 / [Layer Denominator Formula Summary]*` | Percentage of active menu selections resulting in an application cancellation path. |
| 27 | `pCallsReSale` | % Sales / Cross-Sales | `CallsReSale * 1.0 / [Layer Denominator Formula Summary]*` | Share of sales conversions within the operational menu layer. |
| 28 | `pCallsOtherQuestions` | % General Inquiries | `CallsOtherQuestions * 1.0 / [Layer Denominator Formula Summary]*` | Share of generic/other informational query choices within the menu layer. |
| 29 | `pCallsTechnicalQuestions` | % Tech Support Transfers | `CallsTechnicalQuestions * 1.0 / [Layer Denominator Formula Summary]*` | Share of technical queries routed to specialized engineering desks out of sub-menu items. |
| 30 | `pCallsDidntChooseTopic` | % No Input Drops | `CallsDidntChooseTopicTwice * 1.0 / [Layer Denominator Formula Summary]*` | Share of terminal call drops caused by silent timeout exceptions. |

*\* Note on the Global Sub-Menu Layer Denominator:*
The formulas from index 25 to 30 share a standardized compound baseline denominator block to evaluate conversion allocations within that selection layer:
```text
Denominator = (CallsApplicationRescheduled + CallsApplicationCanceled + CallsReSale + CallsOtherQuestions + CallsTechnicalQuestions + CallsDidntChooseTopicTwice)
```

---

## Technical Calculations & Underlying Logic

### 1. Pre-Processing Domain Scoping (Filter Pipeline Optimization)
To protect index lookup trees from query degradation across deep transactional histories, the initialization script resolves target paths prior to running the main CVP data extraction loops:
* **String Input Cleanup:** `REPLACE(@NPPL, 'null', '')` acts as a shield against interface injection errors, transforming raw dropdown selections into an isolated array table `[id]` (`@nppLList`).
* **Dynamic Extension Resolver (`@dnisListfromLocations`):** Extracts associated application directory numbers (`Script_DNIS`) via a nested query against mapping table `tNPP_TelNumbers` based on the targeted location keys. This populates a specific memory cache block used to enforce strict `IN (...)` boundaries during the final aggregate generation sequence.

### 2. Wildcard Text Parsing Pattern Matching (`LIKE` Conditional Logic)
The core metrics parser relies on localized SQL wildcard searches to normalize naming variations introduced by separate application deployment revisions:
* **Regional Naming Normalization:** Using pattern matches like `Event LIKE 'NPP_%_Perenos zayavki'` enables the query engine to strip away structural regional prefixes dynamically. This clusters matching milestone metrics across separate locations into a single unified business counter column.
