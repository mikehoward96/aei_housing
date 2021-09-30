*cd "W:\Sissi\Other\200608 Optimal Blue update\Rural and second home"

global ex_path = "W:\Optimal Blue\output\Rural density and second home analysis v10.xlsx"
global wk = 65 //change every week. continues to increment by 1 every week due to awkward period definitions



/**--------------Rural ZIP----------------**
//Prepare RUCA file *Don't need to run every week

use "W:\Optimal Blue\zip_density.dta", clear //has ZIP, pop2018 area_sqmi popdensity fips
merge 1:1 ZIP using "W:\Optimal Blue\RUCA ZIP crosswalk.dta", keepusing(ruca1) keep(3) nogen //near 100% match rate. Only ones with no fips don't match (21 zips)
merge m:1 fips using "Q:\Tobias\FirstAm PR\analysis\Price Tiers\county_xwalk.dta", keepusing(cbsa_short cbsacode CSACode CSATitle) keep(1 3) nogen
	
	replace CSATitle = cbsa_short if CSATitle == "" & CSACode == ""
	replace CSACode = cbsacode if CSACode == "" & CSATitle != ""
	
	gen metro_core = ruca1 == 1
		replace metro_core  = . if pop2018 == 0
		
	xtile density_decile = popdensity[fw=pop2018], n(5)  
	
	bys CSATitle: gen csa_count = _N
	bys CSACode: drop if _N < 6
	
	gen density_decile_metro = .
	levelsof CSACode, local(levels)
		foreach l of local levels {
			xtile density_decile_`l' = popdensity[fw=pop2018] if CSACode == "`l'", n(5)
			replace density_decile_metro = density_decile_`l' if CSACode == "`l'"
			drop density_decile_`l'
			}
			
	rename popdensity pop_density
	rename ruca1 PrimaryRUCA
	replace density_decile = density_decile - 1
	replace density_decile_metro = density_decile_metro - 1 //to make this file flush with the last one.
	
	save "W:\Optimal Blue\ZIP density and RUCA crosswalk v2.dta", replace

	//for Tableau
	keep state county *RUCA CSATitle ZIP metro_core*
	drop if CSACode == ""
	gen metro_core_label = ""
				 replace metro_core_label = "Yes" if metro_core == 1
				 replace metro_core_label = "No" if metro_core == 0
export excel "W:\Sissi\Other\200608 Optimal Blue update\Rural and second home\data for interactive.xlsx", firstrow(var) replace
*/
			
