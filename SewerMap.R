#' How Much Shit and How Badly Do They Measure It?
#'
#' A script to visualise how much water companies pump sewerage into rivers from
#' Sewer Storm Overflows (SSO) and how what percentage of CSOs are not even
#' monitored
#'
#'

# ---- check for required packages: Install if required ----

# packages <- c('sp', 'spdep', 'tmap', 'classInt', 'grid', 'gridExtra', 'lattice',
#              'dplyr', 'tidyr','sf', 'utils', 'maptiles)
# install.packages(setdiff(packages, rownames(installed.packages())))

# ----- Load Packages ------------
library(dplyr)
library(tidyr)
library(sf)
library(tmap)
library(utils)
library(maptiles)
source("bivariate_tmap.R") # source functions for bivariate mapping
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
    dplyr::summarize(cso_flow_duration=sum(Total_Duration_hrs, na.rm=TRUE),
                     cso_Mon_count = n())


  Join_Sewer_Serv_Data  <- Sewer_Serv_Areas%>%
    left_join(unmon_stats, by='COMPANY') %>%
    left_join(overflow_stats, by='COMPANY') %>%
    mutate(perc_mon = (cso_Mon_count/(cso_Unmon_count + cso_Mon_count))*100,
           cso_flow_durati_per_km2=cso_flow_duration/(as.numeric(st_area(Sewer_Serv_Areas))/1000)) %>%
    tidyr::drop_na() %>%
    st_as_sf()

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
    st_join(Join_Sewer_Serv_Data, largest=T)

  saveRDS(Sewer_Serv_Areas_cent, 'Sewer_Serv_Areas_cent.rds')
}

# Water_Sup_Areas <- shp_from_zip('data/WaterSupplyAreas_incNAVsv1_3.zip') %>%
#   read_sf() %>%
#   group_by(COMPANY) %>%
#   summarise() %>%
#   st_transform(crs=27700)

# --------- Check Data Interactively  ------------
#
# tmap_mode("view")
# tmap::tm_basemap() +
#   tm_shape(Join_Sewer_Serv_Data)+
#   tm_polygons('cso_flow_durati_per_km2',palette=viridisLite::mako(n=nrow(Sewer_Serv_Areas)), legend.show=T) +
#   # tm_shape(Join_Sewer_Serv_Data)+
#   # tm_polygons('perc_mon',palette=viridisLite::viridis(n=nrow(Sewer_Serv_Areas)), legend.show=T) +
#   tm_shape(Sewer_Serv_Areas_cent)+
#   tm_dots('black',legend.show=F) +
#   tm_text('COMPANY', auto.placement=T, size=0.7, just='center')


# --- bivariate



tmap_mode("plot")




base_osm <- get_tiles(st_buffer(st_as_sfc(st_bbox(Join_Sewer_Serv_Data)), 10000),
                      crop = TRUE, zoom = 8,
                     provider=  "Stamen.TerrainBackground")


# Plot bivariate choroplet map

Sewer_Serv_Areas_cent2 <- Sewer_Serv_Areas_cent%>%
  mutate(COMPANY_r = gsub("Water|\\.\\d+[A-Za-z]+", "Wat.", COMPANY),
         COMPANY_r = gsub("Utilities|\\.\\d+[A-Za-z]+", "Util.", COMPANY_r))

png(filename="HowMuchShitAndHowWellDoTheyMeasure.png",
    width = 425*2, height = 480*2 )

bivariate_choropleth(Join_Sewer_Serv_Data, c("cso_flow_durati_per_km2", "perc_mon"),
                     basemap=base_osm, bm_alpha=0.7, bivmap_scale=T,
                     bivmap_labels=c('How Much Shit?*', 'How well do they measure it?**'),
                     poly_alpha=0.7, scale_pos = c('left', 'bottom'),
                     bivmap_label_point=Sewer_Serv_Areas_cent2,
                     bivmap_label_col = 'COMPANY_r',
                     footnote=c(sprintf("* The total volume of Sewer Storm Overflows (SSO) for 2020 divided by water company service area \n
** The proportion of the SSOs that were monitored in 2020 \n
%s \n
© Environment Agency copyright and/or database right 2020. Dŵr Cymru/Welsh Water. The Rivers Trust. All rights reserved."
                                        , maptiles::get_credit("Stamen.TerrainBackground"))),
                     title='How Much Shit and How Well Do They Measure It?')

dev.off()
