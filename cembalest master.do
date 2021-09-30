*Globals
global filepath "X:\HMI Summary Workbook\Do Files"
global Zillowdata "Q:\Tobias\FirstAm PR\Zillow data\AEI_sales-listings_nopending_2013-01-2020-02_alltiers"

global current_yr_m = 2020
global max_month_m = 0 // put in 0 for Dec
global ym = "2020m12"

global current_yr_q = 2020
global max_month_q = 0 // put in 0 for Dec
global yq = "2020q4"

global nr_metros = 100
global yr = 2020
global orig_m = 731
global orig = 244

global orig_mri = 731

**************

* National - Overall HPA
use year quarter orig ln_price ln_avm* weight_hpi tier cbsa_short market_area rank_* tier_* state_e using  "X:\tobias\intermed data\HPI_data_$yq.dta", clear

	replace cbsa_short = "AA National"

		reghdfe ln_price i.tier c.ln_avm_201812#i.tier i.state_e [pw=weight_hpi], a(hpa_cbsa_base = i.orig)
		
			bys orig: keep if _n == 1
			
			gen hpa_cbsa = exp((hpa_cbsa_base - hpa_cbsa_base[1])) * 100				
			
			tostring tier, replace
			replace tier = "all"

			keep orig cbsa_short tier hpa_cbsa rank_pr	
			replace rank_pr = 0
			
	save "X:\tobias\intermed data\hpi_nat_overall_$yq.dta", replace
	

* National - Entry level HPA
use year quarter orig ln_price ln_avm* weight_hpi tier cbsa_short market_area rank_* tier_* state_e using  "X:\tobias\intermed data\HPI_data_$yq.dta", clear

	replace cbsa_short = "AA National"
	keep if inlist(tier, 1, 2)

		reghdfe ln_price i.tier c.ln_avm_201812#i.tier i.state_e [pw=weight_hpi], a(hpa_cbsa_base = i.orig)
		
			bys orig: keep if _n == 1
			
			gen hpa_cbsa = exp((hpa_cbsa_base - hpa_cbsa_base[1])) * 100				
			
			tostring tier, replace
			replace tier = "entry"

			keep orig cbsa_short tier hpa_cbsa rank_pr	
			replace rank_pr = 0
			
	save "X:\tobias\intermed data\hpi_nat_entrylevel_$yq.dta", replace	


*Individual CBSAs - Overall HPA
use year quarter orig ln_price ln_avm* weight_hpi tier cbsa_short market_area rank_* tier_* state_e using  "X:\tobias\intermed data\HPI_data_$yq.dta", clear
*	keep if rank_pr <= $nr_metros                  
	keep if rank_pr <= 100

	bys cbsa_short: keep if _n == 1
                
	levelsof cbsa_short, local(levels)
	 foreach y of local levels {
		use if cbsa_short == "`y'" using "X:\tobias\intermed data\HPI_data_$yq.dta", clear

			reghdfe ln_price i.tier c.ln_avm_201812#i.tier i.state_e [pw=weight_hpi], a(hpa_cbsa_base = i.orig)

				bys orig: keep if _n == 1 
				
				gen hpa_cbsa = exp((hpa_cbsa_base - hpa_cbsa_base[1])) * 100				
				
				tostring tier, replace
				replace tier = "all"

				keep orig cbsa_short tier hpa_cbsa rank_pr	

			save "X:\tobias\intermed data\hpi_`y'_overall_$yq.dta", replace
}



*Individual CBSAs - Entry-level HPA
* CONFIRMED WITH TOBIAS  --> I can exclude all splicing because loan limit changes do not affect tiers 1 and 2
use year quarter orig ln_price ln_avm* weight_hpi tier cbsa_short market_area rank_* tier_* state_e using  "X:\tobias\intermed data\HPI_data_$yq.dta", clear
*	keep if rank_pr <= $nr_metros                  
	keep if rank_pr <= 100

	bys cbsa_short: keep if _n == 1
                
	levelsof cbsa_short, local(levels)
	 foreach y of local levels {
		use if cbsa_short == "`y'" using "X:\tobias\intermed data\HPI_data_$yq.dta", clear
			keep if inrange(tier, 1, 2)
			replace tier = 12
		
			reghdfe ln_price i.tier c.ln_avm_201812#i.tier i.state_e [pw=weight_hpi], a(hpa_cbsa_base = i.orig)

				bys orig: keep if _n == 1 
				
				gen hpa_cbsa = exp((hpa_cbsa_base - hpa_cbsa_base[1])) * 100				
				
				tostring tier, replace
				replace tier = "entry"

				keep orig cbsa_short tier hpa_cbsa rank_pr	

			save "X:\tobias\intermed data\hpi_`y'_entrylevel_$yq.dta", replace
}


