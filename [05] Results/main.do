global path "C:\Users\phynm\OneDrive\Documents\GitHub\honors-thesis"
global streams_dir "$path/[01] Streams/data"
global frag_dir "$path/[03] Fragmentation/data"
global agg_dir "$path/[04] Agglomeration/data" 
global results_dir "$path/[05] Results"

// Import agglomeration and fragmentation data from respective folders

cd "$results_dir/data"

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
save main.dta, replace

import delimited "$agg_dir/kd_creative.csv", clear
rename gamma gamma_c
gen psi_c = lo - obs if gamma_c == 0
replace psi_c = 0 if psi_c < 0
replace psi_c = 0 if psi_c == .
sort psi_c

gen gam_dummy_c = 1 if gamma_c > 0
replace gam_dummy_c = 0 if gamma_c == 0

gen gamma2_c = obs - hi 
drop mmean obs hi lo 
rename cbsa cbsacode

merge 1:1 cbsacode r using main.dta
drop _merge
save main.dta, replace

use main.dta, clear
merge m:1 cbsacode using "$streams_dir/cbsa_streams.dta"
drop if _merge != 3
drop _merge
save main.dta, replace

// Add controls

import delimited "$results_dir/data/controls.csv", clear
rename geoid cbsacode
save controls.dta, replace

use main.dta, clear
merge m:1 cbsacode using "$results_dir/data/controls.dta"
drop if _merge != 3
drop _merge
save main.dta, replace
erase controls.dta

// Add labels

label variable munis_pp "Municipalities per capita"
label variable num_munis "\# of Municipalities"
label variable pop_muni "Total Population"
label variable stream_length_meters "Stream Length (meters)"
label variable aland "Land Area (meters)"
label variable hhi_pop_muni "Population HHI"
label variable streams_per_area "Streams / Area"
label variable greatlake "On Great Lakes"
label variable ocean "On Ocean"
label variable sd_areatri "Terrain Ruggedness"
label variable gamma "\(\Gamma\)"

// Quick visualizations
/*
preserve
drop if r != 250
twoway (scatter obs hhi_pop_muni) (lfit obs hhi_pop_muni)
restore
*/

// 1SLS

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

// OLS

local r_levels 500
local full_controls aland pop_muni share_bach_or_higher num_unis tech

eststo clear

foreach lev of local r_levels {
	eststo m1_`lev': quietly reghdfe gamma num_munis `full_controls' if r == `lev' & gamma != 0, ///
	absorb(state_id) cluster(state_id)
	eststo m2_`lev': quietly reghdfe gamma num_counties `full_controls' if r == `lev' & gamma != 0, ///
	absorb(state_id) cluster(state_id)
	eststo m3_`lev': quietly reghdfe gamma hhi_pop_muni `full_controls' if r == `lev' & gamma != 0, ///
	absorb(state_id) cluster(state_id)
	eststo m4_`lev': quietly reghdfe gamma index_rect `full_controls' if r == `lev' & gamma != 0, ///
	absorb(state_id) cluster(state_id)
	eststo m5_`lev': quietly reghdfe gamma index_circ `full_controls' if r == `lev' & gamma != 0, ///
	absorb(state_id) cluster(state_id)
}

esttab m*, se r2

// 2SLS

eststo clear

foreach lev of local r_levels {	
	eststo m1_`lev': quietly ivreghdfe gamma (num_munis = stream_length_meters) if r == `lev' & gamma != 0, ///
	absorb(state_id) vce(cluster state_id)
	estadd local statefe "Yes"
	
	eststo m2_`lev': quietly ivreghdfe gamma greatlake ocean sd_areatri aland pop_muni (num_munis = stream_length_meters) if r == `lev' & gamma != 0, absorb(state_id) vce(cluster state_id)
	estadd local statefe "Yes"
}

esttab m*, se r2

esttab m* using "$results_dir/figures/main_spec.tex", ///
	label se r2 ///
	mtitles ("" "" "" "" "" "") ///
	mgroups("r = 250" "r = 500" "r = 1000", ///
    pattern(1 0 1 0 1 0)) ///
	stats(statefe r2 N, labels("State FE" "R-squared" "Observations")) ///
	replace
	
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

esttab m*, se r2


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

