
# This script identifies structural changes in MODIS NDVI time series, e.g. from deforestation

# install.packages("devtools")
# devtools::install_github("Paradigm4/SciDBR")
# devtools::install_github("appelmar/scidbst", ref="dev")
# install.packages("gdalUtils") # requires GDAL with SciDB driver (see https://github.com/appelmar/scidb4gdal/tree/dev) on the system:
# devtools::install_github("environmentalinformatics-marburg/mapview")


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

iquery("eo_settrs(MOD13A3,'t', '2000-01-01', 'P30D')") # dummy day-based time resolution, not crucial

bbox = extent(-55,-52,-5,-2) # study area
ext.time = textent(as.POSIXct("2000-01-01"),as.POSIXct("2014-10-14"))

mod.ref = scidbst("MOD13A3")
mod.ref = subarray(mod.ref,limits=ext.time, between=F)
mod.ref = crop(mod.ref,bbox,between=F)


mod.ref.redim = repart(mod.ref@proxy,chunk=c(64,64,180))
mod.ref.redim = subset(mod.ref.redim,"band1 > -9999 and band1 <= 10000") # leave out missing data and clouds (20000)
mod.ref.redim = transform(mod.ref.redim,ndvi = "double(band1) / 10000")$ndvi
mod.ref.redim  = transform(mod.ref.redim, dimx="double(x)", dimy="double(y)", dimt="double(t)")

# this might take around 12 minutes
if (! ("MOD13A3_NDVI_TCHUNK" %in% scidbls())) system.time(scidbeval(mod.ref.redim, name="MOD13A3_NDVI_TCHUNK"))

setSRS(x = scidb("MOD13A3_NDVI_TCHUNK"), mod.ref@srs, mod.ref@affine)


query.R = paste("store(unpack(r_exec(", "MOD13A3_NDVI_TCHUNK", ",'output_attrs=5','expr=
                options(repos=c(CRAN=\"http://cran.uni-muenster.de/\"))
                if(!require(xts)) install.packages(\"xts\")
                if(!require(plyr)) install.packages(\"plyr\")
                if(!require(devtools)) install.packages(\"devtools\")
                if(!require(strucchange)) devtools::install_github(\"appelmar/strucchange\")
                if(!require(bfast)) devtools::install_github(\"appelmar/bfast\")
                set_fast_options()
                ndvi.df = data.frame(ndvi=ndvi,dimy=dimy,dimx=dimx,dimt=dimt)
                f <- function(x) {
                return(
                tryCatch({
                  #nvdi.ts = ts(x$ndvi, start=c(2000,1), frequency=12)
                  year = 2000 + x$dimt %/% 12
                  month = x$dimt %% 12 + 1
                  dates = as.Date(paste(year,month,1,sep=\"-\"))
                  ndvi.ts = bfastts(x$ndvi, dates, \"irregular\")
                  bfast.result = bfastmonitor(ndvi.ts, start = c(2010, 1), order=3, history=\"ROC\")
                  return(c(nt=length(x$dimt), breakpoint = bfast.result$breakpoint,  magnitude = bfast.result$magnitude ))
    }, error=function(e) {
      return (c(nt=0,breakpoint=0,magnitude=0))
    })
  )
}
runtime = system.time(ndvi.change <- ddply(ndvi.df, c(\"dimy\",\"dimx\"), f))[3]
cat(paste(\"Needed \", runtime, \"seconds - \", \"Failed: \", sum(ndvi.change$nt == 0), \" - Succeeded: \", sum(ndvi.change$nt > 0), \"\n\" , sep=\"\"), file=\"/tmp/rexec.log\", append=TRUE)
list(dimy = as.double(ndvi.change$dimy), dimx = as.double(ndvi.change$dimx), nt = as.double(ndvi.change$nt), brk = as.double(ndvi.change$breakpoint), magn = as.double(ndvi.change$magnitude) )'),i), 
", "MOD13A3_TCHUNK_ROUT" ,")", sep="")



# this takes around 5 minutes
iquery(query.R)

target.schema = "<nt:int16, breakpoint:double, magnitude:double>[y=0:1246,2048,0,x=0:1362,2048,0]"
scidbeval(redimension(transform(scidb("MOD13A3_TCHUNK_ROUT"), y="int64(expr_value_0)", x="int64(expr_value_1)", nt = "int16(expr_value_2)", breakpoint = "expr_value_3", magnitude="expr_value_4"),schema = target.schema), name="MOD13A3_CHANGEMAP")
setSRS(x = scidb("MOD13A3_CHANGEMAP"), mod.ref@srs, mod.ref@affine)



# Alternative A: create a TMS that can be easily added to Leaflet
# (requires latest version of scidbst package, update by devtools::install_github("appelmar/scidbst", ref="dev")

as_PNG_layer(scidbst("MOD13A3_CHANGEMAP"), bands = 3, layername = "change_magnitude", min=-0.2, max=0.2)
as_PNG_layer(scidbst("MOD13A3_CHANGEMAP"), bands = 2, layername = "change_breakdate", min=2010, max=2015)


# Alternative B: use GDAL to download result as a GeoTIFF image
library(gdalUtils)
gdal_translate("SCIDB:array=MOD13A3",of = "GTiff",dst_dataset = "changes.tif")

# clean up
scidbremove(c("MOD13A3_CHANGEMAP", "MOD13A3_TCHUNK_ROUT"), force=TRUE)


