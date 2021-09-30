*Delinquency rates at the zip code level

cd "W:\Mike\Delinquency"
global month1 202001 //older month
global month2 202006 //later month


/*Save McDash skinny performance file for Jan. 2020 (Sian already made the ones for June 2020)
*Need: LoanId BankruptcyFlag (maybe) PaymentStatus
use LoanId BankruptcyFlag PaymentStatus using "J:\DataSets7\mcdash_dta_files\LoanMonth_481.dta", clear //hardcode. Change if months are changed
save "performance files\skinny_performance_McDash_$month1", replace

*moving Sian's file to my folder
use "W:\Sian\Intermediate\Tobias Request\Defaults May 2020\EdNotes486.dta", clear
save "performance files\skinny_performance_McDash_$month2", replace
*/



/*Adding MDR (avg. 2012-2019), percent minority and median price to income, median income, median sale price, median DTI, CTLV, FICO and POO.
use SitusZIP5 year month f_loan_type adj_default_rate price ApplicantIncome ApplicantEthnicity ApplicantRace1 f_dti f_cltv f_fico f_occupancy using "X:\tobias\intermed data\all_matched_risk_rated_final_721", clear
drop if year > 2019

expand 2, gen(overall)
replace f_loan_type = "Overall" if overall == 1

foreach t in "Overall" "GSE" "FHA" "RHS" "VA" "Private" {
	gen MDR_`t' = adj_default_rate if f_loan_type == "`t'"
	}

*price to income
gen PTI = price/(ApplicantIncome*1000)

*minority share
gen white = (ApplicantEthnicity != 1 & ApplicantRace1 == 5)  // non-hispanic whites
gen min = 1 - white 
				replace min = . if inlist(ApplicantRace1, 1, 2, 4)  // dropping Native Am, Asian, Hawaiian/ Pacific Islander
				replace min = . if ApplicantEthnicity > 2 | ApplicantRace1 > 5  // dropping if ethnicity not provided / not applicable

*POO
	gen POO = f_occupancy == "Principal"
		replace POO = . if f_occupancy == "" //none, but whatever
								
gcollapse (mean) MDR_* min POO (median) PTI income = ApplicantIncome price dti = f_dti cltv = f_cltv fico = f_fico, by(SitusZIP5)
drop if SitusZIP5 == ""
rename SitusZIP5 zip 
save "intermed\zip level MDR", replace
*/


use LoanId ProductType PurposeOfLoan MortgageType PropertyZipCode ClosingMonth using "U:\mcdash_dta_files\LoanCurrent_skinny.dta", clear

gen orig_year = 1980+floor((ClosingMonth-1)/12)
gen orig_month = cond(mod(ClosingMonth,12)==0,12,mod(ClosingMonth,12))

foreach t in "$month1" "$month2" {
preserve
merge 1:1 LoanId using "performance files\skinny_performance_McDash_`t'", keep(3) nogen

tostring PropertyZipCode, replace format(%05.0f) force
rename PropertyZipCode zip5 

*Loan Types
gen LoanType = 1 if inlist(ProductType,3,6)  //Conventional
replace LoanType = 2 if inlist(ProductType,1,5,7) //FHA
replace LoanType = 3 if ProductType == 2  // VA
keep if inlist(PurposeOfLoan,1,4,5,6)
gen purpose = cond(PurposeOfLoan==1,1,cond(PurposeOfLoan==4,2,cond(PurposeOfLoan==5,3,.)))
keep if inlist(MortgageType,1,4)

*Not included in NC or AC
drop if inlist(PaymentStatus, "R", "T", "X")

*Default status
gen Count=1
gen d30= 1 if PaymentStatus == "1"
gen d60= 1 if PaymentStatus == "2"
gen d90= 1 if PaymentStatus == "3" | PaymentStatus == "4"
gen dF= 1 if PaymentStatus == "F"

*Bankruptcy BR: Count of Bankruptcy, BR2: non 90+ or F count included.
gen BR = 1 if BankruptcyFlag==1
gen BR2 = 1 if BankruptcyFlag==1 & inlist(PaymentStatus, "1", "2")
gen BR3 =1 if BankruptcyFlag==1  & !inlist(PaymentStatus, "1", "2", "3", "4", "F" ) //non delinquent bankruptcy count

*Keep FHA, drop missing Loan purpose
*keep if LoanType==2
drop if purpose==.
drop if LoanType==.

collapse (sum) Count d30 d60 d90 dF BR BR2 BR3 , by(LoanType zip5)

gen NC = d30 + d60 + d90 +dF
gen SD= BR2 + d90 +dF

duplicates drop
drop BR2
sort LoanType zip5

drop if zip5 == ""
gen r_del = NC/Count
gen r_sdel = SD/Count

	foreach v in "d30" "d60" "d90" {
	gen r_`v' = `v'/Count
	}

save "intermed\McDash_nation_`t'", replace
restore
}


