process Dedup {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.17--hd87286a_2' :
        'biocontainers/samtools:1.17--hd87286a_2'}"
    tag { Name }
    label 'process_medium'
    publishDir "${params.outdir}/${Name}/Alignments", mode: 'copy'

    input:
    tuple val(Name), file(aligned), file(index)

    output:
    tuple val(Name), file("${Name}_Aligned_dd.bam"), file("${Name}_Aligned_dd.bam.bai"), emit: dedup_data_ch
    tuple val(Name), file("${Name}_duplication_stats.txt"), emit: dedup_stats_ch

    script:
    """
        samtools sort -@ ${task.cpus} -n ${aligned} |
        samtools fixmate -r -m - ${Name}_Aligned_fm.bam
        samtools sort -@ ${task.cpus} ${Name}_Aligned_fm.bam |
        samtools markdup -r -f ${Name}_duplication_stats.txt -s - ${Name}_Aligned_dd.bam
        samtools index ${Name}_Aligned_dd.bam
    """
}

process Remove_secondaries {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.17--hd87286a_2' :
        'biocontainers/samtools:1.17--hd87286a_2'}"
    tag { Name }
    label 'process_low'
    publishDir "${params.outdir}/${Name}/Alignments", mode: 'copy'

    input:
    tuple val(Name), file(aligned), file(index)

    output:
    tuple val(Name), file("${Name}_noSplit.bam"), file("${Name}_noSplit.bam.bai")

    script:
    """
        samtools view -u -F ${params.Read_ExclFLAG} -q ${params.Read_MinMAPQ} -@ ${task.cpus} ${aligned} | samtools sort -@ ${task.cpus} -o ${Name}_noSplit.bam
        samtools index ${Name}_noSplit.bam
    """
}

process PrimerClip {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bamclipper:1.0.0--pl526_0' :
        'biocontainers/bamclipper:1.0.0--pl526_0'}"
    tag { Name }
    label 'process_medium'
    publishDir "${params.outdir}/${Name}/Alignments", mode: 'copy'

    input:
    tuple val(Name), file(bam), file(bai), file(primer_locs)

    output:
    tuple val(Name), file("${Name}_Aligned_pc.bam"), file("${Name}_Aligned_pc.bam.bai")

    script:
    """
        bamclipper.sh -b ${bam} -p ${primer_locs} -n ${task.cpus} -d 20
        
        basename=\$( echo ${bam} | sed "s/.bam//g" )

        mv \${basename}.primerclipped.bam ${Name}_Aligned_pc.bam
        rm \${basename}.primerclipped.bam.bai
        samtools index ${Name}_Aligned_pc.bam
    """
}

process Downsample {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-bb5f3dab55f89ca6e9acdff899d8409efffcc444:949930df72decfcefd14c5d64ef58250f319589e-0' :
        'biocontainers/mulled-v2-bb5f3dab55f89ca6e9acdff899d8409efffcc444:949930df72decfcefd14c5d64ef58250f319589e-0'}"
    tag { Name }
    label 'process_single'
    publishDir "${params.outdir}/${Name}/Alignments", mode: 'copy'

    input:
    tuple val(Name), file(bam), file(bai), file(depth)

    output:
    tuple val(Name), file("${Name}_Aligned_ds.bam")

    script:
    if (params.Seq_Tech == "Illumina") {
        """
            DownsampleToCoverage.py -r ${bam} -n ${Name}_Aligned_ds.bam -c ${depth} -t ${params.SNP_MaxCov}
        """
    }
    else {
        """
            DownsampleToCoverage.py -r ${bam} -n ${Name}_Aligned_ds.bam -c ${depth} -t ${params.SNP_MaxCov}
        """
    }
}