use zipcode ZIP5 state FIPSCODE county week b_year cbsa_short cbsacode loanpurpose rank_pr loanamount if loanpurpose == "Purchase" & b_year >=2019 using "W:\Optimal Blue\source data\Historical\OptimalBlue_FullDataset", clear
 
	*2021 fix
		gen wrap = inlist(b_year, 2020, 2021) & week < 21
			replace week = week + 53 if wrap == 1 //53 weeks in 2020
			replace b_year = b_year - 1 if wrap == 1
			drop wrap

 
	keep if inrange(week, 21, $wk)

	drop if inlist(zipcode, "", "None")
	rename ZIP5 ZIP
	
	merge m:1 ZIP using "W:\Optimal Blue\ZIP density and RUCA crosswalk v2.dta", keep(1 3) nogen
	
		replace CSATitle = cbsa_short if CSATitle == "" & CSACode == ""
	
	expand 2, gen(d)
	gen period = .
		replace period = 1 if d == 0
		replace period = 2 if d == 1 & inrange(week, ($wk - 4), $wk)
		replace period = 3 if d == 1 & inrange(week, 21, ($wk - 5))
	
	//National chart
	preserve
		
		gcollapse (count) count = week, by(PrimaryRUCA b_year period)
		drop if !inrange(PrimaryRUCA, 1, 10)
		reshape wide count, i(PrimaryRUCA period) j(b_year)
		export excel count2019 count2020 if period == 1 using "$ex_path", sheet("Urban Core - national") sheetmodify cell(B6) keepcellfmt nolabel
		export excel count2019 count2020 if period == 2 using "$ex_path", sheet("Urban Core - national") sheetmodify cell(I6) keepcellfmt nolabel
		export excel count2019 count2020 if period == 3 using "$ex_path", sheet("Urban Core - national") sheetmodify cell(M6) keepcellfmt nolabel
		
	restore
	
	//Metro chart
	gcollapse (count) count = week, by(CSATitle metro_core b_year period)
	
	drop if metro_core == .
	
	bys CSATitle metro_core period (b_year): gen yoy = count / count[1] - 1

	keep if b_year == 2020
	*bys CSATitle period: gen ratio = count[1] / (count[1] + count[2]) if _n == 2 //what is this for?

	bys CSATitle period: egen total = total(count)
		gen total_1 = total if period == 1
		bys CSATitle: carryforward total_1, replace
		
	drop if total_1 < 3000 | CSATitle == "" 
	drop total total_1 b_year
	
	reshape wide count yoy, i(CSATitle period) j(metro_core)
	
	order CSATitle count0 count1 yoy0 yoy1
	gsort period CSATitle
	export excel CSATitle count0 count1 yoy0 yoy1 if period == 1 using "$ex_path", sheet("Urban Core - metro") sheetmodify keepcellfmt cell(A5) nolabel
	export excel yoy0 yoy1 if period == 2 using "$ex_path", sheet("Urban Core - metro") sheetmodify keepcellfmt cell(J5) nolabel
	export excel yoy0 yoy1 if period == 3 using "$ex_path", sheet("Urban Core - metro") sheetmodify keepcellfmt cell(M5) nolabel
	
	//merge to list of 13 largest metros (list too long we can't use keep if inlist)
	//hard-coded, based on CSA rank by population on wikipedia
	merge m:1 CSATitle using "W:\Sissi\Other\misc\200608 Optimal Blue update\Rural and second home\intermed\temp_topCSAlist.dta", keep(3) nogen
	keep if top13 == 1
	order CSA yoy0 yoy1 count0 count1
	gsort period CSATitle
	export excel CSA yoy0 yoy1 if period == 1 using "$ex_path", sheet("Urban Core - chart") sheetmodify cell(A5) keepcellfmt nolabel
	export excel count0 count1 if period == 1 using "$ex_path", sheet("Urban Core - chart") sheetmodify cell(G5) keepcellfmt nolabel //Sissi added if period == 1

	export excel yoy0 yoy1 if period == 2 using "$ex_path", sheet("Urban Core - chart") sheetmodify cell(J5) keepcellfmt nolabel
	export excel yoy0 yoy1 if period == 3 using "$ex_path", sheet("Urban Core - chart") sheetmodify cell(M5) keepcellfmt nolabel
		
		
**--------------Density Analysis------------------**
use zipcode purchaseprice ZIP5 state FIPSCODE county week b_year cbsa_short cbsacode loanpurpose rank_pr loanamount if loanpurpose == "Purchase" & b_year >=2019 using "W:\Optimal Blue\source data\Historical\OptimalBlue_FullDataset", clear
		
		*2021 fix
		gen wrap = inlist(b_year, 2020, 2021) & week < 21
			replace week = week + 53 if wrap == 1 //53 weeks in 2020
			replace b_year = b_year - 1 if wrap == 1
			drop wrap
		
	keep if inrange(week, 21, $wk) 
	 
	drop if inlist(zipcode, "", "None")
	rename ZIP5 ZIP
	
	merge m:1 ZIP using "W:\Optimal Blue\ZIP density and RUCA crosswalk v2.dta", keep(1 3) nogen 
	drop if density_decile_metro == . & CSATitle != ""
	drop if density_decile == .
	
	gen year = 2019
	rename ZIP SitusZIP5
	
	*Use Land Value data filled by cross section data instead
	merge m:1 SitusZIP5 using "X:\tobias\analysis\land shares\intermed data\Land zip5 data 2019 ppts change.dta", keepusing(LV_asis_AEI_most_recent) keep(1 3) nogen
	*merge m:1 ZIP5 year using "W:\Mike\Optimal Blue\OB Data\landvals_zip5.dta", keepusing(landvalueperacreasis) keep(1 3) nogen //75% match rate. Zips are just missing from land vals file
	
	rename (SitusZIP5 LV_asis_AEI_most_recent) (ZIP5 lv)
	
	replace CSATitle = cbsa_short if CSATitle == "" & CSACode == ""
		
