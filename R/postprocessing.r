############################################################################################################
#
# postprocessing.R
#
# Copyright (c) 2011, Konrad Zych
#
# Modified by Danny Arends
# 
# first written March 2011
# last modified September 2011
# last modified in version: 0.9.0
# in current version: active, in main workflow
#
#     This program is free software; you can redistribute it and/or
#     modify it under the terms of the GNU General Public License,
#     version 3, as published by the Free Software Foundation.
#
#     This program is distributed in the hope that it will be useful
#     but without any warranty; without even the implied warranty of
#     merchantability or fitness for a particular purpose.  See the GNU
#     General Public License, version 3, for more details.
#
#     A copy of the GNU General Public License, version 3, is available
#     at http://www.r-project.org/Licenses/GPL-3
#
# Contains: orderChromosomes, majorityRule.internal, mergeChromosomes.internal,
#			switchChromosomes.internal, removeChromosomes.internal, removeChromosomesSub.internal,
#
############################################################################################################

############################################################################################################
#									*** putAdditionsOfCross.internal ***
#
# DESCRIPTION:
# 	putting additions to cross object
# 
# PARAMETERS:
# 	cross - object of class cross, containing physical or genetic map
# 	map - which map should be used for comparison:
#			- genetic - genetic map from cross$maps$genetic
#			- physical - physical map from cross$maps$physical
#
# OUTPUT:
#	object of class cross with additions
#
############################################################################################################
checkBeforeOrdering <- function(cross,map){
	map <- defaultCheck.internal(map, "map", 2, "genetic")
	inListCheck.internal(map,"map",c("genetic","physical"))
	crossContainsMap.internal(cross,map)
	if(map=="genetic"){
		originalMap <- cross$maps$genetic
	}else if(map=="physical"){
		originalMap <- cross$maps$physical
	}
	invisible(originalMap)
}

############################################################################################################
#									*** orderChromosomes ***
#
# DESCRIPTION:
#	ordering chromosomes using genetic/physical map and majority rule
# 
# PARAMETERS:
# 	cross - object of class cross, containing physical or genetic map
# 	map - which map should be used for comparison:
#			- genetic - genetic map from cross$maps$genetic
#			- physical - physical map from cross$maps$physical
#	verbose - be verbose
#
# OUTPUT:
#	object of class cross
#
############################################################################################################
assignChromosomes <- function(cross, population, map=c("genetic","physical"), solveDubbleAssigments = c(none,random,mergeChromosomes), how = c(correlationRule,majorityRule,sumMajorityRule), reOrder=FALSE,verbose=FALSE){
  if(length(cross$geno)<=1) stop("selected cross object contains too little chromosomes to proceed")
  map <- defaultCheck.internal(map,"map",2,"genetic")
  how <- defaultCheck.internal(how,"how",3,correlationRule)
	if(map=="genetic"){
    originalMap <- population$maps$genetic
  }else{
    originalMap <- population$maps$physical
  }
  gcm <- map2mapCorrelationMatrix(cross, population, verbose)
  ordering <- how(cross, originalMap, gcm)  
  #if(!reOrder){
  #  invisible(ordering)
  #}else{
  #  return(reorganiseChromosomes(ordering))
  #}
  return(ordering)
}

assignChromosomes(cross_new_f,population_a,"physical",how=correlationRule)


