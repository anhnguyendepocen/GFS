rm(list=ls())
library(fields)
library(spBayes)
library(MBA)
library(viridis)
library(ggplot2)
library(geoR)

set.seed(1)

dat <- read.table("Sec\ 8.1.3.dat", header=TRUE)

coords <- dat[,c("X","Y")]

dbh <- sqrt(dat[,3])
ht <- dat[,4]

max(iDist(coords))

mod <- sample(1:nrow(coords),0.75*nrow(coords))

coords.mod <- coords[mod,]
coords.ho <- coords[-mod,]
dbh.mod <- dbh[mod]
dbh.ho <- dbh[-mod]
ht.mod <- ht[mod]
ht.ho <- ht[-mod]

m <- lm(ht ~ dbh)

r <- resid(m)

p.dat <- data.frame(x=coords[,1], y=coords[,2], log.dbh=dbh, log.ht=ht, lm.resid=r)

#####################################
##Code for Figure 8.3
#####################################

#pdf(file="figures/ek-dbh-ht.pdf", height=6, width=6)
ggplot(p.dat, aes(x=dbh, y=ht)) + geom_point() +
    theme_bw(base_size = 18) +
    theme(panel.background = element_rect(colour = "black", size=1),
          panel.grid.major = element_blank(),
          panel.grid.minor = element_blank()) +
    xlab(expression(paste(sqrt(DBH), "(cm)"))) + ylab("HT (m)")
#dev.off()

#pdf(file="figures/ek-dbh.pdf", height=6, width=8)
ggplot(p.dat, aes(x=x, y=y, color=dbh^2)) + geom_point() +
    scale_color_viridis(option="D", direction = -1) + theme_bw(base_size = 18) +
    theme(panel.background = element_rect(colour = "black", size=1),
          panel.grid.major = element_blank(),
          panel.grid.minor = element_blank()) +
    xlab("Easting (m)") + ylab("Northing (m)") + labs(color = "DBH (cm)")
#dev.off()

#pdf(file="figures/ek-ht.pdf", height=6, width=8)
ggplot(p.dat, aes(x=x, y=y, color=ht)) + geom_point() +
    scale_color_viridis(option="D", direction = -1) + theme_bw(base_size = 18) +
    theme(panel.background = element_rect(colour = "black", size=1),
          panel.grid.major = element_blank(),
          panel.grid.minor = element_blank()) +
    xlab("Easting (m)") + ylab("Northing (m)") + labs(color = "Height (m)")
#dev.off()

trim <- function(x){
    q <- quantile(x, prob=c(0.025, 0.975))
    x[x<q[1]] <- q[1]
    x[x>q[2]] <- q[2]
    x
}

#####################################
##Code for Figure 8.4
#####################################

#pdf(file="figures/ek-dbh-lm-resid.pdf", height=6, width=8)
ggplot(p.dat, aes(x=x, y=y, color=trim(r))) + geom_point() +
   scale_color_viridis(option="D", direction = -1) + theme_bw(base_size = 18) +
    theme(panel.background = element_rect(colour = "black", size=1),
          panel.grid.major = element_blank(),
          panel.grid.minor = element_blank()) +
    xlab("Easting (m)") + ylab("Northing (m)") + labs(color = "Residuals")
#dev.off()

v <- variog(coords=coords, data=r, uvec=(seq(0, 100, length=20)))

vario.fit.1 <-variofit(v, ini.cov.pars=c(1, 40),
                       cov.model="exponential",
                       minimisation.function="nls",
                       weights="equal")
cex.lab <- 1.5
cex.axis <- 1.5

