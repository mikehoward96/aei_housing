****** Tech Worker Index ******
cd "W:\Mike\Tech Worker Index"
global year = "2019"

/*steps:
*1. download cbsa and national data from https://www.bls.gov/oes/tables.htm and place in
	"directory\source data" 
	Name them 'MSA_YYYY.csv' and 'national_YYYY.csv' respectively
	
*2. update metro wages for new year. */
	import excel "source data\MSA_$year.xlsx", sheet("All May $year Data") firstrow case(upper) clear

		keep if inlist(OCC_CODE, "15-0000")
			rename AREA cbsacode
			rename AREA_TITLE cbsa
			rename OCC_TITLE Occupancy
			
			destring A_MEAN, replace
			*rename A_MEAN wage
			
		keep cbsa cbsacode Occupancy A_MEAN
			gen year = $year
			
			
		*cleaning MSAs
		merge 1:1 cbsa using "intermed data\carp index cbsacode_cw cbsa.dta", keepusing(cbsacode_cw) keep(1 3) nogen //made from "W:\Sissi\Carpenter_Index\PartialMSA_WageEstimate\Carpenters_wage_adjusted_BOS.xlsx"
		rename (cbsacode cbsacode_cw) (cbsacode_old cbsacode)
		
		merge m:1 cbsacode using "X:\tobias\intermed data\metro_ranking_public_records_2019_May.dta", keep(1 3) nogen keepusing(rank_pr)
		keep if rank_pr <= 100
		
	*APPEND IF WE DO THIS AGAIN
	*append using "intermed data\tech_wage_top100.dta"//check for duplicates in terms of year and cbsa
		sort cbsacode year
		
		*tab year
		*gen tag = cbsacode_old != cbsacode & year == $year
		
		drop cbsacode_old
		
	save "intermed data\tech_wage_top100.dta", replace

*3. Clean national data and append
	import excel "source data\national_$year.xlsx", firstrow case(upper) clear

		keep if inlist(OCC_CODE, "15-0000")
		rename OCC_TITLE Occupancy

		drop if H_MEAN=="*"
			destring H_MEAN, replace
			destring H_MEDIAN, replace
			destring A_MEAN, replace
			destring A_MEDIAN, replace

		gen year = $year
		drop if _n > 1
	
		keep Occupancy H_MEAN A_MEAN H_MEDIAN A_MEDIAN year
		
		*append using "intermed data\national_tech_wage.dta" //check for duplicates
	
	save "intermed data\national_tech_wage.dta", replace
	
