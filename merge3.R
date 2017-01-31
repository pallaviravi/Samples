data1=read.csv("C:\\Users\\Pallavi\\Documents\\old-csm-forums.csv", stringsAsFactors=FALSE)
data2=read.csv("C:\\Users\\Pallavi\\Documents\\csm-forums.csv", stringsAsFactors=FALSE)

fulldata <- rbind(data1, data2) 
write.csv(fulldata,"C:\\Users\\Pallavi\\Documents\\fulldata.csv")
