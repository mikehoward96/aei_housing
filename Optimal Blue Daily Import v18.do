/******** Daily Import of Optimal Blue Data *******/
*for after downloading CSV from website and placing in 'Daily' folder
global date = "20210326" //YYYYMMDD
global path = "W:\Optimal Blue\output\Optimal Blue daily updated data Master v3.xlsx"

*saving backup
*use "W:\Optimal Blue\source data\Historical\OptimalBlue_FullDataset", clear
*compress
*save "W:/Optimal Blue/source data/Historical/backups/OB_backup.dta", replace

*importing new day
import delimited "W:/Optimal Blue/source data/Daily/$date.csv", clear

	*March 19th, 2021 changes
		replace loanamount = totalloanamount

*Date Variables
gen year = substr("$date", 1, 4)
gen month = substr("$date", 5, 2)
gen day = substr("$date", 7,2)
gen date = mdy(real(month), real(day), real(year))
format date %td
epiweek date, epiw(week) epiy(b_year)

	*redefine week	
	gen dow = dow(date) // Sunday = 0, Saturday = 6
	gen old_week = week
	
	replace week = week + 1 if dow == 6
	replace week = 1 if week == 53 & !inlist(b_year, 2014, 2020)	
	replace week = 1 if week == 54 //because 2014 had week 53
	
	gen old_b_year = b_year
	replace b_year = b_year + 1 if dow == 6 & week == 1 & old_week == 52 & !inlist(b_year, 2014, 2020)
	replace b_year = b_year + 1 if dow == 6 & week == 1 & old_week == 53 & inlist(b_year, 2014, 2020)
		
	drop old_b_year old_week dow

* FIPSCODE
     gen FIPSCODE = string(statefipscode, "%02.0f") + string(countyfipscode, "%03.0f")
		rename (state county) (state_ob county_ob)
                                                                                                                                                                                                                                
        merge m:1 FIPSCODE using "Q:\Tobias\FirstAm PR\analysis\Price Tiers\county_xwalk.dta", keepusing(cbsa cbsa_short cbsacode market_area_type market_area rank_2017 county state state_name CSACode CSATitle rank_pr) keep(1 3) nogen
        *merge m:1 cbsa_short using "X:\tobias\intermed data\metro_ranking_public_records_2019_May.dta", keep(1 3) nogen keepusing(rank_pr)
*ZIP code
	gen zipcode_ob = zipcode
 
 	drop if inlist(zipcode, "", "None")
                replace zipcode = subinstr(zipcode, ".", "", .)
                replace zipcode = subinstr(zipcode, ",", "", .)
                replace zipcode = subinstr(zipcode, " ", "", .)
                replace zipcode = subinstr(zipcode, "000--", "", .)

			gen hyphen = strpos(zipcode, "-")
			gen strlen = strlen(zipcode)

			gen ZIP5 = zipcode if strlen == 5 & hyphen == 0 //investigate if this is still relevant after changes
                replace ZIP5 = subinstr(zipcode, "-", "", .) if strlen == 6 & hyphen == 6
                replace ZIP5 = substr(zipcode, 1, 5) if strlen == 9 & hyphen == 0
                replace ZIP5 = "0" + zipcode if strlen == 4 & hyphen == 0
                replace ZIP5 = "0" + substr(zipcode, 1, 4) if strlen == 5 & hyphen == 5
                replace ZIP5 = "0" + substr(zipcode, 1, 4) if strlen == 8 & hyphen == 0
                replace ZIP5 = "00" + zipcode if strlen == 3 & hyphen == 0 // google some and they are in Puerto Rico
                replace ZIP5 = substr(zipcode, 1, 5) if hyphen == 6

			drop hyphen strlen

*Jumbo loan types
			gen Year = real(year)
			gen Month = real(month)
			gen Lien = 1  // let’s come back to that
			gen Units = real(substr(numberofunits, 1, 1))
							replace Units = 1 if Units == .
			
			rename (FIPSCODE loantype) (Fips loantype_ob)

	merge m:1 Fips Year Month Units Lien using "Q:\Housing Center Files\Mergable Data\DR_GSELoanLimits_07-21_FipsYearUnitsLienLimit", keepusing(Limit) keep(1 3) nogen
			
			rename Fips FIPSCODE
			drop Year Month
			
			gen loantype = loantype_ob if !inlist(loantype_ob, "Conforming", "NonConforming")
							replace loantype = "Conforming" if loanamount <= Limit & inlist(loantype_ob, "Conforming", "NonConforming")
							replace loantype = "NonConforming" if loanamount > Limit & inlist(loantype_ob, "Conforming", "NonConforming")
		
	*MRI
	do "W:\Optimal Blue\do files\add_mri_OB.do"
	
	
		/*WEEK 53 2020 FIX
		gen wk_53 = week == 53 & b_year == 2020 //dummy will be easier to work with later on
		replace week = 52 if wk_53 == 1
		*/
		
