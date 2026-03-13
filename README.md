# nf-ViralMutations

## Pipeline intent

This pipeline is intended to be used to align Illumina or MinION reads to a reference and call the mutations and consensus.
The mutations called include non-consensus mutations, which is useful when looking at the dynamics of the viral population over time.
The pipeline is designed to allow a number of options for analysis:

- Host removal (Illumina and MinION, non-competitive)
- Primer clipping (position-based) (Illumina and MinION)
- Targeted downsampling (only downsamples regions above the threshold) (Illumina and MinION)
- The minimum depth and frequency thresholds can be adjusted separately for SNP reporting and consensus calling
  
The consensus will include IUPAC alternates if multiple alternate bases create a situation where neither an alternate nor the reference form consensus.

## Installation

The two installation requirements are [Nextflow](https://www.nextflow.io/docs/latest/install.html) and a container platform (the pipeline has profiles for [Singularity](https://docs.sylabs.io/guides/3.5/user-guide/quick_start.html#quick-installation-steps) and [Apptainer](https://apptainer.org/)).

A profile is also set up to use `slurm`, remember to set the `SLURM_Queue` parameter.

## Running the pipeline

Assuming all the parameters are stored in a JSON or YAML file, navigate to the folder where you want the `nextflow` and `work` directories to be located and run the following command:

```shell
nextflow run PHAC-NML/nf-ViralMutations -r v1.1.0 -params-file /loc/of/Params_Exp1.yml -profile singularity,slurm
```

### Running the test configurations

Two test configurations are included as profiles. One tests the Illumina pipeline and includes de-hosting (using MPXV genome as host for speed). The other tests the MinION pipeline and includes primer clipping. The datasets included are quite small so they should run quickly. These tests only ensure all processes can run without issue.

**If you are using SLURM, modify the two configs (`configs/test_illumina.config` and `configs/test_minion.config`) to provide the correct SLURM queue name for your system. Alternatively, you can specify the queue using the `SLURM_Queue` command line parameter.**

```shell
nextflow run PHAC-NML/nf-ViralMutations -r v1.1.0 -profile singularity,slurm,test_MinION
nextflow run PHAC-NML/nf-ViralMutations -r v1.1.0 -profile singularity,slurm,test_Illumina --SLURM_Queue MyQueue
```

## Parameters

The full set of parameters are described in the comments in the `nextflow.config` file.
Some less simple ones are explained below.
It is easier to assemble the pipeline parameters in a YAML or JSON file to be passed with the command line argument `-params-file`.

### Host reference

Since the hosts are usually eukaryotes, their large genome can take some time to index.
To mitigate this, it is also possible to specify the location of the index files.

#### For a new host reference

Set the `Host_Reference` parameter to the full path of the fasta (gzipped or not) sequence and set the `Host_IndexOut` parameter to `true` to save the index to the output folder. (YAML)

```YAML
Host_Reference: "/home/user/Hosts/Human_T2TY.fa.gz"
Host_IndexOut: true
Host_Indexed: false
```

#### For a previously-indexed host reference

Set the `Host_Reference` parameter to the __file path__ of the fasta sequence and set the `Host_Indexed` parameter to `true`. (JSON)

```JSON
{
    "Host_Reference": "/home/user/Hosts/Human_T2TY.fa.gz",
    "Host_IndexOut": false,
    "Host_Indexed": true
}
```

### Illumina adapter clipping

Illumina adapter removal is performed using [fastp](https://github.com/OpenGene/fastp)/[fastplong](https://github.com/OpenGene/fastplong).
Those tools also perform pre- and post-trimming read QC.
It is possible to specify either the number of bases to clip from the 5' end of each base or the specific adapter sequences to trim (specify both).
Custom trim arguments can be specified for both Illumina and MinION trimming.
**Note that the rest of the pipeline is not designed to deal with merged reads, please do not activate this feature."

To clip the first 14 bases from R2 (e.g. Takara stranded RNA prep, pico input): (YAML)

```YAML
    TrimArgs: "--trim_front2 14"
```

To also trim specific adapters from each read (e.g. Zymo Stranded RNA kit): (JSON)

```JSON
{
    "TrimArgs": "--trim_front2 10 --adapter_sequence NNNNNNNNNNAGATCGGAAGAGCACACGTCTGAACTCCAGTCAC --adapter_sequence_r2 AGATCGGAAGAGCGTCGTGTAGGGAAAGA"
}
```

### Alignment filtering

The alignments are filtered to, by default, remove secondary alignments and alignments with Map quality less than 30.
To change those parameters: (JSON)

```JSON
{
    "Read_MinMAPQ": 20,
    "Read_ExclFLAG": 0x810
}
```

### snpEff configuration

The pipeline uses snpEff to infer the effect of mutations.
The snpEff database is "rebuilt" for every run.
In order for the pipeline to run you must pass a name for the pathogen and a folder containing the sequence and annotations.
The entry is added to a barebones snpEff.config file saved in the pipeline directory which passed along to the snpEff process.

- `genes.gtf` contains the annotations in GTF (GFF3) format (concatenated entries for segmented genomes) and the FASTA sequences under a `##FASTA` section

The easiest way to assemble this file is to download the entries (selecting all of them for segmented genomes) from GenBank (or other repository) directly.
If the annotations were modified and exported in a Windows software (e.g. DNASTAR's SeqBuilder or UGENE), make sure the files have LF (and not CRLF) line endings.

### Input reads

The `input` parameter takes a csv file that must have columns `sample` and `fastq_1`.
Absolute paths are generally preferred.

#### Illumina

For Illumina paired-end data (the pipeline does not expect Illumina single-end data), a `fastq_2` column is also needed.

JSON example for Illumina data:

```JSON
{
    "input": "/home/user/Data/Experiment3/samplesheet.csv"
}
```

with the file `samplesheet.csv` looking like:

```CSV
sample,fastq_1,fastq_2
Samp1,/home/user/Data/Experiment3/Fastq/Samp1_S1_R1_001.fastq,/home/user/Data/Experiment3/Fastq/Samp1_S1_R2_001.fastq
Virus3,/home/user/Data/Experiment3/Fastq/Samp2_S5_R1_001.fastq,/home/user/Data/Experiment3/Fastq/Samp2_S5_R2_001.fastq
```

#### MinION

MinION reads are usually stored in a folder called `fastq_pass` which contains a folder for each barcode (e.g. `barcode01`).
If this is the case for your data, set `MinION_split` to `true` and the `long_reads` column of the samplesheet to the path of the folder that contains the fastq files for that sample. You'll also need to specify the extension for the files.

If your data has already been collated and the read files have meaningful names, set `MinION_split` to `false` and the `long_reads` column to the collated fastq file.
If you data is collated but you want to change the sample names, put each read file in its own folder and follow the instructions for non-collated data.

YAML example for non-collated data:

```YAML
input: "/home/user/Data/Experiment2/no_sample/run_guid/samplesheet.csv"
MinION_split: true
Extension: ".fastq.gz"
```

with the file `samplesheet.csv` looking like:

```CSV
sample,long_reads
Samp1,/home/user/Data/Experiment3/fastq_pass/barcode02
Virus3,/home/user/Data/Experiment3/fastq_pass/barcode05
```

JSON example for pre-collated data:

```JSON
{
    "input": "/home/user/Data/Experiment3/no_sample/run_guid/samplesheet.csv",
    "MinION_split": false
}
```

### Primer clipping

The pipeline uses BamClipper for positional primer clipping post-alignment.
This utility uses a 6-column bedpe format to identify primer locations:

RefName   FPrimerStart   FPrimerEnd  RefName   RPrimerStart   RPrimerEnd

The parameter `Primer_Locs` takes a path to this bedpe file.
If the bedpe file was generated by primalscheme or varVAMP, set `Primer_Format` to `ARTIC`.
**Note that varVAMP's bed file reports primer positions according to the consensus of the alignment.**
If the bedpe file is already in the correct 6-column format, set `Primer_Format` to `bamclipper`.

**IMPORTANT: It is assumed that in the ARTIC format, Forward and Reverse primers are on sequential lines. If you have alternate forwards or reverses, pair them with the correct primer. You should not have a file with lines that go: FFRFRRFRFR.**

### Other parameters

- `outdir` defaults to `${launchDir}/Results`, but can be changed.
- `Seq_Tech` should be either `Illumina` or `MinION`.
- `Target_Reference` is the path to the viral genome you are aligning to. Since viral genomes are generally small, it is always re-indexed.
- `Extension` specifies exactly what the extension of the original read files is, e.g.: `.fastq`, `.fa.gz`
- `SLURM_Queue` to specify the SLURM queue or partition to be used. Only used with the `slurm` profile.
- `GenePos` (optional) an Excel file used to annotate the graph of SNPs with the following columns:
  - `CHR` The reference name.
  - `CDS_Name` The name to show on the graph. Assumes most annotation will be CDSs but doesn't check, so you can annotate any feature you want.
  - `Start` The 1-based position for the start of the CDS.
  - `Stop` The 1-based position for the end of the CDS.

## Outputs

Most intermediate files are saved into `outdir` to allow QC of the different steps and to diagnose unexpected results.

### Key Outputs

- `{SampleName}_variants.pdf` Graphical presentation of all the SNPs that pass the depth and minimum frequency. If there are too many, some of the labels will be missing. The grey line represents the depth at each position (left axis) and the red bars position the SNPs along the genome; the red dots show the frequency of the SNP (right axis) along with error bars (based on binomial distribution using frequency and depth).
- `{SampleName}_variants_annot_filtered.tsv`Tab-separated summary of the SNPs/indels along with snpEff annotations. Can be opened in Excel or imported in R for further processing.
- `{SampleName}_variants_annot.vcf` Cleaned-up FreeBayes output (not filtered) with snpEff annotations.
- `{SampleName}_variants.vcf` Raw FreeBayes output.
- `{SampleName}_variants_annot.html` snpEff summary of the effect of mutations.
- `Alignments/{SampleName}_Aligned_pe.bam` Initial alignment to the `Target_Reference`. All derivatives created during clean-up are in the `Alignments` sub-folder, the order they are created is: _dd (deduplicated; Illumina-only), _pc (primer-clipped), _noSplit (filtered), _ds (downsampled; if max-depth was specified).
- `{SampleName}_consensus.fasta` The consensus sequence.

## Example DAGs

Given the different combinations, the DAGs below are not exhaustive but they reflect 3 common scenarios.

### Illumina PCR sequencing

![DAG showing the processes involved in analysing Illumina tiling amplicon data](images/DAG_Illumina_PCR.png)

### Illumina Shotgun sequencing with pre-indexed host sequence

![DAG showing the processes involved in analysing Illumina shotgun data, including de-hosting with a pre-indexed host sequence](images/DAG_Illumina_Shotgun.png)

### MinION PCR sequencing

![DAG showing the processes involved in analysing MinION tiling amplicon data](images/DAG_MinION_PCR.png)

## Support
Should any issues arise when running this pipeline, please create an issue for the moment.

## Legal
Copyright Government of Canada 2024

Written by: National Microbiology Laboratory, Public Health Agency of Canada

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this work except in compliance with the License. You may obtain a copy of the License at:

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

### BamClipper

The BamClipper files (`bin/bamclipper_m.sh`, `bin/clipprimer.pl`, `bin/injectseparator.pl`) are under the original MIT License.

MIT License

Copyright (c) 2016 Chun Hang Au

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.