*============================================================*
* CONSTRUCT BORROWER x ACCOUNT ORIGINATION LOOKUP
*============================================================*

cd "C:\Users\osheen.khare\OneDrive - Centre for Advanced Financial research and Le\Desktop\Fintech"

use "03_raw\originations_cleaned.dta", clear


*------------------------------------------------------------*
* 1. Origination month consistency
*------------------------------------------------------------*

bys person_id loan_ac_id: ///
    egen min_orig_month = min(month)

bys person_id loan_ac_id: ///
    egen max_orig_month = max(month)

gen byte same_orig_month = ///
    min_orig_month == max_orig_month ///
    & !missing(min_orig_month)


*------------------------------------------------------------*
* 2. Pincode consistency
*------------------------------------------------------------*

bys person_id loan_ac_id: ///
    egen min_pincode = min(pincode)

bys person_id loan_ac_id: ///
    egen max_pincode = max(pincode)

gen byte same_pincode = ///
    min_pincode == max_pincode ///
    & !missing(min_pincode)


*------------------------------------------------------------*
* 3. Diagnostics at borrower-account level
*------------------------------------------------------------*

egen byte tag_account = ///
    tag(person_id loan_ac_id)

tab same_orig_month if tag_account, missing
tab same_pincode if tag_account, missing

count if tag_account ///
    & same_orig_month == 1 ///
    & same_pincode == 1

count if tag_account ///
    & same_orig_month == 0

count if tag_account ///
    & same_pincode == 0


*------------------------------------------------------------*
* 4. Keep unambiguous accounts
*------------------------------------------------------------*

keep if same_orig_month == 1 ///
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

save ///
    "04_temp\account_origination_lookup.dta", ///
    replace


*============================================================*
* ADD ORIGINATION INFORMATION TO PORTFOLIO PERFORMANCE
*============================================================*

use ///
    "04_temp\portfolio_performance_clean.dta", ///
    clear


*------------------------------------------------------------*
* Collapse to intended loan-month level
*------------------------------------------------------------*

gcollapse ///
    (max) dpd_30plus ///
          dpd_60plus ///
          dpd_90plus ///
          derog ///
          suit_filed ///
    (max) balance ///
    (firstnm) closing_month, ///
    by( ///
        person_id ///
        loan_ac_id ///
        lender_name ///
        product ///
        portfolio_month ///
    )


*------------------------------------------------------------*
* Check uniqueness
*------------------------------------------------------------*

isid ///
    person_id ///
    loan_ac_id ///
    lender_name ///
    product ///
    portfolio_month


*------------------------------------------------------------*
* Merge account origination information
*------------------------------------------------------------*

merge m:1 person_id loan_ac_id using ///
    "04_temp\account_origination_lookup.dta"

keep if _merge == 3
drop _merge


*------------------------------------------------------------*
* Construct loan age at each portfolio observation
* Only for diagnostics / validity checks here
*------------------------------------------------------------*

gen loan_age_months = ///
    portfolio_month - origination_month

label var loan_age_months ///
    "Months since loan origination"


*------------------------------------------------------------*
* Sanity checks
*------------------------------------------------------------*

summ loan_age_months, detail

count if loan_age_months < 0
count if loan_age_months == 0

tab loan_age_months ///
    if inrange(loan_age_months,-3,18)


*------------------------------------------------------------*
* Keep valid loan ages
*------------------------------------------------------------*

drop if loan_age_months < 0


*------------------------------------------------------------*
* Final checks
*------------------------------------------------------------*

summ loan_age_months

summ ///
    dpd_30plus ///
    dpd_60plus ///
    dpd_90plus ///
    derog


*------------------------------------------------------------*
* Save portfolio panel with origination information
*------------------------------------------------------------*

compress

save ///
    "04_temp\portfolio_performance_6_12m.dta", ///
    replace