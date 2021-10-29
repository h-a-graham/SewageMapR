#' How Much Shit and How Badly Do They Measure It? The Data...
#'
#' This script prepares the data for the plots which show how the volume of
#' storm sewerage overflow (SSO) alongside The proportion of the SSO network
#' that is monitored.
#'
#'


# ----- Load Packages ------------
library(dplyr)
library(tidyr)
library(sf)
library(tmap)
library(utils)
library(exactextractr)
library(terra)

# ------ READ DATA --------------
if (file.exists('Join_Sewer_Serv_Data.rds')){
  Join_Sewer_Serv_Data <- readRDS('Join_Sewer_Serv_Data.rds')
  } else {
  # Unmonitored CSO data
  EW_Unmon_CSO <- read_sf('data/__England_Unmonitored_CSOs_2020.geojson') %>%
    bind_rows(read_sf('data/Welsh_Unmonitored_CSOs_2020.geojson'))%>%
    st_transform(crs=27700)

  # Monitored CSO data
  EW_StormOv_EvDur <- read_sf('data/Event_Duration_Monitoring_-_Storm_Overflows_-_2020_(England_and_Wales).geojson')%>%
    st_transform(crs=27700)


  # Function to open .shp from zipped file
  shp_from_zip <- function(zip_path){
    utils::unzip(zip_path, exdir=file.path(tempdir(), zip_path)) %>%
      dirname() %>%
      first() %>%
      list.files(pattern = "\\.shp$",full.names=T)
  }

  # -- Create Sewer Servie Area Polygon - Attach attributes from CSO data. -- #

  # load
  Sewer_Serv_Areas <- shp_from_zip('data/SewerageServicesAreas_incNAVsv1_3.zip') %>%
    read_sf() %>%
    group_by(COMPANY) %>%
    summarise() %>%
    st_transform(crs=27700) #%>%
  # mutate(cso_Unmon_count = lengths(st_intersects(., EW_Unmon_CSO)),
  #        cso_Unmon_count_km2 = cso_Unmon_count/(as.numeric(st_area(.))/1000))

  unmon_join <- st_join(EW_Unmon_CSO, Sewer_Serv_Areas, join=st_nearest_feature)

  unmon_stats <- unmon_join %>%
    group_by(COMPANY) %>%
    dplyr::summarize(cso_Unmon_count = n())%>%
    st_drop_geometry()

  overflow_join <- st_join(EW_StormOv_EvDur, Sewer_Serv_Areas, join=st_nearest_feature)

  overflow_stats <- overflow_join %>%
    group_by(COMPANY) %>%
    st_drop_geometry() %>%
    dplyr::summarize(cso_flow_duration=sum(Total_Duration_hrs, na.rm=TRUE)/24,
                     cso_Mon_count = n())


  Join_Sewer_Serv_Data  <- Sewer_Serv_Areas%>%
    left_join(unmon_stats, by='COMPANY') %>%
    left_join(overflow_stats, by='COMPANY') %>%
    mutate(perc_mon = (cso_Mon_count/(cso_Unmon_count + cso_Mon_count))*100,
           cso_flow_durati_per_km2=cso_flow_duration/(as.numeric(st_area(Sewer_Serv_Areas))/1000)) %>%
    tidyr::drop_na() %>%
    st_as_sf()

  pop_den_path <- 'data/0995e94d-6d42-40c1-8ed4-5090d82471e1.zip'
  residential_pop_density <- unzip(pop_den_path, exdir=file.path(tempdir())) %>%
    dirname() %>%
    first(.) %>%
    file.path(., 'data', 'UK_residential_population_2011_1_km.asc') %>%
    terra::rast() %>%
    terra::project(., 'epsg:27700')

  Join_Sewer_Serv_Data <- Join_Sewer_Serv_Data %>%
    mutate(pop_dens_sum = exact_extract(residential_pop_density,
                                        Join_Sewer_Serv_Data, 'sum')/(as.numeric(st_area(Join_Sewer_Serv_Data))/1000),
           cso_flow_duration_per_pop = cso_flow_duration/pop_dens_sum)

  saveRDS(Join_Sewer_Serv_Data, 'Join_Sewer_Serv_Data.rds')
}

# --- create
if (file.exists('Sewer_Serv_Areas_cent.rds')){
  Sewer_Serv_Areas_cent <- readRDS('Sewer_Serv_Areas_cent.rds')
} else {
  Sewer_Serv_Areas_cent <- Join_Sewer_Serv_Data %>%
    st_geometry() %>%
    st_inscribed_circle() %>%
    st_centroid(of_largest_polygon=T) %>%
    st_as_sf() %>%
    distinct() %>%
    filter(!st_is_empty(.)) %>%
    st_join(Join_Sewer_Serv_Data, largest=T) %>%
    mutate(COMPANY_r = gsub("Water|\\.\\d+[A-Za-z]+", "Wat.", COMPANY),
           COMPANY_r = gsub("Utilities|\\.\\d+[A-Za-z]+", "Util.", COMPANY_r))

  saveRDS(Sewer_Serv_Areas_cent, 'Sewer_Serv_Areas_cent.rds')
}




