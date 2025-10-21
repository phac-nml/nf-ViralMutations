process BAM_QC {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.17--hd87286a_2' :
        'biocontainers/samtools:1.17--hd87286a_2'}"
    tag { SampleName }
    label 'process_single'
    publishDir "${params.outdir}/${SampleName}/QC/Raw", mode: 'copy'

    input:
    tuple val(SampleName), file(alignment), file(index)

    output:
    tuple val(SampleName), file("*.tsv"), file("*.txt")

    script:
    """
        name=\$( echo ${alignment} | sed "s/.bam//g" )
        samtools flagstats -O tsv ${alignment} > \${name}_flagstats.tsv
        samtools stats ${alignment} > \${name}_stats.txt
    """
}

process Combine_QC {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/multiqc:1.25.1--pyhdfd78af_0' :
        'biocontainers/multiqc:1.25.1--pyhdfd78af_0'}"
    tag { SampleName }
    label 'process_single'
    publishDir "${params.outdir}/${SampleName}/QC", mode: 'copy'

    input:
    tuple val(SampleName), file(snpEff_csv), file(snpEff_vcf), path(raw_dat)

    output:
    tuple val(SampleName), file("${SampleName}_multiqc.html")

    script:
    """
       multiqc --filename ${SampleName}_multiqc.html Raw
    """
}

process Depths {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.17--hd87286a_2' :
        'biocontainers/samtools:1.17--hd87286a_2'}"
    tag { Name }
    label 'process_single'

    publishDir "${params.outdir}/${Name}/QC/Raw", mode: 'copy'

    input:
    tuple val(Name), file(bam), file(bai)

    output:
    tuple val(Name), file("${Name}_depths.tsv")

    script:
    """
            samtools depth -J -aa -d 1000000000 ${bam} > ${Name}_depths.tsv
    """
}

process DepthGraph {
    container 'docker://rocker/tidyverse:4.5.0'
    tag { Name }
    label 'process_single'
    publishDir "${params.outdir}/${Name}/QC", mode: 'copy'

    input:
    tuple val(Name), file(depths)

    output:
    path "${Name}_depth.pdf", optional: true

    script:
    """
        PlotDepth.r ${depths} ${Name}
    """
}
