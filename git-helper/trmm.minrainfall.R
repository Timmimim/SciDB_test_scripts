
# This script computes minimum 30 day accumulated precipitation for a given period

# install.packages("devtools")
# devtools::install_github("Paradigm4/SciDBR")
# devtools::install_github("appelmar/scidbst", ref="dev")
# install.packages("gdalUtils") # requires GDAL with SciDB driver (see https://github.com/appelmar/scidb4gdal/tree/dev) on the system:

SCIDB_HOST = "128.176.148.9"
SCIDB_PORT = 30021
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


# compute average / minimum / maximum precipitation during Jan - Mar 2011


ext.time = textent(as.POSIXct("2008-01-01"),as.POSIXct("2008-06-30"))
bbox = extent(-20,20,-10,10)


trmm.ref = scidbst("TRMM3B42_DAILY")
trmm.ref = subarray(trmm.ref,limits=ext.time, between=F)
trmm.ref = crop(trmm.ref,bbox,between=F)
trmm.ref = subset(trmm.ref,"band1 >= 0")

trmm.ref.1 = repart(x = trmm.ref@proxy,chunk = c(64,64,180),overlap = c(0,0,30) )
trmm.ref.1 = aggregate(trmm.ref.1,window=c(0,0,0,0,30,0), FUN="sum(band1)")
trmm.ref.1 = aggregate(trmm.ref.1,by=list("y","x"), FUN="min(band1_sum)")

# this takes around 5 minutes
scidbeval(trmm.ref.1,name="TRMM_MIN2008_30DAY")


setSRS(x = scidb("TRMM_MIN2008_30DAY"), trmm.ref@srs, trmm.ref@affine)
trmm.ref.2 = scidbst("TRMM_MIN2008_30DAY")


# Alternative A: create a TMS that can be easily added to Leaflet
# (requires latest version of scidbst package, update by devtools::install_github("appelmar/scidbst", ref="dev")
as_PNG_layer(trmm.ref.2)

# Alternative B: use GDAL to download result as a GeoTIFF image
library(gdalUtils)
gdal_translate("SCIDB:array=MOD13A3",of = "GTiff",dst_dataset = "changes.tif")

# clean up
scidbremove(c("TRMM_MIN2008_30DAY"), force=TRUE)

