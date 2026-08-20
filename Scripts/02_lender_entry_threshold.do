*============================================================*
* THRESHOLD DEFINITIONS USING BALANCED ENTRY PANEL
*============================================================*

cd "C:\Users\osheen.khare\OneDrive - Centre for Advanced Financial research and Le\Desktop\Fintech"

use "04_temp\balanced_entry_panel.dta", clear

* Basic checks
isid lender_id pincode month
assert months_since_entry >= 0


*============================================================*
* PANEL A: THREE-MONTH THRESHOLDS
*============================================================*

preserve

* Complete 3-month follow-up only
keep if eligible_3m == 1

* t, t+1, t+2
keep if inrange(months_since_entry,0,2)

drop if missing(lender_group)


*------------------------------------------------------------*
* Monthly activity indicator
*------------------------------------------------------------*
assert !missing(n_loans)
gen byte active = n_loans >= 1 & !missing(n_loans)


*------------------------------------------------------------*
* Collapse to ONE observation per candidate entry event
*------------------------------------------------------------*

gcollapse ///
    (count) n_months=n_loans ///
    (sum) active_months_3m=active ///
          total_loans_3m=n_loans, ///
    by(lender_id lender_group pincode ///
       entry_spell entry_month)

* Every eligible event must contribute exactly 3 months
assert n_months == 3


*------------------------------------------------------------*
* Alternative 3-month definitions
*------------------------------------------------------------*

* Active in all 3 months
gen byte entry_3of3 = ///
    active_months_3m == 3

* Active in at least 2 of 3 months
gen byte entry_2of3 = ///
    active_months_3m >= 2

* Cumulative loan-count thresholds
gen byte entry_3m_cum2 = ///
    total_loans_3m >= 2

gen byte entry_3m_cum3 = ///
    total_loans_3m >= 3

gen byte entry_3m_cum5 = ///
    total_loans_3m >= 5


*------------------------------------------------------------*
* Sanity checks
*------------------------------------------------------------*

assert entry_3of3 <= entry_2of3

assert entry_3m_cum5 <= entry_3m_cum3
assert entry_3m_cum3 <= entry_3m_cum2


*------------------------------------------------------------*
* Save event-level 3-month definitions if useful later
*------------------------------------------------------------*

tempfile threshold3_event
save `threshold3_event'


*------------------------------------------------------------*
* Collapse by lender category
*------------------------------------------------------------*

gcollapse ///
    (count) Candidate_events=entry_spell ///
    (sum) entry_3of3 ///
          entry_2of3 ///
          entry_3m_cum2 ///
          entry_3m_cum3 ///
          entry_3m_cum5, ///
    by(lender_group)


*------------------------------------------------------------*
* Shares of candidate events retained
*------------------------------------------------------------*

gen Share_3of3 = ///
    100 * entry_3of3 / Candidate_events

gen Share_2of3 = ///
    100 * entry_2of3 / Candidate_events

gen Share_cum2 = ///
    100 * entry_3m_cum2 / Candidate_events

gen Share_cum3 = ///
    100 * entry_3m_cum3 / Candidate_events

gen Share_cum5 = ///
    100 * entry_3m_cum5 / Candidate_events


*------------------------------------------------------------*
* Formatting / display
*------------------------------------------------------------*

format Candidate_events ///
       entry_3of3 entry_2of3 ///
       entry_3m_cum2 entry_3m_cum3 entry_3m_cum5 %15.0fc

format Share_* %9.2f

sort lender_group

list lender_group ///
     Candidate_events ///
     Share_3of3 ///
     Share_2of3 ///
     Share_cum2 ///
     Share_cum3 ///
     Share_cum5, ///
     noobs sep(0)


*------------------------------------------------------------*
* Export Panel A
*------------------------------------------------------------*

export excel using ///
    "06_tables\entry_threshold_definitions.xlsx", ///
    sheet("A 3 month") ///
    firstrow(variables) replace

restore


*============================================================*
* PANEL B: SIX-MONTH THRESHOLDS
*============================================================*

preserve

* Complete 6-month follow-up only
keep if eligible_6m == 1

* t through t+5
keep if inrange(months_since_entry,0,5)

drop if missing(lender_group)


*------------------------------------------------------------*
* Monthly activity indicator
*------------------------------------------------------------*
assert !missing(n_loans)
gen byte active = n_loans >= 1 & !missing(n_loans)


*------------------------------------------------------------*
* Collapse to ONE observation per candidate entry event
*------------------------------------------------------------*

gcollapse ///
    (count) n_months=n_loans ///
    (sum) active_months_6m=active ///
          total_loans_6m=n_loans, ///
    by(lender_id lender_group pincode ///
       entry_spell entry_month)

* Every eligible event must contribute exactly 6 months
assert n_months == 6


*------------------------------------------------------------*
* Alternative 6-month definitions
*------------------------------------------------------------*

* Active in all 6 months
gen byte entry_6of6 = ///
    active_months_6m == 6

* Active in at least 4 of 6 months
gen byte entry_4of6 = ///
    active_months_6m >= 4

* Active in at least 3 of 6 months
gen byte entry_3of6 = ///
    active_months_6m >= 3

* Cumulative loan-count thresholds
gen byte entry_6m_cum3 = ///
    total_loans_6m >= 3

gen byte entry_6m_cum5 = ///
    total_loans_6m >= 5

gen byte entry_6m_cum10 = ///
    total_loans_6m >= 10


*------------------------------------------------------------*
* Sanity checks
*------------------------------------------------------------*

assert entry_6of6 <= entry_4of6
assert entry_4of6 <= entry_3of6

assert entry_6m_cum10 <= entry_6m_cum5
assert entry_6m_cum5 <= entry_6m_cum3


*------------------------------------------------------------*
* Save event-level 6-month definitions if useful later
*------------------------------------------------------------*

tempfile threshold6_event
save `threshold6_event'


