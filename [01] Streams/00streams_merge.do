global path "C:\Users\phynm\OneDrive\Documents\GitHub\honors-thesis"
global streams "${path}/[01] Streams/data"
global frag "${path}/[03] Fragmentation/data"
clear

/////////////////////////////////////
*MERGE STREAM DATA WITH FRAG MEASURES
/////////////////////////////////////

cd "$frag"
import delimited fragmentation_basic
cd "$streams"
save fragmentation_basic, replace
clear

import delimited cbsa_streams
keep cbsafp name memi aland awater stream_length_meters stream_length_miles
rename cbsafp cbsacode
save cbsa_streams.dta, replace

merge 1:1 cbsacode using fragmentation_basic
drop if _merge != 3
drop _merge name

save cbsa_streams, replace
erase fragmentation_basic.dta
clear

////////////////////////////////
*ADD DUMMIES FOR BODIES OF WATER
////////////////////////////////

*csv constructed using ArcGIS Pro 
import delimited water_body
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

*csv download from usda economic research service https://www.ers.usda.gov/data-products/area-and-road-ruggedness-scales/descriptions-and-maps
import delimited ruggedness
keep countyfips23 areatri_mean
collapse (mean) mean_areatri=areatri_mean (sd) sd_areatri=areatri_mean, by(countyfips23)

gen z = string(countyfips23, "%05.0f")
drop countyfips23
rename z fips_state_county

save ruggedness, replace
clear

import delimited "https://data.nber.org/cbsa-csa-fips-county-crosswalk/2023/cbsa2fipsxw_2023.csv"
gen fipsstate = string(fipsstatecode, "%02.0f")
gen fipscounty = string(fipscountycode, "%03.0f")
gen fips_state_county = fipsstate + fipscounty
keep cbsacode cbsatitle fips_state_county

merge 1:1 fips_state_county using ruggedness
drop if _merge != 3
drop _merge fips_state_county
collapse (mean) mean_areatri (mean) sd_areatri, by(cbsacode)
destring cbsacode, replace

merge 1:1 cbsacode using cbsa_streams
drop if _merge != 3
drop _merge

order cbsacode num_* pop_* hhi_*
gen streams_per_area = stream_length_meters / aland
erase ruggedness.dta
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

