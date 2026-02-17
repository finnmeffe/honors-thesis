if(!require('pacman')) {
  install.packages('pacman')
}
pacman::p_load(ggplot2, dplyr, tidyverse, data.table, lubridate, ggpubr, skimr, scales, plotly, tidycensus, readxl, httr, jsonlite, sf, mapview, tigris, lehdr)

# read in Census of Governments data
cog_2022 <- read_excel("data/Govt_Units_2022_Final.xlsx")

cog_2022_muni <- cog_2022 %>% 
  select(UNIT_NAME, UNIT_TYPE, POPULATION, FIPS_STATE, FIPS_COUNTY, FIPS_PLACE) %>% 
  filter(UNIT_TYPE %in% c("2 - MUNICIPAL","3 - TOWNSHIP")) %>% 
  rename_with(tolower) %>% 
  mutate(fips = paste0(fips_state,fips_county))

# read in crosswalk 
xwalk.cbsa_fips <- read_csv("https://data.nber.org/cbsa-csa-fips-county-crosswalk/2023/cbsa2fipsxw_2023.csv") %>% 
  mutate(fullfips = paste0(fipsstatecode, fipscountycode)) %>% 
  select(cbsacode,cbsatitle,fullfips)

cog_2022_muni <- cog_2022_muni %>% 
  inner_join(xwalk.cbsa_fips, by = join_by(fips == fullfips))

hhi <- function(col) {
  total = sum(col)
  shares = col/total
  result = sum(shares^2)
  return(result)
} 

# separate out these for townships vs municipalities

cog_2022_sum <- cog_2022_muni %>% 
  group_by(cbsacode) %>% 
  summarise(num_counties = n_unique(fips_county),
            cbsatitle = first(cbsatitle),
            num_munis = n_unique(fips_place[unit_type == "2 - MUNICIPAL"]),
            num_local = n_unique(fips_place),
            pop_muni = sum(population[unit_type == "2 - MUNICIPAL"]),
            pop_total = sum(population),
            hhi_pop_muni = hhi(population[unit_type == "2 - MUNICIPAL"]),
            hhi_pop_total = hhi(population),
  )

write.csv(cog_2022_sum, file = "data/fragmentation_basic.csv", row.names=FALSE)