*LLMA
use loan_id loan_type loan_purpose property_zip original_balance using  "M:\ICHR\CoreLogic\LLMA 2.0\Final data set\LLMA_Originations_P&R_2000_current.dta", clear

foreach t in "$month1" "$month2" {
preserve
*Performance file for June 2020
merge 1:1 loan_id using "M:\ICHR\CoreLogic\LLMA 2.0\Final data set\LLMA_Performance_`t'", keep(3) nogen
gen LoanType = 1 if loan_type == "1"  //Conv
replace LoanType = 2 if loan_type == "3" //FHA
replace LoanType = 3 if loan_type == "2" //VA
drop if LoanType == .

gen purpose = cond(loan_purpose=="1",1,cond(loan_purpose=="3",2,cond(loan_purpose=="2",3,cond(loan_purpose=="5",.,4))))
drop if purpose == 4

gen zip5 = property_zip if substr(property_zip,-2,2) != "00"

gen Count =1 
gen d30= 1 if mba_delinquency_status == "3"
gen d60= 1 if mba_delinquency_status == "6"
gen d90= 1 if mba_delinquency_status == "9"
gen dF= 1 if  mba_delinquency_status == "F"
 
*Not included in NC or AC
drop if  inlist(mba_delinquency_status, "R", "S", "T", "X", "Z")

/*Bankruptcy BR: Count of Bankruptcy, BR2: non 90+ or F count icnluded.
gen BR = 1 if bk_flag=="Y"
gen BR2 = 1 if bk_flag=="Y" & inlist(mba_delinquency_status, "3", "6")
gen BR3 =1 if bk_flag=="Y"  & !inlist(mba_delinquency_status, "3", "6", "9", "F" ) //non delinquent bankruptcy count
*/

*Keep FHA, drop missing Loan purpose
*keep if LoanType==2


*Conforming
rename zip5 ZIP
merge m:1 ZIP using "W:\Mike\Crosswalks\zip_to_fips.dta", keepusing(fips) keep(1 3) nogen
rename ZIP zip5

rename fips Fips
gen Year = 2020
merge m:1 Fips Year using "W:\Mike\Crosswalks\fips_to_limit_skinny.dta", keepusing(Limit) keep(1 3)
	gen conf = . 
	replace conf =1 if (LoanType == 1 & original_balance <= Limit)
	replace conf =0 if (LoanType == 1 & original_balance > Limit)

	expand 2 if conf == 1, gen(conforming)
	replace LoanType = 5 if conforming == 1 //because conforming is a subset of conventional

collapse (sum) Count d30 d60 d90 dF, by(LoanType zip5)

gen NC = d30 + d60 + d90 +dF
gen SD= d90 +dF //+BR

duplicates drop
*drop BR2
sort LoanType zip5

drop if zip5 == ""
gen r_del = NC/Count
gen r_sdel = SD/Count

	foreach v in "d30" "d60" "d90" {
	gen r_`v' = `v'/Count
	}

save "intermed\LLMA_nation_`t'", replace
restore
}

/*fillin for HMDA weights
use "X:\tobias\analysis\Delinquency\intermed data\HMDA_2019_ZIP_counts.dta", clear
fillin zip loan_type
drop if _fillin == 1 & loan_type != 4 //not sure if I should have this in, but we're only doing this to fill in rural
bys zip: replace total = total[1] if _fillin == 1
replace count = 0 if _fillin == 1
replace share = count/total if _fillin == 1
save "intermed\HMDA_weights_Mike", replace
*/