*4. Create benchmark */
	use price weight_sales_all new_c tier cbsacode cbsa_short rank_pr year if rank_pr <= 100 using "X:\tobias\intermed data\cleaned_2012_weighted.dta", clear
		drop if year == ($year + 1)
										
			winsor2 price, by(cbsa_short year) replace cuts(2.5 97.5) 			
			replace price = . if (new_c == 1 & !inrange(price, 50000, 5000000)) | (new_c == 0 & !inrange(price, 25000, 5000000))
			replace price = price/1000

		gen price_0 = price if new_c == 0
		gen price_1 = price if new_c == 1

			drop if price == .
								   
		gcollapse (mean) price price_0 price_1 (p25) price_p25=price price_0_p25=price_0 price_1_p25=price_1 (p75) price_p75=price price_0_p75=price_0 price_1_p75=price_1  [pw=weight_sales_all], by(cbsa_short cbsacode year) fast

		merge m:1 cbsacode year using "intermed data\tech_wage_top100.dta", keep(3) nogen
			rename A_MEAN wage
			
			
		destring wage, replace force
		replace wage = wage/1000

		gen ratio = price / (wage * 1.5) //assuming household income is on avg 1.5 times carpenter income
		gen ratio_p25 = price_p25 / (wage * 1.5)
		gen ratio_p75 = price_p75 / (wage * 1.5)
						
		forval y= 0/1 {
			gen ratio_`y' = price_`y' / (wage * 1.5)
			gen ratio_`y'_p25 = price_`y'_p25 / (wage * 1.5)
			gen ratio_`y'_p75 = price_`y'_p75 / (wage * 1.5)
			}

		drop Occupancy cbsa
		sort rank_pr year

		order cbsa_short cbsacode rank_pr year wage price
	save "intermed data\cbsa_index.dta", replace

	*National level
	use price weight_sales_all new_c tier cbsacode cbsa_short year using "X:\tobias\intermed data\cleaned_2012_weighted.dta", clear
		winsor2 price, by(cbsa_short year) replace cuts(2.5 97.5) 
						
			replace price = . if (new_c == 1 & !inrange(price, 50000, 5000000)) | (new_c == 0 & !inrange(price, 25000, 5000000))
			replace price = price/1000            
		
		gen price_0 = price if new_c == 0
		gen price_1 = price if new_c == 1

		drop if price == . //Not dropping cbsacode=="" this time

		gcollapse (mean) price price_0 price_1 (p25) price_p25=price price_0_p25=price_0 price_1_p25=price_1 (p75) price_p75=price price_0_p75=price_0 price_1_p75=price_1  [pw=weight_sales_all], by(year) fast

		merge 1:1 year using "intermed data\national_tech_wage.dta", keep(3) nogen

		rename A_MEAN wage

		replace wage = wage/1000            
		gen ratio = price / (wage * 1.5)
		gen ratio_p25 = price_p25 / (wage * 1.5)
		gen ratio_p75 = price_p75 / (wage * 1.5)
						
		forval y= 0/1 {
			gen ratio_`y' = price_`y' / (wage * 1.5)
			gen ratio_`y'_p25 = price_`y'_p25 / (wage * 1.5)
			gen ratio_`y'_p75 = price_`y'_p75 / (wage * 1.5)
		}

		drop Occupancy H_MEDIAN A_MEDIAN H_MEAN
		
		gen cbsa_short = "National"
		gen rank_pr = 0
		gen cbsacode = ""
		order cbsa_short cbsacode rank_pr year wage price
		
	*save "intermed data\national_index.dta", replace

		*Combine national and cbsa data
		append using "intermed data\cbsa_index.dta"
		
		sort rank_pr year
		order cbsa_short cbsacode rank_pr year wage price

	*save "intermed data\all_index.dta", replace

		gen benchmark = wage * 1.5 * 3  //assuming benchmark is 3 times the household income
		keep cbsacode cbsa_short year benchmark rank_pr

	save "intermed data\benchmark.dta", replace
	

	
	
	
*5: create and export summary stats
	use price weight_sales_all new_c tier cbsacode cbsa_short rank_pr year if rank_pr <= 100 using "X:\tobias\intermed data\cleaned_2012_weighted.dta", clear
	  
			replace price = . if (new_c == 1 & !inrange(price, 50000, 5000000)) | (new_c == 0 & !inrange(price, 25000, 5000000))
			drop if price == .

			replace price = price / 1000
			
	*do once for entry level and once for overall market
	
