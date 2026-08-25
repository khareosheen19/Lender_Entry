*====================================================================*
* EVENT-STUDY REGRESSIONS
*
* FE:
*   event_id        = pincode x entry-event FE
*   portfolio_month = calendar snapshot FE
*
* SE:
*   clustered by pincode
*
* Reference:
*   -3 to -1 months
*====================================================================*

use ///
    "04_temp\stacked_event_default_2021_2023_12m.dta", ///
    clear


*------------------------------------------------------------*
* Three-month event bins
*------------------------------------------------------------*

gen byte event_bin = .

replace event_bin = 1 if inrange(event_time,-12,-10)
replace event_bin = 2 if inrange(event_time, -9, -7)
replace event_bin = 3 if inrange(event_time, -6, -4)
replace event_bin = 4 if inrange(event_time, -3, -1)
replace event_bin = 5 if inrange(event_time,  0,  2)
replace event_bin = 6 if inrange(event_time,  3,  5)
replace event_bin = 7 if inrange(event_time,  6,  8)
replace event_bin = 8 if inrange(event_time,  9, 11)

label define event_bin_lbl ///
    1 "-12 to -10" ///
    2 "-9 to -7" ///
    3 "-6 to -4" ///
    4 "-3 to -1" ///
    5 "0 to +2" ///
    6 "+3 to +5" ///
    7 "+6 to +8" ///
    8 "+9 to +11", ///
    replace

label values event_bin event_bin_lbl

keep if !missing(event_bin)


*====================================================================*
* REGRESSIONS
*====================================================================*

eststo clear


*------------------------------------------------------------*
* ALL LOANS
*------------------------------------------------------------*

eststo all30: reghdfe ///
    default30_all ///
    ib4.event_bin ///
    [aw=n_valid30_all] ///
    if n_valid30_all > 0, ///
    absorb(event_id portfolio_month) ///
    vce(cluster pincode)


eststo all60: reghdfe ///
    default60_all ///
    ib4.event_bin ///
    [aw=n_valid60_all] ///
    if n_valid60_all > 0, ///
    absorb(event_id portfolio_month) ///
    vce(cluster pincode)


eststo all90: reghdfe ///
    default90_all ///
    ib4.event_bin ///
    [aw=n_valid90_all] ///
    if n_valid90_all > 0, ///
    absorb(event_id portfolio_month) ///
    vce(cluster pincode)


eststo alld: reghdfe ///
    derog_rate_all ///
    ib4.event_bin ///
    [aw=n_valid_derog_all] ///
    if n_valid_derog_all > 0, ///
    absorb(event_id portfolio_month) ///
    vce(cluster pincode)


*------------------------------------------------------------*
* CONSUMER LOANS
*------------------------------------------------------------*

eststo cons30: reghdfe ///
    default30_consumer ///
    ib4.event_bin ///
    [aw=n_valid30_cons] ///
    if n_valid30_cons > 0, ///
    absorb(event_id portfolio_month) ///
    vce(cluster pincode)


eststo cons60: reghdfe ///
    default60_consumer ///
    ib4.event_bin ///
    [aw=n_valid60_cons] ///
    if n_valid60_cons > 0, ///
    absorb(event_id portfolio_month) ///
    vce(cluster pincode)


eststo cons90: reghdfe ///
    default90_consumer ///
    ib4.event_bin ///
    [aw=n_valid90_cons] ///
    if n_valid90_cons > 0, ///
    absorb(event_id portfolio_month) ///
    vce(cluster pincode)


eststo consd: reghdfe ///
    derog_rate_consumer ///
    ib4.event_bin ///
    [aw=n_valid_derog_cons] ///
    if n_valid_derog_cons > 0, ///
    absorb(event_id portfolio_month) ///
    vce(cluster pincode)
	
*====================================================================*
* EVENT-STUDY PLOT: 90+ DPD
*
* Reference period -3 to -1 is explicitly shown at zero.
* Entry line is between -3 to -1 and 0 to +2.
*====================================================================*

