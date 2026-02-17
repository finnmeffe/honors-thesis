import pandas as pd

# download the 2022 Census of Governments Data

df = pd.read_excel("data/Govt_Units_2022_Final.xlsx")
print(df.head())

muni_count = (
    df[df["unit_type"] == ('2 - MUNICIPAL' or '3 - TOWNSHIP')]
    .groupby(['cbsa code', "cbsa title"])
    .size()
    .reset_index(name="num_municipalities")
)

county_count = (
    df.groupby(['cbsa code', "cbsa title"])["county_fips_full"]
    .nunique()
    .reset_index(name="num_counties")
)

def calc_hhi(group):
    shares = group["population"] / group["population"].sum()
    return (shares ** 2).sum()

hhi_df = (
    df[df["unit_type"] == ('2 - MUNICIPAL' or '3 - TOWNSHIP')]
    .groupby(["cbsa code", "cbsa title"])
    .apply(calc_hhi, include_groups=False)
    .reset_index(name="hhi_population")
)

def calc_pop(group):
    return group['population'].sum()

pop_df = (
    df[df["unit_type"] == ('2 - MUNICIPAL' or '3 - TOWNSHIP')]
    .groupby(['cbsa code', 'cbsa title'])
    .apply(calc_pop, include_groups=False)
    .reset_index(name='total_population')
    )

cbsa_summary = (
    muni_count
    .merge(county_count, on=["cbsa code", "cbsa title"], how="outer")
    .merge(hhi_df, on=["cbsa code", "cbsa title"], how="left")
    .merge(pop_df, on=["cbsa code", "cbsa title"], how="left")
    .sort_values("cbsa code")
)

cbsa_summary.to_excel('summary_table.xlsx', index=False)


