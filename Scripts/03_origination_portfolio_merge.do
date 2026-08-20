*============================================================*
* FINAL QUALIFYING ENTRY EVENTS
*
* Definition:
* 1. Candidate entry = no observed lender presence in prior 12 months
*    [already constructed in balanced_entry_panel.dta]
*
* 2. Qualifying entry = lender active in at least 2 of:
*       t, t+1, t+2
*
* 3. First-pass event-study sample:
*       Entry month between Jan 2021 and Dec 2023
*============================================================*

cd "C:\Users\osheen.khare\OneDrive - Centre for Advanced Financial research and Le\Desktop\Fintech"

use "04_temp\balanced_entry_panel.dta", clear


*------------------------------------------------------------*
* 1. Basic checks
*------------------------------------------------------------*

isid lender_id pincode month

assert months_since_entry >= 0
assert !missing(n_loans)


*------------------------------------------------------------*
* 2. Keep events with complete 3-month threshold window
*------------------------------------------------------------*

keep if eligible_3m == 1

* Only t, t+1, t+2 needed to determine qualification
keep if inrange(months_since_entry,0,2)

drop if missing(lender_group)


*------------------------------------------------------------*
* 3. Monthly activity
*------------------------------------------------------------*

gen byte active = n_loans >= 1


*------------------------------------------------------------*
* 4. Collapse to ONE observation per candidate entry event
*------------------------------------------------------------*

gcollapse ///
    (count) n_months=n_loans ///
    (sum) active_months_3m=active ///
          total_loans_3m=n_loans, ///
    by(lender_id lender_group pincode ///
       entry_spell entry_month)

* Every event should contribute exactly three calendar months
assert n_months == 3


*------------------------------------------------------------*
* 5. Apply FINAL threshold: active in >=2 of 3 months
*------------------------------------------------------------*

gen byte qualifying_entry = ///
    active_months_3m >= 2

tab qualifying_entry


*------------------------------------------------------------*
* 6. Keep only qualifying events
*------------------------------------------------------------*

keep if qualifying_entry == 1


*------------------------------------------------------------*
* 7. Restrict ENTRY EVENTS to 2021-2023
*
* Important:
* This restriction applies to entry_month.
* The later outcome window can extend +/- 6 months.
*------------------------------------------------------------*

keep if inrange(entry_month, ym(2021,1), ym(2023,12))

format entry_month %tm


*------------------------------------------------------------*
* 8. Create unique stacked-event identifier
*
* Each lender x pincode x entry occurrence is a separate event.
*------------------------------------------------------------*

egen long event_id = ///
    group(lender_id pincode entry_month entry_spell)

label var event_id ///
    "Unique lender-pincode entry event"


*------------------------------------------------------------*
* 9. Checks
*------------------------------------------------------------*

isid event_id

isid lender_id pincode entry_spell

assert inrange(entry_month, ym(2021,1), ym(2023,12))

assert active_months_3m >= 2
assert active_months_3m <= 3


*------------------------------------------------------------*
* 10. Entry year
*------------------------------------------------------------*

gen entry_year = year(dofm(entry_month))

tab entry_year
tab lender_group

tab lender_group entry_year


*------------------------------------------------------------*
* 11. Useful event-level variables
*------------------------------------------------------------*

label var lender_group ///
    "Type of entering lender"

label var entry_month ///
    "Entry month"

label var active_months_3m ///
    "No. active months among t,t+1,t+2"

label var total_loans_3m ///
    "Total sampled loans over t,t+1,t+2"


*------------------------------------------------------------*
* 12. Final event-study event file
*------------------------------------------------------------*

order ///
    event_id ///
    pincode ///
    lender_id ///
    lender_group ///
    entry_month ///
    entry_year ///
    entry_spell ///
    active_months_3m ///
    total_loans_3m

sort entry_month pincode lender_group lender_id

compress

save ///
    "04_temp\qualifying_entry_events_2of3_2021_2023.dta", ///
    replace
	
*============================================================*
* STACKED EVENT-MONTH SKELETON
*============================================================*

use ///
    "04_temp\qualifying_entry_events_2of3_2021_2023.dta", ///
    clear


*------------------------------------------------------------*
* Each event contributes 13 months: -6,...,0,...,+6
*------------------------------------------------------------*

expand 25

bys event_id: gen event_time = _n - 13

assert inrange(event_time,-12,12)

*------------------------------------------------------------*
* Calendar month corresponding to each event-time observation
*------------------------------------------------------------*

gen portfolio_month = ///
    entry_month + event_time

format portfolio_month %tm


*------------------------------------------------------------*
* Checks
*------------------------------------------------------------*

isid event_id event_time

tab event_time

count

keep ///
    event_id ///
    pincode ///
    lender_id ///
    lender_group ///
    entry_month ///
    entry_year ///
    event_time ///
    portfolio_month