coefplot ///
    (all90, ///
        label("All loans") ///
        msymbol(O)) ///
    (cons90, ///
        label("Consumer loans") ///
        msymbol(D)), ///
    keep( ///
        1.event_bin ///
        2.event_bin ///
        3.event_bin ///
        4.event_bin ///
        5.event_bin ///
        6.event_bin ///
        7.event_bin ///
    ) ///
    baselevels ///
    vertical ///
    yline(0, lpattern(dash)) ///
    xline(4.5, lpattern(dash)) ///
    coeflabels( ///
        1.event_bin = "-12 to -10" ///
        2.event_bin = "-9 to -7" ///
        3.event_bin = "-6 to -4" ///
        4.event_bin = "-3 to -1" ///
        5.event_bin = "0 to +2" ///
        6.event_bin = "+3 to +5" ///
        7.event_bin = "+6 to +8" ///
    ) ///
    ciopts(recast(rcap)) ///
    title("Event Study: 90+ DPD") ///
    subtitle("Reference period: -3 to -1 months") ///
    ytitle("Coefficient relative to -3 to -1 months") ///
    xtitle("Months relative to lender entry") ///
    legend(rows(1) position(6)) ///
    name(g_default90, replace)
	
graph export ///
    "06_tables\event_study_default90_12m.png", ///
    name(g_default90) ///
    replace
	
*============================================================*
* COEFFICIENT PLOT: 60+ DPD
*============================================================*

coefplot ///
    (all60, ///
        label("All loans") ///
        msymbol(O)) ///
    (cons60, ///
        label("Consumer loans") ///
        msymbol(D)), ///
    keep( ///
        1.event_bin ///
        2.event_bin ///
        3.event_bin ///
        4.event_bin ///
        5.event_bin ///
        6.event_bin ///
        7.event_bin ///
        8.event_bin ///
    ) ///
    baselevels ///
    vertical ///
    yline(0, lpattern(dash)) ///
    xline(4.5, lpattern(dash)) ///
    coeflabels( ///
        1.event_bin = "-12 to -10" ///
        2.event_bin = "-9 to -7" ///
        3.event_bin = "-6 to -4" ///
        4.event_bin = "-3 to -1" ///
        5.event_bin = "0 to +2" ///
        6.event_bin = "+3 to +5" ///
        7.event_bin = "+6 to +8" ///
        8.event_bin = "+9 to +11" ///
    ) ///
    ciopts(recast(rcap)) ///
    title("Event Study: 60+ DPD") ///
    subtitle("Reference period: -3 to -1 months") ///
    ytitle("Coefficient relative to -3 to -1 months") ///
    xtitle("Months relative to lender entry") ///
    legend(rows(1) position(6)) ///
    name(g_default60, replace)


graph export ///
    "06_tables\event_study_default60_12m.png", ///
    name(g_default60) ///
    replace


*============================================================*
* COEFFICIENT PLOT: 30+ DPD
*============================================================*

coefplot ///
    (all30, ///
        label("All loans") ///
        msymbol(O)) ///
    (cons30, ///
        label("Consumer loans") ///
        msymbol(D)), ///
    keep( ///
        1.event_bin ///
        2.event_bin ///
        3.event_bin ///
        4.event_bin ///
        5.event_bin ///
        6.event_bin ///
        7.event_bin ///
        8.event_bin ///
    ) ///
    baselevels ///
    vertical ///
    yline(0, lpattern(dash)) ///
    xline(4.5, lpattern(dash)) ///
    coeflabels( ///
        1.event_bin = "-12 to -10" ///
        2.event_bin = "-9 to -7" ///
        3.event_bin = "-6 to -4" ///
        4.event_bin = "-3 to -1" ///
        5.event_bin = "0 to +2" ///
        6.event_bin = "+3 to +5" ///
        7.event_bin = "+6 to +8" ///
        8.event_bin = "+9 to +11" ///
    ) ///
    ciopts(recast(rcap)) ///
    title("Event Study: 30+ DPD") ///
    subtitle("Reference period: -3 to -1 months") ///
    ytitle("Coefficient relative to -3 to -1 months") ///
    xtitle("Months relative to lender entry") ///
    legend(rows(1) position(6)) ///
    name(g_default30, replace)


graph export ///
    "06_tables\event_study_default30_12m.png", ///
    name(g_default30) ///
    replace

*====================================================================*
* HETEROGENEITY BY ENTERING LENDER TYPE
*
* Outcomes:
*   30+ DPD
*   60+ DPD
*   90+ DPD
*
* Samples:
*   All loans
*   Consumer loans
*
* Specification:
*   Event FE            = event_id
*   Calendar-month FE   = portfolio_month
*   SE clustered by     = pincode
*   Reference period    = -3 to -1 months
*
* For each lender type x outcome:
*   Plot All loans and Consumer loans together
*====================================================================*