foreach t in "$month1" "$month2" {
preserve
*Use FHA and VA from McDash, Conv. from LLMA. Assume Rural rates = VA rates Add HMDA weights and collapse down
use  "intermed\McDash_nation_`t'", clear
drop if zip5 == "."
keep if inlist(LoanType, 2, 3) //FHA and VA

save "intermed\McDash_intermed", replace

use  "intermed\LLMA_nation_`t'", clear
drop if zip5 == "."
keep if inlist(LoanType, 1, 5)

append using "intermed\McDash_intermed"

*assume the same same rates for Rural as for VA
expand 2 if LoanType == 3, gen(rural)
replace LoanType = 4 if rural == 1
drop if zip5 == "."

rename (zip5 LoanType) (zip loan_type)
merge 1:1 zip loan_type using "intermed\HMDA_weights_Mike", keepusing(share count) //keep(1 3) //LoanType 5 won't have a share

foreach x in 1 2 3 4 5 {
bys zip loan_type: egen sh_`x' = mean(share) if loan_type == `x'
bys zip: egen r_del_`x' = mean(r_del) if loan_type == `x'
bys zip: egen r_sdel_`x' = mean(r_sdel) if loan_type == `x'
}

replace Count = 0 if loan_type == 5 //to avoid double-counting conforming

save "intermed\temp", replace
collapse (sum) count (mean) r_* sh_*, by(zip)
rename (sh_1 sh_2 sh_3 sh_4 sh_5 r_del_1 r_del_2 r_del_3 r_del_4 r_del_5 r_sdel_1 r_sdel_2 r_sdel_3 r_sdel_4 r_sdel_5) (sh_conv sh_fha sh_va sh_rhs sh_conf del_conv del_fha del_va del_rhs del_conf sdel_conv sdel_fha sdel_va sdel_rhs sdel_conf)
keep count zip sh_conv sh_fha sh_va sh_rhs del_conv del_fha del_va del_rhs del_conf sdel_conv sdel_fha sdel_va sdel_rhs sdel_conf
save "intermed\temp2", replace

use "intermed\temp", clear

keep zip count r_del r_sdel share
collapse (mean) r_* [pweight=share], by(zip)
merge 1:1 zip using "intermed\temp2", keep(1 3) nogen

foreach x in sh_conv sh_fha sh_va sh_rhs {
replace `x' = 0 if `x' == .
}

*egen test = rowtotal(sh_conv sh_fha sh_va sh_rhs) //make sure shares are equal to one

rename zip ZIP
merge 1:1 ZIP using "W:\Mike\Crosswalks\zip_to_fips.dta", keepusing(fips) keep(1 3) nogen //100% match rate
merge m:1 fips using "Q:\Tobias\FirstAm PR\analysis\Price Tiers\county_xwalk.dta", keepusing(county state state_name cbsa_short) keep(1 3) nogen //100% match rate
merge m:1 cbsa_short using "X:\tobias\intermed data\metro_ranking_public_records_2019_May.dta", keep(1 3) nogen keepusing(rank_pr)
rename ZIP zip

rename (r_del r_sdel) (del sdel)
save "intermed\zip_delinquency_rates_`t'", replace
restore
}

*appending months
use "intermed\zip_delinquency_rates_$month2", clear
gen date = "$month2"
append using "intermed\zip_delinquency_rates_$month1"
replace date = "$month1" if date == ""

*Wide dataset
drop rank_pr //causing issues for some reason
reshape wide count del* sdel* sh*, i(zip fips county state state_name cbsa_short) j(date) string
merge m:1 cbsa_short using "X:\tobias\intermed data\metro_ranking_public_records_2019_May.dta", keep(1 3) nogen keepusing(rank_pr)
merge m:1 zip using "intermed\zip level MDR", keep(1 3) keepusing(MDR_Overall PTI min POO income price dti cltv fico) nogen
rename zip ZIP
merge m:1 ZIP using "W:\Optimal Blue\ZIP density and RUCA crosswalk.dta", keepusing(pop_density) keep(1 3)
rename ZIP zip

save "final dtas\delinquency $month1 to $month2 wide", replace

*long dataset
use "intermed\zip_delinquency_rates_$month2", clear
gen date = "$month2"
append using "intermed\zip_delinquency_rates_$month1"
replace date = "$month1" if date == ""

merge m:1 zip using "intermed\zip level MDR", keep(1 3) keepusing(MDR_Overall PTI min POO income price dti cltv fico) nogen
rename zip ZIP
merge m:1 ZIP using "W:\Optimal Blue\ZIP density and RUCA crosswalk.dta", keepusing(pop_density) keep(1 3)
rename ZIP zip

save "final dtas\delinquency $month1 to $month2 long", replace



