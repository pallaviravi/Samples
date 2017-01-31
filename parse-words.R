library(stringr)
library(data.table)
words <-c ("mittani","brothers")
parse_words <- function(words){
  
  data <- read.csv(file="fulldata.csv",sep= ",")[, c('posts')] 
  data <- data.frame(data)
  len<- length(words)
  len<- len-1
  val=0
  final<- list("Results")
  for(val in 0:len){
    temp <- str_count(data,words[val])
    final <- c(final,temp)
    total <- sum(str_count(data,words[val]))
    }
    return (final)
}
results <- parse_words(words)

