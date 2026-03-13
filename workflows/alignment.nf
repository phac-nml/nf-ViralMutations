include {
    AlignSelect ;
    UnalignSelect ;
    MinIONUnalignSelect ;
    UnalignExtract ;
    MinIONUnalignExtract ;
    Sort_Index as SI_BWA_Align ;
    Sort_Index as SI_MinION_Align ;
    MinIONAlign
} from '../modules/alignment.nf'

workflow Alignment {
    take:
    trimmed_reads_ch
    reference_ch    
    host_ch     
    ref_fasta_ch    

    main:
    aligned_reads_ch = channel.empty()
    if (params.Host_Reference) {
        if (params.Seq_Tech == "Illumina") {
            host_fasta_ch = Channel.fromPath("${params.Host_Reference}", type: 'file')
            
            UnalignSelect(trimmed_reads_ch.combine(host_ch).combine(host_fasta_ch))
                | UnalignExtract
                | combine(reference_ch)
                | combine(ref_fasta_ch)
                | AlignSelect
                | SI_BWA_Align
                | set { aligned_reads_ch }
        }
        else {
            MinIONUnalignSelect(trimmed_reads_ch.combine(host_ch))
                | MinIONUnalignExtract
                | combine(ref_fasta_ch)
                | MinIONAlign
                | SI_MinION_Align
                | set { aligned_reads_ch }
        }
    }
    else {
        if (params.Seq_Tech == "Illumina") {
            trimmed_reads_ch.combine(reference_ch)
                | combine(ref_fasta_ch)
                | AlignSelect
                | SI_BWA_Align
                | set { aligned_reads_ch }
        }
        else {
            MinIONAlign(trimmed_reads_ch.combine(ref_fasta_ch))
                | SI_MinION_Align
                | set { aligned_reads_ch }
        }
    }

    emit:
    aligned_reads = aligned_reads_ch
}