####Deprecated!!!!!!!!!! - will be removed in next commit
orderChromosomes <- function(cross,population,map=c("genetic","physical"),use=c("majority","correlation"),max.iter=10,verbose=FALSE){
	if(length(cross$geno)<=1) stop("selected cross object contains too little chromosomes to proceed")
  map <- defaultCheck.internal(map,"map",2,"genetic")
	if(map=="genetic"){
    originalMap <- population$maps$genetic
  }else{
    originalMap <- population$maps$physical
  }
  use <- defaultCheck.internal(use,"use",2,"majority")
	if(use=="majority"){
    use_f  <- majorityRule.internal 
  }else{
    use_f <- correlationRule.internal 
  }
  if(is.null(originalMap)) stop("no ",map," map provided!")  
  
	output <- correlationRule.internal(cross,originalMap,gcm)
	### until every chr on phys map is matched exactly once
	while(max(apply(output,2,sum))>1){
		toMerge <- which(apply(output,2,sum)>1)
		for(curToMerge in toMerge){
			curMerge <- which(output[,curToMerge]==max(output[,curToMerge]))
			cross <- mergeChromosomes.internal(cross,curMerge,curMerge[1])
			output <- use_f(cross,originalMap,gcm)
		}
	}
	#if(verbose) cat(output,"\n")
	order1 <- matrix(0,ncol(output),nrow(output))
	order2 <- matrix(1,ncol(output),nrow(output))
	### until next iteration doesn't change the result
  iter <- 1
	while(any(order1!=order2)||(iter > max.iter)){
		order1 <- output
		for(l in 1:ncol(output)){
			cur <- which(output[,l]==max(output[,l]))
			if(cur!=l)cross <- switchChromosomes.internal(cross,cur,l)
			output <- correlationRule.internal(cross,originalMap,gcm)
		}
		order2 <- output
    if(verbose)cat("done iteration:",iter,"\n")
    iter <- iter+1;
	}
	names(cross$geno) <- 1:length(cross$geno)
	invisible(cross)
}

############################################################################################################
#                                           *** majorityRule ***
#
# DESCRIPTION:
#   Subfunction of assignChromosomes, for every chromosome in cross for every marker checks the marker it is
#   having highest correlation with. Checks on which chromosome this marker is placed in old map. For each of
#   new chromosomee, old chromosome with most markers with high correlation is assigned. 
# 
# PARAMETERS:
#  cross - object of class cross
#  originalMap - map from population object
#  gcm - gene correlation matrix (from map2mapCorrelationMatrix function)
#  verbose - be verbose
# 
# OUTPUT:
#  vector with new ordering of chromosomes inside cross object
#
############################################################################################################
majorityRule <- function(cross, originalMap, gcm, verbose=FALSE){
  nrOfChromosomesInCross <- nchr(cross)
  chrMaxCorMarkers <- apply(abs(gcm),2,function(r){originalMap[rownames(gcm)[which.max(r)],1]})
  output <- vector(mode = "numeric", length = nrOfChromosomesInCross)
  names(output) <-chrnames(cross)
  for(i in 1:nrOfChromosomesInCross){
    markersFromCurChrom <-colnames(cross$geno[[i]]$data)
    markersHighlyCorWithCurChrom <- table(chrMaxCorMarkers[markersFromCurChrom])
    bestCorChrom <- as.numeric(names(markersHighlyCorWithCurChrom)[which.max(markersHighlyCorWithCurChrom)])
    output[i] <- bestCorChrom
  }
  invisible(output)
}

############################################################################################################
#                                          ** sumMajorityRule***
#
# DESCRIPTION:
# 	Subfunction of assignChromosomes, for every chromosome in cross for every marker checks the marker it is
#   having highest correlation with. Checks on which chromosome this marker is placed in old map. For each of
#   new chromosomes one or more of chromosomes from old map will be represented. Function sums correlations for
#   each pair of those and for every new chromosomes assigns old chromosome with highest cumulative cor.
# 
# PARAMETERS:
#  cross - object of class cross
#  originalMap - map from population object
#  gcm - gene correlation matrix (from map2mapCorrelationMatrix function)
#  verbose - be verbose
# 
# OUTPUT:
#  vector with new ordering of chromosomes inside cross object
#
############################################################################################################
sumMajorityRule <- function(cross, originalMap, gcm, verbose=FALSE){
  nrOfChromosomesInCross <- nchr(cross)
  chrMaxCorMarkers <- t(apply(abs(gcm),2,function(r){c(originalMap[rownames(gcm)[which.max(r)],1],max(r))}))
  output <- vector(mode = "numeric", length = nrOfChromosomesInCross)
  names(output) <-chrnames(cross)
  for(i in 1:nrOfChromosomesInCross){
    markersFromCurChrom <-colnames(cross$geno[[i]]$data)
    markersHighlyCorWithCurChrom <- chrMaxCorMarkers[markersFromCurChrom,]
    correlatedChrom <- as.numeric(names(table(markersHighlyCorWithCurChrom[,1])))
    best <- 0
    bestSum <- 0
    for(j in correlatedChrom){
      currentSum <- sum(markersHighlyCorWithCurChrom[which(markersHighlyCorWithCurChrom[,1]==j),2])
      if(currentSum>bestSum){
         best <- j
         bestSum <- currentSum
      } 
    }
    output[i] <- best
  }
  invisible(output)
}



