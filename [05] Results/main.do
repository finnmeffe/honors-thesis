global path "C:\Users\phynm\OneDrive\Documents\GitHub\honors-thesis"
global streams_dir "$path/[01] Streams/data"
global incorp_dir "$path/[02] Incorporation Date/data"
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
label variable num_munis "\# Munis"
label variable num_counties "\# Counties"
label variable index_circ "SDI (Circle)"
label variable index_rect "SDI (Rectangle)"
label variable pop_muni "Total Population"
label variable stream_length_meters "Stream Length (meters)"
label variable aland "Land Area (meters)"
label variable hhi_pop_muni "Population HHI"
label variable streams_per_area "Streams / Area"
label variable greatlake "On Great Lakes"
label variable ocean "On Ocean"
label variable sd_areatri "Terrain Ruggedness"
label variable gamma "\(\Gamma_T\)"
label variable gamma_c "\(\Gamma_C\)"
label variable share_in_central_city "\% in Central City"
label variable share_bach_or_higher "\% Bachelor's or Higher"
label variable num_unis "\# Universities"
label variable tech "\# Tech Firms"
label variable creative "\# Creative Firms"


// Quick visualizations
/*
preserve
drop if r != 250
twoway (scatter obs hhi_pop_muni) (lfit obs hhi_pop_muni)
restore
*/

////////////////////////////////////
// 1SLS
////////////////////////////////////

preserve
keep if r == 0 // remove duplicates

eststo clear

eststo m_base: quietly regress num_munis stream_length_meters
estadd local statefe "No"

eststo m_controls: quietly regress num_munis stream_length_meters greatlake ocean sd_areatri aland pop_muni
estadd local statefe "No"

eststo m_fe: quietly reghdfe num_munis stream_length_meters greatlake ocean sd_areatri aland pop_muni, absorb(state_id) cluster(state_id)
estadd local statefe "Yes"

