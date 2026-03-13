process CombineMinIONFastq {
    publishDir "${params.outdir}/${meta.id}/Combined", pattern: "${meta.id}_combined.fastq.gz", mode: 'copy'
    tag { "$meta.id" }
    label 'process_single'

    input:
    tuple val(meta), path(FOLDER)

    output:
    tuple val(meta), path("${meta.id}_combined.fastq.gz")

    script:
    """
        if [[ "${params.Extension}" =~ .*gz ]]; then
            gunzip -c ${FOLDER}/*${params.Extension} > ${meta.id}_combined.fastq
        else
            cat ${FOLDER}/*${params.Extension} > ${meta.id}_combined.fastq
        fi
        gzip ${meta.id}_combined.fastq
    """
}

process TrimIllumina {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/fastp:0.24.0--heae3180_1' :
        'biocontainers/fastp:0.24.0--heae3180_1'}"
    tag { "$meta.id" }
    label 'process_medium'
    publishDir "${params.outdir}/Trim", pattern: "*.fq.gz", mode: 'copy'
    publishDir "${params.outdir}/${meta.id}/QC/Raw", pattern: "*.json", mode: 'copy'
    publishDir "${params.outdir}/${meta.id}/QC", pattern: "*.html", mode: 'copy'

    input:
    tuple val(meta), file(reads)

    output:
    tuple val(meta), file("${meta.id}_val_1.fq.gz"), file("${meta.id}_val_2.fq.gz"), emit: trim_reads_ch
    tuple val(meta), file("*_TrimReport.json"), file("*_TrimReport.html"), emit: trim_report_ch

    script:
    """
         fastp -i ${reads[0]} -I ${reads[1]} -o ${meta.id}_val_1.fq.gz -O ${meta.id}_val_2.fq.gz\
          -j ${meta.id}_TrimReport.json -h ${meta.id}_TrimReport.html -w ${task.cpus} ${params.TrimArgs}
    """
}

process TrimMinION {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/fastplong:0.2.2--heae3180_0' :
        'biocontainers/fastplong:0.2.2--heae3180_0'}"
    tag { "$meta.id" }
    label 'process_medium'
    publishDir "${params.outdir}/Trim", pattern: "*.fastq.gz", mode: 'copy'
    publishDir "${params.outdir}/${meta.id}/QC/Raw", pattern: "*.json", mode: 'copy'
    publishDir "${params.outdir}/${meta.id}/QC", pattern: "*.html", mode: 'copy'

    input:
    tuple val(meta), file(reads)

    output:
    tuple val(meta), file("${meta.id}_trim.fastq.gz"), emit: trim_reads_ch
    tuple val(meta), file("*_TrimReport.json"), file("*_TrimReport.html"), emit: trim_report_ch

    script:
    """
        fastplong -i ${reads} -o ${meta.id}_trim.fastq.gz -w ${task.cpus} -m 10 -j ./${meta.id}_TrimReport.json -h ./${meta.id}_TrimReport.html  ${params.TrimArgs}
    """
}
