*============================================================*
* 1. CREATE LENDER x PINCODE x MONTH PANEL
*============================================================*

cd "C:\Users\osheen.khare\OneDrive - Centre for Advanced Financial research and Le\Desktop\Fintech"

use "03_raw\originations_cleaned.dta", clear

drop if missing(pincode)

egen long borrower_num = group(person_id)
egen long loan_num = group(person_id loan_ac_id lender_id product_group)

gcollapse ///
    (nunique) n_loans=loan_num ///
    (nunique) n_borrowers=borrower_num, ///
    by(lender_id lender_group pincode month)

isid lender_id pincode month

sort lender_id pincode month

save "04_temp\lender_pincode_month.dta", replace


*============================================================*
* 2. IDENTIFY BASE CANDIDATE ENTRY
*============================================================*

use "04_temp\lender_pincode_month.dta", clear

gen byte present = 1

rangestat (sum) present_l12=present, ///
    interval(month -12 -1) ///
    by(lender_id pincode)

* Positive lending in t after no observed lending in prior 12 months
gen byte candidate_entry = missing(present_l12)

* Sample limits
summ month, meanonly
local first_month = r(min)
local last_month  = r(max)

* Require complete prior 12-month window
gen byte full_prior_window = ///
    month >= `first_month' + 12

replace candidate_entry = 0 ///
    if full_prior_window == 0


*------------------------------------------------------------*
* First observed entry versus re-entry
*------------------------------------------------------------*

bys lender_id pincode (month): ///
    gen byte first_observed_entry = (_n == 1)

gen byte reentry_after_12m = ///
    candidate_entry == 1 ///
    & first_observed_entry == 0

*============================================================*
* 3. TABLE 1: COMPOSITION OF CANDIDATE ENTRY EVENTS
*============================================================*

preserve

keep if candidate_entry == 1

gen byte entry_type = .
replace entry_type = 1 if first_observed_entry == 1
replace entry_type = 2 if reentry_after_12m == 1

label define entry_type_lbl ///
    1 "First observed entry" ///
    2 "Re-entry after 12m absence"

label values entry_type entry_type_lbl

gcollapse ///
    (count) N=candidate_entry, ///
    by(entry_type)

egen total_events = total(N)
gen share = 100 * N / total_events

format N %15.0fc
format share %9.2f

list entry_type N share, noobs sep(0)

export excel using ///
    "06_tables\candidate_entry_composition.xlsx", ///
    firstrow(variables) replace

restore

*------------------------------------------------------------*
* Panel B: Number of candidate entries per lender-pincode
*------------------------------------------------------------*

preserve

bys lender_id pincode: ///
    egen n_candidate_entries = total(candidate_entry)

egen byte tag_lp = tag(lender_id pincode)

keep if tag_lp == 1

gcollapse ///
    (count) lender_pincodes=tag_lp, ///
    by(n_candidate_entries)

egen total_lp = total(lender_pincodes)

gen share = ///
    100 * lender_pincodes / total_lp

format lender_pincodes %15.0fc
format share %9.2f

list n_candidate_entries lender_pincodes share, ///
    noobs sep(0)

export excel using ///
    "06_tables\candidate_entry_composition.xlsx", ///
    sheet("Entry frequency") ///
    firstrow(variables) sheetreplace

restore

*============================================================*
* 4. NUMBER ENTRY SPELLS
*============================================================*

sort lender_id pincode month

bys lender_id pincode (month): ///
    gen entry_spell = sum(candidate_entry)
	
tempfile observed

preserve

keep if entry_spell >= 1

keep lender_id pincode month ///
     n_loans n_borrowers

save `observed'

restore

*============================================================*
* 5. CONSTRUCT ENTRY-SPELL BOUNDARIES
*============================================================*

preserve

keep if candidate_entry == 1

keep lender_id lender_group pincode ///
     entry_spell month

rename month entry_month

sort lender_id pincode entry_spell

* Next candidate-entry month
bys lender_id pincode (entry_spell): ///
    gen next_entry_month = entry_month[_n+1]

* Current spell ends one month before next entry
gen spell_end = next_entry_month - 1