*append to full file
append using "W:\Optimal Blue\source data\Historical\OptimalBlue_FullDataset", force
	sort lockrequesteddate
*remove ID duplicates in case the same day was added twice
	duplicates drop transactionid, force
*remove other duplicates
	duplicates drop zipcode loantype loanpurpose representativefico loanamount date, force	
save "W:\Optimal Blue\source data\Historical\OptimalBlue_FullDataset", replace






*************************************
************WEEKLY IMPORT************
*************************************

*remove slash for weekly import
*Filters needed for the whole workbook
	*Loan Type
            replace loantype = "RHS" if loantype == "USDA" // 5
			drop if !inlist(loantype, "Conforming", "NonConforming", "FHA", "VA", "RHS")
				
		*to order the types the way we want
			gen type_order = 1
				replace type_order = 2 if loantype == "NonConforming"
				replace type_order = 3 if loantype == "FHA"
				replace type_order = 4 if loantype == "VA"
				replace type_order = 5 if loantype == "RHS"
	
	*Day of week
		gen dow = dow(date) // Sunday = 0, Saturday = 6
		
	*Screening for outliers
		replace dtiratio =. if !inrange(dtiratio, 0, 70)
		replace ltv = . if !inrange(ltv, 1, 110)
		replace representativefico = . if !inrange(representativefico, 300, 850)

		*gen adj_default_rate = . //placeholder for MRI. This is to keep the formatting and code consistent with weekly
		
*shortening core variables for ease of use
rename (noterate representativefico dtiratio purchaseprice adj_default_rate) (rate fico dti pprice mri)	

save "W:\Optimal Blue\matching\Data\OB_temp_daily_matched.dta", replace // temporary working file because errors after this are a pain

*******************************************
*Weekly - Everything

	expand 2, gen(dup)
	replace loantype = "Overall" if dup == 1
	replace type_order = 0 if dup == 1
	
	replace cashoutamount = . if !inrange( cashoutamount, 500, 250000) | purpose != "co" // 5th and 95th percentile roughly
	
	gcollapse (count) locks = loanamount ///
			 (mean) rate_avg=rate fico_avg=fico dti_avg=dti  ltv_avg=ltv pprice_avg=pprice mri cashoutamount ///
			 (median) rate_med=rate fico_med=fico dti_med=dti  ltv_med=ltv pprice_med=pprice, by(purpose type_order loantype b_year week) fast
		
			** inserting blank rows
			drop if loantype == "RHS" & purpose == "co" // basically not doing them
			//otherwise try fillin purpose type_order type year week

			sort purpose type_order b_year week
			
			drop if purpose == ""
			
save "W:\Optimal Blue\matching\Data\OB_temp_daily_collapsed.dta", replace //another temp file, because starting from this point is useful too

