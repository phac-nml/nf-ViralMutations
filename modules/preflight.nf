process CreateIndex {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bwa:0.7.18--he4a0461_1' :
        'biocontainers/bwa:0.7.18--he4a0461_1'}"
    label 'process_single'

    input:
    path reference

    output:
    path "${reference}.*"

    script:
    """
        bwa index ${reference}
    """
}

process CreateHostIndex {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bwa:0.7.18--he4a0461_1' :
        'biocontainers/bwa:0.7.18--he4a0461_1'}"
    publishDir "${params.outdir}", mode: 'copy', enabled: params.Host_IndexOut
    label 'process_high_memory'

    input:
    path reference

    output:
    path "${reference}.*"

    script:
    """
        bwa index -b 8000000000 ${reference}
    """
}

process CreateHostIndexMinION {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/minimap2:2.28--he4a0461_3' :
        'biocontainers/minimap2:2.28--he4a0461_3'}"
    publishDir "${params.outdir}", mode: 'copy', enabled: params.Host_IndexOut
    label 'process_high_memory'

    input:
    path reference

    output:
    path "${reference}.*"

    script:
    """
        minimap2 -x map-ont -d ${reference}.mmi ${reference}
    """
}

process SetSnpEff {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/snpeff:5.2--hdfd78af_1' :
        'biocontainers/snpeff:5.2--hdfd78af_1'}"
    label 'process_single'
    tag { snpeff_name }

    input:
    path snpeff_gtf
    val snpeff_name
    file snpeff_config

    output:
    tuple file("snpEff2.config"), path ("${snpeff_gtf}"), path ("./${snpeff_name}/sequence.bin"), path ("./${snpeff_name}/snpEffectPredictor.bin"), val("${snpeff_name}")

    script:
    """
        snpEff_line="\n${snpeff_name}.genome:${snpeff_name}"
        cat ${snpeff_config} > snpEff2.config
        
        echo \$snpEff_line >> snpEff2.config
        mkdir ${snpeff_name}
        cp ${snpeff_gtf} ./${snpeff_name}/.
        snpEff build -noCheckCds -noCheckProtein -c snpEff2.config -dataDir . ${snpeff_name}
    """
}

process SwitchBedpe {
    label 'process_single'

    input:
    path PrimerBed

    output:
    file "*_bc.bedpe"

    script:
    """
        name=\$( echo ${PrimerBed} | sed "s/.bed(pe)?//g" )
        cut -f1,2,3 ${PrimerBed} | awk -v OFS='\t' '!(NR%2){print p, \$0}{p=\$0}' > \${name}_bc.bedpe
    """
}

process GetNextCladeData{
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/nextclade:3.21.0--h9ee0642_0' :
        'biocontainers/nextclade:3.21.0--h9ee0642_0'}"
    label 'process_single'
    tag { "${Name}" }

    input:
    tuple val(Name), val(Reference), val(Dataset)

    output:
    tuple val(Name), val(Reference), path("*.zip")

    script:
    """
        nextclade dataset get --name "${Dataset}" -z ${Name}.zip
    """

}