*******************************************
************** National table *************
*******************************************

	preserve
	
		expand 2, gen(d)
	gen period = .
		replace period = 1 if d == 0
		replace period = 2 if d == 1 & inrange(week, ($wk - 4), $wk)
		replace period = 3 if d == 1 & inrange(week, 21, ($wk - 5))
		drop d
		
		tostring density_decile, gen(density_decile_combine)
			replace density_decile_comb = "0-2" if inrange(density_decile, 0,2)
			drop if density_decile_combine == "."
			
		expand 2, gen(d)
			replace density_decile_combine = "all" if d==1
			
		gcollapse (count) count = week (median) pop_density purchaseprice lv, by(density_decile_combine b_year period)
		
		sort period b_year density_decile
		by period b_year: gen share = count/count[4]
		reshape wide count share pop_density purchaseprice lv, i(density_decile_combine period) j(b_year)
		
		gen yoy = count2020/count2019-1
		gen change = share2020 - share2019 if density_decile_combine != "all"
		order yoy share2019 share2020 change count2019 count2020 pop_density2019 pop_density2020 purchaseprice2019 purchaseprice2020 lv2019 lv2020
		
		replace share2019 = . if density_decile_combine=="all"
		replace share2020 = . if density_decile_combine=="all"
		
	sort period density_decile
		
	export excel yoy share2019 share2020 change if period == 2 using "$ex_path", sheet("Density - limited") cell(R42) keepcellfmt sheetmodify nolabel
	export excel yoy share2019 share2020 if period == 3 using "$ex_path", sheet("Density - limited") cell(V42) keepcellfmt sheetmodify nolabel
	
	keep if period == 1
	
		foreach t in 2019 2020 {
		gen weighted_avg_density_`t' = share`t' * pop_density`t'
		gen temp_`t' = sum(weighted_avg_density_`t')
		}
		
		replace pop_density2020 = temp_2020 if density_decile_combine == "all"
		
	sort density_decile	
	order yoy share* change lv2020 count*
		
	export excel yoy share* change lv2020 count2019 count2020 pop_density2020 purchaseprice2019 purchaseprice2020 if period == 1 using "$ex_path", sheet("Density - limited") cell(C42) keepcellfmt sheetmodify nolabel
	
	restore
	
*******************************************
************ All CSAs *********************
*******************************************
	
	drop if CSATitle == ""
	merge m:1 CSATitle using "W:\Optimal Blue\matching\Data\50 largest CSAs with GDP v2.dta", keep(3) nogen keepusing(Population2019 GDP2018)
	
	
	/*Sissi added for Lot Size analysis
	preserve
		keep CSATitle
		bys CSATitle: keep if _n==1
		save "intermed\CSAlist", replace
	restore
	*/
	
	expand 2, gen(d)
	gen period = .
		replace period = 1 if d == 0
		replace period = 2 if d == 1 & inrange(week, ($wk - 4), $wk)
		replace period = 3 if d == 1 & inrange(week, 21, ($wk - 5))
	drop d
	
	expand 2, gen(d2)
	replace density_decile_metro = 5 if d2 == 1 //overall
	
	gcollapse (count) count = week (median) pop_density purchaseprice lv Population2019 GDP2018, by(CSATitle density_decile_metro b_year period)
	
	sort period CSATitle density_decile_metro b_year
	by period CSATitle density_decile_metro: gen yoy = count[2] / count[1] - 1 if _n == 2
	bys period CSATitle b_year: egen total = total(count) if density_decile != 5
	gen share = count / total		
	reshape wide count yoy share total pop_density purchaseprice lv Population2019 GDP2018, i(CSATitle density_decile_metro period) j(b_year)
	drop yoy2019 lv2019

	bys period CSATitle: replace total2019 = total2019[1] if density_decile == 5
	bys period CSATitle: replace total2020 = total2020[1] if density_decile == 5
	by period CSATitle: replace count2019 = total2019 if density_decile == 5
	by period CSATitle: replace count2020 = total2020 if density_decile == 5
	replace yoy2020 = count2020 / count2019 - 1 if density_decile == 5
	replace share2019 = . if density_decile == 5
	replace share2020 = . if density_decile == 5
	replace pop_density2020 = . if density_decile == 5
	
	tostring density_decile_metro, replace
	merge m:1 CSATitle density_decile_metro using "W:\Mike\Crosswalks\CSATitle_density_decile_metro_LotSizeSqFt v2.dta", keepusing(LotSizeSqFt) nogen
	*drop if density_decile_metro == "all"
	destring density_decile_metro, replace
	
	order CSATitle density_decile_metro period CSATitle density_decile yoy2020 share* count* pop_density* total* purchaseprice* lv* Population20192020 GDP20182020

	replace density_decile_metro = density_decile_metro + 1
	tostring density_decile_metro, replace
	replace density_decile_metro = "All" if density_decile_metro =="6"
	sort period CSATitle density_decile_metro
	
		foreach t in 2019 2020 {
		gen weighted_avg_density_`t' = share`t' * pop_density`t'
		bys period CSATitle: gen temp_`t' = sum(weighted_avg_density_`t')
		replace pop_density`t' = temp_`t' if density_decile_metro == "All"
		}	
		
		*Some CSAs have gaps. couldn't estalbish why, but this fixes it:
		bys period CSATitle: carryforward total2019 total2020, replace
		replace count2019 = total2019 if density_decile_metro == "All"
		replace count2020 = total2020 if density_decile_metro == "All"
		replace yoy2020 = (count2020/count2019) - 1 if density_decile_metro == "All"
	
