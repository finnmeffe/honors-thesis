cd ""
clear

use cbsa_streams

label variable num_muns_pp "Municipalities per capita"
label variable total_population "Total Population"
label variable stream_length_meters "Stream Length (meters)"
label variable aland "Land Area (meters)"
label variable hhi_population "Population HHI"
label variable streams_per_area "Streams / Area"
label variable greatlake "On Great Lakes"
label variable ocean "On Ocean"
label variable sd_areatri "Terrain Ruggedness"

encode state, gen(state_id)

eststo clear 

quietly regress num_municipalities stream_length_meters
estadd local statefe "No"
eststo m1

quietly reghdfe num_municipalities stream_length_meters greatlake ocean sd_areatri aland total_population, absorb(state_id)
estadd local statefe "Yes"
eststo m3

quietly regress hhi_population stream_length_meters
estadd local statefe "No"
eststo m2

quietly reghdfe hhi_population stream_length_meters greatlake ocean sd_areatri aland, absorb(state_id)
estadd local statefe "Yes"
eststo m4


esttab, ///
	se ///
    stats(statefe r2 N, labels("State FE" "R-squared" "Observations"))

esttab m1 m3 m2 m4 using stream_iv.tex, ///
    label se ///
	mtitles("" "" "" "") ///
	mgroups("Number of Municipalities" "Population HHI", ///
        pattern(1 1 0 0) ///
        span ///
        prefix(\multicolumn{@span}{c}{) ///
        suffix(})) ///
    stats(statefe r2 N, labels("State FE" "R-squared" "Observations")) ///
	replace

