*====================================================================*
* DISTRIBUTION OF NUMBER OF ENTRY EVENTS PER PINCODE
*====================================================================*

cd "C:\Users\osheen.khare\OneDrive - Centre for Advanced Financial research and Le\Desktop\Fintech"

*====================================================================*
* 1. CREATE PINCODE-TIER CROSSWALK
*====================================================================*

use "03_raw\originations_cleaned.dta", clear

drop if missing(pincode)
drop if missing(tier)

keep pincode tier
duplicates drop

* Check whether each pincode has a unique tier classification
bys pincode: gen n_tier = _N

tab n_tier

* Stop here and inspect if this fails
assert n_tier == 1

drop n_tier

isid pincode

*------------------------------------------------------------*
* Urban / rural classification
*------------------------------------------------------------*

gen byte area_type = .

replace area_type = 1 ///
    if inlist(tier,"A: METRO","B: URBAN")

replace area_type = 2 ///
    if tier == "D: RURAL"

label define area_lbl ///
    1 "Urban" ///
    2 "Rural", replace

label values area_type area_lbl

tab tier area_type, missing

save "04_temp\pincode_tier_crosswalk.dta", replace



*====================================================================*
* 2. CREATE ONE OBSERVATION PER CANDIDATE ENTRY EVENT
*====================================================================*

use "04_temp\balanced_entry_panel.dta", clear

* One row per candidate entry event
keep if months_since_entry == 0

isid lender_id pincode entry_spell

keep lender_id lender_group pincode ///
     entry_spell entry_month

drop if missing(lender_group)
drop if missing(pincode)
drop if missing(entry_month)

*------------------------------------------------------------*
* Calendar year of candidate entry
*------------------------------------------------------------*

gen entry_year = year(dofm(entry_month))

tab entry_year


*------------------------------------------------------------*
* Define analysis periods
*------------------------------------------------------------*

gen byte period = .

replace period = 1 ///
    if inrange(entry_year,2016,2019)

replace period = 2 ///
    if inrange(entry_year,2021,2023)

replace period = 3 ///
    if inrange(entry_year,2024,2026)

label define period_lbl ///
    1 "2016-2019" ///
    2 "2021-2023" ///
    3 "2024-2026", replace

label values period period_lbl

* 2020 deliberately excluded
drop if missing(period)

tab period


*------------------------------------------------------------*
* Add pincode tier
*------------------------------------------------------------*

merge m:1 pincode ///
    using "04_temp\pincode_tier_crosswalk.dta", ///
    keep(master match)

tab _merge

* Inspect unmatched pincodes if any
count if _merge == 1

drop if _merge == 1
drop _merge

assert !missing(tier)

save "04_temp\candidate_entry_events_period.dta", replace



*====================================================================*
* 3. COUNT ENTRY EVENTS BY PINCODE x PERIOD x LENDER GROUP
*====================================================================*

use "04_temp\candidate_entry_events_period.dta", clear

gcollapse ///
    (count) n_entry_events=entry_spell, ///
    by(pincode tier area_type period lender_group)

isid pincode period lender_group

tempfile positive_entries
save `positive_entries'



*====================================================================*
* 4. CREATE COMPLETE ELIGIBLE PINCODE-PERIOD x LENDER-GROUP GRID
*====================================================================*


*------------------------------------------------------------*
* 4A. Construct observed pincode x period universe
*------------------------------------------------------------*

use "03_raw\originations_cleaned.dta", clear

drop if missing(pincode)
drop if missing(month)

cap drop year
gen year = year(dofm(month))

gen byte period = .

replace period = 1 if inrange(year, 2016, 2019)
replace period = 2 if inrange(year, 2021, 2023)
replace period = 3 if inrange(year, 2024, 2026)

drop if missing(period)

label define period_lbl ///
    1 "2016-2019" ///
    2 "2021-2023" ///
    3 "2024-2026", replace

label values period period_lbl

keep pincode period
duplicates drop

isid pincode period

* Add fixed pincode classification
merge m:1 pincode ///
    using "04_temp\pincode_tier_crosswalk.dta", ///
    keep(match) nogen

assert !missing(tier)

tempfile pincode_periods
save `pincode_periods'


