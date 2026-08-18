*============================================================*
* THRESHOLD DEFINITIONS USING BALANCED ENTRY PANEL
*============================================================*

cd "C:\Users\osheen.khare\OneDrive - Centre for Advanced Financial research and Le\Desktop\Fintech"

use "04_temp\balanced_entry_panel.dta", clear

* Basic checks
isid lender_id pincode month
assert months_since_entry >= 0