* Last observed spell extends to end of sample
replace spell_end = `last_month' ///
    if missing(next_entry_month)

keep lender_id lender_group pincode ///
     entry_spell entry_month spell_end

tempfile spells
save `spells'

restore

*============================================================*
* 6. CREATE COMPLETE MONTHLY PANEL AFTER ENTRY
*============================================================*

use `spells', clear

gen n_months = ///
    spell_end - entry_month + 1

assert n_months >= 1

expand n_months

bys lender_id pincode entry_spell: ///
    gen month = entry_month + _n - 1

format month %tm

isid lender_id pincode month

merge 1:1 lender_id pincode month ///
    using `observed', ///
    keep(master match) ///
    nogen
	
replace n_loans = 0 ///
    if missing(n_loans)

replace n_borrowers = 0 ///
    if missing(n_borrowers)
	
gen months_since_entry = ///
    month - entry_month
	
*------------------------------------------------------------*
* Complete follow-up windows
*------------------------------------------------------------*

summ month, meanonly
scalar LAST_MONTH = r(max)

gen byte eligible_3m = ///
    entry_month <= scalar(LAST_MONTH) - 2

gen byte eligible_6m = ///
    entry_month <= scalar(LAST_MONTH) - 5
	
*============================================================*
* 7. TABLE 3: POST-ENTRY MONTHLY LOAN DISTRIBUTION
*============================================================*

*============================================================*
* PANEL A: ALL MONTHS AFTER ENTRY
*============================================================*

preserve

drop if missing(lender_group)

gen byte zero_month = n_loans == 0

gcollapse ///
    (count) N=n_loans ///
    (mean)  Mean=n_loans ///
            Zero_share=zero_month ///
    (p25)   P25=n_loans ///
    (p50)   Median=n_loans ///
    (p75)   P75=n_loans ///
    (p95)   P95=n_loans, ///
    by(lender_group)

replace Zero_share = 100 * Zero_share

format N %15.0fc
format Mean %9.3f
format Zero_share %9.2f
format P25 Median P75 P95 %9.0f

export excel using ///
    "06_tables\entrant_monthly_volume.xlsx", ///
    sheet("All post-entry months") ///
    firstrow(variables) replace

restore

*============================================================*
* PANEL B: FIRST 3 MONTHS AFTER ENTRY
* Complete 3-month follow-up only
*============================================================*

preserve

keep if eligible_3m == 1
keep if inrange(months_since_entry,0,2)

drop if missing(lender_group)

gen byte zero_month = n_loans == 0

gcollapse ///
    (count) N=n_loans ///
    (mean)  Mean=n_loans ///
            Zero_share=zero_month ///
    (p25)   P25=n_loans ///
    (p50)   Median=n_loans ///
    (p75)   P75=n_loans ///
    (p95)   P95=n_loans, ///
    by(lender_group)

replace Zero_share = 100 * Zero_share

format N %15.0fc
format Mean %9.3f
format Zero_share %9.2f
format P25 Median P75 P95 %9.0f

sort lender_group
list, noobs sep(0)

export excel using ///
    "06_tables\entrant_monthly_volume.xlsx", ///
    sheet("First 3 months") ///
    firstrow(variables) sheetreplace

restore

*============================================================*
* PANEL C: FIRST 6 MONTHS AFTER ENTRY
* Complete 6-month follow-up only
*============================================================*

preserve

keep if eligible_6m == 1
keep if inrange(months_since_entry,0,5)

drop if missing(lender_group)

gen byte zero_month = n_loans == 0

gcollapse ///
    (count) N=n_loans ///
    (mean)  Mean=n_loans ///
            Zero_share=zero_month ///
    (p25)   P25=n_loans ///
    (p50)   Median=n_loans ///
    (p75)   P75=n_loans ///
    (p95)   P95=n_loans, ///
    by(lender_group)

replace Zero_share = 100 * Zero_share

format N %15.0fc
format Mean %9.3f
format Zero_share %9.2f
format P25 Median P75 P95 %9.0f

sort lender_group
list, noobs sep(0)

