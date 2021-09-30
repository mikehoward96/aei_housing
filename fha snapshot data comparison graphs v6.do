*by state instead of county
*Snapshot
use Purpose OrigYear_est PropertyState if Purpose == "Purchase" using "Q:\NHMI\HUD_FHA\Intermediate\FHA_StockData.dta", clear
		gen count_ = 1
		
		expand 2, gen(n)
		replace PropertyState = "Nation" if n == 1
		
		rename (OrigYear_est PropertyState) (year state)
	
	gcollapse (count) snap_fha = count, by(year state)
	
	
		drop if state == ""
	fillin state year
		drop _fillin
			
save "W:\Mike\Optimal Blue\OB Data\fha_stock_state.dta", replace

*HMDA
use loan_amount activity_year state_code county_code derived_dwelling_category conforming_loan_limit action_taken loan_type loan_purpose using "M:\ICHR\HMDA\Data\LAR files\HMDA_LAR_2019.dta", clear
append using "M:\ICHR\HMDA\Data\LAR files\HMDA_LAR_2018.dta", keep(loan_amount activity_year state_code county_code derived_dwelling_category conforming_loan_limit action_taken loan_type loan_purpose)
append using "M:\ICHR\HMDA\Data\LAR files\HMDA_LAR_2020_limited.dta", force keep(loan_amount activity_year state_code county_code action_taken loan_type loan_purpose)
keep loan_amount activity_year state_code county_code derived_dwelling_category conforming_loan_limit action_taken loan_type loan_purpose

	*filter and gen conforming and nonconforming, keep total conv
	keep if action_taken == 1 & loan_purpose == 1 & ///
	(inlist(derived_dwelling_category, "Single Family (1-4 Units):Site-Built", "Single Family (1-4 Units):Manufactured") ///
	| inlist(activity_year, 2020))
	drop if conforming_loan_limit == "U"
	
	*merging on 2020 limits
		rename (activity_year county_code) (Year Fips)
		gen Month = 6
			gen Lien = 1 
			gen Units = 1
		
			merge m:1 Year Fips Month Lien Units using "Q:\Housing Center Files\Mergable Data\DR_GSELoanLimits_07-21_FipsYearUnitsLienLimit", keepusing(Limit) keep(3)
	
		rename (Year Fips) (activity_year county_code)
		
	expand 2 if loan_type == 1, gen(conv)
	
	
	gen round_limit = 10000*(floor(Limit/10000))+5000 //conforming to HMDA rounding
	
	replace conforming_loan_limit  = "NC" if inlist(activity_year, 2020) & loan_amount > round_limit
	replace conforming_loan_limit  = "C" if inlist(activity_year, 2020) & loan_amount <= round_limit
	
	gen loantype = ""
		replace loantype = "conv" if conv == 1
		replace loantype = "conf" if loan_type == 1 & conforming_loan_limit == "C" & loantype == ""
		replace loantype = "nonconf" if loan_type == 1 & conforming_loan_limit == "NC" & loantype == ""
		replace loantype = "fha" if loan_type == 2
		replace loantype = "va" if loan_type == 3
		replace loantype = "rhs" if loan_type == 4
	
	*drop if loantype == "" //no 2020 conf and nonconf
		
	expand 2, gen(nation)
	replace state_code = "Nation" if nation == 1
	
	rename state_code state
		
	gcollapse  (sum) count = action_taken, by(state activity_year loantype)
	
	rename (count activity_year) (count_ year)
	
	reshape wide count_, i(state year) j(loantype) string
	sort state year
	bys state: drop if _N != 3
	
	
	save "W:\Mike\Optimal Blue\OB Data\hmda_18-20_counts_state.dta", replace

use AsOfYr LoanType LoanPurpose ActionType Occupancy State_cd County_cd LoanAmount PropertyType using "M:\ICHR\HMDA\Data\LAR files\HMDA_LAR_2017.dta", clear

	merge m:1 State_cd using "W:\Mike\Crosswalks\State_cd_state.dta", keep(3) nogen

	keep if ActionType == 1 & LoanPurpose == 1 & inlist(PropertyType, 1, 2)
	gen FIPS = State_cd+County_cd
	rename AsOfYr year
	
	merge m:1 year FIPS using "W:\Mike\Loan Limits project\intermed data\fha_gse_limits_v2.dta", keep(3) keepusing(GSElimit) nogen
	
	expand 2 if LoanType == 1, gen(conv)
	gen loantype = ""
		replace loantype = "conv" if conv == 1
		replace loantype = "conf" if LoanType == 1 & (LoanAmount*1000 <= GSElimit) & loantype == ""
		replace loantype = "nonconf" if LoanType == 1 & (LoanAmount*1000 > GSElimit) & loantype == ""
		replace loantype = "fha" if LoanType == 2
		replace loantype = "va" if LoanType == 3
		replace loantype = "rhs" if LoanType == 4
		
	expand 2, gen(nation)
	replace state = "Nation" if nation == 1
		
	gcollapse  (sum) count = ActionType, by(state year loantype)	
	
	
	rename count count_
	
	reshape wide count_, i(state year) j(loantype) string
	sort state year
	
	append using "W:\Mike\Optimal Blue\OB Data\hmda_18-20_counts_state.dta"
		rename (count_conv count_conf count_nonconf count_fha count_rhs count_va) (hmda_conv hmda_conf hmda_nonconf hmda_fha hmda_rhs hmda_va)

		
		
	save "W:\Mike\Optimal Blue\OB Data\hmda_17-20_counts_state.dta", replace

