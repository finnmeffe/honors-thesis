import geopandas as gpd
import pandas as pd

streams = gpd.read_file("C:/Users/phynm/OneDrive/Desktop/school/thesis/iv streams/shapefiles/Streams.shp")
cbsa = gpd.read_file("C:/Users/phynm/OneDrive/Desktop/school/thesis/iv streams/shapefiles/tl_2025_us_cbsa.shp")

# use same CRS
target_crs = "EPSG:5070"
streams = streams.to_crs(target_crs)
cbsa = cbsa.to_crs(target_crs)

# find all streams within a cbsa boundary
streams_cbsa = gpd.overlay(streams, cbsa, how="intersection")

# find stream length
streams_cbsa["stream_length_m"] = streams_cbsa.geometry.length

# summarize stream lengths by CBSA
cbsa_streams = (
    streams_cbsa.groupby("CBSAFP", as_index=False)["stream_length_m"]
    .sum()
    .rename(columns={"stream_length_m": "stream_length_meters"})
)

# convert to miles
cbsa_streams["stream_length_miles"] = cbsa_streams["stream_length_meters"] / 1609.34

# merge back to cbsa polygons 
cbsa_with_streams = cbsa.merge(cbsa_streams, on="CBSAFP", how="left")

# fill missing stream lengths with 0
cbsa_with_streams["stream_length_meters"].fillna(0, inplace=True)
cbsa_with_streams["stream_length_miles"].fillna(0, inplace=True)

# compute area directly on cbsa_with_streams
cbsa_with_streams["area_m2"] = cbsa_with_streams.geometry.area

# export full cbsa_with_streams with all attributes preserved
cbsa_with_streams.to_file("cbsa_with_streams.shp")  # or GeoJSON, etc.
cbsa_with_streams.drop(columns="geometry").to_csv("cbsa_streams_summary.csv", index=False)

print(cbsa_with_streams.head())