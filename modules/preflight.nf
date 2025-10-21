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
    publishDir "${OutFolder}", mode: 'copy'
    label 'process_high_memory'

    input:
    path reference
    path OutFolder

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
    publishDir "${OutFolder}", mode: 'copy'
    label 'process_high_memory'

    input:
    path reference
    path OutFolder

    output:
    path "${reference}.*"

    script:
    """
        minimap2 -x map-ont -d ${reference}.mmi ${reference}
    """
}

process GetIndex {
    label 'process_single'
    tag { referenceName }

    input:
    val index_dir
    val referenceName

    output:
    tuple path("${referenceName}.amb"), path("${referenceName}.ann"), path("${referenceName}.bwt"), path("${referenceName}.pac"), path("${referenceName}.sa"), optional: true, emit: bwa_index_ch
    path("${referenceName}.mmi"), optional: true, emit: minimap_index_ch

    script:
    """
        ln -s ${index_dir}/${referenceName}.* .
    """
}

process SetSnpEff {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/snpeff:5.2--hdfd78af_1' :
        'biocontainers/snpeff:5.2--hdfd78af_1'}"
    label 'process_single'
    tag { snpeff_name }

    input:
    path snpeff_dataFolder
    val snpeff_name
    file snpeff_config

    output:
    file "snpEff2.config"

    script:
    """
        snpEff_line="\n${snpeff_name}.genome:${snpeff_name}"
        cat ${snpeff_config} > snpEff2.config
        
        echo \$snpEff_line >> snpEff2.config

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
