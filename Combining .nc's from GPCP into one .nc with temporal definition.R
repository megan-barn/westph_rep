# load libraries
library(ncdf4)
library(dplyr)
library(RNetCDF)

# path to all files
all_file_path <- "C:/Users/Megan/Documents/prcp_gpcp"

# list all files in directory
all_file_list <- list.files(all_file_path, pattern = "\\.nc$", full.names = TRUE)
all_file_list <- sort(all_file_list)

  # verify structure
    print(length(all_file_list))
    print(head(all_file_list))  

# number of months in 21 years
total_months <- 21 * 12

# create list to store prcp data
final_list <- vector("list", total_months)

# define variable (must be exact same as in the files)
var_name <- "precip"

# loop through each file and extract data
for (file_index in 1:length(all_file_list)) {
  # print current file index and path for debugging
  print(paste("processing file index:", file_index))
  print(all_file_list[file_index])
  
  # open .nc files
  total.nc <- nc_open(all_file_list[file_index])
  
  # list variables to check
  print(names(total.nc$var))
  
  # extract data for specified variable
  prcp <- ncvar_get(total.nc, var_name)
  
  #close .nc files
  nc_close(total.nc)
  
  # store data in final_list
  final_list[[file_index]] <- prcp
}

# check structure and content of loaded data
print(str(final_list))
  # check if final_list has 252 values
  if (length(final_list) != 252) {
    stop("the list final_list does not contain 252 elements")
  }

# Get the dimensions of one sample to define the structure
sample_data <- final_list[[1]]
lat_dim_length <- dim(sample_data)[1]  # Assuming first dimension is latitude
lon_dim_length <- dim(sample_data)[2]  # Assuming second dimension is longitude
print(paste("Latitude dimension:", lat_dim_length))
print(paste("Longitude dimension:", lon_dim_length))

# Define the time dimension (12 months for each of 21 years)
total_months <- 21 * 12

# Define the time values (e.g., 0 to 251 representing months since 2000-01)
time_vals <- 0:(total_months - 1)

# Define the dimensions using ncdim_def
time_dim <- ncdim_def(name = "time", units = "months since 2000-01-01", vals = time_vals)
lat_vals <- seq(-90, 90, length.out = lat_dim_length)
lon_vals <- seq(-180, 180, length.out = lon_dim_length)
lat_dim <- ncdim_def(name = "lat", units = "degrees_north", vals = lat_vals)
lon_dim <- ncdim_def(name = "lon", units = "degrees_east", vals = lon_vals)

# Define the precipitation variable using ncvar_def
precip_var <- ncvar_def(name = "precipitation", units = "mm", 
                        dim = list(time_dim, lat_dim, lon_dim), 
                        longname = "Monthly Precipitation")

# Create the new NetCDF file
output_file <- "combined_precipitation.nc"
nc <- nc_create(output_file, list(precip_var))

# Write the data to the NetCDF file
for (i in 1:length(final_list)) {
  # Note: `start` index is the starting index for each dimension (time, lat, lon)
  # Here, we start at the ith time index and the first index for lat and lon
  ncvar_put(nc, precip_var, final_list[[i]], start = c(i, 1, 1), count = c(1, lat_dim_length, lon_dim_length))
  }

# Add global attributes (metadata)
ncatt_put(nc, 0, "title", "Combined Global Monthly Precipitation Data 2000-2020")
ncatt_put(nc, 0, "source", "Global Precipitation Climatology Project, NOAA Physical Sciences Laboratory")
ncatt_put(nc, 0, "author", "Megan Barnhart")
ncatt_put(nc, 0, "institution", "University of Chicago Existential Risk Lab")
ncatt_put(nc, 0, "history", paste("Created on", Sys.Date()))

# Close the file
nc_close(nc)

# Print confirmation
print(paste("NetCDF file created at:", output_file))
