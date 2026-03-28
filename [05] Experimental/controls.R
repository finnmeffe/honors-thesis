knitr::opts_chunk$set(echo = TRUE)
options(scipen = 0, digits = 3)  # controls base R output`
if(!require('pacman')) {
  install.packages('pacman')
}
pacman::p_load(dplyr, data.table, tidycensus, tidyr, sf)

### Share of population with Bachelor's or higher

edu <- get_acs(
  geography = "cbsa",
  table = "B15003",
  year = 2020,
  survey = "acs5",
  cache_table = TRUE
) %>% 
  select(GEOID, variable, estimate) %>% 
  pivot_wider(names_from = variable, values_from = estimate) %>% 
  mutate(bach_or_higher = B15003_022 + B15003_023 + B15003_024 + B15003_025,
         total = B15003_001,
         share_bach_or_higher = bach_or_higher / total) %>% 
  select(GEOID, share_bach_or_higher)

main <- edu

### Number of universities

unis <- st_read("https://services2.arcgis.com/FiaPA4ga0iQKduv3/arcgis/rest/services/Colleges_and_Universities_View/FeatureServer/0/query?outFields=*&where=1%3D1&f=geojson") 

unis <- unis %>% 
  st_drop_geometry() %>% 
  filter(CONTROL %in% c(1,2)) %>% # public or private np
  group_by(CBSA) %>% 
  summarise(num_unis = n())

main <- main %>% 
  left_join(unis %>% 
              mutate(CBSA = as.character(CBSA)), 
            by = join_by(GEOID == CBSA))

### Total number of firms in industry - load xwalk from agglomeration_v2.rmd

folder <- "C:/Users/phynm/OneDrive/Documents/thesis_data/"

format_naics <- function(codes) {
  a <- as.character(codes)
  
  b <- ifelse(
    nchar(a) <= 2,
    str_pad(a, width = 6, side = "right", pad = "-"),
    str_pad(a, width = 6, side = "right", pad = "/")
  )
  
  b
  
  return(b)
}

zbp <- fread(file.path(folder, "zbp20detail.txt")) %>% 
  select(-c(city, stabbr, cty_name)) %>% 
  mutate(across(`n<5`:`n1000`, ~ replace_na(as.numeric(.x), 0)),
         zip = sprintf("%05d", zip)) %>% 
  pivot_longer(
    cols = `est`:`n1000`,
    names_to = "est_desc",
    values_to = "est"
  ) %>% 
  inner_join(xwalk.zip_cbsa, by = join_by(zip == zip), relationship = "many-to-many") %>% 
  rename(bus_ratio_cbsa = bus_ratio) %>% 
  mutate(adj_est = est * bus_ratio_cbsa) %>% 
  filter(est_desc == "est") %>% 
  select(-est_desc, -est, -bus_ratio_cbsa)

zbp <- zbp %>% 
  mutate(sector = case_when(
    naics %in% format_naics(71) ~ "creative",
    naics %in% format_naics(c(5112,5182,5417,5415)) ~ "tech"
  )) %>% 
  filter(!is.na(sector)) %>% 
  group_by(cbsa, sector) %>% 
  summarise(n = sum(adj_est)) %>% 
  pivot_wider(names_from = sector, values_from = n)

main <- main %>% 
  left_join(zbp, by = join_by(GEOID == cbsa))

### Export

main <- main %>% 
  replace_na(list(num_unis = 0, creative = 0, tech = 0))

write.csv(main, "data/controls.csv", row.names=FALSE)
  