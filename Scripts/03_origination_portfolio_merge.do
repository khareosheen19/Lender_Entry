cd ///
"C:\Users\osheen.khare\OneDrive - Centre for Advanced Financial research and Le\Desktop\Fintech"

*====================================================================*
* PART 1. ACCOUNT-LEVEL ORIGINATION LOOKUP
*====================================================================*

use "03_raw\originations_cleaned.dta", clear


*------------------------------------------------------------*
* 1A. Check origination month consistency
*------------------------------------------------------------*

bysort person_id loan_ac_id: ///
    egen min_orig_month = min(month)

bysort person_id loan_ac_id: ///
    egen max_orig_month = max(month)

gen byte same_orig_month = ///
    min_orig_month == max_orig_month ///
    & !missing(min_orig_month)


*------------------------------------------------------------*
* 1B. Check pincode consistency
*------------------------------------------------------------*

bysort person_id loan_ac_id: ///
    egen min_pincode = min(pincode)

bysort person_id loan_ac_id: ///
    egen max_pincode = max(pincode)

gen byte same_pincode = ///
    min_pincode == max_pincode ///
    & !missing(min_pincode)


*------------------------------------------------------------*
* 1C. Diagnostics
*------------------------------------------------------------*

egen byte tag_account = ///
    tag(person_id loan_ac_id)

tab same_orig_month if tag_account, missing
tab same_pincode if tag_account, missing


*------------------------------------------------------------*
* 1D. Keep accounts with unambiguous information
*------------------------------------------------------------*

keep if ///
    same_orig_month == 1 ///
    & same_pincode == 1

gen origination_month = min_orig_month
gen origination_pincode = min_pincode

keep ///
    person_id ///
    loan_ac_id ///
    origination_month ///
    origination_pincode

duplicates drop

isid person_id loan_ac_id

format origination_month %tm

compress

save ///
    "04_temp\account_origination_lookup.dta", ///
    replace
	
*====================================================================*
* PART 2. MERGE ORIGINATION INFORMATION TO PORTFOLIO
*====================================================================*

use ///
    "04_temp\portfolio_performance_clean.dta", ///
    clear


*------------------------------------------------------------*
* 2A. Collapse remaining duplicate loan-month observations
*
* Unique level:
* borrower x account x lender x product x portfolio month
*------------------------------------------------------------*

gcollapse ///
    (max) ///
        dpd_30plus ///
        dpd_60plus ///
        dpd_90plus ///
        derog ///
    (firstnm) ///
        closing_month, ///
    by( ///
        person_id ///
        loan_ac_id ///
        lender_name ///
        product ///
        portfolio_month ///
    )


isid ///
    person_id ///
    loan_ac_id ///
    lender_name ///
    product ///
    portfolio_month


*------------------------------------------------------------*
* 2B. Merge account origination information
*------------------------------------------------------------*

merge m:1 ///
    person_id ///
    loan_ac_id ///
    using ///
    "04_temp\account_origination_lookup.dta"

tab _merge

keep if _merge == 3
drop _merge


*------------------------------------------------------------*
* 2C. Loan age at each portfolio snapshot
*------------------------------------------------------------*

gen loan_age_months = ///
    portfolio_month - origination_month

label var loan_age_months ///
    "Months since loan origination"


* Impossible observations
drop if loan_age_months < 0


*------------------------------------------------------------*
* 2D. Keep only dates potentially needed for +/-12 analysis
*------------------------------------------------------------*

keep if inrange( ///
    portfolio_month, ///
    ym(2020,1), ///
    ym(2024,12) ///
)


format portfolio_month %tm
format origination_month %tm


*------------------------------------------------------------*
* 2E. Checks
*------------------------------------------------------------*

assert inlist(dpd_30plus,0,1) ///
    if !missing(dpd_30plus)

assert inlist(dpd_60plus,0,1) ///
    if !missing(dpd_60plus)

assert inlist(dpd_90plus,0,1) ///
    if !missing(dpd_90plus)

assert inlist(derog,0,1) ///
    if !missing(derog)


compress

save ///
    "04_temp\portfolio_performance_with_origination.dta", ///
    replace
	
*====================================================================*
* PART 3. FINAL QUALIFYING ENTRY EVENTS
*====================================================================*

use ///
    "04_temp\balanced_entry_panel.dta", ///
    clear


isid lender_id pincode month

assert months_since_entry >= 0
assert !missing(n_loans)


*------------------------------------------------------------*
* Complete t,t+1,t+2 follow-up only
*------------------------------------------------------------*

keep if eligible_3m == 1
keep if inrange(months_since_entry,0,2)

drop if missing(lender_group)


*------------------------------------------------------------*
* Monthly activity
*------------------------------------------------------------*

gen byte active = ///
    n_loans >= 1


