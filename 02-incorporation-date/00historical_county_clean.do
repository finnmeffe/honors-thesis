cd ""

clear

import delimited historical_county_populations_v2
rename cty_fips fips_state_county
tostring fips_state_county, replace force
replace fips_state_county = string(real(fips_state_county), "%05.0f")
rename cty county

save historical_cbsa_populations, replace
clear

/////////////////////////////////
*CREATE HISTORICAL CBSA POPULATIONS
/////////////////////////////////


use county_cbsa_xwalk
format %5s cbsa_code
save county_cbsa_xwalk, replace
keep cbsa_code cbsa_title fips_state_county
merge 1:m fips_state_county using historical_cbsa_populations
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
save historical_cbsa_populations, replace
clear

////////////////////////////////
*CREATE HISTORICAL COUNTY POPULATIONS
////////////////////////////////

import delimited historical_county_populations_v2
rename cty_fips fips_state_county
tostring fips_state_county, replace force
replace fips_state_county = string(real(fips_state_county), "%05.0f")
rename cty county

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


save historical_county_populations, replace
