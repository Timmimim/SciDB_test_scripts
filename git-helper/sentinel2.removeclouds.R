
# This script derives a cloud-free image from a set of Sentinel 2 scenes

# install.packages("devtools")
# devtools::install_github("Paradigm4/SciDBR")
# devtools::install_github("appelmar/scidbst", ref="dev")
# install.packages("gdalUtils") # requires GDAL with SciDB driver (see https://github.com/appelmar/scidb4gdal/tree/dev) on the system:

SCIDB_HOST = "128.176.148.9"
SCIDB_PORT = "30021"
SCIDB_USER = "giscolab"
SCIDB_PW   =  "BxLQmZVL2qqzUhU93usYYdxT"


# We don't want to pass connection details information in every single gdal_translate call und thus set it as environment variables
Sys.setenv(SCIDB4GDAL_HOST=paste("https://",SCIDB_HOST, sep=""), 
           SCIDB4GDAL_PORT=SCIDB_PORT, 
           SCIDB4GDAL_USER=SCIDB_USER,
           SCIDB4GDAL_PASSWD=SCIDB_PW)


library(scidbst)
scidbconnect(host=SCIDB_HOST,port = SCIDB_PORT,
             username = SCIDB_USER, 
             password = SCIDB_PW,
             auth_type = "digest",
             protocol = "https")


s2 = scidbst("SENTINEL2_MS")
s2 = subset(s2,"band1 > 0 and band2 > 0 and band3 > 0 and band4 > 0") # ignore missing values
s2.avg = aggregate(s2,by=list("y","x"), FUN="min(band1),min(band2),min(band3),min(band4)") # compute minimum reflectance for all bands
scidbsteval(s2.avg,name="S2_AGG") # run SciDB query and store result as a new array


# use GDAL to download result as a GeoTIFF image (around 80MB)
library(gdalUtils)
gdal_translate("SCIDB:array=S2_AGG",of = "GTiff",dst_dataset = "S2_AGG.tif")

library(mapview)
x = as(scidbst("S2_AGG"),"RasterBrick") # herunterladen der Daten
x.sample = sampleRegular(x,size=300^2, asRaster=T) # ggf. herunterskalieren
m = mapView(x.sample,legend=TRUE) 
htmlwidgets::saveWidget(m@map, file="temp.html", selfcontained = TRUE)

scidbremove("S2_AGG",force=TRUE)




