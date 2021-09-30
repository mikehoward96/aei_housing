/*********** Geographic concentration of FHA loans **********/	
/************** Public Records ************/

use geoid cbsa_short FIPS loan_type SaleAmt year month FirstMtgAmt price LandUseCode ltv weight_sales_all avm_201812 ///
using "X:\tobias\intermed data\cleaned_2012_weighted.dta", clear
	
	gen ct4 = substr(geoid, 1, 9) // 4-digit census tract
	
	*filters
	keep if inlist(LandUseCode, "1000", "1001", "1002", "1003", "1004", "1005")
	keep if inrange(price, 1000, 5000000)
	keep if inrange(ltv, 20, 120)
	*drop if inlist(year, 2018, 2019) // not in HMDA
	
*merging on list of selected county-years from HMDA
	merge m:1 FIPS year using "W:\Interns\Mike\Loan Limits project\intermed data\sample_list.dta"
	keep if _merge == 3
	drop _merge
	
*reapplying filters to see how many observations are lost
	merge m:1 FIPS year using "W:\Interns\Mike\Loan Limits project\intermed data\fha_gse_limits_v2.dta"
			keep if _merge == 3
			drop _merge
	
		*only keeping counties and years with an upward change in FHA limit. GSE_D included in case we want to look at GSEs in the future
		keep if FHA_D > 1500 & FHA_D != .
		gen same_cll = (FHAlimit == GSElimit) // dummy for FHA CLL == GSE CLL
	
		replace FHA_D = round(FHA_D/0.982, 100)
		replace FHAlimit = round(FHAlimit/0.982, 100)
		replace prev_FHAlimit = round(prev_FHAlimit/0.982, 100)
		replace next_FHAlimit = round(next_FHAlimit/0.982, 100)
	
		gen group = .
			replace group = 1 if ((prev_FHAlimit-(6*FHA_D)) < SaleAmt & SaleAmt <= (prev_FHAlimit-(5*FHA_D)))
			replace group = 2 if ((prev_FHAlimit-(5*FHA_D)) < SaleAmt & SaleAmt <= (prev_FHAlimit-(4*FHA_D)))
			replace group = 3 if ((prev_FHAlimit-(4*FHA_D)) < SaleAmt & SaleAmt <= (prev_FHAlimit-(3*FHA_D)))
			replace group = 4 if ((prev_FHAlimit-(3*FHA_D)) < SaleAmt & SaleAmt <= (prev_FHAlimit-(2*FHA_D)))
			replace group = 5 if ((prev_FHAlimit-(2*FHA_D)) < SaleAmt & SaleAmt <= (prev_FHAlimit-FHA_D))
			replace group = 6 if ((prev_FHAlimit-FHA_D) < SaleAmt & SaleAmt <= prev_FHAlimit) 					// treatment 1
			replace group = 7 if (prev_FHAlimit < SaleAmt & SaleAmt <= FHAlimit) 								// treatment 2
			replace group = 8 if (FHAlimit < SaleAmt & SaleAmt <= (FHAlimit+FHA_D))								// treatment 3
			replace group = 9 if ((FHAlimit+FHA_D) < SaleAmt & SaleAmt <= (FHAlimit+(2*FHA_D)))
			replace group = 10 if ((FHAlimit+(2*FHA_D)) < SaleAmt & SaleAmt <= (FHAlimit+(3*FHA_D)))
			replace group = 11 if ((FHAlimit+(3*FHA_D)) < SaleAmt & SaleAmt <= (FHAlimit+(4*FHA_D)))
			replace group = 12 if ((FHAlimit+(4*FHA_D)) < SaleAmt & SaleAmt <= (FHAlimit+(5*FHA_D)))
		
			drop if group == .
			
	*Checking for FHA bunching using PR. 
	rename loan_type type
	
	*Question: should the line below stay in?
	*replace group = 7 if (type == "FHA" & group == 8) // FHA loans just over the limit are hard-coded to group 7
	
		*FHA share for county-year
		gen fha = type == "FHA" // for checking total FHA share
		bys ct4 year: egen fha_sh_all = mean(fha)
	
		*FHA share in each price bin
		bys ct4 year group: egen fha_sh_bin = mean(fha)

	*bunching criteria is based on: Total counts, FHA share of groups 1-7, FHA share of groups 6 and 7
		*counts for full county and full county-year
		by ct4 year: egen year_count = count(group)
		by ct4: egen total_count = count(group)
		
	*total share_FHA defined above, but share of bins 1-7 is the relevant measure
				gen all_1_7 = inrange(group, 1, 7)
				gen fha_1_7 = inrange(group, 1, 7) & fha == 1
				
				by ct4 year: egen total_all_1_7 = sum(all_1_7)
				by ct4 year: egen total_fha_1_7 = sum(fha_1_7)
				drop all_1_7 fha_1_7
			
		gen fha_sh_1_7 = (total_fha_1_7/total_all_1_7) // FHA share of groups 1-7
		
	*bunching defined as being in groups 6 or 7
			gen fha_6_7 = .
				replace fha_6_7 = 1 if (inlist(group, 6, 7) & fha == 1)
				replace fha_6_7 = 0 if (inlist(group, 6, 7) & fha == 0) // of bunched loans, what % are FHA
		by ct4 year: egen fha_sh_6_7 = mean(fha_6_7)
	
	
	*criteria (TBD)
	xtile terc_6_7 = fha_sh_6_7, n(3)
	xtile terc_1_7 = fha_sh_1_7, n(3)
	
	drop in_sample
	gen in_sample = (inlist(terc_6_7, 3) & inlist(terc_1_7, 3))
	
	save "W:\Interns\Mike\Loan Limits project\intermed data\cll_censustract_pr.dta", replace
	
	collapse (sum) in_sample, by(ct4)
	drop if in_sample == 0
	duplicates drop ct4, force
	replace in_sample = 1
	drop if ct4 == ""
	save "W:\Interns\Mike\Loan Limits project\intermed data\sample_censustracts.dta", replace //list of census tracts to use