preserve			
			gen date = (string(b_year)+" - Week "+string(week))
			
			count if purpose == "p" & loantype == "Conforming"
			local n = `r(N)'
				forval y = 1/16 {
					local m = `n' * `y' + `y' - 1
					di `m'
					insobs 1, after(`m')
					}
			carryforward purpose, replace 
			
			order *med *avg
			order loantype date rate* fico* dti* ltv* pprice* mri locks cashoutamount
			drop b_year week type_order
			
			export excel loantype date rate* fico* dti* ltv* pprice* mri locks if purpose == "p" using "$path", sh("Weekly Purchase", modify) cell(A5) keepcellfmt
			export excel loantype date rate* fico* dti* ltv* pprice* mri locks cashoutamount if purpose == "co" using "$path", sh("Weekly CO", modify) cell(A5) keepcellfmt
			export excel loantype date rate* fico* dti* ltv* pprice* mri locks if purpose == "nco" using "$path", sh("Weekly NCO", modify) cell(A5) keepcellfmt
restore


*******************************************
*Daily Counts and Rates
use type_order loanamount rate purpose date using "W:\Optimal Blue\matching\Data\OB_temp_daily_matched.dta", clear

	expand 2, gen(dup)
	replace type_order = 0 if dup == 1
	
	gcollapse (count) locks_ = loanamount (median) rate_med_=rate, by(purpose type_order date) fast
			
			gen cat = purpose + "_" + string(type_order)
				drop purpose type_order 
				
				drop if date == . //anomaly
				
			reshape wide locks_ rate_med_, i(date) j(cat) string
			
			order date locks_p* rate_med_p* locks_co* rate_med_co* locks_nco* rate_med_nco*
			
			export excel using "$path", sh("Daily Counts & Rates", modify) cell(A4) keepcellfmt
			
			
			
*********************************************	
*Weekly HPA: National and CA
set more off
clear
set matsize 11000
clear matrix
clear mata
set maxvar 32000

use loanpurpose loantype FIPSCODE year ZIP5 purchaseprice b_year week cbsa_short state_name rank_pr using "W:\Optimal Blue\source data\Historical\OptimalBlue_FullDataset", clear
	rename state_name state
	*merging on weight
	drop if loanpurpose == "None"
	
	gen m_LoanPurpose = 3
		replace m_LoanPurpose = 1 if loanpurpose == "Purchase"

	gen m_LoanType = .
		replace m_LoanType = 1 if loantype == "Conforming"
		replace m_LoanType = 2 if loantype == "FHA"
		replace m_LoanType = 3 if loantype == "VA"
		replace m_LoanType = 4 if loantype == "USDA"
		replace m_LoanType = 5 if loantype == "NonConforming"	
		
	drop if m_LoanType == .
	
	merge m:1 FIPSCODE year m_LoanType m_LoanPurpose using "W:\Optimal Blue\workbooks\Weighting\weights_type_purpose_fips_year", keepusing(weight) keep(3) nogen
	
	keep if loanpurpose == "Purchase"
                                                                
** ZIPCODE controls
				gen zip5 = real(ZIP5)
					replace zip5 = . if zip5 == 0
		
		*save "W:\Optimal Blue\Weekly HPA changes\cleaned_intermed_Weekly_HPA.dta", replace
		
*National Regression
	** GENERAL CLEANING	
	drop if purchaseprice < 1000 | purchaseprice == .

		winsor2 purchaseprice, replace trim cuts(1 99) by(b_year week FIPS)
		*drop price
		rename purchaseprice price
		drop if price == .

		gen ln_price = ln(price)                       
		encode(cbsa_short), gen(cbsa_e)
		encode(state), gen(state_e)		
		
		keep ln_price zip5 b_year week cbsa_short cbsa_e weight rank_pr state state_e

       *Regressions for Nation and CA 
		reghdfe ln_price [pw=weight], a(weekly=b_year#i.week zip5)
		*reghdfe ln_price if state=="California" [pw=weight], a(weekly_CA=b_year#i.week zip5)
				
		drop if weekly == . | week == 53
		gen yw = string(b_year) + "-" + string(week)	
		
		keep if state == "California"
			
				bys b_year week: keep if _n == 1
				gen hpa_weekly = exp((weekly - weekly[1])) * 100
				*gen hpa_weekly_CA = exp((weekly_CA - weekly_CA[1])) * 100
							

			gen hpa_weekly_yoy = (hpa_weekly / hpa_weekly[_n-52]) - 1
			*gen hpa_weekly_yoy_CA = (hpa_weekly_CA / hpa_weekly_CA[_n-52]) - 1	
			
			export excel yw hpa_weekly_yoy if b_year >= 2019 using "$path", sheet("HPA", modify) cell(A5) keepcellfmt				
			
*POO, SH, IP, Self-emp, Non-Citizen
use loantype propertytype occupancy selfemployed citizenshipstatus week b_year loanpurpose if loanpurpose == "Purchase" using "W:\Optimal Blue\source data\Historical\OptimalBlue_FullDataset", clear

	drop if occupancy == "None"
	
	foreach v in selfemployed citizenshipstatus {
	drop if `v' == ""
	}
	
	gen PR = occupancy == "Primary Residence"
	gen SH = occupancy == "Second Home"
	gen IP = occupancy == "Investment Property"
	
	gen self_emp = selfemployed == "Yes"
	gen noncitizen = !inlist(citizenshipstatus, "U.S. Citizen", "U.S. Citizen Abroad")
	
		*condo share of Conv. loans
			gen condo = .
				replace condo = 1 if propertytype == "Condo" & inlist(loantype, "Conforming", "NonConforming")
				replace condo = 0 if propertytype != "Condo" & inlist(loantype, "Conforming", "NonConforming")
				
			gen sh_condo = .
				replace sh_condo = SH*condo if SH == 1 & inlist(loantype, "Conforming", "NonConforming")
			gen invest_condo =.
				replace invest_condo = IP*condo if IP == 1 & inlist(loantype, "Conforming", "NonConforming")
			
			gen sh_condo_counts = sh_condo
			gen invest_condo_counts = invest_condo
	
	gcollapse (mean) PR SH IP self_emp noncitizen sh_condo invest_condo (sum) sh_condo_counts invest_condo_counts, by(b_year week) fast
	
	export excel PR SH IP self_emp noncitizen sh_condo invest_condo sh_condo_counts invest_condo_counts using "$path", sh("Buyer Characteristics", modify) cell(D5) keepcellfmt

	
	
