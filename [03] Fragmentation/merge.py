import pandas as pd

# Load both datasets
muni_df = pd.read_excel("C:/Users/phynm/OneDrive/Desktop/school/thesis/municipalities.xlsx")
cbsa_df = pd.read_excel("C:/Users/phynm/OneDrive/Desktop/school/thesis/counties.xlsx", skiprows=2, skipfooter=3)


muni_df.columns = muni_df.columns.str.lower().str.strip()
cbsa_df.columns = cbsa_df.columns.str.lower().str.strip()

muni_df["state_fips"] = muni_df["fips_state"].astype(str).str.zfill(2)
muni_df["county_fips"] = muni_df["fips_county"].astype(str).str.zfill(3)
cbsa_df["state_fips"] = cbsa_df["fips state code"].astype(float).astype(int).astype(str).str.zfill(2)
cbsa_df["county_fips"] = cbsa_df["fips county code"].astype(float).astype(int).astype(str).str.zfill(3)

muni_df["county_fips_full"] = muni_df["state_fips"] + muni_df["county_fips"]
cbsa_df["county_fips_full"] = cbsa_df["state_fips"] + cbsa_df["county_fips"]

merged_df = pd.merge(
    muni_df,
    cbsa_df[["county_fips_full", 'cbsa code', 'metropolitan division code', 'csa code', 'cbsa title',
           'metropolitan/micropolitan statistical area','metropolitan division title', 'csa title']],
    on="county_fips_full",
    how="left"
)

merged_df.to_excel("municipalities_with_cbsa.xlsx", index=False)