preserve
		keep if inlist(tier,1,2)
	
	merge m:1 cbsacode year using "intermed data\benchmark.dta", keep(3) nogen keepusing(benchmark) //was benchmark_6

		gen count = 0
		replace count = 1 if price <= benchmark

	collapse (mean) count max_price=benchmark (count) sales=count [pw=weight_sales_all], by (cbsacode cbsa_short rank_pr year)
		sort rank_pr year
		rename count ratio_3_1

		egen bin_3_1 = cut(ratio_3_1), at(-0.09999999(.1)1.1)
		replace bin_3_1 = round(bin_3_1 * 10, 1)

		gsort year - ratio_3_1
			by year: gen rank = _n
			replace rank = 1 if ratio_3_1 == 1

			tostring rank, gen(rank_string)
			replace rank_string = "1 (tied)" if rank == 1
			
			gen hh_income = (round(max_price/3, .1)) * 1000
			replace max_price = round(max_price, .1) * 1000

		sort cbsa_short year
			by cbsa_short: gen sale_change = sale / sale[1] - 1 

		order max_price, after (rank)
		
		*extra rank variables
			*bys cbsa_short: gen carpenter_index_2012 = ratio_3_1[1]
			bys cbsa_short: gen carpenter_index_$year = ratio_3_1[_N]
			bys cbsa_short: gen rank_in_$year = rank[_N]

		replace cbsa_short = "Riverside-SB, CA" if cbsa_short == "Riverside_SB, CA"
		
		order hh_income, last
		
	save "tech worker index 2019 (entry).dta", replace
	*******************OUTPUT FILE (save backup beforehand ***********************
	export excel using "tableau\summary_results_entry.xlsx", sheet("Data") sheetreplace firstrow(variables)
		
		gen max_price_export = round(max_price/1000)
		gen sales_export = round(sales)
		replace max_price_export = max_price_export * 1000
		
		keep year cbsa_short rank ratio_3_1 max_price_export sales_export hh_income
		sort cbsa_short
		*export
	
restore
	
	*overall market
		merge m:1 cbsacode year using "intermed data\benchmark.dta", keep(3) nogen keepusing(benchmark)

		gen count = 0
		replace count = 1 if price <= benchmark

	collapse (mean) count max_price=benchmark (count) sales=count [pw=weight_sales_all], by (cbsacode cbsa_short rank_pr year)
		sort rank_pr year
		rename count ratio_3_1

		egen bin_3_1 = cut(ratio_3_1), at(-0.09999999(.1)1.1)
		replace bin_3_1 = round(bin_3_1 * 10, 1)

		gsort year - ratio_3_1
			by year: gen rank = _n
			replace rank = 1 if ratio_3_1 == 1

			tostring rank, gen(rank_string)
			*replace rank_string = "1 (tied)" if rank == 1
			
			gen hh_income = (round(max_price/3, .1)) * 1000
			replace max_price = round(max_price, .1) * 1000

		sort cbsa_short year
			by cbsa_short: gen sale_change = sale / sale[1] - 1 

		order max_price, after (rank)
		
		*extra rank variables
			*bys cbsa_short: gen carpenter_index_2012 = ratio_3_1[1]
			bys cbsa_short: gen carpenter_index_$year = ratio_3_1[_N]
			bys cbsa_short: gen rank_in_$year = rank[_N]

		replace cbsa_short = "Riverside-SB, CA" if cbsa_short == "Riverside_SB, CA"
		
		order hh_income, last
		
	save "tech worker index 2019 (all).dta", replace
	*******************OUTPUT FILE (save backup beforehand ***********************
	export excel using "tableau\summary_results_all.xlsx", sheet("Data") sheetreplace firstrow(variables)
	
		gen max_price_export = round(max_price/1000)
		gen sales_export = round(sales)
		replace max_price_export = max_price_export * 1000
		
		keep year cbsa_short rank ratio_3_1 max_price_export sales_export hh_income
		sort cbsa_short
		
		*export

		
		
		
*5.5: addtional data for Ed:
*# and share of tech workers in a metro
*Median home price
*Median lot size
*Median home sq. ft
*Median density/sq. mile
*Median year built

*Get # and share of tech workers
		import excel "source data\MSA_$year.xlsx", sheet("All May $year Data") firstrow case(upper) clear

		keep if inlist(OCC_CODE, "15-0000", "00-0000") //tech workers and overall employed
			rename AREA cbsacode
			rename AREA_TITLE cbsa
			rename OCC_TITLE Occupancy
			
			destring A_MEAN, replace
			*rename A_MEAN wage
			
		keep cbsa cbsacode Occupancy A_MEAN TOT_EMP
			gen year = $year
			bys cbsacode: gen total_emp = TOT_EMP[1]
			by cbsacode: gen tech_emp = TOT_EMP[2]
			drop if Occupancy == "All Occupations"
			
		destring total_emp, replace force
		destring tech_emp, replace force
		
			
		*cleaning MSAs
		merge 1:1 cbsa using "intermed data\carp index cbsacode_cw cbsa.dta", keepusing(cbsacode_cw) keep(1 3) nogen //made from "W:\Sissi\Carpenter_Index\PartialMSA_WageEstimate\Carpenters_wage_adjusted_BOS.xlsx"
		rename (cbsacode cbsacode_cw) (cbsacode_old cbsacode)
		
		merge m:1 cbsacode using "X:\tobias\intermed data\metro_ranking_public_records_2019_May.dta", keep(1 3) nogen keepusing(rank_pr)
		keep if rank_pr <= 100
		
		
	save "intermed data\total_emp.dta", replace	

	use SitusZIP5 YearBuilt LotSizeSqFt SumBuildingSqFt price weight_sales_all new_c tier cbsacode cbsa_short rank_pr year if rank_pr <= 100 using "X:\tobias\intermed data\cleaned_2012_weighted.dta", clear
	  
			replace price = . if (new_c == 1 & !inrange(price, 50000, 5000000)) | (new_c == 0 & !inrange(price, 25000, 5000000))
			drop if price == .

			replace price = price / 1000
			
			
		merge m:1 cbsacode year using "intermed data\total_emp.dta", keep(3) nogen keepusing(total_emp tech_emp)
		
		rename SitusZIP5 ZIP
		merge m:1 ZIP using "W:\Optimal Blue\ZIP density and RUCA crosswalk.dta", keepusing(pop_density) keep(1 3) nogen
		
		replace LotSizeSqFt = . if !inrange(LotSizeSqFt, 500, 90000)
		replace SumBuildingSqFt = . if !inrange(LotSizeSqFt, 100, 50000)
		
		collapse (mean) total_emp tech_emp (median) price LotSizeSqFt SumBuildingSqFt YearBuilt pop_density [pweight = weight_sales_all], by(cbsa_short rank_pr)
		
		sort cbsa_short
		
		gen sh_tech = tech_emp/total_emp 
		 order rank_pr cbsa_short tech_emp sh_tech price LotSizeSqFt SumBuildingSqFt pop_density YearBuilt 
		 
		 replace price = price * 1000


		
		
/*6: export data to heatmap spreadsheet				
	use FIPS uncapped_weight_sales_all price weight_sales_all new_c tier cbsacode cbsa_short rank_pr Deed_ID year SitusLatitude SitusLongitude if rank_pr <= 100 & inlist(year, 2012, $year) using "X:\tobias\intermed data\cleaned_2012_weighted.dta", clear
	  
			*dropping counties for which counts fluctuate widely -> we shouldn't be showing heat maps for them	
			bys FIPS year: gen unw = _N
			by FIPS year: egen w = total(uncapped_weight_sales_all)
			gen annual_weight = w / unw 
			
			by FIPS: egen min_annual_weight = min(annual_weight) 
			
			keep if inrange(annual_weight, min_annual_weight, (min_annual_weight+0.6)) & inrange(min_annual_weight, .5, 2)
			
			
		*price cleaning
		replace price = . if (new_c == 1 & !inrange(price, 50000, 5000000)) | (new_c == 0 & !inrange(price, 25000, 5000000))
		drop if price == .

		replace price = price / 1000
		*keep if inlist(tier,1,2)
	
	merge m:1 cbsacode year using "intermed data\benchmark.dta", keep(3) nogen

		gen count = 0
			replace count = 1 if price <= benchmark

		keep if count == 1
		
		drop if SitusLatitude == . | SitusLongitude == . | SitusLatitude == 0 | SitusLongitude == 0
		
		
		keep year SitusLatitude SitusLongitude Deed_ID cbsa_short cbsacode
					   
					   ** dropping outliers that screw up mapping
			foreach y in SitusLatitude SitusLongitude {
							bys cbsa_short: egen med_`y' = median(`y')
							by cbsa_short: egen pctile_2_`y' = pctile(`y'), p(2)
							by cbsa_short: egen pctile_98_`y' = pctile(`y'), p(98)
							gen range_`y' = abs(pctile_98_`y' - pctile_2_`y')
							gen tag_`y' = abs(`y' - med_`y') > (1.25 * range_`y') 
							}
					
					tab cbsa_short if tag_SitusLongitude > 0 | tag_SitusLatitude  > 0, sort

					gen flag = tag_SitusLatitude == 1 | tag_SitusLongitude == 1
					bys cbsa_short: egen sum_flag = sum(flag)
					drop if flag == 1 & sum_flag < 50
					
			save "intermed data\tech_heatmap.dta", replace
		
	*******************OUTPUT FILE***********************
	export delimited using "tableau\tech_worker_heatmap_$year.csv", replace
	
	
	
	
	
/*% of entry level calculation
	use price weight_sales_all new_c tier cbsacode cbsa_short rank_pr year if rank_pr <= 100 using "X:\tobias\intermed data\cleaned_2012_weighted.dta", clear
	  
			replace price = . if (new_c == 1 & !inrange(price, 50000, 5000000)) | (new_c == 0 & !inrange(price, 25000, 5000000))
			drop if price == .

			replace price = price / 1000
		keep if inlist(tier,1,2)
		
		*San Diego: 256k
		*Houston: 205k
		*Pitt: 275k
		
	keep if inlist(cbsa_short, "San Diego, CA", "Houston, TX", "Pittsburgh, PA")
	
	gen cutoff = .
		replace cutoff = 205 if cbsa_short == "Houston, TX"
		replace cutoff = 256 if cbsa_short == "San Diego, CA"
		replace cutoff = 275 if cbsa_short == "Pittsburgh, PA"
		
	gen tag = price <= cutoff