*Change in Density
	preserve
		keep if density_decile_metro == "All"
		keep CSATitle pop_density2019 pop_density2020 period
		gen change = pop_density2020 - pop_density2019
		gen yoy = (pop_density2020/pop_density2019) - 1
		
		merge m:1 CSATitle using "W:\Sissi\Other\misc\200608 Optimal Blue update\Rural and second home\intermed\temp_topCSAlist.dta", keep(3) keepusing(CSATitle) nogen
		
		reshape wide pop_* change yoy, i(CSATitle) j(period)
		
		gsort - change1
	
	export excel CSATitle - yoy1 using "$ex_path", sheet("Density - change") cell(A5) keepcellfmt sheetmodify nolabel
	export excel change2 yoy2 using "$ex_path", sheet("Density - change") cell(F5) keepcellfmt sheetmodify nolabel
	export excel change3 yoy3 using "$ex_path", sheet("Density - change") cell(H5) keepcellfmt sheetmodify nolabel
	restore

	
	drop pop_density2019 weighted* temp*
	gen change = share2020 - share2019
	gen price_per_avg_lot = (LotSizeSqFt/43560)*lv2020
	
	drop if density_decile_metro == "."
	
	order CSATitle density_decile_metro yoy2020 share* change lv2020 LotSizeSqFt price_per_avg_lot count* pop_density2020 purchaseprice2019 purchaseprice2020 Population20192020 GDP20182020
	
	export excel CSATitle density_decile_metro yoy2020 share* change lv2020 LotSizeSqFt price_per_avg_lot count* pop_density2020 purchaseprice2019 purchaseprice2020 Population20192020 GDP20182020 if period == 1 using "$ex_path", sheet("Density - 50 largest") cell(A4) sheetmodify keepcellfmt nolabel
	export excel yoy2020 share2019 share2020 change if period == 2 using "$ex_path", sheet("Density - 50 largest") cell(R4) sheetmodify keepcellfmt nolabel
	export excel yoy2020 share2019 share2020 if period == 3 using "$ex_path", sheet("Density - 50 largest") cell(V4) sheetmodify keepcellfmt nolabel
	
	
	order period
	
