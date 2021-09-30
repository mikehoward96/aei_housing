/*HMDA loan amount histograms
Kernel plots of loan amounts
POO, 1st lien, SF purchase
By Conv, FHA, VA and RHS
For GSEs as well (action_taken == 6, purchaser_type == 1 or 3
*/
cd "W:\Mike\HMDA import\histograms"
global path "W:\Mike\HMDA import\histograms"

use loan_type loan_purpose occupancy loan_amount action_taken purchaser_type lien_status total_units reverse_mortgage open_end_line_of_credit ///
if loan_purpose == 1 & lien_status == 1 & occupancy == 1 using ///
"M:\ICHR\HMDA\Data\LAR files\HMDA_LAR_2020_limited.dta", clear

	*filters
	drop if loan_amount > 1000000 //100k dropped
	keep if inlist(action_taken, 1, 6) //2m dropped
	*keep if inlist(total_units, "1", "2", "3", "4") //3.6m dropped
	*left with 2.5m
	
	drop if reverse_mortgage == 1
	drop if open_end_line_of_credit == 1
	
	gen la = loan_amount/1000
	
	twoway kdensity la if action_taken == 1, w(10) title("HMDA 2020: Density Plot of Loan Amounts", size(med)) lcolor(black) ///
	xtitle("Loan Amount ($1000s)") ytitle("Percent") ///
	note("Bins are $10,000 wide. Data are for 1st lien, single-family, primary-owner occupied purchase loans for <$1,000,000.", size(vsmall)) || ///
	kdensity la if action_taken == 1 & loan_type == 4, w(10) lcolor(red) ///
	xlabel(#10) ylabel(0 "0" 0.002 "2" 0.004 "4" 0.006 "6" 0.008 "8") xmticks(0(25)1000) ///
	|| kdensity la if action_taken == 6 & inlist(purchaser_type, 1, 3), lcolor(gold) ///
	|| kdensity la if action_taken == 1 & loan_type == 1, lcolor(green) ///
	|| kdensity la if action_taken == 1 & loan_type == 2, ///
	|| kdensity la if action_taken == 1 & loan_type == 3 ///
	, legend(order(1 "Overall" 2 "RHS" 3 "GSEs" 4 "Conv." 5 "FHA" 6 "VA") position(0) bplacement(neast))
		
		graph export "$path\HMDA_combined_v2.png", replace
	


	
*Find NMRI GSE counts in 10,000 price bins
use Agency LoanAmount Purpose Occupancy OrigYear if OrigYear == 2020 & Purpose == "Purchase" & Occupancy == "Principal" ///
using "M:\ICHR\Mortgage Risk Index\Monthly Update\Intermediate\current month.dta", clear

	drop if LoanAmount > 1000000
	replace Agency = "GSE" if inlist(Agency, "FHLMC", "FNMA")
	drop if Agency == "Native Am"
	
	egen la_bin = cut(LoanAmount), at(0(10000)1000000)
	
 gcollapse (count) count_nmri = LoanAmount, by(la_bin Agency)
 sort Agency la_bin
	drop if la_bin == .
	
	fillin Agency la_bin
	replace count = 0 if _f == 1
	drop _f
	
save "nmri_bin_counts.dta", replace
	

	
use loan_type loan_purpose occupancy loan_amount action_taken purchaser_type lien_status total_units reverse_mortgage open_end_line_of_credit ///
if loan_purpose == 1 & lien_status == 1 & occupancy == 1 using ///
"M:\ICHR\HMDA\Data\LAR files\HMDA_LAR_2020_limited.dta", clear
*"M:\ICHR\HMDA\Data\LAR files\HMDA_LAR_2019.dta", clear
	*filters
	drop if loan_amount > 1000000 
	keep if inlist(action_taken, 1) //also tried 1 and 6
	*keep if inlist(total_units, "1", "2", "3", "4") //garbage
	
	
		drop if reverse_mortgage == 1
		drop if open_end_line_of_credit == 1

	
	gen Agency = ""
		replace Agency = "GSE" if loan_type == 1 //not actually GSEs, but we need to merge on the counts
		replace Agency = "FHA" if loan_type == 2
		replace Agency = "VA" if loan_type == 3
		replace Agency = "Rural" if loan_type == 4
		
	drop if Agency == "" //0
	
	/*  HMDA's loan amount bins are weird. They are already binned by 10,000's, but they are recorded
		as the 'midpoint' of that bin. We can therefore just cut like we do for the NMRI and it will work. */
	
	egen la_bin = cut(loan_amount), at(0(10000)1000000)
 
 gcollapse (count) count_hmda = loan_amount, by(la_bin Agency)
 sort Agency la_bin
	drop if la_bin == .
	
	fillin Agency la_bin
	replace count = 0 if _f == 1
	drop _f	
	
merge 1:1 Agency la_bin using "nmri_bin_counts.dta", nogen

save "merged_bin_counts.dta", replace

use "merged_bin_counts.dta", clear
	
	*gen ratio = count_hmda / count_nmri
	gen dif = count_hmda - count_nmri
	replace count_hmda = dif if Agency == "GSE"
	replace Agency = "Conv" if Agency == "GSE"
	
	keep la_bin Agency count_hmda
	reshape wide count_hmda, i(la_bin) j(Agency) string

	
/*
	
	*Overall, GSEs, 4 loan types  
	twoway kdensity la if action_taken == 1, w(10) title("HMDA 2020: Overall (Originated Loans)", size(med)) ///
	xtitle("Loan Amount ($1000s)") ytitle("Percent") note("Bins are $10,000 wide") || ///
	kdensity la if action_taken == 1 & loan_type == 4, w(10) lcolor(red) legend(order(1 "Overall" 2 "RHS")) ///
	xlabel(#10) ylabel(0 "0" 0.002 "2" 0.004 "4" 0.006 "6" 0.008 "8") xmticks(0(25)1000)
		graph export "$path\HMDA_overall.png", replace
	
	*GSEs
	twoway kdensity la if action_taken == 6 & inlist(purchaser_type, 1, 3), w(10) title("HMDA 2020: Fannie & Freddie", size(med)) ///
	xtitle("Loan Amount ($1000s)") ytitle("Percent") note("Bins are $10,000 wide") || ///
	kdensity la if action_taken == 1 & loan_type == 4, w(10) lcolor(red) legend(order(1 "F&F" 2 "RHS")) ///
	xlabel(#10) ylabel(0 "0" 0.002 "2" 0.004 "4" 0.006 "6" 0.008 "8") xmticks(0(25)1000)
		graph export "$path\HMDA_GSEs.png", replace
		
	*action taken = 1, 4 loan types
	twoway kdensity la if action_taken == 1 & loan_type == 1, w(10) title("HMDA 2020: Conventional", size(med)) ///
	xtitle("Loan Amount ($1000s)") ytitle("Percent") note("Bins are $10,000 wide") || ///
	kdensity la if action_taken == 1 & loan_type == 4, w(10) lcolor(red) legend(order(1 "Conventional" 2 "RHS")) ///
	xlabel(#10) ylabel(0 "0" 0.002 "2" 0.004 "4" 0.006 "6" 0.008 "8") xmticks(0(25)1000)
		graph export "$path\HMDA_conventional.png", replace
		
	twoway kdensity la if action_taken == 1 & loan_type == 2, w(10) title("HMDA 2020: FHA", size(med)) ///
	xtitle("Loan Amount ($1000s)") ytitle("Percent") note("Bins are $10,000 wide") || ///
	kdensity la if action_taken == 1 & loan_type == 4, w(10) lcolor(red) legend(order(1 "FHA" 2 "RHS")) ///
	xlabel(#10) ylabel(0 "0" 0.002 "2" 0.004 "4" 0.006 "6" 0.008 "8") xmticks(0(25)1000)
		graph export "$path\HMDA_fha.png", replace
		
	twoway kdensity la if action_taken == 1 & loan_type == 3, w(10) title("HMDA 2020: VA", size(med)) ///
	xtitle("Loan Amount ($1000s)") ytitle("Percent") note("Bins are $10,000 wide") || ///
	kdensity la if action_taken == 1 & loan_type == 4, w(10) lcolor(red) legend(order(1 "VA" 2 "RHS")) ///
	xlabel(#10) ylabel(0 "0" 0.002 "2" 0.004 "4" 0.006 "6" 0.008 "8") xmticks(0(25)1000)
		graph export "$path\HMDA_va.png", replace
		
	twoway kdensity la if action_taken == 1 & loan_type == 4, w(10) title("HMDA 2020: RHS", size(med)) ///
	xtitle("Loan Amount ($1000s)") ytitle("Percent") note("Bins are $10,000 wide") ///
	lcolor(red) legend(order(1 "RHS")) ///
	xlabel(#10) ylabel(0 "0" 0.002 "2" 0.004 "4" 0.006 "6" 0.008 "8") xmticks(0(25)1000)
		graph export "$path\HMDA_rhs.png", replace
	
*/
                *Overall, originated, purchased by institution   
                hist loan_amount, kden w(10000) title("Overall") percent
                                graph export "$path\HMDA_overall.png", replace
                hist loan_amount if action_taken == 1, kden w(10000) title("Overall: Action Taken = 1") percent
                                graph export "$path\HMDA_overall_1.png", replace
                hist loan_amount if action_taken == 6, kden w(10000) title("Overall: Action Taken = 6") percent
                                graph export "$path\HMDA_overall_6.png", replace
                
                *GSEs
                hist loan_amount if action_taken == 6 & inlist(purchaser_type, 1, 3), kden w(10000) title("Fannie & Freddie") percent
                                graph export "$path\HMDA_GSEs.png", replace
                                
                *action taken = 1, 4 loan types
                hist loan_amount if action_taken == 1 & loan_type == 1, kden w(10000) title("Conventional") percent
                                graph export "$path\HMDA_conventional.png", replace
                hist loan_amount if action_taken == 1 & loan_type == 2, kden w(10000) title("FHA") percent
                                graph export "$path\HMDA_fha.png", replace
                hist loan_amount if action_taken == 1 & loan_type == 3, kden w(10000) title("VA") percent
                                graph export "$path\HMDA_va.png", replace
                hist loan_amount if action_taken == 1 & loan_type == 4, kden w(10000) title("RHS") percent
                                graph export "$path\HMDA_rhs.png", replace



