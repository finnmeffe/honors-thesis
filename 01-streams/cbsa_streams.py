import geopandas as gpd
import pandas as pd

# stream shapes from ESRI; cbsa shapes from census
streams = gpd.read_file("Streams.shp")
cbsa = gpd.read_file("tl_2025_us_cbsa.shp")

target_crs = "EPSG:5070"
streams = streams.to_crs(target_crs)
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

cbsa_with_streams.to_file("cbsa_with_streams.shp")  # or GeoJSON, etc.
cbsa_with_streams.drop(columns="geometry").to_csv("cbsa_streams_summary.csv", index=False)


print(cbsa_with_streams.head())