*Avg. FICO charts
	use "W:\Optimal Blue\matching\Data\OB_temp_daily_collapsed.dta", clear
		keep purpose type_order b_year week fico_avg
		
		drop if purpose == "" //anomaly
		
		reshape wide fico_avg, i(type_order b_year week) j(purpose) string
		reshape wide fico_avgco fico_avgnco fico_avgp, i(b_year week) j(type_order)
		drop b_year week fico_avgco5

		export excel using "$path", sh("Avg. FICO charts", modify) cell(C6) keepcellfmt
		
		
		
		
		
		
*************************
******EXPORT CHARTS******
*************************
*Share breakdowns by loan type FIX
	use if b_year >= 2020 & purpose == "p" & type_order != 0 using "W:\Optimal Blue\matching\Data\OB_temp_daily_collapsed.dta", clear		
		gcollapse (sum) locks, by(b_year week type_order)
		reshape wide locks, i(b_year week) j(type_order)
		drop week b_year
		export excel using "$path", sh("Flash Report Charts", modify) cell(AK5) keepcellfmt

		use if b_year >= 2020 & purpose == "co" & type_order != 0 using "W:\Optimal Blue\matching\Data\OB_temp_daily_collapsed.dta", clear		
		gcollapse (sum) locks, by(b_year week type_order)
		reshape wide locks, i(b_year week) j(type_order)
		drop week b_year
		export excel using "$path", sh("Flash Report Charts", modify) cell(BJ5) keepcellfmt
		
		use if b_year >= 2020 & purpose == "nco" & type_order != 0 using "W:\Optimal Blue\matching\Data\OB_temp_daily_collapsed.dta", clear		
		gcollapse (sum) locks, by(b_year week type_order)
		reshape wide locks, i(b_year week) j(type_order)
		drop week b_year
		export excel using "$path", sh("Flash Report Charts", modify) cell(CN5) keepcellfmt
		

*FICO distributions
	use loanpurpose b_year loantype dtiratio ltv FICO representativefico week if b_year >= 2020 & loanpurpose == "Purchase" using "W:\Optimal Blue\source data\Historical\OptimalBlue_FullDataset.dta", clear
		
	*Filters
	*Loan Type
            replace loantype = "RHS" if loantype == "USDA" // 5
			drop if !inlist(loantype, "Conforming", "NonConforming", "FHA", "VA", "RHS")
			
	*Screening for outliers
		replace dtiratio =. if !inrange(dtiratio, 0, 70)
		replace ltv = . if !inrange(ltv, 1, 110)
		replace FICO = . if !inrange(representativefico, 300, 850)
		
		count if FICO ==.
		
	*FICO buckets
		gen FICO_Buckets_300 = cond(FICO>=300 & FICO<=619, 1, 0) //change to combine bottom two buckets
			gen FICO_Buckets_620 = cond(FICO>=620 & FICO<=639, 1, 0)
			gen FICO_Buckets_640 = cond(FICO>=640 & FICO<=659, 1, 0)
			gen FICO_Buckets_660 = cond(FICO>=660 & FICO<=689, 1, 0)
			gen FICO_Buckets_690 = cond(FICO>=690 & FICO<=719, 1, 0)
			gen FICO_Buckets_720 = cond(FICO>=720 & FICO<=769, 1, 0)
			gen FICO_Buckets_770 = cond(FICO>=770 & FICO !=., 1, 0)		
	
	preserve
	
	gcollapse (mean) FICO_Buckets_300 FICO_Buckets_620 FICO_Buckets_640 ///
		FICO_Buckets_660 FICO_Buckets_690 FICO_Buckets_720 FICO_Buckets_770, by(b_year week loantype)
	
	sort loantype b_year week
	
	gen loantype2 = loantype
	drop loantype
	rename loantype2 loantype
	order loantype week //Ask Neil why this is here
	
		replace loantype = "Non_conform" if loantype == "NonConforming"  // for export 
		
		reshape wide FICO_Buckets_300 - FICO_Buckets_770, i(b_year week) j(loantype) str		
	
	export excel *Conforming using "$path", sh("Flash Report Charts", modify) cell(EL6) keepcellfmt 
	export excel *Non_conform using "$path", sh("other potential charts", modify) cell(Q6) keepcellfmt //Not in Flash report
	export excel *FHA using "$path", sh("Flash Report Charts", modify) cell(FB6) keepcellfmt 
	export excel *VA using "$path", sh("Flash Report Charts", modify) cell(FR6) keepcellfmt 	
	export excel *RHS using "$path", sh("other potential charts", modify) cell(AG6) keepcellfmt 		//Not in Flash report
	
	restore
	
	gcollapse (mean) FICO_Buckets_300 FICO_Buckets_620 FICO_Buckets_640 ///
		FICO_Buckets_660 FICO_Buckets_690 FICO_Buckets_720 FICO_Buckets_770, by(b_year week)
		
	sort b_year week
	export excel FICO* using "$path", sh("Flash Report Charts", modify) cell(DW6) keepcellfmt 


