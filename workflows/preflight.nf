include {
    CreateIndex;
    GetIndex;
    CreateHostIndex;
    CreateHostIndexMinION;
    SetSnpEff;
    SwitchBedpe;
} from '../modules/preflight.nf'

workflow PreFlight{
    main:
        snpeff_entry_ch = channel.fromPath("${params.SnpEff_gtf}")
        snpeff_config_ch = channel.fromPath("${projectDir}/data/snpEff.config")
        SetSnpEff(snpeff_entry_ch, params.SnpEff_Name, snpeff_config_ch)

        ref_index_ch = channel.empty()
        
        if ( params.Seq_Tech == "Illumina") {
            ref_index_ch = CreateIndex(params.Target_Reference)
        }
        if( params.Host_Indexed){
            GetIndex(params.Host_IndexFolder, params.Host_Reference)
        } else {
            if(params.Host_Reference){
                if ( params.Seq_Tech == "Illumina") {
                    host_index_ch = CreateHostIndex(params.Host_Reference, params.Host_IndexOutFolder)
                } else {
                    host_index_ch = CreateHostIndexMinION(params.Host_Reference, params.Host_IndexOutFolder)
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
        

    emit:
        SnpEff_config = SetSnpEff.out.ifEmpty("EMPTY")
        Target_Reference = ref_index_ch
        Host_bwa = params.Host_Indexed? GetIndex.out.bwa_index_ch : host_index_ch
        Host_minimap = params.Host_Indexed? GetIndex.out.minimap_index_ch : host_index_ch
        Primers = primer_locs_ch.ifEmpty("EMPTY")
}