############################################################################################################
#                                         *** correlationRule ***
#
# DESCRIPTION:
#  Subfunction of assignChromosomes, assigning chromosome from new map to old ones using mean corelation\
#  between their markers.
# 
# PARAMETERS:
#  cross - object of class cross
#  originalMap - map from population object
#  gcm - gene correlation matrix (from map2mapCorrelationMatrix function)
#  verbose - be verbose
# 
# OUTPUT:
#  vector with new ordering of chromosomes inside cross object
#
############################################################################################################
correlationRule <- function(cross,originalMap,gcm,verbose=FALSE){
  nrOfChromosomesInCross <- nchr(cross)
  output <- vector(mode = "numeric", length = nrOfChromosomesInCross)
  names(output) <-chrnames(cross)
  for(i in 1:nrOfChromosomesInCross){
    markersFromCurNewChrom <-colnames(cross$geno[[i]]$data)
    best <- 0
    bestCorMean <- 0
    for(j in unique(originalMap[,1])){
         markersFromCurOldChrom <- rownames(originalMap)[which(originalMap[,1]==j)]
         currentCorMean <- mean(abs(gcm[markersFromCurOldChrom,markersFromCurNewChrom]))
         if(currentCorMean>bestCorMean){
            bestCorMean <- currentCorMean
            best <- j
         }
    }
    output[i] <- best
  }
  return(output)
}

############################################################################################################
#									*** mergeChromosomes.internal ***
#
# DESCRIPTION:
#	subfunction of segragateChromosomes.internal, merging multiple chromosomes into one
# 
# PARAMETERS:
# 	cross - object of class cross
# 	chromosomes - chromosomes to be merged
# 	name - name of merged chromosome
# 
# OUTPUT:
#	object of class cross
#
############################################################################################################
mergeChromosomes.internal <- function(cross, chromosomes, name, verbose=FALSE){
	if(verbose)cat("Merging chromosomes",chromosomes,"to form chromosome",name,"names:",names(cross$geno),"\n")
	geno <- cross$geno
	markerNames <- NULL
	for(j in chromosomes){
		if(j!=name) markerNames <- c(markerNames, colnames(geno[[j]]$data))
	}
	for(k in markerNames) cross <- movemarker(cross, k, name)
	invisible(cross)
}

############################################################################################################
#									*** switchChromosomes.internal ***
#
# DESCRIPTION:
#	switching two chromosomes of cross object
# 
# cross - object of R/qtl cross type
# chr1, chr2 - numbers of chromosomes to be switched (1,2) == (2,1)
#
############################################################################################################
switchChromosomes.internal <- function(cross, chr1, chr2){
	cat(chr1,chr2,"\n")
	if(chr1!=chr2){
		geno <- cross$geno
		cross$geno[[chr1]] <- geno[[chr2]] 
		cross$geno[[chr2]] <- geno[[chr1]]
		cross <- est.rf(cross)
	}
	invisible(cross)
}


