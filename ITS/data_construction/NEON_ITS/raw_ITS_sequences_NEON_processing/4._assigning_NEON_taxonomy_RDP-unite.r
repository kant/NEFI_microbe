#assign taxonomy.
#clear environment, load packages, functions and paths.----
rm(list=ls())
source('paths.r')
source('NEFI_functions/tic_toc.r')
source('NEFI_functions/fg_assign_parallel.r')
library(doParallel)

#load ASV table, set output path.----
#this needs a lot of memory.
d <- readRDS(NEON_SV.table.path)
output.tax.path <- NEON_tax.path

#1. download unite training set.----
cat('downloading UNITE database...\n')
unite_url <- 'https://files.plutof.ut.ee/doi/B2/07/B2079372C79891519EF815160D4467BBF4AF1288A23E135E666BABF2C5779767.zip'
unite_path.zip <- paste0(data.dir,'unite.fa.zip')
unite_path     <- paste0(data.dir,'sh_general_release_dynamic_01.12.2017.fasta')
cmd <- paste0('curl ',unite_url,' > ',unite_path.zip)
system(cmd)
cmd <- paste0('unzip ',unite_path.zip,' -d ',data.dir)
system(cmd)
cat('UNITE download complete.\n')

#2. assign taxonomy.----
#tax <- dada2::assignTaxonomy(colnames(d),unite_path, multithread = T)

#2_alternate. assign taxonomy in parallel using colin's parallel hack.----
n <- detectCores()
registerDoParallel(cores=n)
if(is.na(n)){
  cat("Detect cores failed. Who knows what doParallel is doing.")
}

#set breakpoints for subsetting taxonomy list.
to_assign <- colnames(d)
brk <- floor(length(to_assign) / n) #floor rounds down. Important here.

#use a foreach loop to do this in parallel on subsets.
tic()
cat('assigning taxonomy with the RDP classifier and unite training set...\n')
output.list <-
  foreach(i = 1:n) %dopar% {
    #tell loop where i of n taxonomy subset starts and ends.
    start <- (brk*i - brk) + 1
    end <- brk*i
    #if you on the last subset go to end.
    if(i == n){end = length(to_assign)}

#assign taxa
    tax.out <- dada2::assignTaxonomy(to_assign[start:end],unite_path)

#return output to list
    return(tax.out)
  }
cat('Taxonomy assignment complete! yeahhhh.\n')
toc()

#merge together output of parallel assignment.
tax <- data.frame(do.call('rbind',output.list))


#3. save output.----
saveRDS(tax, output.tax.path)

#4. cleanup.----
system(paste0('rm -f ',unite_path.zip))
system(paste0('rm -f ',unite_path))
system(paste0('rm -rf ',data.dir,'developer/'))

#end script.