*Optimal Blue
use purpose FIPS state year month ppeinitiallockdate loantype if purpose == "p" using "W:\Optimal Blue\source data\Historical\OptimalBlue_FullDataset", clear
			
			keep if inlist(loantype, "Conforming", "NonConforming", "FHA", "USDA", "VA")
			
			*limiting sample to vetern lenders
			gen orig = ym(real(year), real(month))	
			gen lock_year = real(substr(ppe, 4, 4))
			gen lock_month = real(substr(ppe, 1, 2))

			gen lock_orig = ym(lock_year, lock_month)
			
		keep if lock_orig <= 696 | orig < 696
			
			
		destring year, replace
				*one month lag (only need to get the year right, since we collapse by year)
				replace year = year + 1 if month == "12"
		gen count_ = 1

		expand 2 if inlist(loantype, "Conforming", "NonConforming"), gen(conv)
		replace loantype = "Conv" if conv == 1
			
		
		expand 2, gen(n)
		replace state = "Nation" if n == 1
		
	gcollapse (count) count, by(state year loantype)
		
		drop if state == ""
	
	reshape wide count, i(state year) j(loantype) string
	fillin state year
	
		foreach v in "Conforming" "Conv" "FHA" "NonConforming" "VA" "USDA" {
		rename count_`v' ob_`v'
		}
			
		drop _fillin
		
		rename (ob_Conv ob_Conforming ob_NonConforming ob_FHA ob_USDA ob_VA) (ob_conv ob_conf ob_nonconf ob_fha ob_rhs ob_va)
		
		
save "W:\Mike\Optimal Blue\OB Data\ob_limited_state.dta", replace


	
use "W:\Mike\Optimal Blue\OB Data\hmda_17-20_counts_state.dta", clear	
*Merging all three datasets
	merge 1:1 year state using "W:\Mike\Optimal Blue\OB Data\ob_limited_state.dta", keep(3) nogen
	merge 1:1 year state using "W:\Mike\Optimal Blue\OB Data\fha_stock_state.dta", keep(3) nogen
	
	bys state: keep if _N == 4
	
	
save "W:\Mike\Optimal Blue\OB Data\hmda_ob_snpashot_v3.dta", replace


use "W:\Mike\Optimal Blue\OB Data\hmda_ob_snpashot_v3.dta", clear


	sort state year
	
		foreach t in "conf" "conv" "nonconf" "fha" "va" "rhs" {
			replace ob_`t' = 0 if ob_`t' == .
			replace hmda_`t' = 0 if hmda_`t' == .
		}
		

		foreach d in "ob" "hmda" {
		gen `d'_total = `d'_conv +`d'_fha + `d'_va + `d'_rhs
		}
				
		
		foreach t in "conf" "conv" "nonconf" "fha" "va" "rhs" "total" {
			by state: gen hmda_yoy_`t' = (hmda_`t'/hmda_`t'[_n-1])-1
			by state: gen ob_yoy_`t' = (ob_`t'/ob_`t'[_n-1]) -1
				replace hmda_yoy_`t' = 0 if hmda_yoy_`t' == .
				replace ob_yoy_`t' = 0 if ob_yoy_`t' == .

			gen hmda_share_`t' = (hmda_`t'/hmda_total)
			replace hmda_share_`t' = 0 if hmda_share_`t' == .
		}
			
			drop if year == 2017
		
		
		
		*weighted yoy change based on HMDA loan type shares
		gen obw_yoy_total = (hmda_share_conv*ob_yoy_conv)+(hmda_share_fha*ob_yoy_fha)+(hmda_share_va*ob_yoy_va)+(hmda_share_rhs*ob_yoy_rhs)

	
*Charts	
	reg hmda_yoy_total obw_yoy_total if year == 2020
	local r = e(r2)
	local r2 = round(`r', 0.001)
	twoway scatter hmda_yoy_total obw_yoy_total if year == 2020, xtitle("OB Limited Total") ytitle("HMDA Total") ///
		title("Y-o-Y Change in Purchase Loan Volume: 2020") subtitle("Each dot represents 1 state") ///
		note("R-sq = `r2'. OB is limited to lenders who have been in the sample since Jan. 2018 or earlier.", size(small)) ///
		|| lfit hmda_yoy_total obw_yoy_total if year == 2020, legend(off)
	
	reg hmda_yoy_total obw_yoy_total if year == 2019
	local r = e(r2)
	local r2 = round(`r', 0.001)
	twoway scatter hmda_yoy_total obw_yoy_total if year == 2019 & ob_yoy_total < 2, xtitle("OB Limited Total") ytitle("HMDA Total") ///
		title("Y-o-Y Change in Purchase Loan Volume: 2019") subtitle("Each dot represents 1 state") ///
		note("R-sq = `r2'. OB is limited to lenders who have been in the sample since Jan. 2018 or earlier.", size(small)) ///
		|| lfit hmda_yoy_total obw_yoy_total if year == 2019, legend(off)
		
	reg hmda_yoy_total obw_yoy_total if year == 2018
	local r = e(r2)
	local r2 = round(`r', 0.001)
	twoway scatter hmda_yoy_total obw_yoy_total if year == 2018 & ob_yoy_total < 2, xtitle("OB Limited Total") ytitle("HMDA Total") ///
		title("Y-o-Y Change in Purchase Loan Volume: 2018") subtitle("Each dot represents 1 state") ///
		note("R-sq = `r2'. OB is limited to lenders who have been in the sample since Jan. 2018 or earlier.", size(small)) ///
		|| lfit hmda_yoy_total obw_yoy_total if year == 2018, legend(off)

	
	
	