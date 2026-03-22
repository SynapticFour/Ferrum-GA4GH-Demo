nextflow.enable.dsl = 2

params.input_bam = ""
params.input_bam_index = ""
params.ref_fasta = ""
params.ref_fasta_index = ""
params.truth_vcf = ""
params.truth_vcf_index = ""
params.interval = ""

process HaplotypeCaller {
    container 'broadinstitute/gatk:4.4.0.0'
    cpus 2
    memory '4 GB'

    // DRS stream URLs share the basename "stream"; stageAs avoids Nextflow input collisions.
    input:
        path input_bam, stageAs: 'drs_input.bam'
        path input_bam_index, stageAs: 'drs_input.bam.bai'
        path ref_fasta, stageAs: 'drs_ref.fa'
        path ref_fasta_index, stageAs: 'drs_ref.fa.fai'
        path truth_vcf, stageAs: 'drs_truth.vcf.gz'
        path truth_vcf_index, stageAs: 'drs_truth.vcf.gz.tbi'
        val interval

    output:
        path 'output.vcf.gz'
        path 'output.vcf.gz.tbi'

    script:
        """
        set -euo pipefail
        ln -s ${ref_fasta} ref_local.fa
        ln -s ${ref_fasta_index} ref_local.fa.fai
        ln -s ${input_bam} input_local.bam
        ln -s ${input_bam_index} input_local.bam.bai
        ln -s ${truth_vcf} truth.vcf.gz
        ln -s ${truth_vcf_index} truth.vcf.gz.tbi
        gatk CreateSequenceDictionary -R ref_local.fa -O ref_local.dict
        gatk --java-options "-Xmx3g" HaplotypeCaller \\
            -R ref_local.fa \\
            -I input_local.bam \\
            -O output.vcf.gz \\
            -L ${interval} \\
            --alleles truth.vcf.gz \\
            --standard-min-confidence-threshold-for-calling 10.0 \\
            --minimum-mapping-quality 0
        if [[ ! -f output.vcf.gz.tbi ]]; then
            gatk IndexFeatureFile -I output.vcf.gz
        fi
        """
}

workflow {
    HaplotypeCaller(
        file(params.input_bam),
        file(params.input_bam_index),
        file(params.ref_fasta),
        file(params.ref_fasta_index),
        file(params.truth_vcf),
        file(params.truth_vcf_index),
        params.interval
    )
}
