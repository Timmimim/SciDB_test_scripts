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


write.csv(scidbst.ls(extent = TRUE,srs = TRUE, trs=TRUE), 
          file="datasets.csv",row.names = FALSE,quote = FALSE)