*------------------------------------------------------------*
* CHECK NUMBER OF PINCODES OBSERVED IN EACH PERIOD
*------------------------------------------------------------*

preserve

contract period
list, noobs

restore


*------------------------------------------------------------*
* 4B. Universe of lender groups
*------------------------------------------------------------*

use "04_temp\candidate_entry_events_period.dta", clear

keep lender_group
drop if missing(lender_group)
duplicates drop

sort lender_group

tempfile lenders
save `lenders'


*------------------------------------------------------------*
* 4C. Cross eligible pincode-periods with lender groups
*------------------------------------------------------------*

use `pincode_periods', clear

cross using `lenders'

isid pincode period lender_group


*------------------------------------------------------------*
* 4D. Merge actual entry-event counts
*------------------------------------------------------------*

merge 1:1 pincode period lender_group ///
    using `positive_entries'

tab _merge

/*
    _merge == 1:
        pincode exists in this period,
        but no candidate entry from this lender group.
        These are TRUE ZEROS.

    _merge == 3:
        positive candidate entry count.

    _merge == 2 should not occur.
*/

assert _merge != 2

replace n_entry_events = 0 if _merge == 1

drop _merge

assert !missing(n_entry_events)
assert n_entry_events >= 0

save ///
    "04_temp\pincode_period_lender_entry_counts.dta", ///
    replace



*====================================================================*
* 5. SUMMARY STATISTICS - INDIA OVERALL
*
* Unit:
* pincode x period x lender group
*
* Includes Metro, Urban, Semi-Urban, and Rural pincodes.
*====================================================================*

use "04_temp\pincode_period_lender_entry_counts.dta", clear

preserve

gcollapse ///
(sum)   N_events=n_entry_events ///
    (count) N_pincodes=n_entry_events ///
    (mean)  Mean=n_entry_events ///
    (p5)    P5=n_entry_events ///
    (p25)   P25=n_entry_events ///
    (p50)   Median=n_entry_events ///
    (p75)   P75=n_entry_events ///
    (p95)   P95=n_entry_events, ///
    by(lender_group period)

gen geography = "India overall"

order geography lender_group period ///
      N_pincodes Mean P5 P25 Median P75 P95

format N_pincodes %15.0fc
format Mean %9.3f
format P5 P25 Median P75 P95 %9.0f

sort lender_group period

list, noobs sepby(lender_group)

tempfile overall_summary
save `overall_summary'

export excel using ///
    "06_tables\entry_events_per_pincode_distribution.xlsx", ///
    sheet("India overall") ///
    firstrow(variables) replace

restore



*====================================================================*
* 6. SUMMARY STATISTICS - URBAN PINCODES
*
* Urban = Metro + Urban
* Semi-urban excluded.
*====================================================================*

preserve

keep if area_type == 1

gcollapse ///
(sum)   N_events=n_entry_events ///
    (count) N_pincodes=n_entry_events ///
    (mean)  Mean=n_entry_events ///
    (p5)    P5=n_entry_events ///
    (p25)   P25=n_entry_events ///
    (p50)   Median=n_entry_events ///
    (p75)   P75=n_entry_events ///
    (p95)   P95=n_entry_events, ///
    by(lender_group period)

gen geography = "Urban"

order geography lender_group period ///
      N_pincodes Mean P5 P25 Median P75 P95

format N_pincodes %15.0fc
format Mean %9.3f
format P5 P25 Median P75 P95 %9.0f

sort lender_group period

list, noobs sepby(lender_group)

tempfile urban_summary
save `urban_summary'

export excel using ///
    "06_tables\entry_events_per_pincode_distribution.xlsx", ///
    sheet("Urban") ///
    firstrow(variables) sheetreplace

restore



