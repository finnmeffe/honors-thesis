cd "C:\Users\phynm\OneDrive\Desktop\school\thesis\iv streams"
clear

/////////////////////////////////////
*MERGE STREAM DATA WITH FRAG MEASURES
/////////////////////////////////////

import delimited cbsa_streams_summary
keep cbsafp name memi aland awater stream_length_meters stream_length_miles
rename cbsafp cbsacode

merge 1:1 cbsacode using cbsa_fragmentation
drop if _merge != 3
drop _merge name

save cbsa_streams, replace
clear

////////////////////////////////
*ADD DUMMIES FOR BODIES OF WATER
////////////////////////////////

import delimited water_body_dummies
keep cbsafp greatlake ocean
replace ocean = 0 if ocean == .
rename cbsafp cbsacode

merge 1:1 cbsacode using cbsa_streams
drop if _merge != 3
drop _merge

save cbsa_streams, replace
clear

///////////////////////////////////
*ADD CONTROL FOR TERRAIN RUGGEDNESS
///////////////////////////////////

import delimited raw_ruggedness
keep countyfips23 areatri_mean
collapse (mean) mean_areatri=areatri_mean (sd) sd_areatri=areatri_mean, by(countyfips23)

gen z = string(countyfips23, "%05.0f")
drop countyfips23
rename z fips_state_county

save raw_ruggedness, replace
clear

use county_cbsa_xwalk
keep cbsa_code fips_state_county
rename cbsa_code cbsacode

merge 1:1 fips_state_county using raw_ruggedness
drop if _merge != 3
drop _merge fips_state_county
collapse (mean) mean_areatri (mean) sd_areatri, by(cbsacode)
destring cbsacode, replace

merge 1:1 cbsacode using cbsa_streams
drop if _merge != 3
drop _merge

order cbsacode cbsatitle num_* total_population hhi_population 
gen streams_per_area = stream_length_meters / aland
save cbsa_streams, replace

////////////////////////////
*GATHER STATE AND MULTISTATE
////////////////////////////

gen state = trim(substr(cbsatitle, strpos(cbsatitle, ",") + 1, length(cbsatitle)))
gen len_state = length(state)
tab len_state
gen multistate = 0
replace multistate = 1 if len_state > 2
replace state = substr(state, 1, 2)
drop len_state

save cbsa_streams, replace