#pdf(file="figures/ek-dbh-lm-vario.pdf", height=6, width=6)
plot(1, axes=F, typ="n", xlim=c(0,100), ylim=c(0,3.5), cex.lab=cex.lab, cex.axis=cex.axis, xlab="Distance (m)", ylab="")
mtext("Semivariance (residuals)", side=2, line=2.5, cex=cex.lab)
axis(1, seq(0,100,20), cex.lab=cex.lab, cex.axis=cex.axis)
axis(2, seq(0,3.5,0.5), cex.lab=cex.lab, cex.axis=cex.axis)
abline(h=vario.fit.1$nugget, col="#020212", lw=2)
abline(h=vario.fit.1$cov.pars[1]+vario.fit.1$nugget, col="#020212", lw=2)
abline(v=3/(1/vario.fit.1$cov.pars[2]), col="#020212", lw=2)
points(v$u, v$v, pch=19, cex=2, col="#297B8E")
lines(vario.fit.1, col="#020212", lw=2)
#dev.off()

#####################################
##Code for models including Box 8.2.
##The SVC models have a VERY long
##run time.
#####################################

##Fit candidate models
n.samples <- 5000

##fit non-spatial
m.0 <- bayesLMRef(lm(ht.mod ~ dbh.mod), n.samples=n.samples)

round(summary(m.0$p.beta.tauSq.samples)$quantiles[,c(3,1,5)],2)

##fit SVI (Box 8.2)
starting <- list("phi"=3/50, "sigma.sq"=1.5, "tau.sq"=1.5)

tuning <- list("phi"=0.1, "sigma.sq"=0.01, "tau.sq"=0.01)

cov.model <- "exponential"

priors <- list("phi.Unif"=list(3/150, 3/1),
               "sigma.sq.IG"=list(2, 1.5),
               "tau.sq.IG"=c(2, 1.5))

m.1 <- spSVC(ht.mod ~ dbh.mod, coords=coords.mod, starting=starting, svc.cols=1,
             tuning=tuning, priors=priors, cov.model=cov.model,
             n.samples=n.samples, n.omp.threads=10, n.report=100)

plot(m.1$p.theta.samples, density=FALSE)

m.1 <- spRecover(m.1, start=floor(0.75*n.samples), thin=2, n.omp.threads=4)

round(summary(m.1$p.beta.recover.samples)$quantiles[,c(3,1,5)],2)
round(summary(m.1$p.theta.recover.samples)$quantiles[,c(3,1,5)],2)

##fit SVC
starting <- list("phi"=c(3/50, 3/50), "sigma.sq"=c(1.5, 1), "tau.sq"=1.5)

tuning <- list("phi"=c(0.1,0.1), "sigma.sq"=c(0.01,0.01), "tau.sq"=0.01)

cov.model <- "exponential"

priors <- list("phi.Unif"=list(c(3/150,3/150), c(3/1,3/1)),
               "sigma.sq.IG"=list(c(2,2), c(1.5,1.5)),
               "tau.sq.IG"=c(2, 1.5))

m.2 <- spSVC(ht.mod ~ dbh.mod, coords=coords.mod, starting=starting, svc.cols=1:2,
             tuning=tuning, priors=priors, cov.model=cov.model,
             n.samples=n.samples, n.omp.threads=4, n.report=100)

plot(m.2$p.theta.samples, density=FALSE)

m.2 <- spRecover(m.2, start=floor(0.75*n.samples), thin=2, n.omp.threads=4)

round(summary(m.2$p.beta.recover.samples)$quantiles[,c(3,1,5)],2)
round(summary(m.2$p.theta.recover.samples)$quantiles[,c(3,1,5)],2)

##predict
source("Sec 8.1.3 utils.R")

m.0.pred <- spPredict(m.0, pred.covars=cbind(1,dbh.ho))
m.1.pred <- spPredict(m.1, pred.covars=cbind(1,dbh.ho), pred.coords=as.matrix(coords.ho), n.omp.threads=4)
m.2.pred <- spPredict(m.2, pred.covars=cbind(1,dbh.ho), pred.coords=as.matrix(coords.ho), n.omp.threads=4)

round(crps(ht.ho, apply(m.0.pred$p.y.predictive.samples, 1, mean), apply(m.0.pred$p.y.predictive.samples, 1, var)),2)
round(crps(ht.ho, apply(m.1.pred$p.y.predictive.samples, 1, mean), apply(m.1.pred$p.y.predictive.samples, 1, var)),2)
round(crps(ht.ho, apply(m.2.pred$p.y.predictive.samples, 1, mean), apply(m.2.pred$p.y.predictive.samples, 1, var)),2)

