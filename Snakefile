configfile: "config.json"
localrules: track_changes, track_dir


import os


# add all reads to check fastqc
config["fastqc_rules"]["reads"] = {os.path.basename(p):p for p in [v for t in config["bowtie2_rules"]["units"].values() for v in t]}
# add all paired reads to run trimmomatic
config["trimmomatic_rules"]["reads"] = config["bowtie2_rules"]["units"]
# add all trimmomatic reads to fastqc
config["fastqc_rules"]["reads"].update(
    {r.replace("/","_"):r for r in expand("trimmomatic/{trim_params}/{reads}_{ext}.fastq.gz",
        reads=config["trimmomatic_rules"]["reads"],
        trim_params=config["trimmomatic_rules"]["trim_params"], ext=["1P","2P","1U","2U"])})
# add all samples and units to ray config from prefered trimmomatic parameters
config["ray_rules"]["samples"] = config["bowtie2_rules"]["samples"]
config["ray_rules"]["units"] = {u:expand("trimmomatic/{trim_params}/{reads}_{ext}.fastq.gz", reads=u, ext=["1P", "2P"], trim_params="TruSeq3-m4-pe30-se10-minlen36") for u in config["bowtie2_rules"]["units"]}
# make merged newbler assemblies of all ray assemblies for each sample
config["assembly_merge_rules"]["merge"] = {sample:expand("assembly/ray/{assembly_params}/{sample}/out_{kmer}/Contigs.fasta",
                                                  assembly_params="default",
                                                  kmer=config["ray_rules"]["kmers"],
                                                  sample=sample) for sample in config["ray_rules"]["samples"]}
# add newbler merged assemblies to bowtie2 references for mapping
config["bowtie2_rules"]["references"] = {m:expand("assembly/newbler/{merge}/454AllContigs.fna", merge=m) for m in config["assembly_merge_rules"]["merge"]}
# add newbler merged assemblies to concoct assemblies
config["concoct_rules"]["assemblies"] = {m:expand("assembly/newbler/{merge}/454AllContigs.fna", merge=m) for m in config["assembly_merge_rules"]["merge"]}

# Show all bowtie2 logs and markduplicate percent duplications in the mapping report
config["mapping_report_rules"]["bowtie2_logs"] = sorted(expand("mapping/bowtie2/{mapping_params}/{reference}/units/{unit}.log",
                                                        mapping_params=config["bowtie2_rules"]["mapping_params"],
                                                        reference=config["bowtie2_rules"]["references"],
                                                        unit=config["bowtie2_rules"]["units"]))
config["mapping_report_rules"]["markduplicates_metrics"] = sorted(expand("mapping/bowtie2/{mapping_params}/{reference}/units/{unit}.sorted.removeduplicates.metrics",
                                                                  mapping_params=config["bowtie2_rules"]["mapping_params"],
                                                                  reference=config["bowtie2_rules"]["references"],
                                                                  unit=config["bowtie2_rules"]["units"]))
# Show all assemblies except the cut up ones in the assembly report
config["assembly_report_rules"]["assemblies"] = sorted(
    expand("assembly/newbler/{merge}/454AllContigs.fna", merge=config["assembly_merge_rules"]["merge"]) +
    expand("assembly/ray/{assembly_params}/{sample}/out_{kmer}/Contigs.fasta", assembly_params=config["ray_rules"]["assembly_params"], sample=config["ray_rules"]["samples"], kmer=config["ray_rules"]["kmers"]))




SM_WORKFLOW_LOC="https://raw.githubusercontent.com/binnisb/snakemake-workflows/master/"
#SM_WORKFLOW_LOC = "/glob/inod/github/snakemake-workflows/"
include: SM_WORKFLOW_LOC + "bio/ngs/rules/quality_control/fastqc.rules"
include: SM_WORKFLOW_LOC + "bio/ngs/rules/trimming/trimmomatic.rules"
include: SM_WORKFLOW_LOC + "bio/ngs/rules/assembly/ray.rules"
include: SM_WORKFLOW_LOC + "common/rules/track_dir.rules"
include: SM_WORKFLOW_LOC + "bio/ngs/rules/assembly/merge.rules"
include: SM_WORKFLOW_LOC + "bio/ngs/rules/assembly/report.rules"
include: SM_WORKFLOW_LOC + "bio/ngs/rules/mapping/bowtie2.rules"
include: SM_WORKFLOW_LOC + "bio/ngs/rules/mapping/samtools.rules"
include: SM_WORKFLOW_LOC + "bio/ngs/rules/mapping/report.rules"
include: SM_WORKFLOW_LOC + "bio/ngs/rules/binning/concoct.rules"
include: SM_WORKFLOW_LOC + "bio/ngs/rules/annotation/prodigal.rules"
include: SM_WORKFLOW_LOC + "bio/ngs/rules/blast/rpsblast.rules"
include: SM_WORKFLOW_LOC + "bio/ngs/rules/annotation/hmmer.rules"

rule track_changes:
    input:
        "results_track.txt"