*====================================================================*
* 1. ESTIMATE ALL REGRESSIONS
*====================================================================*

eststo clear


*------------------------------------------------------------*
* Lender groups
*
* First element  = actual lender_group value
* Second element = short name used in stored estimates/files
*------------------------------------------------------------*

local lender_values ///
    `" "ARC" "COOP" "FB" "HFC" "NBFC" "NBFC-FINTECH" "OTHERS" "PSU" "PVT" "SFB" "'

local lender_short ///
    `" "ARC" "COOP" "FB" "HFC" "NBFC" "FIN" "OTH" "PSU" "PVT" "SFB" "'


*------------------------------------------------------------*
* Loop over lender groups
*------------------------------------------------------------*

forvalues j = 1/10 {

    local lg : word `j' of `lender_values'
    local gs : word `j' of `lender_short'

    display "======================================================"
    display "LENDER GROUP: `lg'"
    display "======================================================"


    *========================================================*
    * 30+ DPD
    *========================================================*

    * All loans
    eststo a30_`gs': reghdfe ///
        default30_all ///
        ib4.event_bin ///
        [aw=n_valid30_all] ///
        if lender_group=="`lg'" ///
        & n_valid30_all>0, ///
        absorb(event_id portfolio_month) ///
        vce(cluster pincode)


    * Consumer loans
    eststo c30_`gs': reghdfe ///
        default30_consumer ///
        ib4.event_bin ///
        [aw=n_valid30_cons] ///
        if lender_group=="`lg'" ///
        & n_valid30_cons>0, ///
        absorb(event_id portfolio_month) ///
        vce(cluster pincode)


    *========================================================*
    * 60+ DPD
    *========================================================*

    * All loans
    eststo a60_`gs': reghdfe ///
        default60_all ///
        ib4.event_bin ///
        [aw=n_valid60_all] ///
        if lender_group=="`lg'" ///
        & n_valid60_all>0, ///
        absorb(event_id portfolio_month) ///
        vce(cluster pincode)


    * Consumer loans
    eststo c60_`gs': reghdfe ///
        default60_consumer ///
        ib4.event_bin ///
        [aw=n_valid60_cons] ///
        if lender_group=="`lg'" ///
        & n_valid60_cons>0, ///
        absorb(event_id portfolio_month) ///
        vce(cluster pincode)


    *========================================================*
    * 90+ DPD
    *========================================================*

    * All loans
    eststo a90_`gs': reghdfe ///
        default90_all ///
        ib4.event_bin ///
        [aw=n_valid90_all] ///
        if lender_group=="`lg'" ///
        & n_valid90_all>0, ///
        absorb(event_id portfolio_month) ///
        vce(cluster pincode)


    * Consumer loans
    eststo c90_`gs': reghdfe ///
        default90_consumer ///
        ib4.event_bin ///
        [aw=n_valid90_cons] ///
        if lender_group=="`lg'" ///
        & n_valid90_cons>0, ///
        absorb(event_id portfolio_month) ///
        vce(cluster pincode)
}

*====================================================================*
* PLOTS
*
* Each graph:
*   All loans vs Consumer loans
*
* 10 lender groups x 3 outcomes = 30 graphs
*====================================================================*

local lender_short ///
    ARC COOP FB HFC NBFC FIN OTH PSU PVT SFB