*Awful Tables
	*Tables 1 & 2
	use "W:\Optimal Blue\matching\Data\OB_temp_daily_collapsed.dta", clear
	
	/*ONE TIME FIX FOR WEEK 8 OVERLAP
		replace week = week + 1 if b_year == 2021
		expand 2 if week == 8 & b_year == 2020, gen(overlap)
		replace week = week + 1 if overlap == 1
		drop if week == 9 & b_year == 2020 & overlap != 1
		*/

			replace cashoutamount = round(cashoutamount, 100)

			gen date = (string(b_year)+"w"+string(week))
			
			keep fico_avg ltv_avg dti_avg mri locks cashoutamount type_order b_year week purpose date
			
			gen year2 = b_year //unncessary now that we're using b_year but whatever
			
			sum year2
				global y = `r(max)'
				global yl = `r(max)' - 1
			sum week if year2 == $y
				global w = `r(max)'
				global wl = 8 // Hardcode for start of the COVID-19 crisis
				global wb = 20 //Hardcode for the 'end' of the worst of the crisis
					
			keep if year2 == $y & week == $w | year2 == $yl & week == $wl | year2 == $yl & week == $w | year2 == $yl & week == $wb
			
			gsort purpose type_order -b_year -week
			
		preserve	
		
		*Levels tables
		keep type_order date purpose fico_avg dti_avg ltv_avg mri	
		reshape wide fico_avg dti_avg ltv_avg mri, i( purpose type_order) j(date) string
		
		local varlist = "fico_avg${yl}w${wb} ltv_avg${yl}w${wb} dti_avg${yl}w${wb} fico_avg${y}w${w} ltv_avg${y}w${w} dti_avg${y}w${w} fico_avg${yl}w${wl} ltv_avg${yl}w${wl} dti_avg${yl}w${wl} fico_avg${yl}w${w} ltv_avg${yl}w${w} dti_avg${yl}w${w}"
		foreach var in `varlist' {
				replace `var' = round(`var', 0.1)
				}
				
		local varlist = "mri${yl}w${wb} mri${y}w${w} mri${yl}w${wl} mri${yl}w${w}"
		foreach var in `varlist' {
				replace `var' = round(`var', 0.001)
				}
		
		order fico_avg${y}w${w} fico_avg${yl}w${wb} fico_avg${yl}w${wl} fico_avg${yl}w${w} ///
			  ltv_avg${y}w${w} ltv_avg${yl}w${wb} ltv_avg${yl}w${wl} ltv_avg${yl}w${w} /// 
			  dti_avg${y}w${w} dti_avg${yl}w${wb} dti_avg${yl}w${wl} dti_avg${yl}w${w} ///
			  mri${y}w${w} mri${yl}w${wb} mri${yl}w${wl} mri${yl}w${w}
		
		*levels
		export excel fico_avg${y}w${w} -  mri${yl}w${w} ///
			if purpose == "p" & type_order != 0 using "$path", sh("Flash Report Charts", modify) cell(GB60) keepcellfmt
					
		export excel fico_avg${y}w${w} -  mri${yl}w${w} ///
			if purpose == "co" & !inlist(type_order, 0, 5) using "$path", sh("Flash Report Charts", modify) cell(GB69) keepcellfmt
					
		export excel fico_avg${y}w${w} -  mri${yl}w${w} ///
			if purpose == "nco" & type_order != 0 using "$path", sh("Flash Report Charts", modify) cell(GB77) keepcellfmt
			
		restore
			
			foreach y in fico_avg ltv_avg dti_avg mri {
				by purpose type_order: gen double change_yoy_`y' = `y'[1] - `y'
				}
				
			by purpose type_order: gen double change_yoy_locks = locks[1] / locks - 1
			
			bys purpose date: egen total_locks = total(locks) if type_order != 0
				gen double share = locks / total_locks
							
			keep type_order date purpose change* share cashoutamount
			
			reshape wide change* share cashoutamount, i( purpose type_order) j(date) string

			replace change_yoy_mri${yl}w${wb} = 100*change_yoy_mri${yl}w${wb}
			replace change_yoy_mri${yl}w${wl} = 100*change_yoy_mri${yl}w${wl}
			replace change_yoy_mri${yl}w${w} = 100*change_yoy_mri${yl}w${w}

	local varlist = "change_yoy_fico_avg${yl}w${wb} change_yoy_fico_avg${yl}w${wl} change_yoy_fico_avg${yl}w${w} change_yoy_ltv_avg${yl}w${wb} change_yoy_ltv_avg${yl}w${wl} change_yoy_ltv_avg${yl}w${w} change_yoy_dti_avg${yl}w${wb} change_yoy_dti_avg${yl}w${wl} change_yoy_dti_avg${yl}w${w} change_yoy_mri${yl}w${wb} change_yoy_mri${yl}w${wl} change_yoy_mri${yl}w${w}"
		foreach var in `varlist' {
				replace `var' = round(`var', 0.1)
				}
				*recast double `varlist'
	local varlist = "share${y}w${w} share${yl}w${wb} share${yl}w${wl} share${yl}w${w} change_yoy_locks${yl}w${wb} change_yoy_locks${yl}w${wl} change_yoy_locks${yl}w${w}"			
				foreach var in `varlist' {
					replace `var' = round(`var', 0.01)
					}
				*recast double `varlist'
			
				* Table 1
			export excel change_yoy_fico_avg${yl}w${wb} change_yoy_fico_avg${yl}w${wl} change_yoy_fico_avg${yl}w${w} change_yoy_ltv_avg${yl}w${wb} change_yoy_ltv_avg${yl}w${wl} change_yoy_ltv_avg${yl}w${w} ///
						 change_yoy_dti_avg${yl}w${wb} change_yoy_dti_avg${yl}w${wl} change_yoy_dti_avg${yl}w${w} change_yoy_mri${yl}w${wb} change_yoy_mri${yl}w${wl} change_yoy_mri${yl}w${w} ///
						if purpose == "p" & type_order != 0 using "$path", sh("Flash Report Charts", modify) cell(GB8) keepcellfmt
						
			export excel change_yoy_fico_avg${yl}w${wb} change_yoy_fico_avg${yl}w${wl} change_yoy_fico_avg${yl}w${w} change_yoy_ltv_avg${yl}w${wb} change_yoy_ltv_avg${yl}w${wl} change_yoy_ltv_avg${yl}w${w} ///
						 change_yoy_dti_avg${yl}w${wb} change_yoy_dti_avg${yl}w${wl} change_yoy_dti_avg${yl}w${w} change_yoy_mri${yl}w${wb} change_yoy_mri${yl}w${wl} change_yoy_mri${yl}w${w} ///
						if purpose == "co" & !inlist(type_order, 0, 5) using "$path", sh("Flash Report Charts", modify) cell(GB23) keepcellfmt
						
			export excel change_yoy_fico_avg${yl}w${wb} change_yoy_fico_avg${yl}w${wl} change_yoy_fico_avg${yl}w${w} change_yoy_ltv_avg${yl}w${wb} change_yoy_ltv_avg${yl}w${wl} change_yoy_ltv_avg${yl}w${w} ///
						 change_yoy_dti_avg${yl}w${wb} change_yoy_dti_avg${yl}w${wl} change_yoy_dti_avg${yl}w${w} change_yoy_mri${yl}w${wb} change_yoy_mri${yl}w${wl} change_yoy_mri${yl}w${w} ///
						if purpose == "nco" & type_order != 0 using "$path", sh("Flash Report Charts", modify) cell(GB37) keepcellfmt
	
				* Table 2
			export excel change_yoy_locks${yl}w${wl} change_yoy_locks${yl}w${w} share${y}w${w} share${yl}w${wl} share${yl}w${w} ///
						if purpose == "p" & type_order != 5 using "$path", sh("Flash Report Charts", modify) cell(GP9) keepcellfmt				
				
			export excel change_yoy_locks${yl}w${wl} change_yoy_locks${yl}w${w} share${yl}w${w} share${yl}w${wl} share${yl}w${w} cashoutamount${y}w${w} ///
						if purpose == "co" using "$path", sh("Flash Report Charts", modify) cell(GP20) keepcellfmt	
						
			export excel change_yoy_locks${yl}w${wl} change_yoy_locks${yl}w${w} share${y}w${w} share${yl}w${wl} share${yl}w${w} ///
						if purpose == "nco" &type_order != 5 using "$path", sh("Flash Report Charts", modify) cell(GP31) keepcellfmt
						

*Counts by price tier
	use loanamount loanpurpose month year FIPSCODE b_year week ltv if loanpurpose == "Purchase" using "W:\Optimal Blue\matching\Data\OB_temp_daily_matched.dta", clear 
                
                gen price_impute = loanamount / ltv * 100
                gen quarter = ceil(real(month)/3)
                destring year, replace
                

			// Create Price Tiers
                rename FIPSCODE fips
                merge m:1 fips year quarter using "X:\tobias\intermed data\price_tiers.dta", keepusing(g1 g2* g3* ) keep(1 3) nogen

                gen tier = .
                replace tier = 1 if price_impute < g1 & tier == . & !inlist(price_impute, 0, .)
                replace tier = 2 if price_impute < g2 & tier == . & !inlist(price_impute, 0, .)
                replace tier = 3 if price_impute <= g3 & tier == . & !inlist(price_impute, 0, .)
                replace tier = 4 if price_impute > g3 & tier == . & !inlist(price_impute, 0, .)

				*drop if inlist(dow, 0, 6)
				
		gcollapse (count) locks = loanamount, by(b_year week tier)
			drop if tier == .
			reshape wide locks, i(b_year week) j(tier)
		export excel locks* using "$path", sh("Flash Report Charts", modify) cell(GY6) keepcellfmt 
		

*Color-coded metro table
	*default to CSA if CBSA is missing (Tampa, mainly)
	use b_year loanpurpose week loanamount rank_pr cbsa_short if loanpurpose == "Purchase" & b_year >= 2020 using "W:\Optimal Blue\source data\Historical\OptimalBlue_FullDataset", clear
	
		*national numbers
		bys b_year week: egen nation_locks = count(loanamount)
					
		keep if rank_pr <= 40
		
			sum b_year
				global y = `r(max)'
				global yl = `r(max)' - 1
			sum week if b_year == $y
				global w = `r(max)'
				global wl = `r(max)' - 1			
				*replace week = $w if week == $wl
				
		keep if b_year == $y & inlist(week, $w, $wl) | b_year == $yl & inlist(week, $w, $wl)
		
		gcollapse (count) locks = loanamount (mean) nation_locks, by(cbsa_short b_year week)	
	
			expand 2 if cbsa_short == "Atlanta, GA", gen(nation)
			replace cbsa_short = "Nation" if nation == 1
			replace locks = nation_locks if cbsa_short == "Nation"
	
	sort week cbsa_short b_year
	by week cbsa_short: gen change = (locks[2]-locks[1])/locks[1]
	duplicates drop week cbsa_short, force
	
	keep cbsa_short change week
	reshape wide change, i(cbsa_short) j(week)
	sort change$w
	
	order cbsa_short change$w change$wl
	
	replace cbsa_short = "Riverside-SB, CA" if cbsa_short == "Riverside_SB, CA"
	
	export excel using "$path", sh("Flash Report Charts", modify) cell(IG5) keepcellfmt


*Color-coded 3-period metro table
	*default to CSA if CBSA is missing (Tampa, mainly)
	use b_year loanpurpose week loanamount rank_pr cbsa_short if loanpurpose == "Purchase" & b_year >= 2019 using "W:\Optimal Blue\source data\Historical\OptimalBlue_FullDataset", clear

			*national numbers
			bys b_year week: egen nation_locks = count(loanamount)
			
			keep if rank_pr <= 40

		gcollapse (count) locks = loanamount (mean) nation_locks, by(cbsa_short b_year week)

			expand 2 if cbsa_short == "Atlanta, GA", gen(nation)
			replace cbsa_short = "AANation" if nation == 1
			replace locks = nation_locks if cbsa_short == "AANation"
			
			*2021 fix
			replace week = 100 if b_year > 2020
			replace b_year = 2020 if b_year > 2020

			sum b_year
				global y1 = `r(max)'
				global y2 = `r(max)' - 1
			sum week if b_year == $y1
				global w1 = `r(max)'
				global w2 = 21 //`r(max)' - 5
			
		gen t = .
			replace t = 1 if inrange(week, 1, 8)
			replace t = 2 if inrange(week, 14, 17)
			replace t = 3 if inrange(week, $w2, $w1)
			
			drop if t == .
			
		gcollapse (sum) locks, by(cbsa_short b_year t)
		
		reshape wide locks, i(cbsa_short t) j(b_year)
		
		gen yoy_change_ = (locks2020/locks2019) - 1
		drop locks*
		reshape wide yoy_change, i(cbsa_short) j(t)
		
		replace cbsa_short = "Nation" if cbsa_short == "AANation"
		replace cbsa_short = "Riverside-SB, CA" if cbsa_short == "Riverside_SB, CA"
		
	export excel using "$path", sh("Flash Report Charts", modify) cell(IN5) keepcellfmt 	
	
