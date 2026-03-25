include {
    CreateIndex;
    CreateHostIndex;
    CreateHostIndexMinION;
    SetSnpEff;
    SwitchBedpe;
    GetNextCladeData;
} from '../modules/preflight.nf'

workflow PreFlight{
    main:
        snpeff_entry_ch = channel.fromPath("${params.SnpEff_gtf}")
        snpeff_config_ch = channel.fromPath("${projectDir}/data/snpEff.config")
        SetSnpEff(snpeff_entry_ch, params.SnpEff_Name, snpeff_config_ch)

        ref_index_ch = channel.empty()
        nextclade_ch = channel.empty()
        
        if ( params.Seq_Tech == "Illumina") {
            ref_index_ch = CreateIndex(params.Target_Reference)
        }
        if( params.Host_Indexed){
            if ( params.Seq_Tech == "Illumina"){
                host_index_ch = Channel.value(tuple("${params.Host_Reference}.amb",
                                                    "${params.Host_Reference}.ann",
                                                    "${params.Host_Reference}.bwt",
                                                    "${params.Host_Reference}.pac",
                                                    "${params.Host_Reference}.sa"))
            } else {
                host_index_ch = Channel.value("${params.Host_Reference}.mmi")
            }
        } else {
            if(params.Host_Reference){
                if ( params.Seq_Tech == "Illumina") {
                    host_index_ch = CreateHostIndex(params.Host_Reference)
                } else {
                    host_index_ch = CreateHostIndexMinION(params.Host_Reference)
                }
            } else {
                host_index_ch = channel.empty()
            }
        }

        if (params.Primer_Locs){
            if( params.Primer_Format == "ARTIC"){
                primer_locs_ch = SwitchBedpe(params.Primer_Locs)
            } else {
                primer_locs_ch = Channel.fromPath("${params.Primer_Locs}", checkIfExists: true)
            }
        } else {
            primer_locs_ch = channel.empty()
        }

        if (params.NextClade_assign){
            Channel.fromPath("${params.NextClade_assign}", checkIfExists: true)
            | splitCsv(header: true)
            | GetNextCladeData
            | set { nextclade_ch }
        }
        

    emit:
        SnpEff_config = SetSnpEff.out.ifEmpty("EMPTY")
        Target_Reference = ref_index_ch
        Host = host_index_ch
        Primers = primer_locs_ch.ifEmpty("EMPTY")
        NextClade = nextclade_ch
}