*------------------------------------------------------------*
* Collapse by lender category
*------------------------------------------------------------*

gcollapse ///
    (count) Candidate_events=entry_spell ///
    (sum) entry_6of6 ///
          entry_4of6 ///
          entry_3of6 ///
          entry_6m_cum3 ///
          entry_6m_cum5 ///
          entry_6m_cum10, ///
    by(lender_group)


*------------------------------------------------------------*
* Shares of candidate events retained
*------------------------------------------------------------*

gen Share_6of6 = ///
    100 * entry_6of6 / Candidate_events

gen Share_4of6 = ///
    100 * entry_4of6 / Candidate_events

gen Share_3of6 = ///
    100 * entry_3of6 / Candidate_events

gen Share_cum3 = ///
    100 * entry_6m_cum3 / Candidate_events

gen Share_cum5 = ///
    100 * entry_6m_cum5 / Candidate_events

gen Share_cum10 = ///
    100 * entry_6m_cum10 / Candidate_events


*------------------------------------------------------------*
* Formatting / display
*------------------------------------------------------------*

format Candidate_events ///
       entry_6of6 entry_4of6 entry_3of6 ///
       entry_6m_cum3 entry_6m_cum5 entry_6m_cum10 %15.0fc

format Share_* %9.2f

sort lender_group

list lender_group ///
     Candidate_events ///
     Share_6of6 ///
     Share_4of6 ///
     Share_3of6 ///
     Share_cum3 ///
     Share_cum5 ///
     Share_cum10, ///
     noobs sep(0)


*------------------------------------------------------------*
* Export Panel B
*------------------------------------------------------------*

export excel using ///
    "06_tables\entry_threshold_definitions.xlsx", ///
    sheet("B 6 month") ///
    firstrow(variables) sheetreplace

restore

*============================================================*
* PINCODE SIZE x THRESHOLD ANALYSIS
* Base: balanced entry panel
*============================================================*

use "04_temp\balanced_entry_panel.dta", clear

merge m:1 pincode entry_month ///
    using "04_temp\pincode_size_at_entry.dta", ///
    keep(master match) nogen

assert !missing(baseline_pin_loans)


*------------------------------------------------------------*
* 1. Pincode-size bins
*------------------------------------------------------------*

gen byte pin_size_cat = .

replace pin_size_cat = 1 ///
    if baseline_pin_loans < 10

replace pin_size_cat = 2 ///
    if inrange(baseline_pin_loans,10,24)

replace pin_size_cat = 3 ///
    if inrange(baseline_pin_loans,25,49)

replace pin_size_cat = 4 ///
    if inrange(baseline_pin_loans,50,99)

replace pin_size_cat = 5 ///
    if baseline_pin_loans >= 100

label define pin_size_lbl ///
    1 "<10" ///
    2 "10-24" ///
    3 "25-49" ///
    4 "50-99" ///
    5 "100+"

label values pin_size_cat pin_size_lbl


*============================================================*
* PANEL A: ALL ENTRY EVENTS BY PINCODE SIZE
*============================================================*

preserve

keep if months_since_entry == 0

gcollapse ///
    (count) Entry_events=entry_spell, ///
    by(pin_size_cat)

egen Total_events = total(Entry_events)

gen Share_events = ///
    100 * Entry_events / Total_events

format Entry_events Total_events %15.0fc
format Share_events %9.2f

list pin_size_cat Entry_events Share_events, ///
    noobs sep(0)

export excel using ///
    "06_tables\pincode_threshold_analysis.xlsx", ///
    sheet("A Entry events") ///
    firstrow(variables) replace

restore


*============================================================*
* PANEL B: THREE-MONTH THRESHOLDS BY PINCODE SIZE
*============================================================*

preserve