****************************
* New construction top 100 metros
* Average new construction for 2012:Q1-2020:Q1

* New construction  - National Overall
use orig new_c weight* loan_type tier cbsa_short rank_pr using "X:\tobias\intermed data\cleaned_2012_weighted.dta", clear
	keep if orig <= $orig

	collapse (mean) new_c [pw=weight_sales_all]
	gen tier = "all"
	gen cbsa_short = "AA National"
	
	save "X:\tobias\intermed data\Newc_national_overall_cembalest_$yq.dta", replace	
	
	******
* New construction - National Entry level 
use orig new_c weight* loan_type tier cbsa_short rank_pr using "X:\tobias\intermed data\cleaned_2012_weighted.dta", clear
	keep if orig <= $orig

	replace tier = 12 if inlist(tier, 1, 2)
	replace tier = 34 if inlist(tier, 3, 4)

	collapse (mean) new_c [pw=weight_sales_all], by(tier)
	drop if tier ==. | tier == 34
	drop tier
	gen tier = "entry"
	gen cbsa_short = "AA National"
	
*	reshape wide new_c, i(cbsa_short orig) j(tier)
	save "X:\tobias\intermed data\Newc_national_entrylevel_cembalest_$yq.dta", replace	
	
	*************
	
* New construction by metro - Overall
use orig new_c weight* loan_type tier cbsa_short rank_pr using "X:\tobias\intermed data\cleaned_2012_weighted.dta", clear
	keep if rank_pr <= 100
	keep if orig <= $orig

	collapse (mean) new_c [pw=weight_sales_all], by(cbsa_short)
	gen tier = "all"
	
	save "X:\tobias\intermed data\Newc_100CBSAs_overall_cembalest_$yq.dta", replace	
	
	******
* New construction by metro - Entry level
use orig new_c weight* loan_type tier cbsa_short rank_pr using "X:\tobias\intermed data\cleaned_2012_weighted.dta", clear
	keep if rank_pr <= 100
	keep if orig <= $orig

	replace tier = 12 if inlist(tier, 1, 2)
	replace tier = 34 if inlist(tier, 3, 4)

	collapse (mean) new_c [pw=weight_sales_all], by(cbsa_short tier)
	drop if tier ==. | tier == 34
	drop tier
	gen tier = "entry"
	
*	reshape wide new_c, i(cbsa_short orig) j(tier)
	save "X:\tobias\intermed data\Newc_100CBSAs_entrylevel_cembalest_$yq.dta", replace	
	
	
**********************
* Load newc dataset simply to get 100 cbsa names for levels of
use "X:\tobias\intermed data\Newc_100CBSAs_overall_cembalest_$yq.dta", clear
	
