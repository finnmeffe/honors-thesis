cd ""

/////////////////////////
*MERGING DATASETS
/////////////////////////

*clean municipal incorporation data
clear
import delimited muni-incorporation.csv
tostring census_id_pid6, replace

save muni_incorporation.dta, replace
clear

import delimited fips-crosswalk.csv, stringcols(_all)

merge 1:1 census_id_pid6 using muni_incorporation.dta

*only 6 not matched, can drop
keep if _merge == 3

rename lat latitude
rename v12 longitude

keep census_id_pid6 census_id geoid muniname statefips countyfips placecity latitude longitude yr_incorp
generate place_id = statefips + placecity

save muni_incorporation.dta, replace
clear

*get population data from the census of governments
import excel Govt_Units_2017_Final, firstrow case(lower) sheet("General Purpose")

keep if unit_type == "2 - MUNICIPAL"
rename population population_2017
keep census_id name population_2017 fips_state fips_county fips_place

generate place_id = fips_state + fips_place
distinct place_id

merge 1:1 place_id using muni_incorporation.dta
drop if _merge != 3 
keep census_id name population_2017 fips_state fips_county fips_place place_id latitude longitude yr_incorp
generate fips_state_county = fips_state + fips_county

save muni_incorporation.dta, replace
clear

import excel county_cbsa_xwalk
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

merge 1:m fips_state_county using muni_incorporation.dta
*drops shouldn't be a huge concern here, as not matched from master are mostly PR and cities without incorp dates, whereas not mached from using are municipalities outside of census cbsas

sort _merge
drop if _merge != 3
drop _merge state_fips county_fips

save muni_incorporation.dta, replace
*this outputs the muni_incorporation with basic information and incorporation date

*get the year of greatest growth using 2020 cbsa borders
clear
use historical_cbsa_populations
keep cbsa_code max_decade
merge 1:m cbsa_code using muni_incorporation.dta
sort cbsa_code
drop _merge

save muni_incorporation.dta, replace

*get detailed population statistics
clear
import delimited "cbsa-est2024-alldata-char.csv"

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

merge 1:m cbsa_code using muni_incorporation.dta
sort cbsa_code
drop _merge

/////////////////////////////
*VARIABLE CREATION
/////////////////////////////

drop if yr_incorp == .
sort cbsa_code
*generate rank
by cbsa_code: egen pop_rank = rank(-population_2017)
*sum populations
by cbsa_code: egen total_cbsa_pop = sum(population_2017)
*working HHI - NOTE that this is not comprehensive as there is some data left out, different from the official calculations
sort place_id
by place_id: gen pop_fraction = population_2017 / total_cbsa_pop
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

*generate racial characteristics
by cbsa_code: generate pct_black = (bac_female + bac_male) / tot_pop 


save muni_incorporation.dta, replace
