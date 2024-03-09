

#################################### Data_cleaning

#Data_initial_cleaning -----------------------------------
Std <- function(x){
  RE <- (x-mean(x)) / sqrt(var(x))
  return(RE)
}
library(randomForest)
library(MASS)
library(utils)
library(graphics)
Sentiment_data <- read.csv("Complete_data.csv")

Unique_data <- Sentiment_data[
  !duplicated(Sentiment_data[,"seas_1_1an"]),
]
# Get rid of all N/A values
Complete_data <- na.omit(Unique_data[!duplicated(Unique_data[,"transcript_id"]),])
attach(Complete_data)
CW <- data.frame(cbind(market_equity,assets,sales,book_equity,
                       net_income,enterprise_value,at_gr1,ca_gr1,nca_gr1,
                       lt_gr1,at_gr3,cash_gr1a,ca_gr3,inv_gr1a,nca_gr3,
                       rec_gr1a,lt_gr3,ppeg_gr1a))
Rele_data <- data.frame(apply(data.frame(cbind(ret_1_0,sentiment1,Report_Sent,
                                               QA_Sent,CW)),2,Std ))

Data_for_summstats <- data.frame(ret_1_0,sentiment1,Report_Sent,QA_Sent,CW)

### The current code produces the column "Whole" in Table 1, To get columns "Report"
### and "Q&A" in Table 1 and the results in Table 2, I change all "-c(3,4)" to "-c(2,4)" 
### or "-c(2,3)" or "-c(2:4)". As the second row is whole sentiment, third row is 
### sentiment from report, and fourth row is sentiment from Q&A

### To get Table 4, replace -c(3,4) with -c(3:ncol(Rele_data))

##Q1Random Forest--------------------------------------------

#Sample-splitting ----------------------------------------
set.seed(12345)
s <- ncol(Rele_data) - 3
N1 <- nrow(Rele_data)
N2 <- 0.67*N1
trainindex <- sample(1:N1,N2)
forest_ret_hat <- matrix(0,ncol=s,nrow=nrow(Rele_data[-trainindex,-c(3,4)]))
MSE_for <- rep(0,s)
for (i in 1:s){
  forest_ret <- randomForest(ret_1_0~., data=Rele_data[trainindex,-c(3,4)],mtry=i)
  forest_ret_hat[,i] <- predict(forest_ret, newdata=Rele_data[-trainindex,-c(3,4)])
  MSE_for[i] <- mean((Rele_data[-trainindex,"ret_1_0"]-forest_ret_hat[,i])^2) 
}
MSE_for[which.min(MSE_for)]
# plot for tuning-------------------------------------
par(mar=c(4,4,4,4))
plot(MSE_for,xlab="# of covariates at each split",ylab="MSE",main="")
Forest_MSE <- MSE_for[which.min(MSE_for)] # result
#plot for MSE w.r.t # of trees-----------------------
plot(forest_ret,main="")
#plot for barplot----------------------
#par(mar=c(4,15,1,4))
barplot(as.vector(forest_ret$importance),horiz="TRUE",
        names.arg=c("sentiment","market equity","assets",
                    "sales","book equity","net income","enterprise value", 
                    "1 year total assets growth","1 year current asset growth",
                    "1 year non-current asset growth","1 year long-term earnings growth",
                    "3 years total assets growth","cash growth",
                    "3 years current assets growth","1 year inventory growth",
                    "3 years non-current assets growth",
                    "1 year account receivables growth",
                    "3 years long-term earnings growth",
                    "1 year PPE growth") ,las=1,cex.name=0.8,xlab="importance")

# R^2----------------------------------------------------------
Rsqu_Forest <- (forest_ret_hat[,which.min(MSE_for)] %*% forest_ret_hat[,which.min(MSE_for)]) /
  (Rele_data[-trainindex,"ret_1_0"] %*% Rele_data[-trainindex,"ret_1_0"])


#Q2Linear Regression--------------------------------------
set.seed(123)
  Lin_Reg <- lm(ret_1_0~., data=Rele_data[trainindex,-c(3,4)])
  Lin_Reg_hat <- predict(Lin_Reg,newdata=Rele_data[-trainindex,-c(3,4)])
  MSE_Lin <- mean((Rele_data[-trainindex,"ret_1_0"]-Lin_Reg_hat)^2)
  Rsqu_Lin <- Lin_Reg_hat %*% Lin_Reg_hat /
    (Rele_data[-trainindex,"ret_1_0"] %*% Rele_data[-trainindex,"ret_1_0"])
  MSE_Lin[which.min(MSE_Lin)] # result

plot(sentiment1,ret_1_0)

