import geopandas as gpd
import numpy as np
from scipy.spatial import cKDTree
import pandas as pd

def lfunction(geojson, wac_code):
    geojson = str(geojson)
    employment_type = str(wac_code)
    gdf = gpd.read_file(geojson)
    gdf[employment_type] = gdf[employment_type].astype(float)
    gdf = gdf[gdf[employment_type] > 0].copy()

    gdf = gdf.to_crs(epsg=3857)
    gdf["geometry"] = gdf.geometry.centroid

    coords = np.vstack((gdf.geometry.x.values, gdf.geometry.y.values)).T
    weights = gdf[employment_type].values

    tree = cKDTree(coords)
    miles_to_m = 1609.34
    radii_m = np.array([0.25, 0.5, 0.75, 1, 2, 3, 4, 5, 10, 20, 30, 40, 50]) * miles_to_m

    bounds = gdf.total_bounds  
    study_area = (bounds[2] - bounds[0]) * (bounds[3] - bounds[1])  

    results = []

    for r in radii_m:
        neighbor_lists = tree.query_ball_point(coords, r)
        weighted_counts = np.array([weights[neighbors].sum() for neighbors in neighbor_lists])
    
        K_r = np.sum(weights * weighted_counts) / (np.sum(weights)**2 / study_area)
    
        L_r = np.sqrt(K_r / np.pi) - r
    
        results.append({
            "radius_m": r,
            "radius_miles": r / miles_to_m,
            "K": K_r,
            "L": L_r
            })

    ripley_df = pd.DataFrame(results)
    return ripley_df

