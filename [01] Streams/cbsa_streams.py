import geopandas as gpd
import pandas as pd
import matplotlib.pyplot as plt
import os

# set main crs
target_crs = "5070"

# stream shapes from ESRI, download here: https://www.arcgis.com/home/item.html?id=8206e517c2264bb39b4a0780462d5be1
streams_path = r"C:\Users\phynm\OneDrive\Desktop\school\thesis\[01] IV - Streams\shapefiles\Streams.shp"
streams = gpd.read_file(streams_path)
streams = streams.to_crs(target_crs)

# cbsa shapes from US Census, download here: https://www.census.gov/geographies/mapping-files/time-series/geo/tiger-line-file.html
cbsa_path = r"C:\Users\phynm\OneDrive\Desktop\school\thesis\[01] IV - Streams\shapefiles\tl_2025_us_cbsa.shp"
cbsa = gpd.read_file(cbsa_path)
cbsa = cbsa.to_crs(target_crs)

streams_cbsa = gpd.overlay(streams, cbsa, how="intersection")
streams_cbsa["stream_length_m"] = streams_cbsa.geometry.length

cbsa_streams = (
    streams_cbsa.groupby("CBSAFP", as_index=False)["stream_length_m"]
    .sum()
    .rename(columns={"stream_length_m": "stream_length_meters"})
)

cbsa_streams["stream_length_miles"] = cbsa_streams["stream_length_meters"] / 1609.34
cbsa_with_streams = cbsa.merge(cbsa_streams, on="CBSAFP", how="left")

cbsa_with_streams["stream_length_meters"].fillna(0, inplace=True)
cbsa_with_streams["stream_length_miles"].fillna(0, inplace=True)
cbsa_with_streams["area_m2"] = cbsa_with_streams.geometry.area

output_dir = "data"
if not os.path.exists(output_dir):
    os.makedirs(output_dir)

output_path = os.path.join(output_dir, "cbsa_streams.csv")

cbsa_with_streams.drop(columns="geometry").to_csv(output_path, index=False)

print(cbsa_with_streams.head())