*prepping data for regression
use geoid cbsa_short FIPS loan_type SaleAmt year month FirstMtgAmt price LandUseCode ltv weight_sales_all avm_201812 ///
using "X:\tobias\intermed data\cleaned_2012_weighted.dta", clear
	
	gen ct4 = substr(geoid, 1, 9) // 4-digit census tract
	
	*filters
		keep if inlist(LandUseCode, "1000", "1001", "1002", "1003", "1004", "1005")
		keep if inrange(price, 1000, 5000000)
		keep if inrange(ltv, 20, 120)	
	*merging on list of selected counties from prior analysis
		merge m:1 ct4 using "W:\Interns\Mike\Loan Limits project\intermed data\sample_censustracts.dta"
		keep if _merge == 3
		drop _merge	
	*reapplying filters to see how many observations are lost
		merge m:1 FIPS year using "W:\Interns\Mike\Loan Limits project\intermed data\fha_gse_limits_v2.dta"
		keep if _merge == 3
		drop _merge
		
save "W:\Interns\Mike\Loan Limits project\intermed data\sample_merged_ct.dta", replace



/************ Regression Analysis ***************/
*regressions of year pairs
use "W:\Interns\Mike\Loan Limits project\intermed data\sample_merged_ct.dta", clear
gen fha = loan_type == "FHA"
*year pair: yr1 & yr2
local yr1 = 2015 //pick a year
local yr2 = `yr1' + 1

	keep if inlist(year, `yr1', `yr2')
	gen current = year == `yr2'
	
	*shifting limits based on LTV assumption
		replace FHA_D = round(FHA_D/0.982, 100)
		replace FHAlimit = round(FHAlimit/0.982, 100)
		replace prev_FHAlimit = round(prev_FHAlimit/0.982, 100)
		replace next_FHAlimit = round(next_FHAlimit/0.982, 100)
	
		*replacing t-1 CLL characteristics with t characteristics so that t-1 loans are binned properly
		replace FHA_D = next_FHAlimit - FHAlimit if current == 0 // a t-1 loan's delta should be next year's delta
		replace prev_FHAlimit = FHAlimit if current == 0 // a t-1 loan's previous limit should be its year's limit
		replace FHAlimit = next_FHAlimit if current == 0 // a t-1 loan's limit should be next year's

	*price bins
		gen group = .
			replace group = 1 if ((prev_FHAlimit-(6*FHA_D)) < SaleAmt & SaleAmt <= (prev_FHAlimit-(5*FHA_D)))
			replace group = 2 if ((prev_FHAlimit-(5*FHA_D)) < SaleAmt & SaleAmt <= (prev_FHAlimit-(4*FHA_D)))
			replace group = 3 if ((prev_FHAlimit-(4*FHA_D)) < SaleAmt & SaleAmt <= (prev_FHAlimit-(3*FHA_D)))
			replace group = 4 if ((prev_FHAlimit-(3*FHA_D)) < SaleAmt & SaleAmt <= (prev_FHAlimit-(2*FHA_D)))
			replace group = 5 if ((prev_FHAlimit-(2*FHA_D)) < SaleAmt & SaleAmt <= (prev_FHAlimit-FHA_D))
			replace group = 6 if ((prev_FHAlimit-FHA_D) < SaleAmt & SaleAmt <= prev_FHAlimit) 					// treatment 1
			replace group = 7 if (prev_FHAlimit < SaleAmt & SaleAmt <= FHAlimit) 								// treatment 2
			replace group = 8 if (FHAlimit < SaleAmt & SaleAmt <= (FHAlimit+FHA_D))								// treatment 3
			replace group = 9 if ((FHAlimit+FHA_D) < SaleAmt & SaleAmt <= (FHAlimit+(2*FHA_D)))
			replace group = 10 if ((FHAlimit+(2*FHA_D)) < SaleAmt & SaleAmt <= (FHAlimit+(3*FHA_D)))
			replace group = 11 if ((FHAlimit+(3*FHA_D)) < SaleAmt & SaleAmt <= (FHAlimit+(4*FHA_D)))
			replace group = 12 if ((FHAlimit+(4*FHA_D)) < SaleAmt & SaleAmt <= (FHAlimit+(5*FHA_D)))
		
			drop if group == .
	
	*generating other controls
		encode FIPS, gen(FIPS_e)
		gen ln_SaleAmt = ln(SaleAmt)
		gen ln_avm_201812 = ln(avm_201812)
	
*regression model
	areg ln_SaleAmt i.year i.group i.group#current ln_avm_201812 i.month [pweight = weight_sales_all], a(FIPS_e)
	table group year fha