foreach g of local lender_short {


    *--------------------------------------------------------*
    * Nice lender title
    *--------------------------------------------------------*

    local gtitle "`g'"

    if "`g'"=="ARC"  local gtitle "ARC"
    if "`g'"=="COOP" local gtitle "Cooperative Banks"
    if "`g'"=="FB"   local gtitle "Foreign Banks"
    if "`g'"=="HFC"  local gtitle "HFC"
    if "`g'"=="NBFC" local gtitle "NBFC"

    if "`g'"=="FIN" ///
        local gtitle "NBFC-Fintech"

    if "`g'"=="OTH" ///
        local gtitle "Others"

    if "`g'"=="PSU" ///
        local gtitle "Public Sector Banks"

    if "`g'"=="PVT" ///
        local gtitle "Private Sector Banks"

    if "`g'"=="SFB" ///
        local gtitle "Small Finance Banks"


    *========================================================*
    * 30+ DPD
    *========================================================*

    coefplot ///
        (a30_`g', ///
            label("All loans") ///
            msymbol(O)) ///
        (c30_`g', ///
            label("Consumer loans") ///
            msymbol(D)), ///
        keep( ///
            1.event_bin ///
            2.event_bin ///
            3.event_bin ///
            4.event_bin ///
            5.event_bin ///
            6.event_bin ///
            7.event_bin ///
        ) ///
        baselevels ///
        vertical ///
        yline(0, lpattern(dash)) ///
        xline(4.5, lpattern(dash)) ///
        coeflabels( ///
            1.event_bin = "-12 to -10" ///
            2.event_bin = "-9 to -7" ///
            3.event_bin = "-6 to -4" ///
            4.event_bin = "-3 to -1" ///
            5.event_bin = "0 to +2" ///
            6.event_bin = "+3 to +5" ///
            7.event_bin = "+6 to +8" ///
        ) ///
        ciopts(recast(rcap)) ///
        title("`gtitle' Entry: 30+ DPD") ///
        subtitle("Reference period: -3 to -1 months") ///
        ytitle("Coefficient relative to -3 to -1 months") ///
        xtitle("Months relative to lender entry") ///
        legend(rows(1) position(6)) ///
        name(g30_`g', replace)


    graph export ///
        "06_tables\event_study_30_`g'_all_consumer.png", ///
        name(g30_`g') ///
        width(2000) ///
        replace


    *========================================================*
    * 60+ DPD
    *========================================================*

    coefplot ///
        (a60_`g', ///
            label("All loans") ///
            msymbol(O)) ///
        (c60_`g', ///
            label("Consumer loans") ///
            msymbol(D)), ///
        keep( ///
            1.event_bin ///
            2.event_bin ///
            3.event_bin ///
            4.event_bin ///
            5.event_bin ///
            6.event_bin ///
            7.event_bin ///
        ) ///
        baselevels ///
        vertical ///
        yline(0, lpattern(dash)) ///
        xline(4.5, lpattern(dash)) ///
        coeflabels( ///
            1.event_bin = "-12 to -10" ///
            2.event_bin = "-9 to -7" ///
            3.event_bin = "-6 to -4" ///
            4.event_bin = "-3 to -1" ///
            5.event_bin = "0 to +2" ///
            6.event_bin = "+3 to +5" ///
            7.event_bin = "+6 to +8" ///
        ) ///
        ciopts(recast(rcap)) ///
        title("`gtitle' Entry: 60+ DPD") ///
        subtitle("Reference period: -3 to -1 months") ///
        ytitle("Coefficient relative to -3 to -1 months") ///
        xtitle("Months relative to lender entry") ///
        legend(rows(1) position(6)) ///
        name(g60_`g', replace)


    graph export ///
        "06_tables\event_study_60_`g'_all_consumer.png", ///
        name(g60_`g') ///
        width(2000) ///
        replace


    *========================================================*
    * 90+ DPD
    *========================================================*

    coefplot ///
        (a90_`g', ///
            label("All loans") ///
            msymbol(O)) ///
        (c90_`g', ///
            label("Consumer loans") ///
            msymbol(D)), ///
        keep( ///
            1.event_bin ///
            2.event_bin ///
            3.event_bin ///
            4.event_bin ///
            5.event_bin ///
            6.event_bin ///
            7.event_bin ///
        ) ///
        baselevels ///
        vertical ///
        yline(0, lpattern(dash)) ///
        xline(4.5, lpattern(dash)) ///
        coeflabels( ///
            1.event_bin = "-12 to -10" ///
            2.event_bin = "-9 to -7" ///
            3.event_bin = "-6 to -4" ///
            4.event_bin = "-3 to -1" ///
            5.event_bin = "0 to +2" ///
            6.event_bin = "+3 to +5" ///
            7.event_bin = "+6 to +8" ///
        ) ///
        ciopts(recast(rcap)) ///
        title("`gtitle' Entry: 90+ DPD") ///
        subtitle("Reference period: -3 to -1 months") ///
        ytitle("Coefficient relative to -3 to -1 months") ///
        xtitle("Months relative to lender entry") ///
        legend(rows(1) position(6)) ///
        name(g90_`g', replace)


    graph export ///
        "06_tables\event_study_90_`g'_all_consumer.png", ///
        name(g90_`g') ///
        width(2000) ///
        replace
}