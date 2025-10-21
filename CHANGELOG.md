# CHANGELOG

## Release 1.1.0 - 2025-XX-XX

### Fixes
- Consensus process wasn't working if the reference fasta contained empty lines between segment sequences (default for fasta files from NCBI). This was due to bcftools stopping the processing when it hit an empty line. A sed command was introduced to remove empty lines from the reference before piping into bcftools. Also, it is a good idea to remove the empty lines from the reference fasta in the first place.

### Changes
- Switched read trimming to fastp/fastplong. These softwares also provide the pre- and post-trimming QC reports.
  - Since all arguments are named (rather than positional), a single process is sufficient to add custom features to the trimming
  - Since fastp/fastplong already provide QC reports (better ones than FastQC), the FastQC process was removed as well.
- Switched input to a samplesheet.
  - Passed to the `input` parameter, as per nf-core and IRIDA Next standards.
  - Expects the 3 columns: `sample`,`fastq_1`,`fasq_2`
    - For MinION, use the `longreads` column for the fastq file (if MinION_split is `false`) or the folder of fastqs (if MinION_split is `true`)
  - The parameter `Data_Folder` has been removed.
- Added profiles to the config, which allows easy toggle of SLURM and between Singularity/Apptainer/Docker and other systems.
- The parameter `Result_Folder` is now `outdir` for compatibility with nf-core and IRIDA Next.
- Parameter validation has been implemented, the pipeline will print non-default parameter values when it starts.
- The parameter `Singularity_cache` no longer exists, that was creating weird questions w.r.t. testing and we can let the software deal with that.
- Added the data and files for minimal pipeline testing. The test profiles `test_MinION` and `test_Illumina` can be used.
- The process that creates the plot of depth no longer outputs empty plots (nothing is output if no reads align).

## Release 1.0.1 - 2025-04-01

### Fixes
- Fixed the issue related to Fastqc running out of memory
- Fixed an issue where the minimum number of lines output from FreeBayes was too low and allowed empty files (header only) to be pushed to the next processes.
- Fixed an issue collecting a pre-indexed host genome didn't work due to too many output files in the output tuple (one was duplicated)
  - Fixed an issue where the subworkflow was doing an `ifEmpty` check on the GetIndex output and the single value passed was triggering bad behaviour

## Release 1.0.0 - 2025-01-28

### Major changes
- Switched to containers (using Singularity at the moment) instead of Conda
  - Had to split some processes (mostly separate alignments from samtools usage)
- Re-structured the Preflight and Alignment workflows to:
  - Allow de-hosting of MinION data
  - Remove target reference pre-indexing with BWA for MinION data

### Other changes
- Moved resource assignment from processes to configs/resources.config
- Removed two processes that were leftovers from using LoFreq3

## Release 0.1.0 - 2024-11-07

Initial commit
Add CHANGELOG