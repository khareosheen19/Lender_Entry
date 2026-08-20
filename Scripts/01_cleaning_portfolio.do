*====================================================================*
* CLEAN PORTFOLIO FOR LOAN-PERFORMANCE EVENT STUDY
*
* First pass:
*   Entry events: 2021-2023
*   Event window: +/- 6 months
*
* Therefore retain portfolio months:
*   2020m7 - 2024m6
*====================================================================*

cd "C:\Users\osheen.khare\OneDrive - Centre for Advanced Financial research and Le\Desktop\Fintech"

use ///
"C:\Users\osheen.khare\Dropbox\CIBIL 1 Percent\portfolio_duplicated.dta", ///
clear


*====================================================================*
* 1. KEEP ONLY VARIABLES NEEDED FOR EVENT STUDY
*====================================================================*

keep ///
    unique_id ///
    account_number ///
    acct_type ///
    portfolio_month ///
    product ///
    lender_name ///
    score_range ///
    payment_history ///
    balance ///
    owner_indic ///
    close_dt ///
    high_credit ///
    credit_limit ///
    suit_filed ///
    derog ///
    wo_settled ///
    wo_amt_total ///
    wo_amt_principal ///
    emi_amt_int ///
    actual_paymt


*====================================================================*
* 2. IDS
*====================================================================*

rename unique_id      person_id
rename account_number loan_ac_id

label var person_id  "Unique Person ID"
label var loan_ac_id "Unique Loan Account ID"


*====================================================================*
* 3. PORTFOLIO MONTH
*====================================================================*

gen ym = date(portfolio_month, "YMD")
gen mnth = mofd(ym)
format mnth %tm
drop ym portfolio_month
rename mnth portfolio_month

label var portfolio_month "Portfolio Month"


*------------------------------------------------------------*
* Restrict to months required for 2021-2023 event-study pass
*------------------------------------------------------------*

keep if inrange( ///
    portfolio_month, ///
    ym(2020,1), ///
    ym(2024,12) ///
)

tab portfolio_month



*====================================================================*
* 4. KEEP ONLY VARIABLES NEEDED
*====================================================================*

keep ///
    person_id ///
    loan_ac_id ///
    acct_type ///
    portfolio_month ///
    product ///
    lender_name ///
    payment_history ///
    balance ///
    close_dt ///
    suit_filed ///
    derog ///
    wo_settled ///
    wo_amt_total ///
    wo_amt_principal


*====================================================================*
* 5. PAYMENT HISTORY / DPD
*
* Main loan-performance variable.
*
* Categories from Portfolio_Issues.xlsx:
*
* A.0-STD
* B.1-29
* C.30-59
* D.60-89/SMA
* E.90-149/SUB
* F.150-179/DBT
* G.180-210/LSS
* H.211-359
* I.360-719
* J.720-900
* K.NA
*====================================================================*


*------------------------------------------------------------*
* Standardize strings
*------------------------------------------------------------*

replace payment_history = strtrim(payment_history)


*------------------------------------------------------------*
* Main delinquency indicators
* Missing/NA remains missing
*------------------------------------------------------------*

gen byte dpd_1plus = .
replace dpd_1plus = 0 if payment_history == "A.0-STD"
replace dpd_1plus = 1 if inlist(payment_history, ///
    "B.1-29", ///
    "C.30-59", ///
    "D.60-89/SMA", ///
    "E.90-149/SUB", ///
    "F.150-179/DBT", ///
    "G.180-210/LSS", ///
    "H.211-359", ///
    "I.360-719", ///
    "J.720-900")


gen byte dpd_30plus = .
replace dpd_30plus = 0 ///
    if inlist(payment_history, "A.0-STD", "B.1-29")

replace dpd_30plus = 1 ///
    if inlist(payment_history, ///
        "C.30-59", ///
        "D.60-89/SMA", ///
        "E.90-149/SUB", ///
        "F.150-179/DBT", ///
        "G.180-210/LSS", ///
        "H.211-359", ///
        "I.360-719", ///
        "J.720-900")


gen byte dpd_60plus = .
replace dpd_60plus = 0 ///
    if inlist(payment_history, ///
        "A.0-STD", ///
        "B.1-29", ///
        "C.30-59")

replace dpd_60plus = 1 ///
    if inlist(payment_history, ///
        "D.60-89/SMA", ///
        "E.90-149/SUB", ///
        "F.150-179/DBT", ///
        "G.180-210/LSS", ///
        "H.211-359", ///
        "I.360-719", ///
        "J.720-900")


*------------------------------------------------------------*
* MAIN DEFAULT OUTCOME: 90+ DPD
*------------------------------------------------------------*

gen byte dpd_90plus = .

replace dpd_90plus = 0 ///
    if inlist(payment_history, ///
        "A.0-STD", ///
        "B.1-29", ///
        "C.30-59", ///
        "D.60-89/SMA")