*Color-coded state table
	use state_name week b_year loanpurpose if loanpurpose == "Purchase" & b_year >= 2019 using "W:\Optimal Blue\source data\Historical\OptimalBlue_FullDataset", clear			
			rename state_name state
			drop if state == ""
			
			expand 2, gen(nation)
			replace state = "AANation" if nation == 1
				
			sum b_year
				global y1 = `r(max)'
				global y2 = `r(max)' - 1
			sum week if b_year == $y1
				global w1 = `r(max)'
				*global w2 = `r(max)' - 1
				
		keep if inlist(b_year, $y1, $y2) & inlist(week, $w1)
		
		
		table state week b_year, replace
		by state week: gen yoy = table1 / table1[1] - 1
				
				keep if b_year == $y1
					*replace yoy = (yoy + yoy[_n-1]) / 2 if week == $w1 & b_year == $y1 & inlist(state, "Alaska", "North Dakota", "South Dakota", "Vermont", "Wyoming", "Hawaii", "District of Columbia") 
					*keep if week == $w1
				
				replace state = "Nation" if state == "AANation"
	
	export excel state yoy using "$path", sh("Flash Report Charts", modify) cell(IK5) keepcellfmt 

	
	
	
*Other potential charts tab					
*Cash-out MRI
	use week b_year loanamount loantype Limit purpose adj_default_rate if purpose == "co" & b_year >= 2019 using "W:\Optimal Blue\source data\Historical\OptimalBlue_FullDataset", clear

		   rename loantype loantype_ob
		   
				gen loantype = loantype_ob if !inlist(loantype_ob, "Conforming", "NonConforming")
							replace loantype = "Conforming" if loanamount <= Limit & inlist(loantype_ob, "Conforming", "NonConforming")
							replace loantype = "NonConforming" if loanamount > Limit & inlist(loantype_ob, "Conforming", "NonConforming")
		
		            replace loantype = "RHS" if loantype == "USDA" // 5
					drop if !inlist(loantype, "Conforming", "NonConforming", "FHA", "VA", "RHS")
			
				expand 2, gen(overall)
				replace loantype = "Overall" if overall == 1
				
                gcollapse (mean) adj_default_rate, by(b_year week loantype)
                reshape wide adj_default_rate, i(b_year week) j(loantype) string
				
				drop *RHS
				order *Overall *Conforming *NonConforming *FHA *VA             
                *keep if b_year >= 2019
				
				export excel adj_default_rate* using "$path", sh("other potential charts", modify) cell(CT5) keepcellfmt
				
				
				
				
/*APOR Rate Spread
use loanterm amortizationtype loanpurpose loantype month day year b_year week noterate representativefico totalloanamount ltv if b_year >= 2020 using "W:\Optimal Blue\source data\Historical\OptimalBlue_FullDataset", clear
	keep if loanterm == "30 Yr" & amortizationtype == "Fixed"
	keep if loanpurpose == "Purchase" & inlist(loantype, "Conforming")
	
	
	gen dow = dow(mdy( real(month), real(day), real(year)))
	bys b_year week: egen apor = mean(noterate) if representativefico >= 740 & inrange(ltv, 60, 80) & inrange(dow, 1, 3)
	
	sort b_year week apor
		by b_year week: carryforward apor, replace

		gen rate_spread = noterate - apor
		gen rate_spread_35 = rate_spread + .35
		gen rate_spread_40 = rate_spread + .4
		gen rate_spread_30 = rate_spread + .3
		gen rate_spread_25 = rate_spread + .25

