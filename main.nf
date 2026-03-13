nextflow.enable.dsl = 2

include { Alignment  } from './workflows/alignment.nf'

include { PreFlight  } from './workflows/preflight.nf'

include { PreProcess } from './workflows/preprocess.nf'

include { CleanUp    } from './workflows/cleanup.nf'

include { Results    } from './workflows/results.nf'

include {
    BAM_QC ;
    DepthGraph ;
    Combine_QC
} from './modules/qc.nf'

include { validateParameters; paramsHelp; paramsSummaryLog; paramsSummaryMap } from 'plugin/nf-validation'

import org.slf4j.LoggerFactory;

workflow {

    //Shamelessly stolen from phac-nml/mikrokondo
    def logger2 = LoggerFactory.getLogger(nextflow.script.ScriptBinding)
    // This is working but if things get messy a better solution would be to look for a way to detach the console appender
    logger2.setLevel(ch.qos.logback.classic.Level.ERROR)
    validateParameters()
    logger2.setLevel(ch.qos.logback.classic.Level.DEBUG)
    log.info paramsSummaryLog(workflow)

    setFolder = {
        def sample = it[0].id
        def newPath = "${params.outdir}/${sample}/QC/Raw"

        return [it[0], it[1], it[2], newPath]
    }
    
    reference_ch = Channel.fromPath(params.Target_Reference, type: 'file', checkIfExists: true)
    PreFlight()
    PreProcess()
    Alignment(PreProcess.out.trimmed_reads, PreFlight.out.Target_Reference, PreFlight.out.Host, reference_ch)
    BAM_QC(Alignment.out.aligned_reads)
    CleanUp(Alignment.out.aligned_reads, PreFlight.out.Primers)
    Results(CleanUp.out.final_align, reference_ch, PreFlight.out.SnpEff_config, CleanUp.out.depths)
    DepthGraph(CleanUp.out.depths)
    Results.out.snpEff_report
        | map(setFolder)
        | Combine_QC
}
