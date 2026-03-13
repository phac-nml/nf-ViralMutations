include {
    SnpCall ;
    SnpEff ;
    Consensus ;
    Variant_Plot ;
    MakeNiceVCF ;
    FilterVCF
} from '../modules/results.nf'

workflow Results {
    take:
    final_alignment_ch
    reference_ch      
    snpeff_config_ch  
    depths_ch         

    main:
    basic_vcf_header = channel.fromPath("${projectDir}/data/basic_header.vcf", type: 'file')
    SnpCall(final_alignment_ch.combine(reference_ch))
        | combine(basic_vcf_header)
        | MakeNiceVCF
    if (params.SnpEff_Name) {
        filtervcf_ch = channel.fromPath("${projectDir}/bin/filter_vcf_lofreq_tsv.awk", type: 'file')
        SnpEff(MakeNiceVCF.out.nice_vcf_ch.combine(snpeff_config_ch))
        FilterVCF(SnpEff.out.snpeff_files_ch.combine(filtervcf_ch))
        if (params.GenePos) {
            geneLocs_ch = channel.fromPath(params.GenePos, type: 'file')
            depths_ch.join(FilterVCF.out.snpeff_graph_ch)
                | combine(geneLocs_ch)
                | Variant_Plot
        }
        else {
            depths_ch.join(FilterVCF.out.snpeff_graph_ch)
                | combine(channel.from(""))
                | Variant_Plot
        }
    }

    Consensus(MakeNiceVCF.out.consensus_vcf_ch.join(depths_ch).combine(reference_ch))

    emit:
    snpEff_report = SnpEff.out.snpeff_qc_ch
    snp_calls     = MakeNiceVCF.out.nice_vcf_ch
}
