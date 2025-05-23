library(geosphere)
while (1==1) {
  rm(list = ls(all.names = TRUE)) 
  cmd <- paste("if ! kill -0 ",Sys.getpid()," 2>/dev/null; then","\n","echo 'Restarting process...'","\n","/Library/Frameworks/R.framework/Resources/bin/Rscript '/Users/eab/Projects/adsb/plane_id_logge.R'  > '/Users/eab/Projects/adsb/plane_id_loggeR.log' 2>&1 &","\n","exit 1","\n","fi")  
  writeLines(cmd,"/Users/eab/Projects/adsb/gitignore/inputs/sys_cmd.sh")
  suppressWarnings(rm(cmd))
  closeAllConnections()
  rm(list = ls(all.names = TRUE))
  closeAllConnections()
  start_time <- Sys.time()
  print(paste0(Sys.getpid()," - Start time: ",start_time))
  
  {
    if (Sys.info()['sysname'] == "Linux") {
      setwd("/home/eab")
      wd <- "/home/eab"
      path <- "/home/eab/Projects/metrobus/"
    }
    else if (Sys.info()['sysname'] == "Windows") {
      setwd("C:/Users/ebarbaro")
      wd <- "C:/Users/ebarbaro"
      path <- "C:/Users/ebarbaro/R/Sandbox/metrobus/"
    }
    else if (Sys.info()['sysname'] == "Darwin") {
      setwd(Sys.getenv("HOME"))
      wd <- Sys.getenv("HOME")
      path <- Sys.getenv("adsb_proj_path")
    }
  }
  
  ###
  pg <- dbConnect(RPostgres::Postgres()
                  , host=Sys.getenv("pg_host")
                  , port=Sys.getenv("pg_port")
                  , dbname="adsb"
                  , user=Sys.getenv("pg_user")
                  , password=Sys.getenv("pg_password"))
  ###
  planes_db <- dbGetQuery(pg,'select distinct * from public.planes')
  dbWriteTable(pg,"planes_tmp",planes_db, row.names = FALSE, overwrite = TRUE, append = FALSE)
  dbDisconnect(pg)
  closeAllConnections()
  
  ###
  planes_db$FirstSeen <- as.POSIXct(planes_db$FirstSeen, tz = Sys.timezone())
  planes_db$LastSeen <- as.POSIXct(planes_db$LastSeen, tz = Sys.timezone())
  planes_db <- planes_db[!duplicated(planes_db$hex),]
  planes_db <- planes_db[!is.na(planes_db$hex),]
  
  ###
  query_all <- Sys.getenv("adsb")
  all_aircraft <-  GET(query_all, add_headers())
  ac_pull <- rawToChar(all_aircraft$content)
  write(ac_pull,paste0(path,"/gitignore/json-outputs/adsb_error.json"))
  ac_pull <- fromJSON(ac_pull)
  ac_pull <- ac_pull$aircraft
  mylist <- ac_pull
  e <- length(ac_pull)
  
  ##########
  {
    if (e == 0) {
      print(paste0(Sys.time(),": No results returned. Fetching more data..."))
      next
    }
    else if (e >= 1) {
      my_list <- data.frame("hex" = NA,"flight" = NA,"alt_baro" = NA,"baro_rate" = NA,"gs" = NA,"nav_heading" = NA,"version" = NA,"messages" = NA,"seen" = NA,"category" = NA,"lon" = NA,"lat" = NA,"squawk" = NA,"emergency" = NA)
      my_list_f <- bind_rows(mylist,my_list)
      final_planes <- subset(my_list_f,select = c(hex,flight,alt_baro,baro_rate,gs,nav_heading,version,messages,seen,category,lon,lat,squawk,emergency))
      final_planes_f <- final_planes[!is.na(final_planes$hex),]
      final_planes$FirstSeen <- Sys.time()
      final_planes <- final_planes %>%
        mutate(dist_km = distGeo(
          p1 = cbind(lon, lat),
          p2 = cbind(Sys.getenv("lon"),Sys.getenv("lat"))) / 1000
        ) 
      final_planes$dist_km <- round(final_planes$dist_km, digits = 3)
      planes <- final_planes[!duplicated(final_planes$hex),]
      
      ##
      existing_planes <- inner_join(planes,planes_db,by="hex")
      existing_planes <- existing_planes[!is.na(existing_planes$hex),]
      missing_planes <- anti_join(planes_db,planes,by="hex")
      
      {
        if (nrow(existing_planes)>0) {
          existing_planes$SeenTimes.x <- existing_planes$SeenTimes
          existing_planes$SeenTimes <- ifelse(((existing_planes$messages.x >= existing_planes$messages.y)), existing_planes$SeenTimes, (existing_planes$SeenTimes +1))
          existing_planes$flight <- ifelse(!is.na(existing_planes$flight.x),coalesce(existing_planes$flight.x,existing_planes$flight.y),coalesce(existing_planes$flight.y,existing_planes$flight.x))
          existing_planes$alt_baro <- coalesce(existing_planes$alt_baro.x,existing_planes$alt_baro.y)
          existing_planes$gs <- coalesce(existing_planes$gs.x,existing_planes$gs.y)
          existing_planes$nav_heading <- coalesce(existing_planes$nav_heading.x,existing_planes$nav_heading.y)
          existing_planes$version <- coalesce(existing_planes$version.x,existing_planes$version.y)
          existing_planes$messages <- coalesce(existing_planes$messages.x,existing_planes$messages.y)
          existing_planes$seen <- coalesce(existing_planes$seen.x,existing_planes$seen.y)
          existing_planes$squawk <- coalesce(existing_planes$squawk.x,existing_planes$squawk.y)
          existing_planes$emergency <- coalesce(existing_planes$emergency.x,existing_planes$emergency.y)
          
          existing_planes$baro_rate <- coalesce(existing_planes$baro_rate.x,existing_planes$baro_rate.y)
          existing_planes$category <- ifelse(!is.na(existing_planes$category.x),coalesce(existing_planes$category.x,existing_planes$category.y),coalesce(existing_planes$category.y,existing_planes$category.x))
          existing_planes$lon <- coalesce(existing_planes$lon.x,existing_planes$lon.y)
          existing_planes$lat <- coalesce(existing_planes$lat.x,existing_planes$lat.y)
          
          existing_planes <- existing_planes %>%
            mutate(dist_km = distGeo(
              p1 = cbind(lon, lat),
              p2 = cbind(Sys.getenv("lon"),Sys.getenv("lat"))) / 1000
            ) 
          existing_planes$dist_km <- round(existing_planes$dist_km, digits = 3)
          
          existing_planes$FirstSeen <- existing_planes$FirstSeen.y
          existing_planes$LastSeen <- Sys.time()
          existing_planes <- subset(existing_planes, select=c(hex,flight,alt_baro,baro_rate,nav_heading,gs,dist_km,messages,seen,category,squawk,emergency,lon,lat,version,SeenTimes,FirstSeen,LastSeen))
          existing_planes$trigger_timestamp <- Sys.time()
          existing_planes_b <- bind_rows(existing_planes,missing_planes)
          rm(existing_planes)
          existing_planes <- existing_planes_b[!duplicated(existing_planes_b$hex),]
          rm(existing_planes_b)
          pg <- dbConnect(RPostgres::Postgres()
                          , host=Sys.getenv("pg_host")
                          , port=Sys.getenv("pg_port")
                          , dbname="adsb"
                          , user=Sys.getenv("pg_user")
                          , password=Sys.getenv("pg_password"))
          dbWriteTable(pg,"planes",existing_planes, row.names = FALSE, overwrite = TRUE, append = FALSE)
          end_time <- Sys.time()
          log <- data.frame(
            Source = "planes",
            rows_added = nrow(existing_planes),
            StartTime = start_time,
            EndTime = end_time,
            trigger_timestamp = Sys.time())
          new_planes <- anti_join(planes,existing_planes,by="hex")
          new_planes <- new_planes[!is.na(new_planes$hex),]
          if (nrow(new_planes)>0) {
            dbWriteTable(pg,"log",log, row.names = FALSE, overwrite = FALSE, append = TRUE)
          }
          dbDisconnect(pg)
          closeAllConnections()
          suppressWarnings(rm(log,new_planes))
        }
      }
      new_planes <- anti_join(planes,existing_planes,by="hex")
      new_planes <- new_planes[!is.na(new_planes$hex),]
      {
        if (nrow(new_planes)>0) {
          new_planes$SeenTimes <- 1
          new_planes <- new_planes %>%
            mutate(dist_km = distGeo(
              p1 = cbind(lon, lat),
              p2 = cbind(Sys.getenv("lon"),Sys.getenv("lat"))) / 1000
            ) 
          new_planes$dist_km <- round(new_planes$dist_km, digits = 3)
          new_planes$FirstSeen <- Sys.time()
          new_planes$LastSeen <- Sys.time()
          new_planes <- subset(new_planes, select=c(hex,flight,alt_baro,baro_rate,nav_heading,gs,dist_km,messages,seen,category,squawk,emergency,lon,lat,version,SeenTimes,FirstSeen,LastSeen))
          new_planes$trigger_timestamp <- Sys.time()
          new_planes <- new_planes[!is.na(new_planes$hex),]
          pg <- dbConnect(RPostgres::Postgres()
                          , host=Sys.getenv("pg_host")
                          , port=Sys.getenv("pg_port")
                          , dbname="adsb"
                          , user=Sys.getenv("pg_user")
                          , password=Sys.getenv("pg_password"))
          dbWriteTable(pg,"planes",new_planes, row.names = FALSE, overwrite = FALSE, append = TRUE)
          end_time <- Sys.time()
          dbDisconnect(pg)
          closeAllConnections()
        }
      }
      invisible(gc())
      print(paste0(Sys.time(),": ",nrow(new_planes)," planes added + ",nrow(existing_planes)," updated (",nrow(new_planes)+nrow(existing_planes)," tot.) in ",round(difftime(Sys.time(),start_time,units = "secs"))," secs (AND i took the trash out)."))
    }
  }
}