*******************************************
************ Top 20 ***********************
*******************************************

	merge m:1 CSATitle using "W:\Mike\Optimal Blue\OB Data\density_top_CSAs.dta", keep(3) keepusing(CSATitle) nogen

	
	//add one row below each metro
	expand 2 if density_decile_metro =="All", gen(d)
	sort period CSATitle density* d
	replace yoy2020 = . if d==1
	replace count2019 = . if d==1
	replace count2020 = . if d==1
	replace pop_density2020 = . if d==1
	replace purchaseprice2019 = . if d==1
	replace purchaseprice2020 = . if d==1
	*replace f2020 = . if d == 1 // not sure why this is in there
	drop d
		
	//combined density 1&2 for selected metros
	bys period CSATitle (density_decile_metro): replace count2019 = count2019[1] + count2019[2] if density_decile_metro=="1" & inlist(CSATitle, "Chicago-Naperville, IL-IN-WI","Cleveland-Akron-Canton, OH","Minneapolis-St. Paul, MN-WI","Portland-Vancouver-Salem, OR-WA","St. Louis-St. Charles-Farmington, MO-IL")
	bys period CSATitle (density_decile_metro): replace count2020 = count2020[1] + count2020[2] if density_decile_metro=="1" & inlist(CSATitle, "Chicago-Naperville, IL-IN-WI","Cleveland-Akron-Canton, OH","Minneapolis-St. Paul, MN-WI","Portland-Vancouver-Salem, OR-WA","St. Louis-St. Charles-Farmington, MO-IL")
	bys period CSATitle (density_decile_metro): replace pop_density2020 = (pop_density2020[1] + pop_density2020[2])/2 if density_decile_metro=="1" & inlist(CSATitle, "Chicago-Naperville, IL-IN-WI","Cleveland-Akron-Canton, OH","Minneapolis-St. Paul, MN-WI","Portland-Vancouver-Salem, OR-WA","St. Louis-St. Charles-Farmington, MO-IL")
	
	drop if density_decile_metro =="2" & inlist(CSATitle, "Chicago-Naperville, IL-IN-WI","Cleveland-Akron-Canton, OH","Minneapolis-St. Paul, MN-WI","Portland-Vancouver-Salem, OR-WA","St. Louis-St. Charles-Farmington, MO-IL")

	replace yoy2020 = count2020 / count2019 - 1 if density_decile_metro != "All"
	replace share2019 = count2019/total2019 if density_decile_metro != "All"
	replace share2020 = count2020/total2020 if density_decile_metro != "All"
	
	preserve
	drop if CSATitle == "Raleigh-Durham-Cary, NC"
	export excel yoy2020 share* count* pop_density2020 if period == 1 using "$ex_path", sheet("Density - top 20") sheetmodify cell(C4) keepcellfmt nolabel
	export excel yoy2020 if period == 2 using "$ex_path", sheet("Density - top 20") sheetmodify cell(J4) keepcellfmt nolabel
	export excel yoy2020 if period == 3 using "$ex_path", sheet("Density - top 20") sheetmodify cell(K4) keepcellfmt nolabel
	restore
	
*******************************************
************ Six CSAs ********************
*******************************************

	keep if inlist(CSATitle, "Los Angeles-Long Beach, CA","New York-Newark, NY-NJ-CT-PA","San Jose-San Francisco-Oakland, CA","Seattle-Tacoma, WA","Washington-Baltimore-Arlington, DC-MD-VA-WV-PA", "Raleigh-Durham-Cary, NC")
	drop if yoy2020 == .
	
	/*
	replace lv2020 = . if yoy2020 == .
	replace Population20192020 = . if yoy2020 == .
	replace GDP20182020 = . if yoy2020 == .
	replace change = . if yoy2020 == .
	replace LotSizeSqFt = . if yoy2020 == .
	replace price_per_avg_lot = . if yoy2020 == .
	*/
	
	replace CSATitle = "ZZZ" if CSATitle == "Raleigh-Durham-Cary, NC"
	sort period CSATitle density_decile_metro
	
	export excel yoy2020 share* change lv2020 LotSizeSqFt price_per_avg_lot count* pop_density2020 purchaseprice2019 purchaseprice2020 Population20192020 GDP20182020 if period == 1 using "$ex_path", sheet("Density - limited") cell(C4) sheetmodify keepcellfmt nolabel
	export excel yoy2020 share2019 share2020 change if period == 2 using "$ex_path", sheet("Density - limited") cell(R4) sheetmodify keepcellfmt nolabel
	export excel yoy2020 share2019 share2020 if period == 3 using "$ex_path", sheet("Density - limited") cell(v4) sheetmodify keepcellfmt nolabel

	