############################################################################################################
#									*** reduceChromosomesNumber ***
#
# DESCRIPTION:
#	Function to remove chromosomes from cross object. Those can specified in three ways described below.
# 
# PARAMETERS:
# 	cross - object of class cross
# 	numberOfChromosomes - how many chromosomes should stay (remove all but 1:numberOfChromosomes)
#	verbose - be verbose
# 
# OUTPUT:
#	object of class cross
#
############################################################################################################
reduceChromosomesNumber <- function(cross, numberOfChromosomes,verbose=FALSE){
	if(is.null(cross)&&!(any(class(cross)=="cross"))) stop("Not a cross object!\n")
	if(!(missing(numberOfChromosomes))){
		if(numberOfChromosomes<length(cross$geno)){
			for(i in length(cross$geno):(numberOfChromosomes+1)){
				cross <- removeChromosomesSub.internal(cross,i,verbose)
			}
		}
	}else{
		stop("You have to provide one of following: numberOfChromosomes, chromosomes or minLength")
	}
	invisible(cross)
}

############################################################################################################
#									*** removeChromosomes ***
#
# DESCRIPTION:
#	Function to remove chromosomes from cross object. Those can specified in three ways described below.
# 
# PARAMETERS:
# 	numberOfChromosomes - how many chromosomes should stay (remove all but 1:numberOfChromosomes)
# 	chromosomesToBeRmv - explicitly provide functions with NAMES of chromosomes to be removed
#	verbose - be verbose
# 
# OUTPUT:
#	object of class cross
#
############################################################################################################
removeChromosomes <- function(cross, chromosomesToBeRmv, verbose=FALSE){
	if(is.null(cross)&&!(any(class(cross)=="cross"))) stop("Not a cross object!\n")
	if(!(missing(chromosomesToBeRmv))){
		for(i in chromosomesToBeRmv){
			if(!(i%in%names(cross$geno))){
				stop("There is no chromosome called ",i,"\n")
			}else{
				cross <- removeChromosomesSub.internal(cross,i,verbose)
			}
		}
	}else{
		stop("You have to provide one of following: numberOfChromosomes, chromosomes or minLength")
	}
	invisible(cross)
}

############################################################################################################
#									*** removeTooSmallChromosomes ***
#
# DESCRIPTION:
#	Function to remove chromosomes from cross object. Those can specified in three ways described below.
# 
# PARAMETERS:
# 	cross - object of class cross
#	verbose - be verbose
# 	minNrOfMarkers - specify minimal number of markers chromosome is allowed to have (remove all that have
#					 less markers than that)
# 
# OUTPUT:
#	object of class cross
#
############################################################################################################
removeTooSmallChromosomes <- function(cross, minNrOfMarkers, verbose=FALSE){
	if(is.null(cross)&&!(any(class(cross)=="cross"))) stop("Not a cross object!\n")
	if(!(missing(minNrOfMarkers))){
		if(length(cross$geno)>1){
			if(length(cross$geno[[1]]$map)<minNrOfMarkers) minNrOfMarkers <- length(cross$geno[[1]]$map)-1
			for(i in length(cross$geno):1){
				if(length(cross$geno[[i]]$map)<minNrOfMarkers){
					cross <- removeChromosomesSub.internal(cross,i,verbose)
				}
			}
		}
	}else{
		stop("You have to provide one of following: numberOfChromosomes, chromosomes or minLength")
	}
	invisible(cross)
}

############################################################################################################
#									*** removeChromosomesSub.internal ***
#
# DESCRIPTION:
#	subfunction of removeChromosomes.internal, removing from given cross object specified chromosome
# 
# PARAMETERS:
# 	cross - object of class cross
# 	chr - chromosome to be removed (number or name)
# 
# OUTPUT:
#	object of class cross
#
############################################################################################################
removeChromosomesSub.internal <- function(cross, chr,verbose=FALSE){
	if(verbose)cat("removing chromosome:",chr," markers:",names(cross$geno[[chr]]$map),"\n")
	cross$rmv <- cbind(cross$rmv,cross$geno[[chr]]$data)
	cross <- drop.markers(cross, names(cross$geno[[chr]]$map))
	invisible(cross)
}