save ///
    "04_temp\entry_event_month_stack.dta", ///
    replace
	
use ///
    "04_temp\portfolio_performance_6_12m.dta", ///
    clear

rename origination_pincode pincode

keep ///
    person_id ///
    loan_ac_id ///
    pincode ///
    origination_month ///
    portfolio_month ///
    product ///
    lender_name ///
    dpd_30plus ///
    dpd_60plus ///
    dpd_90plus ///
    derog

drop if missing(pincode)
drop if missing(portfolio_month)

*============================================================*
* CLASSIFY CONSUMER / HOUSEHOLD CREDIT
*============================================================*

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

count if consumer_loan == 1
count if consumer_loan == 0

*------------------------------------------------------------*
* Save prepared portfolio file
*------------------------------------------------------------*

compress

save ///
    "04_temp\portfolio_performance_6_12m_flagged.dta", ///
    replace


*============================================================*
* JOIN LOAN PERFORMANCE TO ENTRY EVENTS
*============================================================*

use ///
    "04_temp\portfolio_performance_6_12m_flagged.dta", ///
    clear

joinby pincode portfolio_month using ///
    "04_temp\entry_event_month_stack.dta"
	
gen loan_age_at_entry = ///
    entry_month - origination_month

keep if inrange(loan_age_at_entry,6,12)
	
*============================================================*
* COLLAPSE STACKED LOAN DATA TO EVENT x EVENT-TIME LEVEL
*
* Unit after collapse:
*   Entry event x portfolio month
*
* Outcomes constructed separately for:
*   1. All eligible loans
*   2. Consumer / household loans
*============================================================*


*------------------------------------------------------------*
* 1. TOTAL LOAN COUNTS
*------------------------------------------------------------*

gen byte one_loan = 1

gen byte one_consumer = ///
    consumer_loan == 1


*------------------------------------------------------------*
* 2. VALID OUTCOME DENOMINATORS
*
* Important:
* Missing DPD observations must NOT enter the denominator.
*------------------------------------------------------------*

* All loans
gen byte valid30_all = ///
    !missing(dpd_30plus)

gen byte valid60_all = ///
    !missing(dpd_60plus)

gen byte valid90_all = ///
    !missing(dpd_90plus)

gen byte valid_derog_all = ///
    !missing(derog)


* Consumer loans only
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
* 3. CONSUMER-SPECIFIC NUMERATORS
*
* Set to missing when DPD itself is unavailable.
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


*------------------------------------------------------------*
* 4. COLLAPSE TO ENTRY EVENT x PORTFOLIO MONTH
*------------------------------------------------------------*

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
        event_id ///
        pincode ///
        lender_group ///
        entry_month ///
        portfolio_month ///
        event_time ///
    )


*============================================================*
* 5. DEFAULT RATES: ALL ELIGIBLE LOANS
*============================================================*

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


*============================================================*
* 6. DEFAULT RATES: CONSUMER / HOUSEHOLD LOANS
*============================================================*

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


*============================================================*
* 7. FORMATS / LABELS
*============================================================*

label var default30_all ///
    "Share of all eligible loans 30+ DPD"

label var default60_all ///
    "Share of all eligible loans 60+ DPD"

label var default90_all ///
    "Share of all eligible loans 90+ DPD"

label var default30_consumer ///
    "Share of eligible consumer loans 30+ DPD"

label var default60_consumer ///
    "Share of eligible consumer loans 60+ DPD"

label var default90_consumer ///
    "Share of eligible consumer loans 90+ DPD"

label var n_loans_all ///
    "Number of eligible loans"

label var n_loans_consumer ///
    "Number of eligible consumer loans"


*============================================================*
* 8. UNIQUENESS / SANITY CHECKS
*============================================================*

isid event_id event_time

assert portfolio_month == entry_month + event_time

assert inrange(event_time,-12,12)

assert inrange(default30_all,0,1) ///
    if !missing(default30_all)

assert inrange(default60_all,0,1) ///
    if !missing(default60_all)

assert inrange(default90_all,0,1) ///
    if !missing(default90_all)

assert inrange(default30_consumer,0,1) ///
    if !missing(default30_consumer)

assert inrange(default60_consumer,0,1) ///
    if !missing(default60_consumer)

assert inrange(default90_consumer,0,1) ///
    if !missing(default90_consumer)


*============================================================*
* 9. DIAGNOSTICS
*============================================================*

tab event_time

summ ///
    default30_all ///
    default60_all ///
    default90_all ///
    default30_consumer ///
    default60_consumer ///
    default90_consumer

summ ///
    n_loans_all ///
    n_loans_consumer, ///
    detail

count if missing(default90_all)
count if missing(default90_consumer)


*============================================================*
* 10. SAVE STACKED EVENT-STUDY DATA
*============================================================*

compress

save ///
    "04_temp\stacked_event_default_2021_2023.dta", ///
    replace