#' How Much Shit and How Badly Do They Measure It? The Maps
#'
#' This script prepares the data for the plots which show how the volume of
#' storm sewerage overflow (SSO) alongside The proportion of the SSO network
#' that is monitored.
#'
#'


# ---- check for required packages: Install if required ----

# packages <- c('sp', 'spdep', 'tmap', 'classInt', 'grid', 'gridExtra', 'lattice',
#              'dplyr', 'tidyr','sf', 'utils', 'maptiles', 'exactextractr')
# install.packages(setdiff(packages, rownames(installed.packages())))

# --- bivariate


library(sf)
library(tmap)
library(maptiles)
library(viridisLite)
source('SewerMapData.R')
source("bivariate_tmap.R") # source functions for bivariate mapping

tmap_mode("plot")



base_osm <- get_tiles(st_buffer(st_as_sfc(st_bbox(Join_Sewer_Serv_Data)), 10000),
                      crop = TRUE, zoom = 8,
                      provider=  "Stamen.TerrainBackground")


# Plot bivariate choroplet map
bivariate_plot <- function(file_name, biv_cols, normalise_method, biv_palette='BlueOrange'){
  png(filename=file_name,
      width = 425*2, height = 480*2 )

  bivariate_choropleth(Join_Sewer_Serv_Data, biv_cols,
                       basemap=base_osm, bm_alpha=0.7, bivmap_scale=T,
                       biv_palette=biv_palette,
                       bivmap_labels=c('How Much Shit?*', 'How well do they measure it?**'),
                       poly_alpha=0.8, scale_pos = c('left', 'bottom'),
                       bivmap_label_point=Sewer_Serv_Areas_cent,
                       bivmap_label_col = 'COMPANY_r',
                       footnote=c(sprintf("* The total volume of Sewer Storm Overflows (SSO) for 2020 %s \n
** The proportion of the SSOs that were monitored in 2020 \n
%s \n
© Environment Agency copyright and/or database right 2020. Dŵr Cymru/Welsh Water. The Rivers Trust. All rights reserved."
                                          , normalise_method, maptiles::get_credit("Stamen.TerrainBackground"))),
                       title='How Much Shit and How Well Do They Measure It?')

  dev.off()
}

choropleth_plot <- function(poly, col_name, col_pal, title, file_name,bm_alpha=0.5,
                            poly_alpha=0.8, style='jenks', digits = 0, port=T,
                            sci=F){
  # png(filename=file_name,
  #     width = 425*2, height = 480*2 )
  tm <-tm_shape(base_osm, bbox=st_bbox(poly))+
    tm_rgb(alpha=bm_alpha,legend.show = FALSE)+
    tm_shape(poly) +
    # Fill
    tm_polygons(col_name, palette=col_pal,
                alpha=poly_alpha,
                style=style,
                # n=nrow(poly),
                legend.is.portrait=port,
                legend.format=list(scientific=sci),
                title= title) +
    tm_shape(Sewer_Serv_Areas_cent)+
    tm_dots('black', size=0.2, legend.show=F) +
    tm_text('COMPANY_r', auto.placement=F, size=1.5, just=c('center'),
            fontface = 3, ymod=-1)+
    tm_layout(frame=T,
              legend.title.size = 2.2,
              legend.text.size = 1.5,
              legend.title.fontface =3,
              legend.height = 0.2,
              legend.format = list(digits = digits)) +
    # Add scale bar
    tm_scale_bar(
      position=c("left", "bottom"), width=0.25, text.size=1.4) +

    # Add rhe legend
    tm_legend(scale=0.75) +
    tm_compass(position=c("right", "top"), size=5, text.size=1.4) +
    tm_credits(sprintf("%s \n
© Environment Agency copyright and/or database right 2020. Dŵr Cymru/Welsh Water. The Rivers Trust. All rights reserved."
                                          , maptiles::get_credit("Stamen.TerrainBackground")), position=c("right", "bottom"),
               size=1.0, width=0.6)
    tmap_save(tm, filename = file_name, width = 425*8, height = 480*8)
  # plot(tm)
  # dev.off()
}

#Bivariate plots
bivariate_plot(file_name = "Bivariate_PopNormal.png",
               biv_cols= c("cso_flow_duration_per_pop", "perc_mon"),
               normalise_method = 'divided by population density')

bivariate_plot(file_name = "Bivariate_AreaNormal.png",
               biv_cols= c("cso_flow_durati_per_km2", "perc_mon"),
               normalise_method = 'divided by sewerage service area',
               biv_palette='BlueRed')

bivariate_plot(file_name = "Bivariate_Total.png",
               biv_cols= c("cso_flow_duration", "perc_mon"),
               normalise_method = '',
               biv_palette='GreenPurple')

# Single value Choropleths
choropleth_plot(Join_Sewer_Serv_Data,
                col_name = "perc_mon",
                col_pal= viridis(nrow(Join_Sewer_Serv_Data)),
                title="% of SSOs that are Monitored",
                file_name='Choropleth_PercentMon.png')

choropleth_plot(Join_Sewer_Serv_Data,
                col_name = "cso_flow_duration_per_pop",
                col_pal= inferno(nrow(Join_Sewer_Serv_Data)),
                title= 'Log10 SSO flow duration (hrs) divided by Pop. density (people per km^2)',
                style='log10',
                file_name='Choropleth_flow_duration_per_pop.png',
                port = F)

choropleth_plot(Join_Sewer_Serv_Data,
                col_name = "cso_flow_durati_per_km2",
                col_pal= mako(nrow(Join_Sewer_Serv_Data)),
                title= 'SSO flow duration (hrs) divided by sewerage service area (km^2)',
                style='pretty',
                file_name='Choropleth_flow_duration_per_km2.png',
                digits=4, sci=T)