**------------------Second Home Analysis---------------------**
//Prepare second home census data **Don't need to run every week
/*
import excel "W:\Sissi\Other\200608 Optimal Blue update\Rural and second home\2010 Census Data\US\US.xlsx", sheet("US") firstrow clear
              gcollapse (sum) H0030001 H0050006, by(ZCTA5)
              drop if ZCTA5 == ""
              rename (H0030001 H0050006) (total vacation)
              gen vacation_rate = vacation / total //missing vacation rate means no housing unit in the ZIP
              rename ZCTA5 ZIP5 
                                                  
                save "X:\tobias\analysis\Optimal Blue\intermed data\ZIP_2nd_homes.dta", replace                         
                                                  
              //merge on CBSAs/counties/CSAs
              rename ZIP5 zip
              merge 1:1 zip using "W:\Sissi\crosswalks\zip2county_totratio.dta", keep(1 3) nogen
                                                  rename county FIPSCODE
                                                  merge m:1 FIPSCODE using "Q:\Tobias\FirstAm PR\analysis\Price Tiers\county_xwalk.dta", keepusing(cbsa cbsa_short cbsacode county state state_name CSA*) keep(1 3) nogen
                                                  
                                                  collapse (sum) vacation total, by(cbsacode cbsa_short)
                                                  gen vacation_rate = vacation / total 
                                                  drop if cbsa_short == ""
                                                  
                save "X:\tobias\analysis\Optimal Blue\intermed data\cbsa_2nd_homes.dta", replace      
                                                  
             
*/

use ZIP5 state FIPSCODE county week b_year cbsa_short cbsacode loanpurpose rank_pr loanamount if loanpurpose == "Purchase" & b_year >= 2019 using "W:\Optimal Blue\source data\Historical\OptimalBlue_FullDataset", clear

	*2021 fix
		gen wrap = inlist(b_year, 2020, 2021) & week < 21
			replace week = week + 53 if wrap == 1 //53 weeks in 2020
			replace b_year = b_year - 1 if wrap == 1
			drop wrap

	keep if  inrange(week, 21, $wk)
	merge m:1 ZIP5 using "X:\tobias\analysis\Optimal Blue\intermed data\ZIP_2nd_homes.dta", keep(3) nogen

	gen vacation_def = .
		replace vacation_def = 5 if vacation_rate > 0.05 & vacation_rate != .
		replace vacation_def = 10 if vacation_rate > 0.1 & vacation_rate != .
		replace vacation_def = 20 if vacation_rate > 0.2 & vacation_rate != .

	expand 2, gen(d1)
		replace vacation_def = 999 if d1==1
		
	expand 2, gen(d)
	gen period = .
		replace period = 1 if d == 0
		replace period = 2 if d == 1 & inrange(week, ($wk - 4), $wk)
		replace period = 3 if d == 1 & inrange(week, 21, ($wk - 5))
		
	gcollapse (count) count = week, by(vacation_def b_year period) 

	sort period b_year vacation_def
	bys period b_year: replace count = count[1] + count[2] + count[3] if vacation_def==5
	by period b_year: replace count = count[2] + count[3] if vacation_def==10
	by period b_year: gen market_share = count/count[4]
	
	reshape wide count market_share, i(vacation_def period) j(b_year)

	gen yoy = count2020/count2019 - 1

	replace market_share2019 = . if vacation_def==999
	replace market_share2020 = . if vacation_def==999

	sort period vacation_def
	
export excel market_share* yoy if vacation_def!=. & period == 1 using "$ex_path", sheet("Second Home") sheetmodify cell(B4) nolabel keepcellfmt
export excel market_share* yoy if vacation_def!=. & period == 2 using "$ex_path", sheet("Second Home") sheetmodify cell(G4) nolabel keepcellfmt
export excel market_share* yoy if vacation_def!=. & period == 3 using "$ex_path", sheet("Second Home") sheetmodify cell(L4) nolabel keepcellfmt


**-----------------------Metro group analysis----------------------**
use week loanpurpose b_year rank_pr if b_year >= 2019 & loanpurpose == "Purchase" using "W:\Optimal Blue\source data\Historical\OptimalBlue_FullDataset", clear

	*2021 fix
		gen wrap = inlist(b_year, 2020, 2021) & week < 21
			replace week = week + 53 if wrap == 1 //53 weeks in 2020
			replace b_year = b_year - 1 if wrap == 1
			drop wrap
			
			keep if inrange(week, 1, $wk)

	forval y = 1/$wk {
					gen week_`y' = week == `y'
					}

	gen size = .
					replace size = 1 if inrange(rank_pr, 1, 20)
					replace size = 2 if inrange(rank_pr, 21, 50)
					replace size = 3 if inrange(rank_pr, 51, 100)
					replace size = 4 if inrange(rank_pr, 101, 250)
					replace size = 5 if inrange(rank_pr, 251, 500)
					replace size = 6 if size == .

	gcollapse (sum) week_*, by(size b_year) fast
					sort b_year size
	forval y = 1/$wk {	
		bys b_year: egen week_`y'_total = total(week_`y')
		gen week_`y'_share = week_`y'/week_`y'_total
	}
	
	drop week_1 - week_20_share
	
