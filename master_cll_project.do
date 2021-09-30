/*************** Master Do-file (v3) *******************/

/********************** HMDA *******************/
*Applying filters and merging CLLs

		forval y = 2012/2017 {
			append using "M:\ICHR\HMDA\Data\LAR files\HMDA_LAR_`y'.dta"
			}
		keep AsOfYr State_cd County_cd ActionType LoanType LoanPurpose PropertyType LoanAmount
		
		*filters and cleaning
			keep if inlist(ActionType,1)
			keep if inlist(LoanPurpose,1) 
			keep if PropertyType !=  3
			gen FIPS = (State_cd+County_cd)
			drop if FIPS == "NANA " | FIPS == "na" | FIPS == "NA" | FIPS == "78NA"
									
			keep FIPS AsOfYr LoanType LoanAmount
			rename AsOfYr year
						
			replace LoanAmount = 1000*LoanAmount
			drop if !inrange(LoanAmount, 1000, 5000000) // dropping outliers and amounts are not recorded in 1000s
				
			gen type = ""
				replace type = "Conv" if LoanType == 1 // Can be used as proxy for GSE
				replace type = "FHA" if LoanType == 2
				replace type = "Other" if type == ""
					
		save "W:\Interns\Mike\Loan Limits project\hmda 12-17 skinny.dta", replace		
				
*Selecting counties to include in final dataset
	*excluding non-disclosure states
		drop if substr(FIPS, 1, 2) == "02" // Alaska
		drop if substr(FIPS, 1, 2) == "16" // Idaho
		drop if substr(FIPS, 1, 2) == "20" // Kansas
		drop if substr(FIPS, 1, 2) == "22" // Louisiana
		drop if substr(FIPS, 1, 2) == "28" // Mississippi
		drop if substr(FIPS, 1, 2) == "29" // Missouri
		drop if substr(FIPS, 1, 2) == "30" // Montana
		drop if substr(FIPS, 1, 2) == "35" // New Mexico
		drop if substr(FIPS, 1, 2) == "38" // North Dakota
		drop if substr(FIPS, 1, 2) == "48" // Texas
		drop if substr(FIPS, 1, 2) == "49" // Utah
		drop if substr(FIPS, 1, 2) == "56" // Wyoming
		drop if substr(FIPS, 1, 2) == "72" // Puerto Rico
		
			drop if year == 2012 // no limits in CLL file	
		merge m:1 FIPS year using "W:\Interns\Mike\Loan Limits project\intermed data\fha_gse_limits_v2.dta"
			keep if _merge == 3
			drop _merge
	
	*********************************************************************************
	save "W:\Interns\Mike\Loan Limits project\intermed data\hmda_merged.dta", replace 
	*********************************************************************************
	
	*only keeping counties and years with a significant upward change in FHA limit. GSE_D included in case we want to do this with GSEs in the future
		keep if FHA_D > 1500 & FHA_D != . // Generate dummy instead?
		gen same_cll = (FHAlimit == GSElimit) // dummy for FHA CLL == GSE CLL
	
	*Converting loan amount and CLL to sale price (assuming LTVs) and designing price bins.
		gen SaleAmt = .
			replace SaleAmt = round(LoanAmount/0.982, 100) if type == "FHA"
			replace SaleAmt = round(LoanAmount/0.9, 100) if type == "Conv"
			replace SaleAmt = LoanAmount if type == "Other"
			
		replace FHA_D = round(FHA_D/0.982, 100)
		replace FHAlimit = round(FHAlimit/0.982, 100)
		replace prev_FHAlimit = round(prev_FHAlimit/0.982, 100)
		replace next_FHAlimit = round(next_FHAlimit/0.982, 100)
		*replace *GSE*

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
		
			drop if group == . //excluding loans too far on either side of CLL change.				

	***************************************************************************************
	save "W:\Interns\Mike\Loan Limits project\intermed data\cll_intermed_hmda.dta", replace
	***************************************************************************************	
	
*Checking for FHA bunching using HMDA. 
	replace group = 7 if (type == "FHA" & group == 8) // FHA loans just over the limit are hard-coded to group 7
	drop if group > 7 & type == "FHA" // cats and dogs, likely misrecorded 2-4 units
	
		*FHA share for county-year
		gen fha = type == "FHA" // for checking total FHA share
		bys FIPS year: egen fha_sh_all = mean(fha)
	
		*FHA share in each price bin
		bys FIPS year group: egen fha_sh_bin = mean(fha)

	*bunching criteria is based on: Total counts, FHA share of groups 1-7, FHA share of groups 6 and 7
		*counts for full county and full county-year
		by FIPS year: egen year_count = count(group)
		by FIPS: egen total_count = count(group)
		
	*total FHA share defined above, but share of bins 1-7 is the relevant measure
				gen all_1_7 = inrange(group, 1, 7)
				gen fha_1_7 = inrange(group, 1, 7) & fha == 1
				
				by FIPS year: egen total_all_1_7 = sum(all_1_7)
				by FIPS year: egen total_fha_1_7 = sum(fha_1_7)
				drop all_1_7 fha_1_7
			
		gen fha_share_1_7 = (total_fha_1_7/total_all_1_7) // FHA share of groups 1-7
		
	*bunching defined as being in groups 6 or 7
			gen fha_6_7 = .
				replace fha_6_7 = 1 if (inlist(group, 6, 7) & fha == 1)
				replace fha_6_7 = 0 if (inlist(group, 6, 7) & fha == 0) // of bunched loans, what % are FHA
		by FIPS year: egen fha_sh_6_7 = mean(fha_6_7)
	
	
	*criteria (TBD)
	gen high_bunching = fha_sh_6_7 > 0.15 //year-county specific
	gen high_fha_share = fha_share_1_7 > 0.2 //year-county specific
	gen high_year_count = year_count > 1000 // year-county specific
	gen high_total_count = total_count > 2000 // county-specific
		
	gen in_sample = (high_bunching*high_fha_share*high_year_count*high_total_count) 

	*saving list of sample county-years
	collapse (sum) in_sample, by(FIPS year)
	gsort - in_sample FIPS year
	drop if in_sample == 0
	gen source = "HMDA"
	save "W:\Interns\Mike\Loan Limits project\intermed data\sample_list.dta", replace
	
	
	
