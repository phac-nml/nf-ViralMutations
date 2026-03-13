process AlignSelect {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bwa:0.7.18--he4a0461_1' :
        'biocontainers/bwa:0.7.18--he4a0461_1'}"
    tag { "$meta.id" }
    label 'process_high'

    input:
    tuple val(meta), file(read1), file(read2), path(amb_file), path(ann_file), path(bwt_file), path(pac_file), path(sa_file), path(Ref_fasta)

    output:
    tuple val(meta), file("${meta.id}.sam")

    script:
    """
        bwa mem ${Ref_fasta} -t ${task.cpus} -T 0 ${read1} ${read2} | awk '{if (\$3 != "*") {print}}' > ${meta.id}.sam
    """
}

process UnalignSelect {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bwa:0.7.18--he4a0461_1' :
        'biocontainers/bwa:0.7.18--he4a0461_1'}"
    tag { "$meta.id" }
    label 'process_high'
    publishDir "${params.outdir}/${meta.id}/Alignments", mode: 'copy'

    input:
    tuple val(meta), file(read1), file(read2), path(amb_file), path(ann_file), path(bwt_file), path(pac_file), path(sa_file), path(Ref_fasta)

    output:
    tuple val(meta), file("${meta.id}_Host.sam")

    script:
    """
        bwa mem ${Ref_fasta} -t ${task.cpus} ${read1} ${read2} | awk '{if (\$3 == "*" && \$5 == "0") {print}}' > ${meta.id}_Host.sam
    """
}

process UnalignExtract {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.17--hd87286a_2' :
        'biocontainers/samtools:1.17--hd87286a_2'}"
    tag { "$meta.id" }
    label 'process_medium'
    publishDir "${params.outdir}/${meta.id}", mode: 'copy'

    input:
    tuple val(meta), file(samfile)

    output:
    tuple val(meta), file("R1_${meta.id}.fastq"), file("R2_${meta.id}.fastq")

    script:
    """
        samtools bam2fq -@ ${task.cpus} -1 R1_${meta.id}.fastq -2 R2_${meta.id}.fastq -0 /dev/null -s /dev/null ${samfile}
    """
}

process MinIONAlign {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/minimap2:2.28--he4a0461_3' :
        'biocontainers/minimap2:2.28--he4a0461_3'}"
    tag { "$meta.id" }
    label 'process_high'
    publishDir "${params.outdir}/${meta.id}/Alignments", mode: 'copy'

    input:
    tuple val(meta), file(reads), path(FastaReference)

    output:
    tuple val(meta), file("${meta.id}_Aligned.sam")

    script:
    """
        minimap2 -x map-ont -a -t ${task.cpus} ${FastaReference} ${reads} | awk '{if (\$3 != "*") {print}}' > ${meta.id}_Aligned.sam
    """
}

process MinIONUnalignSelect {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/minimap2:2.28--he4a0461_3' :
        'biocontainers/minimap2:2.28--he4a0461_3'}"
    tag { "$meta.id" }
    label 'process_high'
    publishDir "${params.outdir}/${meta.id}", mode: 'copy'

    input:
    tuple val(meta), file(reads), path(mmi_file)

    output:
    tuple val(meta), file("${meta.id}_Host.sam")

    script:
    """
        minimap2 -x map-ont -a ${mmi_file} -t ${task.cpus} ${reads} | awk '{if (\$3 == "*" && \$5 == "0") {print}}' > ${meta.id}_Host.sam
    """
}

process MinIONUnalignExtract {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.17--hd87286a_2' :
        'biocontainers/samtools:1.17--hd87286a_2'}"
    tag { "$meta.id" }
    label 'process_medium'
    publishDir "${params.outdir}/${meta.id}", mode: 'copy'

    input:
    tuple val(meta), file(samfile)

    output:
    tuple val(meta), file("Reads_${meta.id}.fastq")

    script:
    """
        samtools bam2fq -@ ${task.cpus} -0 Reads_${meta.id}.fastq -s /dev/null ${samfile}
    """
}

process Sort_Index {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.17--hd87286a_2' :
        'biocontainers/samtools:1.17--hd87286a_2'}"
    tag { "$meta.id" }
    label 'process_low'
    publishDir "${params.outdir}/${meta.id}/Alignments", mode: 'copy'

    input:
    tuple val(meta), file(samfile)

    output:
    tuple val(meta), file("*.bam"), file("*.bam.bai")

    script:
    """
        filename=\$( echo ${samfile} | cut -f 1 -d '.' )
        samtools view -u ${samfile} | samtools sort -@ ${task.cpus} -o \${filename}_sorted.bam
        samtools index \${filename}_sorted.bam
    """
}