round(rmspe(ht.ho, apply(m.0.pred$p.y.predictive.samples, 1, mean)),2)
round(rmspe(ht.ho, apply(m.1.pred$p.y.predictive.samples, 1, mean)),2)
round(rmspe(ht.ho, apply(m.2.pred$p.y.predictive.samples, 1, mean)),2)

##compute fit metrics 

##non-spatial
m.0.diag <- nonspDiag(m.1$Y, m.1$X, m.0$p.beta.tauSq.samples[,1:2], m.0$p.beta.tauSq.samples[,"tau.sq"])
round(m.0.diag$DIC,2)
round(m.0.diag$WAIC,2)

##SVI
m.1.diag <- svcDiag(m.1$Y, m.1$X, m.1$X[,1,drop=FALSE], m.1$p.beta.recover.samples, m.1$p.theta.recover.samples, m.1$p.w.recover.samples)
round(m.1.diag$DIC,2)
round(m.1.diag$WAIC,2)

##SVC
m.2.diag <- svcDiag(m.2$Y, m.2$X, m.2$Z, m.2$p.beta.recover.samples, m.2$p.theta.recover.samples, m.2$p.w.recover.samples)
round(m.2.diag$DIC,2)
round(m.2.diag$WAIC,2)

##
t.b.0 <- apply(m.2$p.tilde.beta.recover.samples.list[["tilde.beta.(Intercept)"]],1,mean)
t.b.dbh <- apply(m.2$p.tilde.beta.recover.samples.list[["tilde.beta.dbh.mod"]],1,mean)

svc.df <- data.frame(x=coords.mod[,1], y=coords.mod[,2], t.b.0=t.b.0, t.b.dbh=t.b.dbh)


#pdf(file="figures/svc-tbeta-0.pdf", height=6, width=8)
ggplot(svc.df, aes(x=x, y=y, color=t.b.0)) + geom_point() +
   scale_color_viridis(option="D", direction = -1) + theme_bw(base_size = 18) +
    theme(panel.background = element_rect(colour = "black", size=1),
          panel.grid.major = element_blank(),
          panel.grid.minor = element_blank()) +
    xlab("Easting (m)") + ylab("Northing (m)") + labs(color = "")
#dev.off()

#pdf(file="figures/svc-tbeta-dbh.pdf", height=6, width=8)
ggplot(svc.df, aes(x=x, y=y, color=t.b.dbh)) + geom_point() +
   scale_color_viridis(option="D", direction = -1) + theme_bw(base_size = 18) +
    theme(panel.background = element_rect(colour = "black", size=1),
          panel.grid.major = element_blank(),
          panel.grid.minor = element_blank()) +
    xlab("Easting (m)") + ylab("Northing (m)") + labs(color = "")
#dev.off()


pred.df <- data.frame(ht.obs = ht.ho,
                      ht.pred = c(apply(m.0.pred$p.y.predictive.samples, 1, mean),
                                  apply(m.1.pred$p.y.predictive.samples, 1, mean),
                                  apply(m.2.pred$p.y.predictive.samples, 1, mean)),
                      Model = c(rep("Non-spatial", length(ht.ho)), rep("SVI", length(ht.ho)), rep("SVC", length(ht.ho))))

pred.df$Model <- factor(pred.df$Model, levels=c("Non-spatial", "SVI", "SVC"))

                      
#pdf(file="figures/ek-pred-scatter.pdf")
ggplot(pred.df, aes(x=ht.obs, y=ht.pred, color=Model)) + geom_point(size=0.75) + # coord_fixed() +
    coord_equal(xlim=range(pred.df[,1:2]),ylim=range(pred.df[,1:2])) + 
    theme_bw(base_size = 18) +
    theme(panel.background = element_rect(colour = "black", size=1),
          panel.grid.major = element_blank(),
          panel.grid.minor = element_blank()) +
    xlab("Observed HT (m)") + ylab("Predicted HT (m)") +
    geom_abline(intercept = 0, slope = 1) +
    scale_colour_viridis_d(direction = -1) +
    guides(colour = guide_legend(override.aes = list(size=5))) 