keep if eligible_3m == 1
keep if inrange(months_since_entry,0,2)

assert !missing(n_loans)

gen byte active = ///
    n_loans >= 1 & !missing(n_loans)

*------------------------------------------------------------*
* Collapse to entry-event level
*------------------------------------------------------------*

gcollapse ///
    (count) n_months=n_loans ///
    (sum) active_months_3m=active ///
          total_loans_3m=n_loans, ///
    by(lender_id lender_group pincode ///
       entry_spell entry_month pin_size_cat)

assert n_months == 3


*------------------------------------------------------------*
* Alternative thresholds
*------------------------------------------------------------*

gen byte entry_3of3 = ///
    active_months_3m == 3

gen byte entry_2of3 = ///
    active_months_3m >= 2

gen byte entry_3m_cum2 = ///
    total_loans_3m >= 2

gen byte entry_3m_cum3 = ///
    total_loans_3m >= 3

gen byte entry_3m_cum5 = ///
    total_loans_3m >= 5


*------------------------------------------------------------*
* Collapse by pincode-size category
*------------------------------------------------------------*

gcollapse ///
    (count) Candidate_events=entry_spell ///
    (sum) entry_3of3 ///
          entry_2of3 ///
          entry_3m_cum2 ///
          entry_3m_cum3 ///
          entry_3m_cum5, ///
    by(pin_size_cat)

gen Share_3of3 = ///
    100 * entry_3of3 / Candidate_events

gen Share_2of3 = ///
    100 * entry_2of3 / Candidate_events

gen Share_cum2 = ///
    100 * entry_3m_cum2 / Candidate_events

gen Share_cum3 = ///
    100 * entry_3m_cum3 / Candidate_events

gen Share_cum5 = ///
    100 * entry_3m_cum5 / Candidate_events

format Candidate_events entry_* %15.0fc
format Share_* %9.2f

list pin_size_cat ///
     Candidate_events ///
     Share_3of3 ///
     Share_2of3 ///
     Share_cum2 ///
     Share_cum3 ///
     Share_cum5, ///
     noobs sep(0)

export excel using ///
    "06_tables\pincode_threshold_analysis.xlsx", ///
    sheet("B 3m thresholds") ///
    firstrow(variables) sheetreplace

restore


*============================================================*
* PANEL C: SIX-MONTH THRESHOLDS BY PINCODE SIZE
*============================================================*

preserve

keep if eligible_6m == 1
keep if inrange(months_since_entry,0,5)

assert !missing(n_loans)

gen byte active = ///
    n_loans >= 1 & !missing(n_loans)

*------------------------------------------------------------*
* Collapse to entry-event level
*------------------------------------------------------------*

gcollapse ///
    (count) n_months=n_loans ///
    (sum) active_months_6m=active ///
          total_loans_6m=n_loans, ///
    by(lender_id lender_group pincode ///
       entry_spell entry_month pin_size_cat)

assert n_months == 6


*------------------------------------------------------------*
* Alternative thresholds
*------------------------------------------------------------*

gen byte entry_6of6 = ///
    active_months_6m == 6

gen byte entry_4of6 = ///
    active_months_6m >= 4

gen byte entry_3of6 = ///
    active_months_6m >= 3

gen byte entry_6m_cum3 = ///
    total_loans_6m >= 3

gen byte entry_6m_cum5 = ///
    total_loans_6m >= 5

gen byte entry_6m_cum10 = ///
    total_loans_6m >= 10


*------------------------------------------------------------*
* Collapse by pincode-size category
*------------------------------------------------------------*

gcollapse ///
    (count) Candidate_events=entry_spell ///
    (sum) entry_6of6 ///
          entry_4of6 ///
          entry_3of6 ///
          entry_6m_cum3 ///
          entry_6m_cum5 ///
          entry_6m_cum10, ///
    by(pin_size_cat)

gen Share_6of6 = ///
    100 * entry_6of6 / Candidate_events

gen Share_4of6 = ///
    100 * entry_4of6 / Candidate_events

gen Share_3of6 = ///
    100 * entry_3of6 / Candidate_events

gen Share_cum3 = ///
    100 * entry_6m_cum3 / Candidate_events

gen Share_cum5 = ///
    100 * entry_6m_cum5 / Candidate_events

gen Share_cum10 = ///
    100 * entry_6m_cum10 / Candidate_events

format Candidate_events entry_* %15.0fc
format Share_* %9.2f

list pin_size_cat ///
     Candidate_events ///
     Share_6of6 ///
     Share_4of6 ///
     Share_3of6 ///
     Share_cum3 ///
     Share_cum5 ///
     Share_cum10, ///
     noobs sep(0)

export excel using ///
    "06_tables\pincode_threshold_analysis.xlsx", ///
    sheet("C 6m thresholds") ///
    firstrow(variables) sheetreplace

restore