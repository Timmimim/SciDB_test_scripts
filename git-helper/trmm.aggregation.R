
# install.packages("devtools")
# devtools::install_github("Paradigm4/SciDBR")
# devtools::install_github("appelmar/scidbst", ref="dev")
# install.packages("gdalUtils") # requires GDAL with SciDB driver (see https://github.com/appelmar/scidb4gdal/tree/dev) on the system:

SCIDB_HOST = "128.176.148.9"
SCIDB_PORT = "30021"
SCIDB_USER = "giscolab"
SCIDB_PW   =  "BxLQmZVL2qqzUhU93usYYdxT" 	 

Sys.setenv(http_proxy="")
Sys.setenv(https_proxy="")
Sys.setenv(HTTP_PROXY="")
Sys.setenv(HTTPS_PROXY="")

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

scidbst.ls(extent=TRUE) # query available datasets

# compute average / minimum / maximum precipitation during Jan - Mar 2011
trmm = scidbst("TRMM3B42_DAILY")
ext = textent(as.POSIXct("2011-01-01"),
              as.POSIXct("2011-04-01"))
trmm.subset = subarray(x=trmm,limits=ext,between=T)
trmm.subset.summary = aggregate.t(trmm.subset,FUN="avg(band1),stdev(band1),min(band1),max(band1)")
scidbsteval(trmm.subset.summary,name="TRMM_2011Q1_SUMMARY") # run SciDB query and store result as a new array


# use GDAL to download result as a GeoTIFF image
library(gdalUtils)
gdal_translate("SCIDB:array=TRMM_2011Q1_SUMMARY",of = "GTiff",dst_dataset = "TRMM_2011Q1_SUMMARY.tif")
scidbremove("TRMM_2011Q1_SUMMARY",force=TRUE)





