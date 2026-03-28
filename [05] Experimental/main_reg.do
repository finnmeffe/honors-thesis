global path "C:\Users\phynm\OneDrive\Documents\GitHub\honors-thesis"
global streams_dir "$path/[01] Streams/data"
global frag_dir "$path/[03] Fragmentation/data"
global agg_dir "$path/[04] Agglomeration/data" 

// Import agglomeration and fragmentation data from respective folders

cd "$path/[05] Experimental/data"

import delimited "$agg_dir/kd_tech.csv", clear 

gen psi = lo - obs if gamma == 0 // Psi calculation from Duranton and Overman (2005)
replace psi = 0 if psi < 0
replace psi = 0 if psi == .
sort psi

gen gam_dummy = 1 if gamma > 0
replace gam_dummy = 0 if gamma == 0

gen gamma2 = obs - hi // Stat for each CBSA
drop mmean
rename cbsa cbsacode
save kd_tech.dta, replace

use kd_tech.dta, clear
merge m:1 cbsa using "$streams_dir/cbsa_streams.dta"
drop if _merge != 3
drop _merge
save kd_tech.dta, replace

// Quick visualizations
/*
preserve
drop if r != 250
twoway (scatter obs hhi_pop_muni) (lfit obs hhi_pop_muni)
restore
*/

// IV

preserve 
keep if r == 0 // remove duplicates

quietly reghdfe num_munis stream_length_meters greatlake ocean sd_areatri aland pop_muni, absorb(state_id) cluster(state_id)
estadd local statefe "Yes"
eststo m_muni

quietly reghdfe num_counties stream_length_meters greatlake ocean sd_areatri aland pop_muni, absorb(state_id) cluster(state_id)
estadd local statefe "Yes"
eststo m_county 

quietly reghdfe hhi_pop_muni stream_length_meters greatlake ocean sd_areatri aland, absorb(state_id) cluster(state_id)
estadd local statefe "Yes"
eststo m_hhi

quietly reghdfe index_rect stream_length_meters greatlake ocean sd_areatri aland, absorb(state_id) cluster(state_id)
estadd local statefe "Yes"
eststo m_sdir

quietly reghdfe index_circ stream_length_meters greatlake ocean sd_areatri aland, absorb(state_id) cluster(state_id)
estadd local statefe "Yes"
eststo m_sdic

esttab m_*, se r2
restore

// Main Specification

local r_levels 250 500 1000
eststo clear

foreach lev of local r_levels {	
	eststo m1_`lev': quietly ivreghdfe gamma (num_munis = stream_length_meters) if r == `lev' & gamma != 0, ///
	absorb(state_id) vce(cluster state_id)
	estadd local statefe "Yes"
	
	eststo m2_`lev': quietly ivreghdfe gamma greatlake ocean sd_areatri aland pop_muni (num_munis = stream_length_meters) if r == `lev' & gamma != 0, absorb(state_id) vce(cluster state_id)
	estadd local statefe "Yes"
}

esttab m*, se

// Add negative gammas

local r_levels 250 500 1000
eststo clear

foreach lev of local r_levels {	
	eststo m1_`lev': quietly ivreghdfe gamma2 (num_munis = stream_length_meters) if r == `lev', ///
	absorb(state_id) vce(cluster state_id)
	estadd local statefe "Yes"
	
	eststo m2_`lev': quietly ivreghdfe gamma2 greatlake ocean sd_areatri aland pop_muni (num_munis = stream_length_meters) if r == `lev', absorb(state_id) vce(cluster state_id)
	estadd local statefe "Yes"
}

esttab m*, se


// Logit Regression

*twoway scatter gam_dummy num_munis
eststo clear

foreach lev of local r_levels {
eststo probit_`lev': quietly ivprobit gam_dummy (num_munis = stream_length_meters) greatlake ocean sd_areatri aland pop_muni i.state_id if r == `lev', /// 
vce(cluster state_id)
estadd local statefe "Yes"

eststo lpm_`lev': quietly ivreghdfe gam_dummy greatlake ocean sd_areatri aland pop_muni (num_munis = stream_length_meters) if r == `lev', absorb(state_id) vce(cluster state_id)
estadd local statefe "Yes"
}

esttab probit_* lpm_*, se r2 drop(*.state_id)