export excel using ///
    "06_tables\entrant_monthly_volume.xlsx", ///
    sheet("First 6 months") ///
    firstrow(variables) sheetreplace

restore

save "04_temp\balanced_entry_panel.dta", replace

*====================================================================*
* 8. TABLE 4: DISTRIBUTION OF LOANS FROM CANDIDATE ENTRANTS
*====================================================================*


*====================================================================*
* 1. START FROM LENDER x PINCODE x MONTH PANEL
*====================================================================*

use "04_temp\lender_pincode_month.dta", clear

sort lender_id pincode month

gen byte present = 1

rangestat (sum) present_l12=present, ///
    interval(month -12 -1) ///
    by(lender_id pincode)

* Candidate entry:
* positive sampled lending in t, but no sampled lending
* by the same lender-pincode during t-12,...,t-1
gen byte candidate_entry = ///
    missing(present_l12)


*------------------------------------------------------------*
* Require complete prior 12-month window
*------------------------------------------------------------*

summ month, meanonly
local first_month = r(min)

gen byte full_prior_window = ///
    month >= `first_month' + 12

replace candidate_entry = 0 ///
    if full_prior_window == 0


*====================================================================*
* 2. KEEP CANDIDATE-ENTRY MONTHS
*====================================================================*

keep if candidate_entry == 1

drop if missing(lender_group)
drop if missing(pincode)
drop if missing(month)

assert n_loans >= 1


*====================================================================*
* 3. COLLAPSE ACROSS INDIVIDUAL LENDERS
*====================================================================*

gen byte entrant_lender = 1

gcollapse ///
    (sum) entrant_loans=n_loans ///
    (sum) entrant_borrowers=n_borrowers ///
    (sum) n_entrant_lenders=entrant_lender, ///
    by(pincode month lender_group)

isid pincode month lender_group

assert entrant_loans >= 1
assert n_entrant_lenders >= 1

save ///
    "04_temp\pincode_month_lendergroup_candidate_entry.dta", ///
    replace

preserve

gcollapse ///
    (count) N_pincode_months=entrant_loans ///
    (mean)  Mean=entrant_loans ///
    (p5)    P5=entrant_loans ///
    (p25)   P25=entrant_loans ///
    (p50)   Median=entrant_loans ///
    (p75)   P75=entrant_loans ///
    (p95)   P95=entrant_loans, ///
    by(lender_group)

format N_pincode_months %15.0fc
format Mean %9.3f
format P5 P25 Median P75 P95 %9.0f

sort lender_group

list lender_group ///
     N_pincode_months ///
     Mean P5 P25 Median P75 P95, ///
     noobs sep(0)

export excel using ///
    "06_tables\entrant_loan_distribution_pincode_month.xlsx", ///
    sheet("Entrant loan distribution") ///
    firstrow(variables) replace

restore


*============================================================*
* PINCODE SIZE ANALYSIS
*============================================================*


*------------------------------------------------------------*
* 1. Construct prior-12-month pincode size
*------------------------------------------------------------*

*============================================================*
* PINCODE SIZE ANALYSIS
*============================================================*

*------------------------------------------------------------*
* 1. Construct prior-12-month pincode size
*------------------------------------------------------------*

use "03_raw\originations_cleaned.dta", clear

drop if missing(pincode) | missing(month)

egen long loan_num = ///
    group(person_id loan_ac_id lender_id product_group)

gcollapse ///
    (nunique) pincode_month_loans=loan_num, ///
    by(pincode month)

sort pincode month

* Sample limits
summ month, meanonly
local first_month = r(min)

* Sampled originations in the pincode during t-12,...,t-1
rangestat (sum) baseline_pin_loans=pincode_month_loans, ///
    interval(month -12 -1) ///
    by(pincode)

* If the full prior window exists and rangestat finds
* no pincode-month observations, interpret as zero loans
replace baseline_pin_loans = 0 ///
    if missing(baseline_pin_loans) ///
    & month >= `first_month' + 12

keep pincode month baseline_pin_loans

rename month entry_month

save "04_temp\pincode_size_at_entry.dta", replace


