# westph_rep
We are testing global environmental trends against instances of state failure between the years 1982 and 2023. One-hundered and sixty-eight states were coded as failed (1) or not failed (0) based on scoring system derived from the Bertelsmung-Stiftlung's Transformation Index, Human Development Index, ___taxation source___, and ___drinking water source___. 

The five predictor variables are:
> T_SUM: Mean departure from baseline (1960-1980) growing season temperature over historically agriculturally productive land areas.

> V_LOW: Average change in vegatation density from 1982 to 2023 over the same land areas as T_SUM.

> P_DRT: Incidence of drought conditions (SPEI < -1) in the state's continental (if applicable) land area.

> T_WIN: Average change in winter temperature from 1982 to 2023 in the state's continental (if applicable) land area.

> C_WET: Frequency of 'wet' years (SPEI > 1.5) in and around densely populated urban areas.

We expect above average growing season temperatures, decreases in vegetation density, increases in winter temperature, and high incidence of statewide drought and 'wet' urban conditions will correlate with state failure (1) due to our theory that famine and disease are hallmarks of historical failure events that are being exacerbated by climate change.






Raw data sources:

> Winter and growing season temperatures at 2 meters from ERA5 monthly averaged data on single levels from 1940 to present, Copernicus Climate Data Store. 

>   Monthly precipitation data from NOAA's Physical Science Laboratory Global Precipitation Climatology Project (GPCP).
      > GPCP data was standardized with the Standardized Precipitation
Evapotranspiration Index (SPEI) using the Thornthwaite method.

> Vegetation data obtained from NOAA Climate Data Record of Normalized Difference Vegetation Index (NDVI), Version 4, NOAA's NCEI Climate Data Guide website