* Append all HPA data, drop new_c data for now
	levelsof cbsa_short, local(levels)
	 foreach y of local levels {
		append using "X:\tobias\intermed data\hpi_`y'_overall_$yq.dta"
		append using "X:\tobias\intermed data\hpi_`y'_entrylevel_$yq.dta"
		}
		
		append using "X:\tobias\intermed data\hpi_nat_overall_$yq.dta"
		append using "X:\tobias\intermed data\hpi_nat_entrylevel_$yq.dta"
		
	keep if orig == 240
	drop new_c
	drop if cbsa_short == "Urban Honolulu, HI"
	
	
		* Merge on new construction data
		merge 1:1 cbsa_short tier using "X:\tobias\intermed data\Newc_100CBSAs_overall_cembalest_$yq.dta", keep(1 3) nogen 
		rename new_c new_c1
		merge 1:1 cbsa_short tier using "X:\tobias\intermed data\Newc_100CBSAs_entrylevel_cembalest_$yq.dta", keep(1 3) nogen
		rename new_c new_c2
		merge 1:1 cbsa_short tier using "X:\tobias\intermed data\Newc_national_overall_cembalest_$yq.dta", keep(1 3) nogen 
		rename new_c new_c3
		merge 1:1 cbsa_short tier using "X:\tobias\intermed data\Newc_national_entrylevel_cembalest_$yq.dta", keep(1 3) nogen 

		replace new_c = new_c1 if new_c ==.
		replace new_c = new_c2 if new_c ==.
		replace new_c = new_c3 if new_c ==.	
		drop new_c1 new_c2 new_c3
		
		*Boise fix
		replace cbsa_short = "Boise, ID" if cbsa_short == "Boise City, ID"
	
			* Merge on emplyment data
			*merge m:1 cbsa_short using "X:\tobias\analysis\HPA & Supply\Employment data\intermed data\employment growth.dta", keepusing(emp_index_1990_2017) keep(1 3) nogen  // OLD DATA (1990-2017)
			merge m:1 cbsa_short using "U:\Neil\Intermediate\BEA employment\BEA Employment data by cbsa 1990-2018.dta", keep(1 3) nogen keepusing(Emp_1990_2018)

			replace Emp_1990_2018 = 1.325 if cbsa_short == "AA National"  // This is the value we get if sum all counties in original xls file
			egen emp_group = cut(Emp_1990_2018), at(0,1.25,1.5,10)
			
			gen hpa_group_lt25 = hpa_cbsa if emp_group == 0
			gen hpa_group_25to50 = hpa_cbsa if emp_group == 1.25
			gen hpa_group_gt50 = hpa_cbsa if emp_group == 1.5
			
			sort tier Emp_1990_2018
			
			drop orig rank_pr hpa_cbsa emp_group
			order cbsa_short Emp_1990_2018 new_c hpa_group_lt25 hpa_group_25to50 hpa_group_gt50 tier			

					save "W:\Mike\Cembalest\land values\cembalest base.dta", replace
					
use "W:\Mike\Cembalest\land values\cembalest base.dta", clear
					
					replace cbsa_short = "Boise City, ID" if cbsa_short == "Boise, ID"
			
				merge m:1 cbsa_short using "U:\Neil\Workbooks\Misc\Ed's curated 76 metros.dta"
				keep if _merge == 3 | cbsa_short == "AA National" //| cbsa_short == "Boise, ID"
				gsort tier -_m Emp
				
				
				
				
*Begin Mike's part
*cbsa year landvalueperacreasis using "W:\Mike\Optimal Blue\OB Data\adj_land_values.dta"

keep if tier == "all" & hpa_group_gt50 != .
gen year = 2020
drop _merge

replace cbsa_short = "Boise, ID" if cbsa_short == "Boise City, ID"

merge m:1 cbsa_short using "W:\Mike\Crosswalks\cbsa_cbsa_short_cbsacode.dta", keep(3) nogen
destring cbsacode, replace
tostring cbsacode, replace
merge 1:1 cbsacode year using "X:\tobias\analysis\land shares\intermed data\land_cbsacode_2020.dta", keepusing(LV_asis_AEI) nogen keep(3)
rename LV_asis_AEI lv


keep cbsa_short new_c hpa_group_gt50 lv
sum lv //intervals of 400,000 divide these 30 roughly into thirds
rename hpa_group_gt50 hpa

gen hpa_low_lv = hpa if lv >= 189300 & lv < 400000
gen hpa_med_lv = hpa if lv >= 400000 & lv < 700000
gen hpa_high_lv = hpa if lv >= 700000 & lv <= 1421300

/*
gen hpa_low_lv = hpa if lv < 400000
gen hpa_med_lv = hpa if lv >= 400000 & lv < 800000
gen hpa_high_lv = hpa if lv >= 800000
*/

sort lv

save "W:\Mike\Optimal Blue\OB Data\cembalest1_$yq.dta", replace

	replace hpa_med_lv = hpa_low_lv if hpa_med_lv == . & hpa_high_lv == .
	*drop hpa_low_lv
	order cbsa_short hpa lv new_c hpa_med_lv hpa_high_lv
