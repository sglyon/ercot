#ERCOT Forecasting - Basic DLM Model Setup
#This file creates the y, F and G objects for all zones and saves as R objects.

#================================================================
# Read in load and covariate data ===============================
#================================================================

#Housekeeping
rm(list=ls())

#Set working directory.
setwd('/Users/jennstarling/UTAustin/Research/ercot')

#Read in load data.
load = read.table('data/load_data.gz',row.names=NULL,sep=',',header=T,stringsAsFactors=F)

#Read in temp, dewpoint and windspeed data.
zone_temp = read.csv(file='data/weather_processed_by_zone/zone_temp.csv',header=T,row.names=1)
zone_dewpt = read.csv(file='data/weather_processed_by_zone/zone_dewpt.csv',header=T,row.names=1)
zone_windspd = read.csv(file='data/weather_processed_by_zone/zone_windspd.csv',header=T,row.names=1)

#Read population and business hour data.
counties = read.csv('data/county_data.csv',header=T,stringsAsFactors=F)
bushr = read.csv('data/is_bushour.csv',header=T,stringsAsFactors=F)

#Switch bushr from true/false to 0/1.
bushr$is_bushour = ifelse(bushr$is_bushour=='False',0,1)

#================================================================
# Preliminary Time Checks =======================================
#================================================================

#1. Visual check that zones are in same order in load and covariate data.
head(load)
head(zone_temp)
head(zone_dewpt)
head(zone_windspd)

#1. Match up load times and weather data times.
# (Should be none missing, due to imputation in weather processing file.)
dim(load)
dim(zone_temp)	#Temp, dewpoint and windspeed all have same measurement times.

### 	NOTE: It is okay to have more temperature data than load data.
###		This data set has extra temperature data on the end; 
###		we will only use readings which match to load times.

#Count loads missing temp times and show rows.
sum(!(load$Time %in% rownames(zone_temp)))
load[!(load$Time %in% rownames(zone_temp)),]

#2. Match up load times and business hour data.
sum(!(load$Time %in% bushr$datetime))

### 	If any of these values return >0, some load times are missing covariates.

#================================================================
# Set up y, F, G for DLM ========================================
#================================================================

#Create DLM matrices and vectors for each zone.
n = nrow(load)	#Num observations.
p = 33			#Num predictors. WITH DAILY #****************

#Data structures to hold one set of y, G, F per zone, and one for entire ercot.
y = list()
F = list()
G = list()
t = load$Time

#Set up y, F, and G for each zone.  
#Matches up covariate times to load times.
for (i in 1:8){

	y[[i]] = load[i+1]
	G[[i]] = diag(p)
	
	#------------------------------------------------------------
	# Construct F matrix - temp, temp^2, bushr, hourly dummies.
	#------------------------------------------------------------
	
	F.int = rep(1,n) #Intercept term.
	F.temp = zone_temp[which(rownames(zone_temp) %in% load$Time),i] 	
	F.temp2 = F.temp^2
	F.holiday = bushr[which(bushr$datetime %in% load$Time),2]		
	F.hrdummies = matrix(0,nrow=n,ncol=23)	#Hours 00 (midnight) is baseline.
	
	for (j in 0:22){
		F.hrdummies[,j+1] = as.numeric(substr(load$Time,12,13))==j
	}
	colnames(F.hrdummies) = paste('hr.',c(1:23),sep='')
	
	#------------------------------------------------------------
	# Add day-of-week dummies to F matrix.
	#------------------------------------------------------------
	
	F.daydummies = matrix(0,nrow=n, ncol=6) #Sunday is baseline.	
	wk.days = weekdays(as.Date(t))
	days.list = c('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday')

	for (j in 1:6){
		F.daydummies[which(wk.days==days.list[j+1]),j] = 1
	}
	colnames(F.daydummies) = c('M','T','W','Th','F','Sa')
	
	#------------------------------------------------------------
	# Assemble F matrix.
	#------------------------------------------------------------
	
	F[[i]] = as.matrix(cbind.data.frame(F.int,F.temp,F.temp2,F.holiday,F.hrdummies,F.daydummies)) #***********
	
}

y_all = y
F_all = F
G_all = G

names(y) = names(F_all) = names(G_all) = colnames(zone_temp)

times = rownames(zone_temp[which(rownames(zone_temp) %in% load$Time),])
dates = as.Date(substr(times,1,10))
hrs = as.numeric(substr(times,12,13))
days = format(dates, format="%a")
datetime_info = data.frame(date=dates,hr=hrs, day=days)

#Output R objects.
saveRDS(y_all,'R Code/Model_Fitting_Scenarios/2_With Daily Dummies (Time Varying)/R Data Objects/dlm_y_allzones.rda')
saveRDS(F_all,'R Code/Model_Fitting_Scenarios/2_With Daily Dummies (Time Varying)/R Data Objects/dlm_F_allzones.rda')
saveRDS(G_all,'R Code/Model_Fitting_Scenarios/2_With Daily Dummies (Time Varying)/R Data Objects/dlm_G_allzones.rda')
saveRDS(datetime_info,'R Code/Model_Fitting_Scenarios/2_With Daily Dummies (Time Varying)/R Data Objects/dlm_datetime_info.rda')