esttab m_* using "$results_dir/reg_figures/1sls_1.tex", ///
    se ///
    r2 ///
    label ///
    stats(statefe N r2, labels("State FE" "Observations" "R-squared")) ///
    mgroups("Dependent Variable: Number of Municipalities", pattern(1 0 0) ///
        prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    booktabs ///
    replace

eststo clear

quietly reghdfe num_munis stream_length_meters greatlake ocean sd_areatri aland pop_muni, absorb(state_id) cluster(state_id)
estadd local statefe "Yes"
estadd local controls "Yes"
eststo m_muni

quietly reghdfe num_counties stream_length_meters greatlake ocean sd_areatri aland pop_muni, absorb(state_id) cluster(state_id)
estadd local statefe "Yes"
estadd local controls "Yes"
eststo m_county 

quietly reghdfe hhi_pop_muni stream_length_meters greatlake ocean sd_areatri aland pop_muni, absorb(state_id) cluster(state_id)
estadd local statefe "Yes"
estadd local controls "Yes"
eststo m_hhi

quietly reghdfe share_in_central_city stream_length_meters greatlake ocean sd_areatri aland pop_muni, absorb(state_id) cluster(state_id)
estadd local statefe "Yes"
estadd local controls "Yes"
eststo m_scc

quietly reghdfe index_rect stream_length_meters greatlake ocean sd_areatri aland pop_muni, absorb(state_id) cluster(state_id)
estadd local statefe "Yes"
estadd local controls "Yes"
eststo m_sdir

quietly reghdfe index_circ stream_length_meters greatlake ocean sd_areatri aland pop_muni, absorb(state_id) cluster(state_id)
estadd local statefe "Yes"
estadd local controls "Yes"
eststo m_sdic

esttab m_*, se r2

esttab m_* using "$results_dir/reg_figures/1sls_2.tex", ///
    se ///
    r2 ///
    label ///
    stats(statefe controls N r2, labels("State FE" "Controls" "Observations" "R-squared")) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    booktabs ///
    replace

restore

////////////////////////////////////
// OLS
////////////////////////////////////

local r_levels 250 500 1000
local full_controls aland pop_muni share_bach_or_higher num_unis tech

foreach lev of local r_levels {

eststo clear

	eststo m1_`lev': quietly reghdfe gam_dummy num_munis `full_controls' if r == `lev', ///
	absorb(state_id) cluster(state_id)
	estadd local statefe "Yes"
	
	eststo m2_`lev': quietly reghdfe gam_dummy num_counties `full_controls' if r == `lev', ///
	absorb(state_id) cluster(state_id)
	estadd local statefe "Yes"
	
	eststo m3_`lev': quietly reghdfe gam_dummy hhi_pop_muni `full_controls' if r == `lev', ///
	absorb(state_id) cluster(state_id)
	estadd local statefe "Yes"
	
	eststo m6_`lev': quietly reghdfe gam_dummy share_in_central_city `full_controls' if r == `lev', ///
	absorb(state_id) cluster(state_id)
	estadd local statefe "Yes"
	
	eststo m4_`lev': quietly reghdfe gam_dummy index_rect `full_controls' if r == `lev', ///
	absorb(state_id) cluster(state_id)
	estadd local statefe "Yes"
	
	eststo m5_`lev': quietly reghdfe gam_dummy index_circ `full_controls' if r == `lev', ///
	absorb(state_id) cluster(state_id)
	estadd local statefe "Yes"
	
esttab m*, se r2
	
esttab m* using "$results_dir/reg_figures/ols_`lev'.tex", ///
    se ///
    r2 ///
    label ///
	order(num_munis num_counties hhi_pop_muni share_in_central_city index_rect index_circ) ///
    stats(statefe N r2, labels("State FE" "Observations" "R-squared")) ///
	mgroups("Dependent Variable: \(\Gamma\) Dummy at Radius `lev'm", pattern(1 0 0) ///
        prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
	nomtitles ///
    booktabs ///
	replace
}

////////////////////////////////////
// 2SLS (radius own tables)
////////////////////////////////////

local r_levels 250 500 1000
eststo clear

foreach lev of local r_levels {
eststo clear

eststo m_lpm1: quietly ivregress 2sls gam_dummy (num_munis = stream_length_meters) if r == `lev', vce(robust)
estadd local statefe "No"

eststo m_pro1: quietly ivprobit gam_dummy (num_munis = stream_length_meters) if r == `lev',
estadd local statefe "No"
estadd scalar rho = tanh(_b[/athrho2_1])
estadd scalar sig = exp(_b[/lnsigma2])

eststo m_lpm2: quietly ivregress 2sls gam_dummy (num_munis = stream_length_meters) greatlake ocean sd_areatri aland pop_muni if r == `lev', vce(robust)
estadd local statefe "No"

eststo m_pro2: quietly ivprobit gam_dummy (num_munis = stream_length_meters) greatlake ocean sd_areatri aland pop_muni if r == `lev'
estadd local statefe "No"
estadd scalar rho = tanh(_b[/athrho2_1])
estadd scalar sig = exp(_b[/lnsigma2])

eststo m_lpm3: quietly ivreghdfe gam_dummy (num_munis = stream_length_meters) greatlake ocean sd_areatri aland pop_muni share_bach_or_higher num_unis tech if r == `lev', absorb(state_id) vce(cluster state_id)
estadd local statefe "Yes"

eststo m_pro3: quietly ivprobit gam_dummy (num_munis = stream_length_meters) greatlake ocean sd_areatri aland pop_muni share_bach_or_higher num_unis tech i.state_id if r == `lev', /// 
vce(cluster state_id)
estadd local statefe "Yes"
estadd scalar rho = tanh(_b[/athrho2_1])
estadd scalar sig = exp(_b[/lnsigma2])

esttab m*, se r2 keep(main:) drop(*.state_id _cons)

esttab m* using "$results_dir/reg_figures/2sls_`lev'_full.tex", ///
	keep(main:) drop(*.state_id _cons) ///
    se ///
	r2 ///
	label ///
	mgroups("LPM" "Probit" "LPM" "Probit" "LPM" "Probit", ///
        pattern(1 1 1 1 1 1) ///
        span ///
        prefix(\multicolumn{@span}{c}{) ///
        suffix(})) ///
    stats(rho sig statefe N, ///
		labels("\(\rho\)" "\(\sigma\)" "State FE" "Observations")) ///
    nomtitles ///
	booktabs ///
	replace 
	
ereturn list
}

////////////////////////////////////
// 2SLS (combined table)
////////////////////////////////////

local r_levels 250 500 1000
eststo clear

foreach lev of local r_levels {

eststo m_lpm_`lev': quietly ivreghdfe gam_dummy (num_munis = stream_length_meters) greatlake ocean sd_areatri aland pop_muni share_bach_or_higher num_unis tech if r == `lev', absorb(state_id) vce(cluster state_id)
estadd local statefe "Yes"
estadd local ivcontrols "Yes"

eststo m_pro_`lev': quietly ivprobit gam_dummy (num_munis = stream_length_meters) greatlake ocean sd_areatri aland pop_muni share_bach_or_higher num_unis tech i.state_id if r == `lev', /// 
vce(cluster state_id)
estadd local statefe "Yes"
estadd local ivcontrols "Yes"
estadd scalar rho = tanh(_b[/athrho2_1])
estadd scalar sig = exp(_b[/lnsigma2])
	
}

esttab m_*, se r2 drop(*.state_id _cons greatlake ocean sd_areatri aland pop_muni)

esttab m* using "$results_dir/reg_figures/2sls_full.tex", ///
	keep(main:) drop(*.state_id _cons greatlake ocean sd_areatri aland pop_muni) ///
    se ///
	r2 ///
	label ///
	mgroups("r = 250" "r = 500" "r = 1000", ///
        pattern(1 0 1 0 1 0) ///
        span ///
        prefix(\multicolumn{@span}{c}{) ///
        suffix(})) ///
    stats(rho sig statefe ivcontrols N, ///
		labels("\(\rho\)" "\(\sigma\)" "State FE" "IV Controls" "Observations")) ///
    nomtitles ///
	booktabs ///
	replace 

////////////////////////////////////
// 2SLS (continuous gamma)
////////////////////////////////////	

eststo clear

foreach lev of local r_levels {	
	eststo m1_`lev': quietly ivreghdfe gamma (num_munis = stream_length_meters) if r == `lev' & gamma != 0, ///
	absorb(state_id) vce(cluster state_id)
	estadd local statefe "Yes"
	estadd local ivcontrols "No"
	
	eststo m2_`lev': quietly ivreghdfe gamma greatlake ocean sd_areatri aland pop_muni (num_munis = stream_length_meters) share_bach_or_higher num_unis tech if r == `lev' & gamma != 0, absorb(state_id) vce(cluster state_id)
	estadd local statefe "Yes"
	estadd local ivcontrols "Yes"
}

esttab m*, se r2

esttab m1_* m2_* using "$results_dir/reg_figures/2sls_cont_gam.tex", ///
	drop(greatlake ocean sd_areatri aland pop_muni) ///
	label se r2 ///
	mgroups("r = 250" "r = 500" "r = 1000" "r = 250" "r = 500" "r = 1000", ///
        pattern(1 1 1 1 1 1) ///
        span ///
        prefix(\multicolumn{@span}{c}{) ///
        suffix(}) ) ///
	stats(statefe ivcontrols r2 N, labels("State FE" "IV Controls" "R-squared" "Observations")) ///
	nomtitles ///
	booktabs ///
	replace
	
	
////////////////////////////////////
// 2SLS (tech and creative comparison)
////////////////////////////////////

eststo clear

// for LPM

foreach lev of local r_levels {

eststo m_lpm_`lev': quietly ivreghdfe gam_dummy (num_munis = stream_length_meters) greatlake ocean sd_areatri aland pop_muni share_bach_or_higher num_unis tech if r == `lev', absorb(state_id) vce(cluster state_id)
estadd local statefe "Yes"
estadd local ivcontrols "Yes"

eststo m_lpm_`lev'_c: quietly ivreghdfe gam_dummy_c (num_munis = stream_length_meters) greatlake ocean sd_areatri aland pop_muni share_bach_or_higher num_unis creative if r == `lev', absorb(state_id) vce(cluster state_id)
estadd local statefe "Yes"
estadd local ivcontrols "Yes"
	
}

esttab, se r2

esttab m_* using "$results_dir/reg_figures/2sls_tech_creative.tex", ///
	drop(greatlake ocean sd_areatri aland pop_muni) ///
	label se r2 ///
	mgroups("r = 250" "r = 500" "r = 1000", ///
        pattern(1 0 1 0 1 0) ///
        span ///
        prefix(\multicolumn{@span}{c}{) ///
        suffix(}) ) ///
	mtitles("\(\Gamma_T\)" "\(\Gamma_C\)" "\(\Gamma_T\)" "\(\Gamma_C\)" "\(\Gamma_T\)" "\(\Gamma_C\)") ///
    nodepvars ///
	stats(statefe ivcontrols r2 N, labels("State FE" "IV Controls" "R-squared" "Observations")) ///
	booktabs ///
	replace
 	
////////////////////////////////////
// Testing Space
////////////////////////////////////

* different measures of fragmentation

local r_levels 250 500 1000
eststo clear

foreach lev of local r_levels {

eststo m_lpm_`lev': quietly ivreghdfe gam_dummy (num_munis = stream_length_meters) greatlake ocean sd_areatri aland pop_muni share_bach_or_higher num_unis tech if r == `lev', absorb(state_id) vce(cluster state_id)
estadd local statefe "Yes"
estadd local ivcontrols "Yes"

eststo m_pro_`lev': quietly ivprobit gam_dummy (num_munis = stream_length_meters) greatlake ocean sd_areatri aland pop_muni share_bach_or_higher num_unis tech i.state_id if r == `lev', /// 
vce(cluster state_id)
estadd local statefe "Yes"
estadd local ivcontrols "Yes"
estadd scalar rho = tanh(_b[/athrho2_1])
estadd scalar sig = exp(_b[/lnsigma2])
	
}

esttab m_*, se r2 drop(*.state_id _cons greatlake ocean sd_areatri aland pop_muni)

* substitute counties for municipalities

local r_levels 250 500 1000
eststo clear

foreach lev of local r_levels {

eststo m_lpm_`lev': quietly ivreghdfe gam_dummy (num_counties = stream_length_meters) greatlake ocean sd_areatri aland pop_muni share_bach_or_higher num_unis tech if r == `lev', absorb(state_id) vce(cluster state_id)
estadd local statefe "Yes"
estadd local ivcontrols "Yes"

eststo m_pro_`lev': quietly ivprobit gam_dummy (num_counties = stream_length_meters) greatlake ocean sd_areatri aland pop_muni share_bach_or_higher num_unis tech i.state_id if r == `lev', /// 
vce(cluster state_id)
estadd local statefe "Yes"
estadd local ivcontrols "Yes"
estadd scalar rho = tanh(_b[/athrho2_1])
estadd scalar sig = exp(_b[/lnsigma2])
	
}

esttab m_*, se r2 drop(*.state_id _cons greatlake ocean sd_areatri aland pop_muni)

esttab m* using "$results_dir/reg_figures/2sls_full_counties.tex", ///
	keep(main:) drop(*.state_id _cons greatlake ocean sd_areatri aland pop_muni) ///
    se ///
	r2 ///
	label ///
	mgroups("r = 250" "r = 500" "r = 1000", ///
        pattern(1 0 1 0 1 0) ///
        span ///
        prefix(\multicolumn{@span}{c}{) ///
        suffix(})) ///
    stats(rho sig statefe ivcontrols N, ///
		labels("\(\rho\)" "\(\sigma\)" "State FE" "IV Controls" "Observations")) ///
    nomtitles ///
	booktabs ///
	replace 

////////////////////////////////////
// Incorp Year IV
////////////////////////////////////

// Add incorporation year/law data

merge m:1 cbsacode using "$incorp_dir/muni_incorporation"
drop if _merge != 3
drop _merge

label variable yr_incorp_av_all "Mean Year of Incorporation"
label variable incorpreqdummy "Incorporation Requirements"

preserve
drop if r!= 0
drop if yr_incorp_av_all < 1800
*twoway (scatter index_circ yr_incorp_av_all) (lfit index_circ yr_incorp_av_all)

eststo clear
eststo m1: regress index_circ yr_incorp_av_all
eststo m2: regress index_rect yr_incorp_av_all
eststo m3: regress index_circ yr_incorp_av_all fullhomerule incorpreqdummy pop_muni aland sd_areatri
eststo m4: regress index_rect yr_incorp_av_all fullhomerule incorpreqdummy pop_muni aland

esttab m*, se r2
restore

local r_levels 250 500 1000
eststo clear

foreach lev of local r_levels {

eststo m_lpm_`lev': quietly ivregress 2sls gam_dummy (index_circ = yr_incorp_av_all) fullhomerule incorpreqdummy pop_muni aland sd_areatri share_bach_or_higher num_unis tech if r == `lev', vce(robust) first
estadd local ivcontrols "Yes"

eststo m_pro_`lev': quietly ivprobit gam_dummy (index_circ = yr_incorp_av_all) fullhomerule incorpreqdummy pop_muni aland sd_areatri share_bach_or_higher num_unis tech if r == `lev'
estadd local ivcontrols "Yes"
estadd scalar rho = tanh(_b[/athrho2_1])
estadd scalar sig = exp(_b[/lnsigma2])
	
}

esttab m_*, se r2

eststo clear

preserve
drop if r != 0
eststo iv: regress index_circ yr_incorp_av_all fullhomerule incorpreqdummy aland sd_areatri pop_muni share_bach_or_higher num_unis tech
eststo m: ivregress 2sls gam_dummy (index_circ = yr_incorp_av_all) fullhomerule incorpreqdummy pop_muni share_bach_or_higher num_unis tech aland sd_areatri, vce(robust) first
estat firststage
esttab iv m , se
restore

local r_levels 250 500 1000
eststo clear

preserve
drop if r != 0
drop if gam_dummy == .
eststo iv: regress index_circ yr_incorp_av_all fullhomerule incorpreqdummy aland sd_areatri pop_muni share_bach_or_higher num_unis tech
restore

foreach lev of local r_levels {

eststo m_lpm_`lev': quietly ivregress 2sls gam_dummy (index_circ = yr_incorp_av_all) fullhomerule incorpreqdummy aland sd_areatri pop_muni share_bach_or_higher num_unis tech if r == `lev', vce(robust)
estadd local ivcontrols "Yes"

eststo m_pro_`lev': quietly ivprobit gam_dummy (index_circ = yr_incorp_av_all) fullhomerule incorpreqdummy aland sd_areatri pop_muni share_bach_or_higher num_unis tech if r == `lev', /// 
vce(robust)
estadd local ivcontrols "Yes"
estadd scalar rho = tanh(_b[/athrho2_1])
estadd scalar sig = exp(_b[/lnsigma2])
	
}

esttab iv m_*, se r2 ///
	keep(main: yr_incorp_av_all index_circ fullhomerule incorpreqdummy aland sd_areatri pop_muni share_bach_or_higher num_unis tech)

esttab iv m* using "$results_dir/reg_figures/2sls_incorp.tex", ///
    se ///
	r2 ///
	label ///
	mgroups("1SLS" "r = 250" "r = 500" "r = 1000", ///
        pattern(1 1 0 1 0 1 0) ///
        span ///
        prefix(\multicolumn{@span}{c}{) ///
        suffix(})) ///
    stats(rho sig N, ///
		labels("\(\rho\)" "\(\sigma\)" "Observations")) ///
    nomtitles ///
	booktabs ///
	replace 
