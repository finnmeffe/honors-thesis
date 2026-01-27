cd ""
clear

use muni_incorporation

*keep cbsa_code cbsa_title total_cbsa_pop hhi_pop share_in_central_city yr_incorp_main yr_incorp_av_all main_state

duplicates drop
gsort -total_cbsa_pop

local varlist = "hhi_pop yr_incorp_main yr_incorp_av_5 yr_incorp_av_all tot_pop pct_black main_state log_pop max_decade multi_state"

label variable hhi_pop "HHI - Population"
label variable yr_incorp_main "Year Incorporated (Primary City)"
label variable yr_incorp_av_all "Year Incorporated (CBSA Av.)"
label variable total_cbsa_pop "Population"
gen log_pop = log(tot_pop)
label variable log_pop "Population (log)"

destring main_state, replace
xtset main_state

collapse (mean) `varlist', by(cbsa_code)

////////////////
*main regression
////////////////

eststo m2: quietly regress hhi_pop yr_incorp_main, absorb(main_state)
eststo m3: quietly regress hhi_pop yr_incorp_main log_pop max_decade, absorb(main_state)
preserve
drop if tot_pop < 100000
eststo m5: quietly regress hhi_pop yr_incorp_main, absorb(main_state)
eststo m6: quietly regress hhi_pop yr_incorp_main max_decade log_pop, absorb(main_state)
restore
eststo m8: quietly regress hhi_pop yr_incorp_av_all, absorb(main_state)
eststo m9: quietly regress hhi_pop yr_incorp_av_all max_decade log_pop, absorb(main_state)



esttab, se ar2

esttab m2 m3 m5 m6 m8 m9 using incorp_iv.tex, ///
    label se ///
	mtitles("" "" "" "" "" "") ///
	mgroups("Main City Incorp. Year" "Average Incorp. Year", ///
        pattern(1 1 1 1 0 0) ///
        span ///
        prefix(\multicolumn{@span}{c}{) ///
        suffix(})) ///
    stats(r2 N, labels("R-squared" "Observations")) ///
	replace

eststo clear

eststo m0: quietly regress hhi_pop yr_incorp_main yr_incorp_av_all yr_incorp_av_5 log_pop pct_black, absorb(main_state)
scatter hhi_pop yr_incorp_main || lfit hhi_pop yr_incorp_main
eststo m1: quietly regress hhi_pop yr_incorp_main yr_incorp_av_all yr_incorp_av_5 log_pop pct_black
eststo m2: quietly regress hhi_pop yr_incorp_av_all log_pop pct_black multi_state, absorb(main_state)
eststo m3: quietly regress hhi_pop yr_incorp_av_5 log_pop pct_black multi_state, absorb(main_state)

esttab, se ar2
eststo clear
restore

////////////////////
*nonparametric tests
////////////////////

preserve 
drop if tot_pop < 100000
eststo m1: quietly npregress kernel hhi_pop yr_incorp_main
npgraph

esttab, se ar2
restore

///////////////////////////
*TEST BEFORE AND AFTER 1900 
///////////////////////////

*effects after 1900 
preserve
keep if yr_incorp_main >= 1900
eststo m1: quietly regress hhi_pop yr_incorp_main log_pop pct_black, absorb(main_state)
restore

*effects before 1900 period (restrict to before 1700 as well)
preserve
keep if yr_incorp_main < 1900 & yr_incorp_main >= 1700
eststo m2: quietly regress hhi_pop yr_incorp_main log_pop pct_black, absorb(main_state)
restore

gen post_1900 = 0
replace post_1900 = 1 if yr_incorp_main >= 1900
eststo m3: quietly regress hhi_pop yr_incorp_main log_pop pct_black post_1900, absorb(main_state)

esttab, se ar2

//////////////
*summary stats
//////////////

clear

use muni_incorporation

distinct place_id
bys cbsa_code: gen muni_count = _N

egen tag = tag(fips_state_county)
bys cbsa_code: egen county_count = total(tag)
drop tag

label variable muni_count "# of Municipalities"
label variable county_count "# of Counties"
label variable total_cbsa_pop "CBSA Population"
label variable cbsa_type "MSA or μSA"
label variable hhi_pop "Population HHI"
label variable share_in_central_city "Share in Central City"

preserve
keep cbsa_type muni_count county_count hhi_pop share_in_central_city total_cbsa_pop share_in_central_city
order muni_count county_count hhi_pop share_in_central_city total_cbsa_pop share_in_central_city cbsa_type

outreg2 using sum_stats, replace tex sum(log) label
restore 

distinct cbsa_code

use muni_incorporation

distinct place_id
bys cbsa_code: gen muni_count = _N

egen tag = tag(fips_state_county)
bys cbsa_code: egen county_count = total(tag)
drop tag

label variable muni_count "# of Municipalities"
label variable county_count "# of Counties"
label variable total_cbsa_pop "CBSA Population"
label variable cbsa_type "MSA or μSA"
label variable hhi_pop "Population HHI"
label variable share_in_central_city "Share in Central City"

preserve
keep cbsa_type muni_count county_count hhi_pop share_in_central_city total_cbsa_pop share_in_central_city
order muni_count county_count hhi_pop share_in_central_city total_cbsa_pop share_in_central_city cbsa_type

outreg2 using sum_stats, replace tex sum(log) label
restore 

distinct cbsa_code

