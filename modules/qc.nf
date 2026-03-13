process BAM_QC {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.17--hd87286a_2' :
        'biocontainers/samtools:1.17--hd87286a_2'}"
    tag { "$meta.id" }
    label 'process_single'
    publishDir "${params.outdir}/${meta.id}/QC/Raw", mode: 'copy'

    input:
    tuple val(meta), file(alignment), file(index)

    output:
    tuple val(meta), file("*.tsv"), file("*.txt")

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
    tag { "$meta.id" }
    label 'process_single'
    publishDir "${params.outdir}/${meta.id}/QC", mode: 'copy'

    input:
    tuple val(meta), file(snpEff_csv), file(snpEff_vcf), path(raw_dat)

    output:
    tuple val(meta), file("${meta.id}_multiqc.html")

    script:
    """
       multiqc --filename ${meta.id}_multiqc.html Raw
    """
}

process Depths {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.17--hd87286a_2' :
        'biocontainers/samtools:1.17--hd87286a_2'}"
    tag { "$meta.id" }
    label 'process_single'

    publishDir "${params.outdir}/${meta.id}/QC/Raw", mode: 'copy'

    input:
    tuple val(meta), file(bam), file(bai)

    output:
    tuple val(meta), file("${meta.id}_depths.tsv")

    script:
    """
            samtools depth -J -aa -d 1000000000 ${bam} > ${meta.id}_depths.tsv
    """
}

process DepthGraph {
    container 'docker://rocker/tidyverse:4.5.0'
    tag { "$meta.id" }
    label 'process_single'
    publishDir "${params.outdir}/${meta.id}/QC", mode: 'copy'

    input:
    tuple val(meta), file(depths)

    output:
    tuple val(meta), file("${meta.id}_depth.pdf"), optional: true

    script:
    """
        PlotDepth.r ${depths} ${meta.id}
    """
}
