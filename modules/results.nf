process SnpCall {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/freebayes:1.3.8--h6a68c12_2' :
        'biocontainers/freebayes:1.3.8--h6a68c12_2'}"
    tag { Name }
    label 'process_single_long'
    publishDir "${params.outdir}/${Name}", pattern: "${Name}_variants.vcf", mode: 'copy'

    input:
    tuple val(Name), file(bam), file(bai), file(reference)

    output:
    tuple val(Name), file("${Name}_variants.vcf"), optional: true

    script:
    if (params.Seq_Tech == "Illumina") {
        """
            freebayes -b ${bam} -f ${reference} --pooled-continuous -v ${Name}_variants.vcf -p 1 -B 3 -E -1 -F 0.005 --min-coverage 1
            
            num_lines=\$( wc -l ${Name}_variants.vcf | cut -f1 -d ' ' )
            if [ \$num_lines -lt 65 ]; then
                rm ${Name}_variants.vcf
            fi
        """
    }
    else {
        """
            freebayes -b ${bam} -f ${reference} --pooled-continuous -v ${Name}_variants.vcf -m ${params.Read_MinMAPQ} -p 1 -B 3 -E -1 --haplotype-length -1 -F 0.03 --min-coverage 1
            
            num_lines=\$( wc -l ${Name}_variants.vcf | cut -f1 -d ' ' )
            if [ \$num_lines -lt 65 ]; then
                rm ${Name}_variants.vcf
            fi
        """
    }
}

process MakeNiceVCF {
    container 'docker://rocker/tidyverse:4.5.0'
    tag { Name }
    label 'process_single'
    publishDir "${params.outdir}/${Name}", pattern: "${Name}_clean.vcf", mode: 'copy'
    publishDir "${params.outdir}/${Name}/QC", pattern: "${Name}_consensus.vcf", mode: 'copy'

    input:
    tuple val(Name), file(freebayes_vcf), file(basic_header)

    output:
    tuple val(Name), file("${Name}_clean.vcf"), emit: nice_vcf_ch
    tuple val(Name), file("${Name}_consensus.vcf"), emit: consensus_vcf_ch, optional: true

    script:
    """
        CleanVCF.R ${freebayes_vcf} ${params.Consensus_MinFreq} ${params.Consensus_MinDepth}

        if [ -f "${Name}_clean_consensus.vcf" ]; then
            cat basic_header.vcf ${Name}_clean_consensus.vcf > ${Name}_consensus.vcf
        fi
    """
}

process SnpEff {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/snpeff:5.2--hdfd78af_1' :
        'biocontainers/snpeff:5.2--hdfd78af_1'}"
    tag { Name }
    label 'process_single'
    publishDir "${params.outdir}/${Name}", mode: 'copy'
    publishDir "${params.outdir}/${Name}/QC/Raw", pattern: "${Name}_snpEff.csv", mode: 'copy'

    input:
    tuple val(Name), file(vcf), file(snpEff_cfg), path(snpEff_folder)

    output:
    tuple val(Name), file("${Name}_variants_annot.vcf"), file("${Name}_variants_missense.vcf"), file("${Name}_variants_stops.vcf"), file("${Name}_variants_updown_mod.vcf"), file("${Name}_variants_annot.html"), emit: snpeff_files_ch, optional: true
    tuple val(Name), file("${Name}_snpEff.csv"), file("${Name}_variants_annot.vcf"), emit: snpeff_qc_ch, optional: true

    script:
    """
        numLines=\$((\$(wc -l ${vcf} | cut -d ' ' -f 1)-5))
        echo \$numLines
        if [ \$numLines -gt 0 ]; then
            snpEff eff -ud 100 -dataDir . -config ${snpEff_cfg} -csvStats ${Name}_snpEff.csv -s ${Name}_variants_annot.html ${params.SnpEff_Name} ${vcf} > ${Name}_variants_annot.vcf
            grep -E "(#|missense)" ${Name}_variants_annot.vcf > ${Name}_variants_missense.vcf
            grep -E "(#|stop)" ${Name}_variants_annot.vcf > ${Name}_variants_stops.vcf
            grep -E "(#|MODIFIER)" ${Name}_variants_annot.vcf > ${Name}_variants_updown_mod.vcf
            

        else
            echo "No variants found."
        fi

    """
}

process FilterVCF {
    tag { Name }
    label 'process_single'
    publishDir "${params.outdir}/${Name}", mode: 'copy'

    input:
    tuple val(Name), file(vcf), file(mis_vcf), file(stop_vcf), file(updown_vcf), file(html), file(filterFile)

    output:
    tuple val(Name), file("${Name}_variants_annot_filtered.tsv"), emit: snpeff_graph_ch, optional: true

    script:
    """
        awk -v f=${params.SNP_MinFreq} -v d=${params.SNP_MinDepth} -f filter_vcf_lofreq_tsv.awk ${vcf} > ${Name}_variants_annot_filtered.tsv
    """
}

process Consensus {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bcftools:1.21--h8b25389_0' :
        'biocontainers/bcftools:1.21--h8b25389_0'}"
    tag { Name }
    label 'process_single'
    publishDir "${params.outdir}/${Name}", mode: 'copy'

    input:
    tuple val(Name), file(variants), file(depths), file(reference)

    output:
    tuple val(Name), file("${Name}_consensus.fasta")

    script:
    minDepth = params.Consensus_MinDepth < params.SNP_MinDepth ? params.SNP_MinDepth : params.Consensus_MinDepth
    """
        awk '\$3<${minDepth} {print}' ${depths} | cut -f1,2 > mask.tsv
        sort -k1,1 -k2,2n mask.tsv > mask_sorted.tsv
        bgzip ${variants}
        tabix ${variants}.gz
        cat ${reference} | sed "/^\$/d" | bcftools consensus -p ${Name}_ -I -H A -m mask_sorted.tsv ${variants}.gz > ${Name}_consensus.fasta
    """
}

process Variant_Plot {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-ae2aedaf90918321f3e23bf48366c58c84aa4aa1:be6189ed69d26e8c2c00eaf8e8c9624f6b1c683f-0' :
        'biocontainers/mulled-v2-ae2aedaf90918321f3e23bf48366c58c84aa4aa1:be6189ed69d26e8c2c00eaf8e8c9624f6b1c683f-0'}"
    tag { Name }
    label 'process_single'
    publishDir "${params.outdir}/${Name}", mode: 'copy'

    input:
    tuple val(Name), file(depths), file(variants_annot), file(geneName)

    output:
    tuple val(Name), file("${Name}_variants.pdf"), optional: true

    script:
    if ("${params.GenePos}" == "") {
        """
            PlotSNP.r ${depths} ${variants_annot} ${Name}
        """
    }
    else {
        """
            PlotSNP.r ${depths} ${variants_annot} ${Name} ${geneName}
        """
    }
}
