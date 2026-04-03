global data_dir "C:\Users\phynm\OneDrive\Desktop\school\thesis\[02] IV - Incorporation Date"
global working_dir "C:\Users\phynm\OneDrive\Documents\GitHub\honors-thesis\[02] Incorporation Date"

cd "$working_dir"

import delimited "$data_dir/historical_county_populations_v2", clear
rename cty_fips fips_state_county
tostring fips_state_county, replace force
replace fips_state_county = string(real(fips_state_county), "%05.0f")
rename cty county

save "$data_dir/historical_cbsa_populations", replace
clear

/////////////////////////////////
*CREATE HISTORICAL CBSA POPULATIONS
/////////////////////////////////


use "$data_dir/county_cbsa_xwalk"
format %5s cbsa_code
save "$data_dir/county_cbsa_xwalk", replace
keep cbsa_code cbsa_title fips_state_county
merge 1:m fips_state_county using "$data_dir/historical_cbsa_populations"
drop if _merge != 3

collapse (sum) pop_*, by(cbsa_code cbsa_title)

local years
forvalues y = 1900(10)2010 {
	local years "`years' `y'"
}

foreach y of local years {
	local next = `y' + 10
	capture confirm variable pop_`next'
	if !_rc {
		gen pctchg_`next' = 100 * (pop_`next' - pop_`y') / pop_`y'
	}
}

egen max_growth = rowmax(pctchg_*)

gen max_decade = . 

foreach var of varlist pctchg_* {
    * Extract the ending year from the variable name
    local endyear = substr("`var'", strpos("`var'", "_") + 1, .)

    replace max_decade = `endyear' if `var' == max_growth
}

order cbsa_code cbsa_title max_decade
save "$data_dir/historical_cbsa_populations", replace
clear

/////////////////////////
*MERGING DATASETS
/////////////////////////

*clean municipal incorporation data
import delimited "$data_dir/muni-incorporation.csv", clear
tostring census_id_pid6, replace

save "data/muni_incorporation.dta", replace
clear

import delimited "$data_dir/fips-crosswalk.csv", stringcols(_all) clear

merge 1:1 census_id_pid6 using "data/muni_incorporation.dta"

*only 6 not matched, can drop
keep if _merge == 3

rename lat latitude
rename v12 longitude

keep census_id_pid6 census_id geoid muniname statefips countyfips placecity latitude longitude yr_incorp
generate place_id = statefips + placecity
gen fips_state_county = statefips + countyfips

save "data/muni_incorporation.dta", replace

*enrich with COG population data

import delimited "$data_dir/general_purpose_2022", clear
keep census_id_pid6 population
tostring census_id_pid6, replace
destring population, ignore(",") replace force
rename population muni_population

merge 1:1 census_id_pid6 using "data/muni_incorporation.dta"
drop if _merge != 3
drop _merge

save "data/muni_incorporation.dta", replace

import excel "$data_dir/county_cbsa_xwalk", clear
rename A cbsa_code
format %5s cbsa_code
rename D cbsa_title
rename E cbsa_type
rename J state_fips
rename K county_fips
rename L central_outlying
drop in 1/3

keep cbsa_code cbsa_title cbsa_type state_fips county_fips central_outlying
generate fips_state_county = state_fips + county_fips
drop if missing(fips_state_county)

merge 1:m fips_state_county using "data/muni_incorporation.dta"
*drops shouldn't be a huge concern here, as not matched from master are mostly PR and cities without incorp dates, whereas not mached from using are municipalities outside of census cbsas

sort _merge
drop if _merge != 3
drop _merge state_fips county_fips

save "data/muni_incorporation.dta", replace
*this outputs the muni_incorporation with basic information and incorporation date

*get the year of greatest growth using 2020 cbsa borders
clear
use "$data_dir/historical_cbsa_populations"
keep cbsa_code max_decade
merge 1:m cbsa_code using "data/muni_incorporation.dta"
sort cbsa_code
drop _merge

save "data/muni_incorporation.dta", replace

