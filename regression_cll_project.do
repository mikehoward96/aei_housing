*regressions of year pairs
use "W:\Interns\Mike\Loan Limits project\intermed data\sample_merged.dta", clear
*year pair: yr1/yr2
local yr1 = 2017
local yr2 = `yr1' + 1
*keep if FIPS == "04013"

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
	*reg ln_SaleAmt i.year i.group i.group#current ln_avm_201812 i.month
	tab group year if loan_type == "FHA"
	
	*when pooling counties
	areg ln_SaleAmt i.year i.group i.group#current ln_avm_201812 i.month [pweight = weight_sales_all], a(FIPS_e) //pweights?
	
	