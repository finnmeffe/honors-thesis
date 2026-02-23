# Economics Honors Thesis

This repository contains code used as part of my senior thesis investigating the role of political fragmentation on urban spatial agglomeration. thesis_draf.pdf contains a rough draft of the first sections of the paper. 

### [01] Streams - _Stata, Python_

This folder contains code for the construction of the "small streams" instrument. cbsa_streams.py aggregates necessary geospatial streams data by county. 00streams_merge.do merges all datasets to construct full suite of controls, and 01streams_regress.do conducts the regressions.

### [02] Incorporation Date - _Stata_ 

Holds code for a secondary instrument based on municipal incorporation date as both a separate line of research and means of testing the first instrument. 00historical_county_clean.do processes data from a historical county dataset, 01incorporation_merge.do merges the files, and 02incoporation_regress.do performs the basic regressions.

### [03] Fragmentation - _R, Python_

spatial_fragmentation.rmd constructs a new measure of political fragmentation using border shapes as a proxy for municipal competition as a further exercise of defining fragmentation in the thesis. index.py and merge.py are simple files to construct the primary fragmentation measure.

### [04] Agglomeration - _R, Python_

Holds code for constructing the measure of firm agglomeration. cbsa_to_lehd_json.py creates jsons for each CBSA in the sample from LODES data. The measure of concentration (Ripley L) is then calculated from these jsons using ripley_l.py. agglomeration_main.R contains a similar workflow, though more refined and readable as Rmd file (suggested to get an overview of the process).
