global path "C:\Users\phynm\OneDrive\Documents\GitHub\honors-thesis/[01] Streams"
cd "$path/data"
clear

use cbsa_streams

label variable munis_pp "Municipalities per capita"
label variable pop_muni "Total Population"
label variable stream_length_meters "Stream Length (meters)"
label variable aland "Land Area (meters)"
label variable hhi_pop_muni "Population HHI"
label variable streams_per_area "Streams / Area"
label variable greatlake "On Great Lakes"
label variable ocean "On Ocean"
label variable sd_areatri "Terrain Ruggedness"

drop if cbsa_type == "Micropolitan Statistical Area"

eststo clear 

quietly regress num_munis stream_length_meters
estadd local statefe "No"
eststo m1

quietly reghdfe num_munis stream_length_meters greatlake ocean sd_areatri aland pop_muni, absorb(state_id) cluster(state_id)
estadd local statefe "Yes"
eststo m3

quietly regress hhi_pop_muni stream_length_meters
estadd local statefe "No"
eststo m2

quietly reghdfe hhi_pop_muni stream_length_meters greatlake ocean sd_areatri aland, absorb(state_id) cluster(state_id)
estadd local statefe "Yes"
eststo m4


esttab, ///
	se ///
    stats(statefe r2 N, labels("State FE" "R-squared" "Observations"))

esttab m1 m3 m2 m4 using "$path/figures/stream_iv.tex", ///
    label se ///
	mtitles("" "" "" "") ///
	mgroups("Number of Municipalities" "Population HHI", ///
        pattern(1 1 0 0) ///
        span ///
        prefix(\multicolumn{@span}{c}{) ///
        suffix(})) ///
    stats(statefe r2 N, labels("State FE" "R-squared" "Observations")) ///
	replace