*====================================================================*
* 7. SUMMARY STATISTICS - RURAL PINCODES
*====================================================================*

preserve

keep if area_type == 2

gcollapse ///
(sum)   N_events=n_entry_events ///
    (count) N_pincodes=n_entry_events ///
    (mean)  Mean=n_entry_events ///
    (p5)    P5=n_entry_events ///
    (p25)   P25=n_entry_events ///
    (p50)   Median=n_entry_events ///
    (p75)   P75=n_entry_events ///
    (p95)   P95=n_entry_events, ///
    by(lender_group period)

gen geography = "Rural"

order geography lender_group period ///
      N_pincodes Mean P5 P25 Median P75 P95

format N_pincodes %15.0fc
format Mean %9.3f
format P5 P25 Median P75 P95 %9.0f

sort lender_group period

list, noobs sepby(lender_group)

tempfile rural_summary
save `rural_summary'

export excel using ///
    "06_tables\entry_events_per_pincode_distribution.xlsx", ///
    sheet("Rural") ///
    firstrow(variables) sheetreplace

restore



*====================================================================*
* 8. COMBINED SUMMARY TABLE
*====================================================================*

use `overall_summary', clear

append using `urban_summary'
append using `rural_summary'

order geography lender_group period ///
      N_pincodes Mean P5 P25 Median P75 P95

sort geography lender_group period

save "04_temp\entry_events_distribution_summary.dta", replace

export excel using ///
    "06_tables\entry_events_per_pincode_distribution.xlsx", ///
    sheet("Combined summary") ///
    firstrow(variables) sheetreplace



*====================================================================*
* 9. DISTRIBUTION PLOTS
*====================================================================*

use "04_temp\pincode_period_lender_entry_counts.dta", clear

capture mkdir "07_figures\entry_distribution_plots"


*------------------------------------------------------------*
* 9A. INDIA OVERALL
*------------------------------------------------------------*

levelsof lender_group, local(lendergroups)

foreach lg of local lendergroups {

    * Safe lender-group name for filename
    local safe = strtoname("`lg'")

histogram n_entry_events ///
    if lender_group == "`lg'", ///
    discrete ///
    fraction ///
    by(period, ///
        title("Candidate Entry Events per Pincode: `lg'") ///
        cols(3) ///
        note("")) ///
    xtitle("Number of candidate entry events per pincode") ///
    ytitle("Fraction of pincodes") ///
    name(g_overall_`safe', replace)

    graph export ///
        "07_figures\entry_distribution_plots\overall_`safe'.png", ///
        replace
}



*------------------------------------------------------------*
* 9B. URBAN PINCODES
* Metro + Urban
*------------------------------------------------------------*

foreach lg of local lendergroups {

    local safe = strtoname("`lg'")

    histogram n_entry_events ///
        if lender_group == "`lg'" ///
        & area_type == 1, ///
        discrete ///
        fraction ///
        by(period, ///
            title("Candidate Entry Events per Urban Pincode: `lg'") ///
            note("") ///
            cols(3)) ///
        xtitle("Number of candidate entry events per Urban pincode") ///
        ytitle("Fraction of pincodes") ///
        name(g_urban_`safe', replace)

    graph export ///
        "07_figures\entry_distribution_plots\urban_`safe'.png", ///
        replace
}



*------------------------------------------------------------*
* 9C. RURAL PINCODES
*------------------------------------------------------------*

foreach lg of local lendergroups {

    local safe = strtoname("`lg'")

    histogram n_entry_events ///
        if lender_group == "`lg'" ///
        & area_type == 2, ///
        discrete ///
        fraction ///
        by(period, ///
            title("Candidate Entry Events per Rural Pincode: `lg'") ///
            note("") ///
            cols(3)) ///
        xtitle("Number of candidate entry events per Rural pincode") ///
        ytitle("Fraction of pincodes") ///
        name(g_rural_`safe', replace)

    graph export ///
        "07_figures\entry_distribution_plots\rural_`safe'.png", ///
        replace
}