*get detailed population statistics
clear
import delimited "$data_dir/cbsa-est2024-alldata-char.csv"

drop if agegrp != 0
drop agegrp
drop if year != 1
drop year
drop mdiv
drop lsad
tostring cbsa, replace
rename cbsa cbsa_code
drop if sumlev != 310
drop sumlev
drop name

distinct cbsa_code

keep cbsa_code tot_pop

merge 1:m cbsa_code using "data/muni_incorporation.dta"
sort cbsa_code
drop _merge

/////////////////////////////
*VARIABLE CREATION
/////////////////////////////

drop if yr_incorp == .
sort cbsa_code
*generate rank
by cbsa_code: egen pop_rank = rank(-muni_population)
*sum populations
by cbsa_code: egen total_cbsa_pop = sum(muni_population)
*working HHI - NOTE that this is not comprehensive as there is some data left out, different from the official calculations
sort place_id
by place_id: gen pop_fraction = muni_population / total_cbsa_pop
sort cbsa_code
by cbsa_code: egen hhi_pop = sum(pop_fraction^2)
*fraction in central city
by cbsa_code: egen share_in_central_city = max(cond(pop_rank==1, pop_fraction, .))

*get the main state of each cbsa (based on central city) to account for state fixed effects
preserve
keep if pop_rank == 1
keep cbsa_code fips_state
rename fips_state main_state
duplicates drop
tempfile mainstate
save `mainstate'
restore

merge m:1 cbsa_code using `mainstate'
drop _merge

*get year incorporated variables
sort cbsa_code
by cbsa_code: egen yr_incorp_main = max(cond(pop_rank==1, yr_incorp, .))
by cbsa_code: egen yr_incorp_av_5 = mean(cond(pop_rank <= 5, yr_incorp, .))
by cbsa_code: egen yr_incorp_av_all = mean(yr_incorp)
by cbsa_code: egen yr_incorp_md_all = median(yr_incorp)

*1 for MSA, 0 for mSA
generate type = 1 if cbsa_type == "Metropolitan Statistical Area"
replace type = 0 if type == .
drop cbsa_type
rename type cbsa_type
*1 for multistate, 0 for single state
ssc install distinct
bys cbsa_code fips_state: gen tag = _n == 1
bys cbsa_code: egen distinct_states = total(tag)
bys cbsa_code: gen multi_state = 1 if distinct_states > 1
replace multi_state = 0 if multi_state == .
drop tag distinct_states

format %5s cbsa_code
save "data/muni_incorporation.dta", replace

*can observe trends with above data set. I make a streamlined version since fragmentation measures are already calculated and stored in "[03] Fragmentation"

keep cbsa_code cbsa_title max_decade yr_incorp_*
collapse yr_incorp*, by(cbsa_code cbsa_title max_decade)
rename cbsa_code cbsacode
save "data/muni_incorporation.dta", replace

///////////////////////////
// Regression Testing Space
///////////////////////////

global frag_dir "C:\Users\phynm\OneDrive\Documents\GitHub\honors-thesis\[03] Fragmentation"

import delimited "$frag_dir/data/fragmentation_full", clear
destring index_circ, replace force
destring index_rect, replace force
tostring cbsacode, replace format(%05.0f)

merge 1:1 cbsacode using "$working_dir/data/muni_incorporation"
drop if _merge != 3
drop _merge
format %5s cbsacode

drop if yr_incorp_av_all < 1800

twoway (scatter index_circ yr_incorp_av_all) (lfit index_circ yr_incorp_av_all)

eststo clear
eststo m1: regress index_circ yr_incorp_main
eststo m2: regress index_circ yr_incorp_md_all
eststo m3: regress index_circ yr_incorp_av_5
eststo m4: regress index_circ yr_incorp_av_all

esttab m*, se r2

eststo clear
eststo m1: regress index_rect yr_incorp_main
eststo m2: regress index_rect yr_incorp_md_all
eststo m3: regress index_rect yr_incorp_av_5
eststo m4: regress index_rect yr_incorp_av_all

esttab m*, se r2