*------------------------------------------------------------*
* Collapse to candidate event
*------------------------------------------------------------*

gcollapse ///
    (count) n_months=n_loans ///
    (sum) ///
        active_months_3m=active ///
        total_loans_3m=n_loans, ///
    by( ///
        lender_id ///
        lender_group ///
        pincode ///
        entry_spell ///
        entry_month ///
    )


assert n_months == 3


*------------------------------------------------------------*
* Final qualification: >=2 of 3 months
*------------------------------------------------------------*

gen byte qualifying_entry = ///
    active_months_3m >= 2

tab qualifying_entry

keep if qualifying_entry == 1


*------------------------------------------------------------*
* Entry years 2021-2023
*------------------------------------------------------------*

keep if inrange( ///
    entry_month, ///
    ym(2021,1), ///
    ym(2023,12) ///
)

format entry_month %tm


*------------------------------------------------------------*
* Event ID
*------------------------------------------------------------*

egen long event_id = ///
    group( ///
        lender_id ///
        pincode ///
        entry_month ///
        entry_spell ///
    )

isid event_id

assert inrange(active_months_3m,2,3)


gen entry_year = ///
    year(dofm(entry_month))

tab entry_year
tab lender_group


compress

save ///
    "04_temp\qualifying_entry_events_2of3_2021_2023.dta", ///
    replace	
	
*====================================================================*
* PART 4. +/-12 MONTH EVENT SKELETON
*====================================================================*

use ///
    "04_temp\qualifying_entry_events_2of3_2021_2023.dta", ///
    clear


* 25 months: -12 through +12
expand 25


bysort event_id: ///
    gen byte event_time = _n - 13


assert inrange(event_time,-12,12)


*------------------------------------------------------------*
* Calendar month represented by each event-time observation
*------------------------------------------------------------*

gen portfolio_month = ///
    entry_month + event_time

format portfolio_month %tm


*------------------------------------------------------------*
* Checks
*------------------------------------------------------------*

isid event_id event_time

assert ///
    portfolio_month == ///
    entry_month + event_time

bysort event_id: ///
    assert _N == 25


tab event_time


keep ///
    event_id ///
    pincode ///
    lender_id ///
    lender_group ///
    entry_month ///
    entry_year ///
    event_time ///
    portfolio_month


compress

save ///
    "04_temp\entry_event_month_stack_12m.dta", ///
    replace
	
*====================================================================*
* PART 5. ROLLING 6-12 MONTH LOAN COHORT
*====================================================================*

use ///
    "04_temp\portfolio_performance_with_origination.dta", ///
    clear


rename origination_pincode pincode


*------------------------------------------------------------*
* 5A. Restrict to loans aged 6-12 months
* AT EACH portfolio snapshot
*------------------------------------------------------------*

keep if inrange(loan_age_months,6,12)

assert inrange(loan_age_months,6,12)


*------------------------------------------------------------*
* 5B. Consumer / household classification
*
* Keep ALL loans.
* consumer_loan is just a flag.
*------------------------------------------------------------*

gen byte consumer_loan = 0


replace consumer_loan = 1 if inlist(product, ///
    "CONSUMER LOAN", ///
    "PERSONAL LOAN", ///
    "P2P Personal Loan", ///
    "CREDIT CARD", ///
    "SECURED CREDIT CARD", ///
    "AUTO LOAN", ///
    "TWO WHEELER LOAN")


replace consumer_loan = 1 if inlist(product, ///
    "USED CAR LOAN", ///
    "EDUCATION LOAN", ///
    "HOUSING LOAN", ///
    "PROPERTY LOAN", ///
    "GOLD LOAN", ///
    "PSL-GOLD LOAN")


replace consumer_loan = 1 if inlist(product, ///
    "LOAN AGAINST BANK DEPOSITS", ///
    "LOAN AGAINST SHARES/SECURITY")


tab product consumer_loan, missing
tab consumer_loan

*====================================================================*
* PART 6. DEFAULT NUMERATORS AND DENOMINATORS
*====================================================================*


*------------------------------------------------------------*
* Total loan counts
*------------------------------------------------------------*

gen byte one_loan = 1

gen byte one_consumer = ///
    consumer_loan == 1


*------------------------------------------------------------*
* Valid outcome denominators: all loans
*------------------------------------------------------------*

gen byte valid30_all = ///
    !missing(dpd_30plus)

gen byte valid60_all = ///
    !missing(dpd_60plus)

gen byte valid90_all = ///
    !missing(dpd_90plus)

gen byte valid_derog_all = ///
    !missing(derog)


*------------------------------------------------------------*
* Valid outcome denominators: consumer loans
*------------------------------------------------------------*

gen byte valid30_cons = ///
    consumer_loan == 1 ///
    & !missing(dpd_30plus)