############################################################################################################
#									*** smoothGeno ***
#
# DESCRIPTION:
#	checking if fitted normal distributions do not overlap
# 
# PARAMETERS:
# 	offspring - currently processed row
# 	EM - output of normalmixEM function
# 	overlapInd - how many individuals are allowed to be overlapping between distributions
# 
# OUTPUT:
#	boolean
#
############################################################################################################
smoothGeno <- function(cross,windowSize=1,chr,verbose=FALSE){
	if(!any(class(cross) == "cross")) stop("Input should have class \"cross\".")
	cross <- fill.geno(cross)
	n.ind <- nind(cross)
  if(missing(chr)) chr <- 1:nchr(cross)
  cross_geno  <- vector(length(chr),mode="list")
  for(i in 1:length(chr)){
    cat("--- chr 1 ---\n")
    cross_geno[[i]]  <- smoothGenoSub.internal(cross$geno[[chr[i]]],windowSize,verbose)
  }
	for(i in 1:length(chr)){
		cross$geno[[chr[i]]]$data <- cross_geno[[i]]$data
	}
  cat("running est.rf\n")
	cross <- est.rf(cross)
   cat("running est.map\n")
	cross <- recalculateMap.internal(cross)
	invisible(cross)
}

############################################################################################################
#									*** smoothGenoSub.internal ***
#
# DESCRIPTION:
#	checking if fitted normal distributions do not overlap
# 
# PARAMETERS:
# 	offspring - currently processed row
# 	EM - output of normalmixEM function
# 	overlapInd - how many individuals are allowed to be overlapping between distributions
# 
# OUTPUT:
#	boolean
#
############################################################################################################
smoothGenoSub.internal <- function(geno,windowSize,verbose){
  old_genotype <- geno$data
	genotype <- old_genotype
	genotype <- t(apply(genotype,1,smoothGenoRow.internal,windowSize))
	if(verbose) cat("changed",sum(genotype!=old_genotype)/length(genotype)*100,"% values because of genotyping error\n")
	geno$data <- genotype
	invisible(geno)
}

############################################################################################################
#									*** smoothGenoRow.internal ***
#
# DESCRIPTION:
#	checking if fitted normal distributions do not overlap
# 
# PARAMETERS:
# 	offspring - currently processed row
# 	EM - output of normalmixEM function
# 	overlapInd - how many individuals are allowed to be overlapping between distributions
# 
# OUTPUT:
#	boolean
#
############################################################################################################
smoothGenoRow.internal <- function(genoRow,windowSize){
  if(length(genoRow)>windowSize+2){
    if(any(genoRow[1:windowSize]!=genoRow[windowSize+1])&&any(genoRow[1:windowSize]!=genoRow[windowSize+2])&&(genoRow[windowSize+1]==genoRow[windowSize+2])){
      genoRow[1:windowSize] <- genoRow[windowSize+1]
    }
    for(i in 2:(length(genoRow)-windowSize-1)){
      if(any(genoRow[i:(i+windowSize)]!=genoRow[i-1])&&any(genoRow[i:(i+windowSize)]!=genoRow[i+windowSize+1])&&(genoRow[i-1]==genoRow[i+windowSize+1])){
        genoRow[i:(i+windowSize)] <- genoRow[i-1]
      }
    }
    if(any(genoRow[(length(genoRow)-windowSize):(length(genoRow))]!=genoRow[(length(genoRow)-windowSize-1)])&&any(genoRow[(length(genoRow)-windowSize):(length(genoRow))]!=genoRow[(length(genoRow)-windowSize-2)])&&(genoRow[(length(genoRow)-windowSize-1)]==genoRow[(length(genoRow)-windowSize-2)])){
      genoRow[(length(genoRow)-windowSize):(length(genoRow))] <- genoRow[(length(genoRow)-windowSize-1)]
    }
  }
  invisible(genoRow)
}

recalculateMap.internal <- function(cross,...){
	newmap <- est.map(cross,offset=0,...)
	cross2 <- replace.map(cross, newmap)
	invisible(cross2)
}
