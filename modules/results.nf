process SnpCall {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/freebayes:1.3.8--h6a68c12_2' :
        'biocontainers/freebayes:1.3.8--h6a68c12_2'}"
    tag { "$meta.id" }
    label 'process_single_long'
    publishDir "${params.outdir}/${meta.id}", pattern: "${meta.id}_variants.vcf", mode: 'copy'

    input:
    tuple val(meta), file(bam), file(bai), file(reference)

    output:
    tuple val(meta), file("${meta.id}_variants.vcf"), optional: true

    script:
    if (params.Seq_Tech == "Illumina") {
        """
            freebayes -b ${bam} -f ${reference} --pooled-continuous -v ${meta.id}_variants.vcf -p 1 -B 3 -E -1 -F 0.005 --min-coverage 1
            
            num_lines=\$( wc -l ${meta.id}_variants.vcf | cut -f1 -d ' ' )
            if [ \$num_lines -lt 65 ]; then
                rm ${meta.id}_variants.vcf
            fi
        """
    }
    else {
        """
            freebayes -b ${bam} -f ${reference} --pooled-continuous -v ${meta.id}_variants.vcf -m ${params.Read_MinMAPQ} -p 1 -B 3 -E -1 --haplotype-length -1 -F 0.03 --min-coverage 1
            
            num_lines=\$( wc -l ${meta.id}_variants.vcf | cut -f1 -d ' ' )
            if [ \$num_lines -lt 65 ]; then
                rm ${meta.id}_variants.vcf
            fi
        """
    }
}

process MakeNiceVCF {
    container 'docker://rocker/tidyverse:4.5.0'
    tag { "$meta.id" }
    label 'process_single'
    publishDir "${params.outdir}/${meta.id}", pattern: "${meta.id}_clean.vcf", mode: 'copy'
    publishDir "${params.outdir}/${meta.id}/QC", pattern: "${meta.id}_consensus.vcf", mode: 'copy'

    input:
    tuple val(meta), file(freebayes_vcf), file(basic_header)

    output:
    tuple val(meta), file("${meta.id}_clean.vcf"), emit: nice_vcf_ch
    tuple val(meta), file("${meta.id}_consensus.vcf"), emit: consensus_vcf_ch, optional: true

    script:
    """
        CleanVCF.R ${freebayes_vcf} ${params.Consensus_MinFreq} ${params.Consensus_MinDepth}

        if [ -f "${meta.id}_clean_consensus.vcf" ]; then
            cat basic_header.vcf ${meta.id}_clean_consensus.vcf > ${meta.id}_consensus.vcf
        fi
    """
}

process SnpEff {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/snpeff:5.2--hdfd78af_1' :
        'biocontainers/snpeff:5.2--hdfd78af_1'}"
    tag { "$meta.id" }
    label 'process_single'
    publishDir "${params.outdir}/${meta.id}", mode: 'copy'
    publishDir "${params.outdir}/${meta.id}/QC/Raw", pattern: "${meta.id}_snpEff.csv", mode: 'copy'

    input:
    tuple val(meta), file(vcf), file(snpEff_cfg), path(snpeff_gtf), path(snpeff_seqbin), path(snpeff_predbin), val(snpeff_name)

    output:
    tuple val(meta), file("${meta.id}_variants_annot.vcf"), file("${meta.id}_variants_missense.vcf"), file("${meta.id}_variants_stops.vcf"), file("${meta.id}_variants_updown_mod.vcf"), file("${meta.id}_variants_annot.html"), emit: snpeff_files_ch, optional: true
    tuple val(meta), file("${meta.id}_snpEff.csv"), file("${meta.id}_variants_annot.vcf"), emit: snpeff_qc_ch, optional: true

    script:
    """
        mkdir ${snpeff_name}
        cp ${snpeff_gtf} ./${snpeff_name}/genes.gtf
        cp ${snpeff_seqbin} ./${snpeff_name}/sequence.bin
        cp ${snpeff_predbin} ./${snpeff_name}/snpEffectPredictor.bin

        numLines=\$((\$(wc -l ${vcf} | cut -d ' ' -f 1)-5))
        echo \$numLines
        if [ \$numLines -gt 0 ]; then
            snpEff eff -ud 100 -dataDir . -config ${snpEff_cfg} -csvStats ${meta.id}_snpEff.csv -s ${meta.id}_variants_annot.html ${params.SnpEff_Name} ${vcf} > ${meta.id}_variants_annot.vcf
            grep -E "(#|missense)" ${meta.id}_variants_annot.vcf > ${meta.id}_variants_missense.vcf
            grep -E "(#|stop)" ${meta.id}_variants_annot.vcf > ${meta.id}_variants_stops.vcf
            grep -E "(#|MODIFIER)" ${meta.id}_variants_annot.vcf > ${meta.id}_variants_updown_mod.vcf
            

        else
            echo "No variants found."
        fi

    """
}

process FilterVCF {
    tag { "$meta.id" }
    label 'process_single'
    publishDir "${params.outdir}/${meta.id}", mode: 'copy'

    input:
    tuple val(meta), file(vcf), file(mis_vcf), file(stop_vcf), file(updown_vcf), file(html), file(filterFile)

    output:
    tuple val(meta), file("${meta.id}_variants_annot_filtered.tsv"), emit: snpeff_graph_ch, optional: true

    script:
    """
        awk -v f=${params.SNP_MinFreq} -v d=${params.SNP_MinDepth} -f filter_vcf_lofreq_tsv.awk ${vcf} > ${meta.id}_variants_annot_filtered.tsv
    """
}

process Consensus {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bcftools:1.21--h8b25389_0' :
        'biocontainers/bcftools:1.21--h8b25389_0'}"
    tag { "$meta.id" }
    label 'process_single'
    publishDir "${params.outdir}/${meta.id}", mode: 'copy'

    input:
    tuple val(meta), file(variants), file(depths), file(reference)

    output:
    tuple val(meta), file("${meta.id}_consensus.fasta")

    script:
    minDepth = params.Consensus_MinDepth < params.SNP_MinDepth ? params.SNP_MinDepth : params.Consensus_MinDepth
    """
        awk '\$3<${minDepth} {print}' ${depths} | cut -f1,2 > mask.tsv
        sort -k1,1 -k2,2n mask.tsv > mask_sorted.tsv
        bgzip ${variants}
        tabix ${variants}.gz
        cat ${reference} | sed "/^\$/d" | bcftools consensus -p ${meta.id}_ -I -H A -m mask_sorted.tsv ${variants}.gz > ${meta.id}_consensus.fasta
    """
}

process Variant_Plot {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-ae2aedaf90918321f3e23bf48366c58c84aa4aa1:be6189ed69d26e8c2c00eaf8e8c9624f6b1c683f-0' :
        'biocontainers/mulled-v2-ae2aedaf90918321f3e23bf48366c58c84aa4aa1:be6189ed69d26e8c2c00eaf8e8c9624f6b1c683f-0'}"
    tag { "$meta.id" }
    label 'process_single'
    publishDir "${params.outdir}/${meta.id}", mode: 'copy'

    input:
    tuple val(meta), file(depths), file(variants_annot), file(geneName)

    output:
    tuple val(meta), file("${meta.id}_variants.pdf"), optional: true

    script:
    if ("${params.GenePos}" == "") {
        """
            PlotSNP.r ${depths} ${variants_annot} ${meta.id}
        """
    }
    else {
        """
            PlotSNP.r ${depths} ${variants_annot} ${meta.id} ${geneName}
        """
    }
}