gen byte valid60_cons = ///
    consumer_loan == 1 ///
    & !missing(dpd_60plus)

gen byte valid90_cons = ///
    consumer_loan == 1 ///
    & !missing(dpd_90plus)

gen byte valid_derog_cons = ///
    consumer_loan == 1 ///
    & !missing(derog)


*------------------------------------------------------------*
* Consumer outcome numerators
*------------------------------------------------------------*

gen byte dpd30_cons_num = ///
    (dpd_30plus == 1 & consumer_loan == 1) ///
    if !missing(dpd_30plus)

gen byte dpd60_cons_num = ///
    (dpd_60plus == 1 & consumer_loan == 1) ///
    if !missing(dpd_60plus)

gen byte dpd90_cons_num = ///
    (dpd_90plus == 1 & consumer_loan == 1) ///
    if !missing(dpd_90plus)

gen byte derog_cons_num = ///
    (derog == 1 & consumer_loan == 1) ///
    if !missing(derog)
	
*====================================================================*
* PART 7. COLLAPSE PORTFOLIO TO PINCODE x PORTFOLIO MONTH
*====================================================================*

gcollapse ///
    (sum) ///
        n_loans_all=one_loan ///
        n_loans_consumer=one_consumer ///
        n_valid30_all=valid30_all ///
        n_valid60_all=valid60_all ///
        n_valid90_all=valid90_all ///
        n_valid_derog_all=valid_derog_all ///
        n_valid30_cons=valid30_cons ///
        n_valid60_cons=valid60_cons ///
        n_valid90_cons=valid90_cons ///
        n_valid_derog_cons=valid_derog_cons ///
        default30_all_num=dpd_30plus ///
        default60_all_num=dpd_60plus ///
        default90_all_num=dpd_90plus ///
        derog_all_num=derog ///
        default30_cons_num=dpd30_cons_num ///
        default60_cons_num=dpd60_cons_num ///
        default90_cons_num=dpd90_cons_num ///
        derog_cons_num=derog_cons_num, ///
    by( ///
        pincode ///
        portfolio_month ///
    )


isid pincode portfolio_month


compress

save ///
    "04_temp\pincode_month_performance_6_12m.dta", ///
    replace
	
*====================================================================*
* PART 8. JOIN PINCODE PERFORMANCE TO ENTRY EVENTS
*====================================================================*

use ///
    "04_temp\entry_event_month_stack_12m.dta", ///
    clear


joinby ///
    pincode ///
    portfolio_month ///
    using ///
    "04_temp\pincode_month_performance_6_12m.dta"


*------------------------------------------------------------*
* Checks
*------------------------------------------------------------*

assert inrange(event_time,-12,12)

assert ///
    portfolio_month == ///
    entry_month + event_time


* Since pincode-month performance is unique:
isid event_id event_time


display "========================================"
display "OBSERVED EVENT-TIME SUPPORT"
display "========================================"

tab event_time


display "========================================"
display "PORTFOLIO SNAPSHOTS"
display "========================================"

tab portfolio_month

*====================================================================*
* PART 9. DEFAULT RATES
*====================================================================*


*------------------------------------------------------------*
* All loans
*------------------------------------------------------------*

gen double default30_all = ///
    default30_all_num / n_valid30_all ///
    if n_valid30_all > 0

gen double default60_all = ///
    default60_all_num / n_valid60_all ///
    if n_valid60_all > 0

gen double default90_all = ///
    default90_all_num / n_valid90_all ///
    if n_valid90_all > 0

gen double derog_rate_all = ///
    derog_all_num / n_valid_derog_all ///
    if n_valid_derog_all > 0


*------------------------------------------------------------*
* Consumer loans
*------------------------------------------------------------*

gen double default30_consumer = ///
    default30_cons_num / n_valid30_cons ///
    if n_valid30_cons > 0

gen double default60_consumer = ///
    default60_cons_num / n_valid60_cons ///
    if n_valid60_cons > 0

gen double default90_consumer = ///
    default90_cons_num / n_valid90_cons ///
    if n_valid90_cons > 0

gen double derog_rate_consumer = ///
    derog_cons_num / n_valid_derog_cons ///
    if n_valid_derog_cons > 0


*------------------------------------------------------------*
* Sanity checks
*------------------------------------------------------------*

foreach v in ///
    default30_all ///
    default60_all ///
    default90_all ///
    derog_rate_all ///
    default30_consumer ///
    default60_consumer ///
    default90_consumer ///
    derog_rate_consumer {

    assert inrange(`v',0,1) ///
        if !missing(`v')
}


isid event_id event_time


compress

save ///
    "04_temp\stacked_event_default_2021_2023_12m.dta", ///
    replace
	