#Q3Regression Trees ----------------------------------
set.seed(123)
library(tree)
tree_ret <- tree(ret_1_0 ~., Rele_data[trainindex,-c(3,4)])
#cv_tree_ret <- cv.tree(tree_ret)
#plot(cv_tree_ret$size,cv_tree_ret$dev,xlab="# of terminal nodes",ylab="CV error")
 # prune_ret <- prune.tree(tree_ret,best=5)
  prune_ret_hat <- predict(tree_ret,newdata=Rele_data[-trainindex,-c(3,4)])
  MSE_tree_ret <- mean((Rele_data[-trainindex,"ret_1_0"]-prune_ret_hat)^2) # result
Rsqu_Tree <- (prune_ret_hat %*% prune_ret_hat) / 
  (Rele_data[-trainindex,"ret_1_0"] %*% Rele_data[-trainindex,"ret_1_0"])
plot(prune_ret)
text(prune_ret)

#Q4boosting-----------------------------------------
set.seed(123)
library(gbm)
boost_ret_hat <- matrix(0,ncol=10,nrow=nrow(Rele_data[-trainindex,-c(3,4)]))
MSE_boost_ret <- rep(0,10)
# Tuning number of leaves per tree
for (i in 1:10){
  boost_ret <- gbm(ret_1_0~., data=Rele_data[trainindex,-c(3,4)],distribution="gaussian",
                  interaction.depth=i,shrinkage=0.01)
  boost_ret_hat[,i] <- predict(boost_ret,newdata=Rele_data[-trainindex,-c(3,4)])
  MSE_boost_ret[i] <- mean((Rele_data[-trainindex,"ret_1_0"]-boost_ret_hat[,i])^2)
}
plot(MSE_boost_ret,xlab="# of leaves per tree",ylab="MSE")
MSE_boost_ret[which.min(MSE_boost_ret)] # result
Rsqu_Boost <- boost_ret_hat[,which.min(MSE_boost_ret)] %*% boost_ret_hat[,which.min(MSE_boost_ret)] /
  (Rele_data[-trainindex,"ret_1_0"] %*% Rele_data[-trainindex,"ret_1_0"])
# It turns out that 9 leaves per tree is optimal

# Measurement of fit-----------------
plot(boost_ret_hat[,which.min(MSE_boost_ret)],col='blue')
points(Rele_data[-trainindex,"ret_1_0"],col="red")
legend(x="topright",box.col=legend=c("boosted","True"))


# choosing learning rate for boosting-----------------------
set.seed(123)
shrink_boost_hat <- matrix(0,ncol=10,nrow=nrow(Rele_data[-trainindex,-c(3,4)]))
MSE_boost_shrink <- rep(0,10)
for ( i in 1:10){
  shrink_boost_ret <- gbm(ret_1_0~., data=Rele_data[trainindex,-c(3,4)],distribution="gaussian",
                          interaction.depth=9,shrinkage=0.01*i)
  shrink_boost_hat[,i] <- predict(shrink_boost_ret,newdata=Rele_data[-trainindex,-c(3,4)])
  MSE_boost_shrink[i] <- mean((Rele_data[-trainindex,"ret_1_0"]-shrink_boost_hat)^2) 
}
plot(seq(from=0.01,to=0.1,by=0.01),MSE_boost_shrink,xlab="shrinkage parameter",
     ylab="MSE")

MSE_boost_shrink[which.min(MSE_boost_shrink)]



#Q5Model Averaging---------------------
Frame_for_Mod_Ave <- data.frame(cbind(Rele_data[-trainindex,"ret_1_0"],
                                      forest_ret_hat[,which.min(MSE_for)],
                                      Lin_Reg_hat,
                                      prune_ret_hat,
                                      boost_ret_hat[,which.min(MSE_boost_ret)]))
attach(Frame_for_Mod_Ave)
Mod_Ave <- lm(V1~ 0+V2+Lin_Reg_hat+prune_ret_hat+V5,data=Frame_for_Mod_Ave)

Ave_pred <- as.matrix(Frame_for_Mod_Ave[,-1]) %*% Mod_Ave$coefficients

MSE_Mod_Ave <- mean((Ave_pred-Rele_data[-trainindex,"ret_1_0"])^2) # result

Rsqu_Ave <- t(Ave_pred) %*% Ave_pred /
  (Rele_data[-trainindex,"ret_1_0"] %*% Rele_data[-trainindex,"ret_1_0"])



#other plots-------------------

plot(sentiment1,ret_1_0,ylab="short term reversal",xlab="sentiment")


#Summary Statistics----------------------------------------------------

AAA <- data.frame(colMeans(Data_for_summstats))
BBB <- data.frame(sqrt(apply(Data_for_summstats,2,var)))
CCC <- data.frame(cbind(AAA,BBB))
Summ <- write.csv(CCC,"Summ.csv")



