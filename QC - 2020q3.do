*Run globals in master to begin.

use "X:\Metro Data Interactive\Intermediate Data\all_original_data_$yq.dta", clear

*After working out fixes with Tobias, use the file below and rerun the graphs (save the original graphs in another folder if you want to compare)
*use "X:\Metro Data Interactive\Final DTAs\final_QC_$yq.dta", clear

keep if rank <= 60
sort cbsa_short orig


// share in that tier              

	// entry level 
		levelsof cbsa_short, local(levels)
		di `levels'
		foreach l of local levels {
		line share12 orig if cbsa_short == "`l'", ///
				title("`l'")       ///
				subtitle( " Loan Share by tier") ///
				ylabels(0(.1)1) ///
				xline(208 212 216 220 224 228 232 236 240) ///
				xlabel(208 "2012Q1" 212 "2013:Q1" 216 "2014:Q1"  220 "2015:Q1" 224 "2016:Q1" 228 "2017:Q1" 232 "2018:Q1" 236 "2019:Q1" 240 "2020:Q1")
				graph export "X:\Metro Data Interactive\QC\charts - $yq\tier\loan_share_`l'_$yq.png", replace
		}
		
		
// sale amt
           		
levelsof cbsa_short, local(levels)
di `levels'
foreach l of local levels {
line price price12 price34 orig if cbsa_short == "`l'", ///
                title("`l'")       ///
                subtitle( "Avg Sale Price (Instit. financed)") ///
				xline(208 212 216 220 224 228 232 236 240) ///
				xlabel(208 "2012Q1" 212 "2013:Q1" 216 "2014:Q1"  220 "2015:Q1" 224 "2016:Q1" 228 "2017:Q1" 232 "2018:Q1" 236 "2019:Q1" 240 "2020:Q1") ///
                legend(order (1 "all" 2 "entry-level" 3 "move-up"))				
                graph export "X:\Metro Data Interactive\QC\charts - $yq\sale amt\saleamt_`l'_$yq.png", replace
}


 // mri

levelsof cbsa_short, local(levels)
di `levels'
foreach l of local levels {
line mri-mri34 orig if cbsa_short == "`l'", ///
                title("`l'")       ///
                subtitle( "mri") ///
				xline(208 212 216 220 224 228 232 236 240) ///
				xlabel(208 "2012Q1" 212 "2013:Q1" 216 "2014:Q1"  220 "2015:Q1" 224 "2016:Q1" 228 "2017:Q1" 232 "2018:Q1" 236 "2019:Q1" 240 "2020:Q1") ///
                ylabels(0(.05).2) ///
                legend(order (1 "all" 2 "entry-level" 3 "move-up"))
                graph export "X:\Metro Data Interactive\QC\charts - $yq\mri\mri_`l'_$yq.png", replace
}   
        

//supply

levelsof cbsa_short, local(levels)
di `levels'
foreach l of local levels {
line months_supply months_supply12 months_supply34 orig if cbsa_short == "`l'" & orig >= 212, ///
                title("`l'")       ///
                subtitle( "Months' Supply") ///
				xline(212 216 220 224 228 232 236 240) ///
				xlabel(212 "2013:Q1" 216 "2014:Q1"  220 "2015:Q1" 224 "2016:Q1" 228 "2017:Q1" 232 "2018:Q1" 236 "2019:Q1" 240 "2020:Q1") ///
                legend(order (1 "all" 2 "entry-level" 3 "move_up"))
                graph export "X:\Metro Data Interactive\QC\charts - $yq\supply\supply_`l'_$yq.png", replace
}


				
// mew construction share

sort cbsa_short orig
levelsof cbsa_short, local(levels)					
di `levels'
foreach l of local levels {
line new_c_share new_c12_share new_c34_share orig if cbsa_short == "`l'" & orig >= 212, ///
                title("`l'")       ///
                subtitle( "New Construction Share of Sales") ///
				xline(212 216 220 224 228 232 236 240) ///
				xlabel(212 "2013:Q1" 216 "2014:Q1"  220 "2015:Q1" 224 "2016:Q1" 228 "2017:Q1" 232 "2018:Q1" 236 "2019:Q1" 240 "2020:Q1") ///
                legend(order (1 "all" 2 "entry-level" 3 "move_up"))
                graph export "X:\Metro Data Interactive\QC\charts - $yq\new construction\new_c_share_`l'_$yq.png", replace
}

		
// HPA
sort cbsa_short orig
levelsof cbsa_short, local(levels)					
di `levels'
foreach l of local levels {
line hpa_cbsaall hpa_cbsa12 hpa_cbsa34 orig if cbsa_short == "`l'" & orig >= 208, ///
                title("`l'")       ///
                subtitle( "House Price Appreciation") ///
				xline(208 212 216 220 224 228 232 236 240) ///
				xlabel(208 "2012:Q1" 212 "2013:Q1" 216 "2014:Q1"  220 "2015:Q1" 224 "2016:Q1" 228 "2017:Q1" 232 "2018:Q1" 236 "2019:Q1" 240 "2020:Q1") ///
                legend(order (1 "all" 2 "entry-level" 3 "move_up"))
                graph export "X:\Metro Data Interactive\QC\charts - $yq\HPA\HPA_`l'_$yq.png", replace
}
		
		