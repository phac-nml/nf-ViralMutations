process AlignSelect {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bwa:0.7.18--he4a0461_1' :
        'biocontainers/bwa:0.7.18--he4a0461_1'}"
    tag { Name }
    label 'process_high'

    input:
    tuple val(Name), file(read1), file(read2), path(amb_file), path(ann_file), path(bwt_file), path(pac_file), path(sa_file), path(Ref_fasta)

    output:
    tuple val(Name), file("${Name}.sam")

    script:
    """
        bwa mem ${Ref_fasta} -t ${task.cpus} -T 0 ${read1} ${read2} | awk '{if (\$3 != "*") {print}}' > ${Name}.sam
    """
}

process UnalignSelect {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bwa:0.7.18--he4a0461_1' :
        'biocontainers/bwa:0.7.18--he4a0461_1'}"
    tag { Name }
    label 'process_high'
    publishDir "${params.outdir}/${Name}/Alignments", mode: 'copy'

    input:
    tuple val(Name), file(read1), file(read2), path(amb_file), path(ann_file), path(bwt_file), path(pac_file), path(sa_file), path(Ref_fasta)

    output:
    tuple val(Name), file("${Name}_Host.sam")

    script:
    """
        bwa mem ${Ref_fasta} -t ${task.cpus} ${read1} ${read2} | awk '{if (\$3 == "*" && \$5 == "0") {print}}' > ${Name}_Host.sam
    """
}

process UnalignExtract {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.17--hd87286a_2' :
        'biocontainers/samtools:1.17--hd87286a_2'}"
    tag { Name }
    label 'process_medium'
    publishDir "${params.outdir}/${Name}", mode: 'copy'

    input:
    tuple val(Name), file(samfile)

    output:
    tuple val(Name), file("R1_${Name}.fastq"), file("R2_${Name}.fastq")

    script:
    """
        samtools bam2fq -@ ${task.cpus} -1 R1_${Name}.fastq -2 R2_${Name}.fastq -0 /dev/null -s /dev/null ${samfile}
    """
}

process MinIONAlign {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/minimap2:2.28--he4a0461_3' :
        'biocontainers/minimap2:2.28--he4a0461_3'}"
    tag { Name }
    label 'process_high'
    publishDir "${params.outdir}/${Name}/Alignments", mode: 'copy'

    input:
    tuple val(Name), file(reads), path(FastaReference)

    output:
    tuple val(Name), file("${Name}_Aligned.sam")

    script:
    """
        minimap2 -x map-ont -a -t ${task.cpus} ${FastaReference} ${reads} | awk '{if (\$3 != "*") {print}}' > ${Name}_Aligned.sam
    """
}

process MinIONUnalignSelect {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/minimap2:2.28--he4a0461_3' :
        'biocontainers/minimap2:2.28--he4a0461_3'}"
    tag { Name }
    label 'process_high'
    publishDir "${params.outdir}/${Name}", mode: 'copy'

    input:
    tuple val(Name), file(reads), path(mmi_file)

    output:
    tuple val(Name), file("${Name}_Host.sam")

    script:
    """
        minimap2 -a ${mmi_file} -t ${task.cpus} ${reads} | awk '{if (\$3 == "*" && \$5 == "0") {print}}' > ${Name}_Host.sam
    """
}

process MinIONUnalignExtract {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.17--hd87286a_2' :
        'biocontainers/samtools:1.17--hd87286a_2'}"
    tag { Name }
    label 'process_medium'
    publishDir "${params.outdir}/${Name}", mode: 'copy'

    input:
    tuple val(Name), file(samfile)

    output:
    tuple val(Name), file("Reads_${Name}.fastq")

    script:
    """
        samtools bam2fq -@ ${task.cpus} -0 Reads_${Name}.fastq -s /dev/null ${samfile}
    """
}

process Sort_Index {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.17--hd87286a_2' :
        'biocontainers/samtools:1.17--hd87286a_2'}"
    tag { Name }
    label 'process_low'
    publishDir "${params.outdir}/${Name}/Alignments", mode: 'copy'

    input:
    tuple val(Name), file(samfile)

    output:
    tuple val(Name), file("*.bam"), file("*.bam.bai")

    script:
    """
        filename=\$( echo ${samfile} | cut -f 1 -d '.' )
        samtools view -u ${samfile} | samtools sort -@ ${task.cpus} -o \${filename}_sorted.bam
        samtools index \${filename}_sorted.bam
    """
}