#dev.off()


##surfaces (hacked just to predict the mean)
grid <- as.matrix(expand.grid(seq(min(coords[,1]), max(coords[,1]), by=1), seq(min(coords[,2]), max(coords[,2]), by=1)))

set.seed(1)
sub <- sample(1:nrow(m.1$p.theta.recover.samples), 25)

m.1.surfs <- m.1
m.1.surfs$p.theta.recover.samples <- m.1$p.theta.recover.samples[sub,]
m.1.surfs$p.beta.recover.samples <- m.1$p.beta.recover.samples[sub,]
m.1.surfs$p.w.recover.samples <- m.1$p.w.recover.samples[,sub]
m.1.surfs <- spPredict(m.1.surfs, pred.covars=cbind(1,rep(mean(dbh.ho),nrow(grid))), pred.coords=grid, n.omp.threads=4, n.report=1)

m.2.surfs <- m.2
m.2.surfs$p.theta.recover.samples <- m.2$p.theta.recover.samples[sub,]
m.2.surfs$p.beta.recover.samples <- m.2$p.beta.recover.samples[sub,]
m.2.surfs$p.w.recover.samples <- m.2$p.w.recover.samples[,sub]
m.2.surfs <- spPredict(m.2.surfs, pred.covars=cbind(1,rep(mean(dbh.ho),nrow(grid))), pred.coords=grid, n.omp.threads=4, n.report=1)

df.svi <- data.frame(x = rep(grid[,1], 3), y = rep(grid[,2], 3),
                     z = apply(m.1.surfs$p.tilde.beta.predictive.samples.list[[1]], 1, mean))


df.svc.0 <- data.frame(x = rep(grid[,1], 3), y = rep(grid[,2], 3),
                       z = apply(m.2.surfs$p.tilde.beta.predictive.samples.list[[1]], 1, mean))


df.svc.1 <- data.frame(x = rep(grid[,1], 3), y = rep(grid[,2], 3),
                       z = apply(m.2.surfs$p.tilde.beta.predictive.samples.list[[2]], 1, mean))

#pdf(file="figures/ek-svi-b1.pdf", height=6, width=8)
ggplot(df.svi, aes(x, y, fill = z)) + geom_raster() +
    scale_fill_viridis(option="D") + theme_bw(base_size = 18) +
    theme(panel.background = element_rect(colour = "black", size=1),
          panel.grid.major = element_blank(),
          panel.grid.minor = element_blank()) +
    xlab("Easting (m)") + ylab("Northing (m)") + labs(fill = expression(paste(tilde(beta[1]))))
#dev.off()

#pdf(file="figures/ek-svc-b1.pdf", height=6, width=8)
ggplot(df.svc.0, aes(x, y, fill = z)) + geom_raster() +
    scale_fill_viridis(option="D") + theme_bw(base_size = 18) +
    theme(panel.background = element_rect(colour = "black", size=1),
          panel.grid.major = element_blank(),
          panel.grid.minor = element_blank()) +
    xlab("Easting (m)") + ylab("Northing (m)") + labs(fill = expression(paste(tilde(beta)[1])))
#dev.off()

#pdf(file="figures/ek-svc-b2.pdf", height=6, width=8)
ggplot(df.svc.1, aes(x, y, fill = z)) + geom_raster() +
    scale_fill_viridis(option="D") + theme_bw(base_size = 18) +
    theme(panel.background = element_rect(colour = "black", size=1),
          panel.grid.major = element_blank(),
          panel.grid.minor = element_blank()) +
    xlab("Easting (m)") + ylab("Northing (m)") + labs(fill = expression(paste(tilde(beta)[DBH])))
#dev.off()
