*HMDA 2020 import
*lender list
clear
forval y = 2017/2019 {
append using "M:\ICHR\HMDA\Data\TS records - Institution Names\HMDA_TS_`y'.dta"
}

append using "M:\ICHR\HMDA\Data\LAR files\HMDA_LAR_2020_limited.dta", keep(lei)

	keep lei
	duplicates drop lei, force


levelsof lei, local (levels)
foreach i of local levels {
                capture import delimited "https://s3.amazonaws.com/cfpb-hmda-public/prod/modified-lar/2020/`i'.txt", delimiters("|") clear
                qui capture save "M:\ICHR\HMDA\Source\2020 lenders\a_`i'.dta", replace
                }

clear
forval y = 2018/2019 {
	append using "M:\ICHR\HMDA\Data\TS records - Institution Names\HMDA_TS_`y'.dta"
}
append using "M:\ICHR\HMDA\Data\LAR files\HMDA_LAR_2020_limited.dta", keep(lei)

	keep lei
	duplicates drop lei, force
	drop if lei == ""
	
	save "W:\Mike\HMDA import\lender list.dta", replace
	
	
		
levelsof lei, local (levels)
	foreach i of local levels {
			capture use "M:\ICHR\HMDA\Source\2020 lenders\a_`i'.dta", clear
				capture tostring v11, replace force //county
				capture destring v12, replace force //census tract
				capture tostring v45, replace force //income
				capture tostring v65, replace force //loan term
				capture save "M:\ICHR\HMDA\Source\2020 lenders\b_`i'.dta", replace
			}

use "W:\Mike\HMDA import\lender list.dta", clear

levelsof lei, local (levels)
foreach i of local levels {
         capture append using "M:\ICHR\HMDA\Source\2020 lenders\b_`i'.dta", force
}



drop lei
drop if v1 == .
drop h2su2sqgkj938-pr
*drop bake4vahvcu55 - na
save "M:\ICHR\HMDA\Data\Intermediate\hmda_2020_temp.dta", replace
	
*conform to 2018/19
use "M:\ICHR\HMDA\Data\Intermediate\hmda_2020_temp.dta", clear 

rename v1 activity_year
rename v2 lei
rename v3 loan_type
rename v4 loan_purpose
rename v5 preapproval
rename v6 construction_method
rename v7 occupancy_type
rename v8 loan_amount
rename v9 action_taken
rename v10 state_code
rename v11 county_code
rename v12 census_tract
rename v13 applicant_ethnicity_1
rename v14 applicant_ethnicity_2 
rename v15 applicant_ethnicity_3
rename v16 applicant_ethnicity_4
rename v17 applicant_ethnicity_5
rename v18 co_applicant_ethnicity_1
rename v19 co_applicant_ethnicity_2
rename v20 co_applicant_ethnicity_3
rename v21 co_applicant_ethnicity_4
rename v22 co_applicant_ethnicity_5
rename v23 ethnicity_observed
rename v24 co_applicant_ethnicity_observed
rename v25 applicant_race_1
rename v26 applicant_race_2
rename v27 applicant_race_3
rename v28 applicant_race_4
rename v29 applicant_race_5
rename v30 co_applicant_race_1 
rename v31 co_applicant_race_2
rename v32 co_applicant_race_3
rename v33 co_applicant_race_4
rename v34 co_applicant_race_5 
rename v35 applicant_race_observed
rename v36 co_applicant_race_observed
rename v37 applicant_sex
rename v38 co_applicant_sex
rename v39 applicant_sex_observed
rename v40 co_applicant_sex_observed
rename v41 applicant_age
rename v42 applicant_age_above_62
rename v43 co_applicant_age
rename v44 co_applicant_age_above_62
rename v45 income
rename v46 purchaser_type
rename v47 rate_spread
rename v48 hoepa_status
rename v49 lien_status
rename v50 applicant_credit_score_type
rename v51 co_applicant_credit_score_type
rename v52 denial_reason_1
rename v53 denial_reason_2
rename v54 denial_reason_3
rename v55 denial_reason_4
rename v56 total_loan_costs
rename v57 total_points_and_fees
rename v58 origination_charges
rename v59 discount_points
rename v60 lender_credits
rename v61 interest_rate
rename v62 prepayment_penalty_term
rename v63 debt_to_income_ratio
rename v64 combined_loan_to_value_ratio
rename v65 loan_term
rename v66 intro_rate_period
rename v67 balloon_payment
rename v68 interest_only_payment
rename v69 negative_amortization
rename v70 other_nonamortizing_features
rename v71 property_value
rename v72 manufactured_home_secured_proper
rename v73 manufactured_home_land_property_
rename v74 total_units
rename v75 multifamily_affordable_units
rename v76 submission_of_application
rename v77 initially_payable_to_institution
rename v78 aus_1
rename v79 aus_2
rename v80 aus_3
rename v81 aus_4
rename v82 aus_5
rename v83 reverse_mortgage
rename v84 open_end_line_of_credit
rename v85 business_or_commercial_purpose

bys lei loan_type loan_purpose preapproval occupancy_type loan_amount action_taken state_code income county_code census_tract ///
	applicant_ethnicity_1 co_applicant_ethnicity_1 applicant_race_1 co_applicant_race_1 applicant_sex co_applicant_sex applicant_age ///
	rate_spread lien_status combined_loan_to_value_ratio debt_to_income_ratio loan_term: gen n = _n
*bys LegalEntityIdentifier Loan_Type Loan_Purpose Preapproval Occupancy_Type Loan_Amount Action_Taken State Income County Census_Tract ///
	*EthnicityApp_1 EthnicityCoapp_1 RaceApp_1 RaceCoApp_1 Sex_App Sex_CoApp Age_App Rate_Spread Lien_status CLTV DTI LoanTerm: gen tot = _N
	keep if n == 1
	drop n
	
	*FIPS
		destring county_code, replace force
		gen county_code_t = string(county_code, "%05.0f")
		replace county_code_t = "NA" if county_code == .
		
		gen census_tract_t = string(census_tract, "%011.0f")
		
		drop census_tract county_code
		rename (census_tract_t county_code_t) (census_tract county_code)
	
		replace census_tract = "" if census_tract == "."
	*census tract
	
	save "M:\ICHR\HMDA\Data\LAR files\HMDA_LAR_2020.dta", replace