export excel *share if b_year==2020 using "$ex_path", sheet("Metro Group") cell(v4) sheetmodify keepcellfmt nolabel


*New second home sheet
use ZIP5 state FIPSCODE county week b_year cbsa_short cbsacode loanpurpose rank_pr loanamount if loanpurpose == "Purchase" & b_year >= 2019 using "W:\Optimal Blue\source data\Historical\OptimalBlue_FullDataset", clear
	merge m:1 ZIP5 using "X:\tobias\analysis\Optimal Blue\intermed data\ZIP_2nd_homes.dta", keep(3) nogen
	
	drop if week == 53

	gen vac = vacation_rate > 0.2

	expand 2, gen(d1)
		replace vac = 2 if d1==1

	gcollapse (count) count = loanamount, by(vac b_year week) fast
		bys vac: gen yoy = (count/count[_n-52]) - 1
	
	reshape wide count yoy, i(week b_year) j(vac)
	drop if b_year == 2019
	
	sort b_year week
	order b_year week count* yoy*


export excel count* yoy* using "$ex_path", sheet("Urban and SH Analysis - weekly") cell(B5) sheetmodify keepcellfmt nolabel
	
	
	
use zipcode ZIP5 state FIPSCODE county week b_year cbsa_short cbsacode loanpurpose rank_pr loanamount if loanpurpose == "Purchase" & b_year >=2019 using "W:\Optimal Blue\source data\Historical\OptimalBlue_FullDataset", clear

	drop if inlist(zipcode, "", "None")
	rename ZIP5 ZIP
	
	merge m:1 ZIP using "W:\Optimal Blue\ZIP density and RUCA crosswalk v2.dta", keep(1 3) nogen
	
		
		
		gcollapse (count) count = loanamount, by(metro_core week b_year)
		sort metro* b_year week
		
		drop if metro_core == .
		drop if week == 53
		
		bys metro_core: gen yoy = (count/count[_n-52]) - 1 

		reshape wide count yoy, i(b_year week) j(metro_core)
		drop if b_year == 2019
		
		order *1 *0
		order b_year week count* yoy*	
	
export excel count* yoy* using "$ex_path", sheet("Urban and SH Analysis - weekly") cell(K5) sheetmodify keepcellfmt nolabel


/* RUN ONCE A MONTH AROUND THE 15th
**------------------------Lot size analysis-----------------------------** no need to update every week
**Assessor file 
use YearBuilt LandUseCode SitusZIP5 FIPS LotSizeSqFt using "X:\final\Assessor_skinny.dta", clear  
  
                keep if inrange(real(LandUseCode), 1000, 1103)
                drop if inlist(LandUseCode, "1004", "1005", "1006", "1009", "1010") 
                keep if inrange(LotSizeSqFt, 500, 87120)
  
                rename FIPS fips
                //add CSA
                merge m:1 fips using "Q:\Tobias\FirstAm PR\analysis\Price Tiers\county_xwalk.dta", keepusing(cbsa_short CSACode CSATitle) keep(1 3) nogen
                replace CSATitle = cbsa_short if CSATitle == "" & CSACode == ""

                merge m:1 CSATitle using "W:\Optimal Blue\matching\Data\50 largest CSAs with GDP v2.dta", keep(3) nogen

                *merge m:1 CSATitle using "intermed\CSAlist", keep(3) nogen

                rename SitusZIP5 ZIP
                merge m:1 ZIP using "W:\Optimal Blue\ZIP density and RUCA crosswalk v2.dta", keep(1 3) keepusing(density_decile*) nogen
                                
                expand 2, gen(d)
                                tostring density_decile_metro, replace
                                replace density_decile_metro = "5" if d==1
                                
                gcollapse (median) LotSizeSqFt, by(density_decile_metro CSACode CSATitle) fast
                
                sort CSATitle density_decile_metro
                drop if density_decile_metro =="."
                
                save "W:\Mike\Crosswalks\CSATitle_density_decile_metro_LotSizeSqFt v2.dta", replace

