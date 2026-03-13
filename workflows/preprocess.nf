include {
    CombineMinIONFastq ;
    TrimMinION ;
    TrimIllumina ;
} from '../modules/preprocess.nf'

include { fromSamplesheet } from 'plugin/nf-validation'

workflow PreProcess {
    main:
    if (params.Seq_Tech == "MinION") {
        trimmed_reads_ch = Channel.empty()

        if (params.MinION_split) {
            RawReadFolders_ch = Channel.empty()

            Channel.fromSamplesheet("input")
                | map { 
                        meta -> format_reads(meta)
                    }
                | view()
                | set { RawReadFolders_ch }
            CombineMinIONFastq(RawReadFolders_ch)
                | TrimMinION
                | set { trimmed_reads_ch }
        }
        else {
            MinION_reads_ch = Channel.empty()

            Channel.fromSamplesheet("input", parameters_schema: 'nextflow_schema.json')
                | map { 
                        meta -> format_reads(meta)
                    }
                | view()
                | set { MinION_reads_ch }
            TrimMinION(MinION_reads_ch)
                | set { trimmed_reads_ch }
        }
    }
    else {
        raw_reads_ch = Channel.empty()

        Channel.fromSamplesheet("input")
                | map { 
                        meta -> format_reads(meta)
                    }
                | view()
                | set { raw_reads_ch }

        trimmed_reads_ch = TrimIllumina(raw_reads_ch)
    }

    emit:
    trimmed_reads = trimmed_reads_ch.trim_reads_ch
    trim_reports  = trimmed_reads_ch.trim_report_ch
}

def format_reads(ArrayList sheet_data){
    def meta = [:]
    def error_occured = false
    if(sheet_data[0].id){
        meta.id = sheet_data[0].id
        meta.sample = sheet_data[0].id
        meta.external_id = sheet_data[0].external_id
    }else{
        meta.id = sheet_data[0].external_id
        meta.sample = sheet_data[0].external_id
        meta.external_id = sheet_data[0].external_id
    }

    def ret_val = null

    // A map could probably clean this up
    if(sheet_data[0].fastq_1 && sheet_data[0].fastq_2){
        ret_val = tuple(meta, [file(sheet_data[0].fastq_1), file(sheet_data[0].fastq_2)])

    }else if(sheet_data[0].long_reads){
        ret_val = tuple(meta, file(sheet_data[0].long_reads))

    }else{
        log.warning "Cannot determine what type of data is presented for $meta.id, more that one read type is specified"
        error_occured = true
    }

    if(error_occured){
        exit 1
    }

    return ret_val
}