/************** Public Records ************/
*repeating analysis with PR to compare list of county-years.

use geoid cbsa_short FIPS loan_type SaleAmt year month FirstMtgAmt price LandUseCode ltv weight_sales_all avm_201812 ///
using "X:\tobias\intermed data\cleaned_2012_weighted.dta", clear
	
	*** December rule not fixed in this file ***
	
	*filters
	keep if inlist(LandUseCode, "1000", "1001", "1002", "1003", "1004", "1005")
	keep if inrange(price, 1000, 5000000)
	keep if inrange(ltv, 20, 120)
	drop if inlist(year, 2018, 2019) // not in HMDA
	
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
	replace group = 7 if (type == "FHA" & group == 8) // FHA loans just over the limit are hard-coded to group 7
	
		*FHA share for county-year
		gen fha = type == "FHA" // for checking total FHA share
		bys FIPS year: egen fha_sh_all = mean(fha)
	
		*FHA share in each price bin
		bys FIPS year group: egen fha_sh_bin = mean(fha)

	*bunching criteria is based on: Total counts, FHA share of groups 1-7, FHA share of groups 6 and 7
		*counts for full county and full county-year
		by FIPS year: egen year_count = count(group)
		by FIPS: egen total_count = count(group)
		
	*total share_FHA defined above, but share of bins 1-7 is the relevant measure
				gen all_1_7 = inrange(group, 1, 7)
				gen fha_1_7 = inrange(group, 1, 7) & fha == 1
				
				by FIPS year: egen total_all_1_7 = sum(all_1_7)
				by FIPS year: egen total_fha_1_7 = sum(fha_1_7)
				drop all_1_7 fha_1_7
			
		gen fha_share_1_7 = (total_fha_1_7/total_all_1_7) // FHA share of groups 1-7
		
	*bunching defined as being in groups 6 or 7
			gen fha_6_7 = .
				replace fha_6_7 = 1 if (inlist(group, 6, 7) & fha == 1)
				replace fha_6_7 = 0 if (inlist(group, 6, 7) & fha == 0) // of bunched loans, what % are FHA
		by FIPS year: egen fha_sh_6_7 = mean(fha_6_7)
	
	
	*criteria (TBD)
	gen high_bunching = fha_sh_6_7 > 0.15 //year-county specific
	gen high_fha_share = fha_share_1_7 > 0.2 //year-county specific
	gen high_year_count = year_count > 1000 // year-county specific
	gen high_total_count = total_count > 2000 // county-specific
	
	replace in_sample = (high_bunching*high_fha_share*high_year_count*high_total_count)
	
	save "W:\Interns\Mike\Loan Limits project\intermed data\cll_forqc_pr.dta", replace
	
	collapse (sum) in_sample, by(FIPS year)
	gsort - in_sample FIPS year
	drop if in_sample == 0
	gen source = "PR"
	append using "W:\Interns\Mike\Loan Limits project\intermed data\sample_list.dta"
	duplicates tag FIPS year, gen(dups)
	tab dups source
	
	*saving sample list
	keep if source == "PR" & dups == 1
	duplicates drop FIPS, force
	keep FIPS
	save "W:\Interns\Mike\Loan Limits project\intermed data\sample_counties.dta", replace //list of counties to use


*prepping data for regression
use cbsa_short FIPS loan_type SaleAmt year month FirstMtgAmt price LandUseCode ltv weight_sales_all avm_201812 ///
using "X:\tobias\intermed data\cleaned_2012_weighted.dta", clear
	
	*filters
		keep if inlist(LandUseCode, "1000", "1001", "1002", "1003", "1004", "1005")
		keep if inrange(price, 1000, 5000000)
		keep if inrange(ltv, 20, 120)	
	*merging on list of selected counties from prior analysis
		merge m:1 FIPS using "W:\Interns\Mike\Loan Limits project\intermed data\sample_counties.dta"
		keep if _merge == 3
		drop _merge	
	*reapplying filters to see how many observations are lost
		merge m:1 FIPS year using "W:\Interns\Mike\Loan Limits project\intermed data\fha_gse_limits_v2.dta"
		keep if _merge == 3
		drop _merge
		
save "W:\Interns\Mike\Loan Limits project\intermed data\sample_merged.dta", replace



/************ Regression Analysis ***************/
*regressions of year pairs
use "W:\Interns\Mike\Loan Limits project\intermed data\sample_merged.dta", clear
*year pair: yr1 & yr2
local yr1 = 2017 //pick a year
local yr2 = `yr1' + 1
keep if FIPS == "04013" //pick a county

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
	*for one county
	reg ln_SaleAmt i.year i.group i.group#current ln_avm_201812 i.month
	table group year if loan_type == "FHA" // to view counts of FHA loans invading new price bin
	
	*when pooling counties
	*areg ln_SaleAmt i.year i.group i.group#current ln_avm_201812 i.month [pweight = weight_sales_all], a(FIPS_e)
