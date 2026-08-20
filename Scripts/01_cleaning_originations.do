cd "C:\Users\osheen.khare\OneDrive - Centre for Advanced Financial research and Le\Desktop\Fintech"

import delimited using "03_raw\origination_consumer_new.csv", clear


* --- Product group ---
rename product product_group
label var product_group "Broad Product Categories"


* LOAN CHARACTERISTICS
* --- Date: origination month ---
gen ym = date(origin_month, "YMD")
gen mnth = mofd(ym)
format mnth %tm
drop ym origin_month
rename mnth month
label var month "Origination Month"

gen year = yofd(dofm(month))
label var year "Origination Year"

* --- Lender group ---
gen lender_group = ""
replace lender_group = regexs(1) if regexm(lender_cat, "([A-Za-z-]+)")
label var lender_group "Lender Group"

* --- Payment frequency ---
destring paymt_freq, replace
label define paymt_freq_lbl       ///
    1 "Weekly"          2 "Fortnightly"    3 "Monthly"  ///
    4 "Quarterly"       5 "Bullet Payment" 6 "Daily"    ///
    7 "Half Yearly"     8 "Yearly"         9 "On Demand"
label values paymt_freq paymt_freq_lbl
label var paymt_freq "Payment Frequency"

* --- Repayment tenure ---
label var repay_tenure "Repayment Tenure in Months"
// replace repay_tenure = . if inlist(repay_tenure, -1, 0, 999)
// replace repay_tenure = . if repay_tenure > 480

* --- Sanctioned Amount ---
destring sanctioned_amount, replace
replace sanctioned_amount = . if sanctioned_amount <= 0
label var sanctioned_amount "Amount Sanctioned at Account Opening"

* --- EMI Amount ---
destring emi_amt_int, replace
replace emi_amt_int = . if emi_amt_int <= 0

gen emi_gt_sanctioned = ///
    emi_amt_int > sanctioned_amount ///
    if !missing(emi_amt_int, sanctioned_amount)

label var emi_amt_int "EMI Amount Installment"
label var emi_gt_sanctioned "EMI Exceeds Sanctioned Amount"

* --- Interest Rate ---
destring int_rate, replace
replace int_rate = . if int_rate == -1
label var int_rate "Interest Rate"
// replace int_rate = . if int_rate <= 0 | int_rate > 100

* --- Collateral ---
label define collateral_lbl             ///
    0 "No Collateral" 1 "Property"      ///
    2 "Gold"          3 "Shares"        ///
    4 "Savings AC & FD" 5 "Multiple Securities" 6 "Others"
rename collataral_type collateral_type
label values collateral_type collateral_lbl
label var collateral_type "Collateral Type"

rename collataral_value collateral_value
destring collateral_value, replace
replace collateral_value = 0 if collateral_type == 0
replace collateral_value = . if collateral_value == -1
label var collateral_value "Collateral Value"

gen collateral_below_sanctioned = ///
    collateral_value < sanctioned_amount ///
    if collateral_value > 0 & sanctioned_amount > 0
label var collateral_below_sanctioned ///
    "Collateral Value Below Sanctioned Amount"


* DEMOGRAPHIC INDICATORS
* --- Gender ---
replace gender = "0" if gender == "MALE"
replace gender = "1" if gender == "FEMALE"
replace gender = "2" if gender == "OTHER"
destring gender, replace
label define gender_lbl 0 "Male" 1 "Female" 2 "Others"
label values gender gender_lbl
label var gender "Gender"

* --- Age ---
destring age, replace

gen byte invalid_age = !missing(age) & age == -6 & (age < 18 | age > 100)
// replace age = . if invalid_age == 1
						   
label var age "Age"

* --- Occupation ---
replace occupation = upper(strtrim(occupation))
label var occupation "Occupation"

* --- Score band (as per CIBIL definition) ---
replace score_range = -1 if missing(score_range)

gen score_band = ""
replace score_band = "1.SubPrime"    if score_range >  -1 & score_range <= 680
replace score_band = "2.NearPrime"   if score_range >= 681 & score_range <= 730
replace score_band = "3.Prime"       if score_range >= 731 & score_range <= 770
replace score_band = "4.PrimePlus"   if score_range >= 771 & score_range <= 790
replace score_band = "5.SuperPrime"  if score_range >= 791
replace score_band = "6.NewToCredit" if score_range == -1 

label var score_range "CIBIL Score"
label var score_band  "CIBIL Score Band"

* GEOGRAPHICAL INDICATORS
* --- Pincode ---
replace pincode = "" if pincode == "OTHERS"
destring pincode, replace
label var pincode "Pincode"

* --- State and Tier ---
replace state = "" if upper(strtrim(state)) == "OTHERS"
replace tier  = "" if upper(strtrim(tier))  == "OTHERS"
label var state      "State"
label var tier       "Tier"

// * --- Consistent encoding and labels ---**
// naam encode occupation state tier product_group score_band lender_group ///
//     using "01_docs\cibil_1p_retail_labels.xlsx", replace 
//	
// * KEY IDENTIFIERS
// * --- IDs ---
rename unique_id person_id
// naam id person_id using "01_docs\cibil_1p_retail", replace
label var person_id "Unique Person as per CIBIL"
//
rename account_number loan_ac_id
// naam id loan_ac_id using "01_docs\cibil_1p_retail", replace
label var loan_ac_id "Unique Loan Account as per CIBIL"
//
rename lender_cat lender_id
// naam id lender_id using "01_docs\cibil_1p_retail", replace
label var lender_id "Unique Lender ID"

* Number of records per borrower-account
bysort person_id loan_ac_id: gen n_records_loan = _N

* Number of lenders per borrower-account
bysort person_id loan_ac_id: egen n_lenders_loan = nvals(lender_id)

* Number of products per borrower-account
bysort person_id loan_ac_id: egen n_products_loan = nvals(product_group)

gen co_lent = n_lenders_loan > 1
gen product_split = n_products_loan > 1

label var n_records_loan  "Records per Borrower-Loan Account"
label var n_lenders_loan  "Lenders per Borrower-Loan Account"
label var n_products_loan "Products per Borrower-Loan Account"
label var co_lent         "Multiple Lenders on Loan Account"
label var product_split   "Multiple Products on Loan Account"

compress
