#! /bin/bash
#PBS -l nodes=1:ppn=4
#PBS -l walltime=25:00:00
#PBS -A jlt22_b_g_sc_default

#This script will download 1000Genomes files and select a set of SNP from a given file
#Be sure to do this on the cluster

#Download 1000Genomes (checks if newer files are in the ftp)
cd ~/scratch
mkdir -p 1000Genomes
cd 1000Genomes/
wget -c -N -r -l1 -nd -nH ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20130502/

#Copying list of snps to 1000genomes directory
cp ~/work/hgdp/snplist.txt .

#Keep only the snps in the snplist for every chromosome and merge them all
for file in *chr*.gz
do
    outname=$echo$(echo $file | cut -d '.' -f 2)
    vcftools --gzvcf $file --snps snplist.txt --recode --out $outname
done

#Concatenate the vcf files, from chr1 to chr22
inputnames=$(ls chr[0-9]*.recode.vcf)
vcf-concat $inputnames | gzip -c > 1000Gtotal.vcf.gz

#Convert the vcf file into a plink (bed, bim, fam) file
plink --vcf 1000Gtotal.vcf.gz --make-bed --out 1000Gtotal

#copy the final file to the hgdp folder
files=$(ls 1000Gtotal.*)
cp $files ~/work/hgdp/
cp integrated_call_samples_v3.20130502.ALL.panel ~/work/hgdp/
cd ~/work/hgdp/

#Generating a bed file from HGDP and keeping only autosomal chromosomes and those in the 1000Genomes
plink --file HGDP --autosome --extract 1000Gtotal.bim --make-bed --out HGDP
#Initial merging of 1000Genomes data with HGDP
plink --bfile HGDP --bmerge 1000Gtotal --make-bed --out Merge1000G_HGDP
#If there are snps with flip strand
plink --bfile 1000Gtotal --flip Merge1000G_HGDP-merge.missnp --make-bed --out 1000G_flip
#Second merging attempt
plink --bfile HGDP --bmerge 1000G_flip --make-bed --out Merge1000G_HGDP
#Exclude probably real multiallelic snps
plink --bfile 1000G_flip --exclude Merge1000G_HGDP-merge.missnp --make-bed --out 1000G_flipclean
plink --bfile HGDP --exclude Merge1000G_HGDP-merge.missnp --make-bed --out HGDPclean
#Final merging, keeping the 1000G coordinates
plink --bfile 1000G_flipclean --bmerge HGDPclean --make-bed --out Merge1000G_HGDP

rm 1000G_flip.* 1000G_flipclean.* HGDPclean.*