replace dpd_90plus = 1 ///
    if inlist(payment_history, ///
        "E.90-149/SUB", ///
        "F.150-179/DBT", ///
        "G.180-210/LSS", ///
        "H.211-359", ///
        "I.360-719", ///
        "J.720-900")


label var dpd_1plus  "Any DPD"
label var dpd_30plus "30+ DPD"
label var dpd_60plus "60+ DPD"
label var dpd_90plus "90+ DPD"


*------------------------------------------------------------*
* Verify
*------------------------------------------------------------*

tab payment_history dpd_90plus, missing
tab dpd_30plus, missing
tab dpd_60plus, missing
tab dpd_90plus, missing


*====================================================================*
* 6. DEROGATORY FLAG
*
* Excel shows:
*   0 = No derogatory
*   1 = Derogatory
*
* Well populated, so useful as secondary outcome.
*====================================================================*

capture confirm string variable derog

if !_rc {
    destring derog, replace force
}

replace derog = . if !inlist(derog,0,1)

label define derog_lbl ///
    0 "No derogatory" ///
    1 "Derogatory", replace

label values derog derog_lbl

label var derog "Derogatory account flag"

tab derog, missing


*====================================================================*
* 7. SUIT FILED
*
* Very incomplete (~88m missing observations), so keep only as
* secondary/descriptive outcome, NOT main default measure.
*====================================================================*

capture confirm string variable suit_filed

if !_rc {
    destring suit_filed, replace force
}

gen byte any_suit_filed = .
replace any_suit_filed = 0 if suit_filed == 0
replace any_suit_filed = 1 if inlist(suit_filed,1,2,3)

label var any_suit_filed "Any suit filed status"

tab suit_filed any_suit_filed, missing


*====================================================================*
* 8. WRITE-OFF / SETTLED STATUS
*
* 96% missing in the full portfolio.
* Retain but do not use as the baseline outcome.
*====================================================================*

capture confirm string variable wo_settled

if !_rc {
    destring wo_settled, replace force
}


*------------------------------------------------------------*
* Written-off type status
*------------------------------------------------------------*

gen byte written_off_status = .

replace written_off_status = 0 ///
    if !missing(wo_settled)

replace written_off_status = 1 ///
    if inlist(wo_settled, ///
        2, /// Written off
        4, /// Post WO settled
        6, /// Written off and account sold
        8, /// Account purchased and written off
        13) // Post write-off closed

label var written_off_status ///
    "Written-off status among reported WO statuses"


*====================================================================*
* 9. WRITE-OFF AMOUNTS
*
* Approximately 98% unavailable.
* Clean sentinel -1, but do not use as primary outcomes.
*====================================================================*

foreach var in wo_amt_total wo_amt_principal {

    capture confirm string variable `var'

    if !_rc {
        destring `var', replace force
    }

    replace `var' = . if `var' == -1
}

label var wo_amt_total ///
    "Total write-off amount"

label var wo_amt_principal ///
    "Principal write-off amount"


*====================================================================*
* 10. BALANCE
*
* IMPORTANT:
* Do NOT delete all negative balances.
*
* The diagnostics show ~1.36m non--1 negative balances and ~80%
* of negative balances are credit-card observations. These can reflect
* credit balances and should not automatically be treated as missing.
*====================================================================*

capture confirm string variable balance

if !_rc {
    destring balance, replace force
}

* Only known sentinel
replace balance = . if balance == -1

label var balance "Outstanding balance"

gen byte positive_balance = ///
    balance > 0 & !missing(balance)

label var positive_balance ///
    "Positive outstanding balance"


*====================================================================*
* 11. CLOSING DATE
*
* January 1900 is a placeholder and should be treated as missing.
*====================================================================*

gen double closing_date = date(close_dt,"YMD")
format closing_date %td
gen closing_month = mofd(closing_date)
format closing_month %tm

replace closing_month = . ///
    if closing_month == tm(1900m1)

label var closing_month "Account closing month"


*====================================================================*
* 12. CLEAN PRODUCT VARIABLE
*====================================================================*

rename acct_type product_type

label var product_type "Product sub-category"
label var product      "Broad product category"


*====================================================================*
* 13. BASIC QUALITY CHECKS
*====================================================================*

tab payment_history, missing

summ ///
    dpd_1plus ///
    dpd_30plus ///
    dpd_60plus ///
    dpd_90plus ///
    derog ///
    any_suit_filed


* Loan-account x reporting-period duplicates
duplicates report ///
    person_id loan_ac_id portfolio_month

duplicates report ///
    person_id loan_ac_id lender_name product portfolio_month
	
* --- Lender group ---
gen lender_group = ""
replace lender_group = regexs(1) if regexm(lender_name, "([A-Za-z-]+)")
label var lender_group "Lender Group"

compress

save ///
    "04_temp\portfolio_performance_clean.dta", ///
    replace