*------------------------------------------------------------*
* 2. Merge onto balanced entry panel
*------------------------------------------------------------*

use "04_temp\balanced_entry_panel.dta", clear

merge m:1 pincode entry_month ///
    using "04_temp\pincode_size_at_entry.dta", ///
    keep(master match) nogen

count if missing(baseline_pin_loans)


*------------------------------------------------------------*
* 3. Create pincode-size bins
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

tab pin_size_cat, missing


*------------------------------------------------------------*
* 4. One tag per candidate entry event
*------------------------------------------------------------*
gen byte entry_tag = ///
    months_since_entry == 0


*============================================================*
* PANEL A
* DISTRIBUTION OF ALL CANDIDATE ENTRY EVENTS BY PINCODE SIZE
*============================================================*

preserve

keep if entry_tag == 1
drop if missing(pin_size_cat)

gcollapse ///
    (count) Entry_events=entry_tag, ///
    by(pin_size_cat)

egen Total_events = total(Entry_events)

gen Share_events = ///
    100 * Entry_events / Total_events

format Entry_events Total_events %15.0fc
format Share_events %9.2f

sort pin_size_cat

list pin_size_cat ///
     Entry_events Share_events, ///
     noobs sep(0)

export excel using ///
    "06_tables\pincode_size_entry_activity.xlsx", ///
    sheet("A All entry events") ///
    firstrow(variables) replace

restore

rename eligible_3m complete_3m_window
rename eligible_6m complete_6m_window

*============================================================*
* PANEL B
* FIRST 3 MONTHS AFTER ENTRY BY PINCODE SIZE
*============================================================*

preserve

* Only entries for which t,t+1,t+2 are all observable
keep if complete_3m_window == 1

* First three months of each entry event
keep if inrange(months_since_entry,0,2)

drop if missing(pin_size_cat)

gen byte zero_month = ///
    n_loans == 0

gcollapse ///
    (sum)   Entry_events=entry_tag ///
    (count) N_months=n_loans ///
    (mean)  Mean=n_loans ///
            Zero_share=zero_month ///
    (p25)   P25=n_loans ///
    (p50)   Median=n_loans ///
    (p75)   P75=n_loans ///
    (p95)   P95=n_loans, ///
    by(pin_size_cat)

replace Zero_share = ///
    100 * Zero_share

format Entry_events N_months %15.0fc
format Mean %9.3f
format Zero_share %9.2f
format P25 Median P75 P95 %9.0f

sort pin_size_cat

list pin_size_cat ///
     Entry_events N_months ///
     Mean Zero_share ///
     P25 Median P75 P95, ///
     noobs sep(0)

export excel using ///
    "06_tables\pincode_size_entry_activity.xlsx", ///
    sheet("B First 3 months") ///
    firstrow(variables) sheetreplace

restore


*============================================================*
* PANEL C
* FIRST 6 MONTHS AFTER ENTRY BY PINCODE SIZE
*============================================================*

preserve

* Only entries for which t,...,t+5 are all observable
keep if complete_6m_window == 1

* First six months of each entry event
keep if inrange(months_since_entry,0,5)

drop if missing(pin_size_cat)

gen byte zero_month = ///
    n_loans == 0

gcollapse ///
    (sum)   Entry_events=entry_tag ///
    (count) N_months=n_loans ///
    (mean)  Mean=n_loans ///
            Zero_share=zero_month ///
    (p25)   P25=n_loans ///
    (p50)   Median=n_loans ///
    (p75)   P75=n_loans ///
    (p95)   P95=n_loans, ///
    by(pin_size_cat)

replace Zero_share = ///
    100 * Zero_share

format Entry_events N_months %15.0fc
format Mean %9.3f
format Zero_share %9.2f
format P25 Median P75 P95 %9.0f

sort pin_size_cat

list pin_size_cat ///
     Entry_events N_months ///
     Mean Zero_share ///
     P25 Median P75 P95, ///
     noobs sep(0)

export excel using ///
    "06_tables\pincode_size_entry_activity.xlsx", ///
    sheet("C First 6 months") ///
    firstrow(variables) sheetreplace

restore