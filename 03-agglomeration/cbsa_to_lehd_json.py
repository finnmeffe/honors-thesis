# should work fine: patchy block coverage when looking at json maps seems to correlate with 
# expected jobs in the area (i.e. downtowns are still fully covered)

#defines functions: 
    #cbsa_wac_enriched(cbsa_code, wac_year), outputs an enriched json

import pandas as pd
import geopandas as gpd
from tqdm import tqdm
import requests
import time
import os
import matplotlib.pyplot as plt

state_abbrev_lookup = {
"01": "al", "02": "ak", "04": "az", "05": "ar", "06": "ca", "08": "co", "09": "ct",
"10": "de", "11": "dc", "12": "fl", "13": "ga", "15": "hi", "16": "id", "17": "il",
"18": "in", "19": "ia", "20": "ks", "21": "ky", "22": "la", "23": "me", "24": "md",
"25": "ma", "26": "mi", "27": "mn", "28": "ms", "29": "mo", "30": "mt", "31": "ne",
"32": "nv", "33": "nh", "34": "nj", "35": "nm", "36": "ny", "37": "nc", "38": "nd",
"39": "oh", "40": "ok", "41": "or", "42": "pa", "44": "ri", "45": "sc", "46": "sd",
"47": "tn", "48": "tx", "49": "ut", "50": "vt", "51": "va", "53": "wa", "54": "wv",
"55": "wi", "56": "wy"
}

def cbsa_wac_enriched(cbsa_code, wac_year):
    cbsa_code = str(cbsa_code)
    
    #find counties in the specified cbsa
    cross = pd.read_csv("crosswalk county cbsa.csv", dtype=str)
    cross['full_fips'] = cross['fipsstatecode'] + cross['fipscountycode']
    cbsa_counties = cross.loc[cross['cbsacode'] == cbsa_code, 'full_fips'].unique().tolist()
    cbsa_title = cross.loc[cross['cbsacode'] == cbsa_code, 'cbsatitle'].unique()
    cbsa_title = cbsa_title[0]
    print(f"Counties in {cbsa_title} CBSA: {cbsa_counties}")
    
    state_fips_needed = sorted({c[:2] for c in cbsa_counties})
    print("State FIPS needed:", state_fips_needed)

    #get the necessary census blocks
    blocks_list = []
    for st in tqdm(state_fips_needed, desc="state block shapefiles"):
        url = f"https://www2.census.gov/geo/tiger/TIGER2010/TABBLOCK/2010/tl_2010_{st}_tabblock10.zip"
        print("url:", url)
        gdf = gpd.read_file(url)
        gdf['GEOID10'] = gdf['GEOID10'].astype(str)
        counties_in_state = [c for c in cbsa_counties if c.startswith(st)]
        if not counties_in_state:
            continue
        gdf = gdf[gdf['GEOID10'].str[:5].isin(counties_in_state)].copy()
        gdf = gdf[['GEOID10', 'geometry']].rename(columns={'GEOID10': 'w_geocode'})
        blocks_list.append(gdf)

    blocks = pd.concat(blocks_list, ignore_index=True)
    print(f"Total blocks: {len(blocks):,}")

    year = str(wac_year) #latest year that WAC goes up to, usually 2019 
    dataset = "wac"
    unique_state_fips = state_fips_needed
    states_to_download = {fips: state_abbrev_lookup[fips] for fips in unique_state_fips if fips in state_abbrev_lookup}

    dfs = []
    for fips, state in states_to_download.items():
        base_url = f"https://lehd.ces.census.gov/data/lodes/LODES7/{state}/{dataset}/"
        filename = f"{state}_{dataset}_S000_JT00_{year}.csv.gz"
        url = base_url + filename

        print(f"{state.upper()} ({fips}) LEHD file from:")
        print(f"   {url}")

        try:
            df = pd.read_csv(url, dtype={'w_geocode': str})
            df["state_fips"] = fips
            dfs.append(df)
            print(f"{len(df):,} rows")
        except Exception as e:
            print(f"failed to download {state.upper()}: {e}")

    if len(dfs) == 0:
        raise ValueError("no data downloaded")

    lehd = pd.concat(dfs, ignore_index=True)
    
    blocks = blocks.rename(columns={'GEOID10': 'w_geocode'})
    
    merged = blocks.merge(lehd, on='w_geocode', how='inner')

    print(f"Merged blocks with LEHD: {len(merged):,}")
    
    folder = r"/geojson storage"
    file_path = f"{cbsa_title}_{wac_year}_blocks_lehd.geojson"
    
    output_path = os.path.join(folder, file_path)

    merged.to_file(output_path, driver="GeoJSON")
    print(f"Saved merged data to {output_path}")
