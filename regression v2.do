/* We want to calulcate a risk-adjusted note rate differential for low loan amounts, i.e.
do lower balance loans pay higher rates?
Use NMRI 2020 w/ typical filters.
Control for state FEs, risk profile (FICO, LTV, DTI, loan term), dummy vector for agency and orig_m
Create loan amount buckets
2020 CLL: $510,400

*/

cd "W:\Mike\low balance premium"

use Agency LoanAmount Purpose Occupancy OrigYear Orig NoteRate CLTV_Buckets DTI_Buckets FICO_Buckets State Loan_Term_Buckets ///
if OrigYear == 2020 & Purpose == "Purchase" & Occupancy == "Principal" ///
using "M:\ICHR\Mortgage Risk Index\Monthly Update\Intermediate\current month.dta", clear

*check earlier years
	*filters
	keep if LoanAmount <= 450000
	*hist NoteRate //looks okay, but some out there at 9 or 10%. Ask Tobias about screening
	*keep if inrange(NoteRate, 0, ?)
	*hist LoanAmount if NoteRate > 7 //all in lower buckets (<$70k)

	*Variable of interest: loan amount buckets
		egen la_bin = cut(LoanAmount), at(0(25000)450000)
		replace la_bin = 25000 if LoanAmount < 50000 
	
	*controls
		*agency
			drop if Agency == "Native Am"
			replace Agency = "GSE" if inlist(Agency, "FHLMC", "FNMA") //try leaving out this step
			encode Agency, gen(agency_e)
		
		*state
			encode State, gen(state_e)
			
		*risk profile
			replace DTI = DTI*100
			
	*N counts check
			tab la_bin
			
********************		
*****regression*****
********************

		areg NoteRate i.la_bin i.agency_e i.CLTV i.DTI i.FICO i.Loan_Term i.Orig, a(state_e)
			
			predict risk_adj_rate
			gen premium = risk_adj_rate - NoteRate
					
					margins i.la_bin
			
		/*reg premium i.la_bin
		
		
		*gcollapse (mean) NoteRate, by(la_bin)
