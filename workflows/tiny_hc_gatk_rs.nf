nextflow.enable.dsl = 2

// Optional Alpha path: Rust gatk-rs HaplotypeCaller under Ferrum WES→TES.
// Default demo remains workflows/tiny_hc.nf (Broad GATK 4.4). Soft-fail if image missing.
// Image: set params.gatk_rs_image from FERRUM_GA4GH_GATK_RS_IMAGE (pinned). No default :latest.
// CompressIndex uses htslib biocontainer for .vcf.gz + .tbi expected by hap.py.

params.input_bam = ""
params.input_bam_index = ""
params.ref_fasta = ""
params.ref_fasta_index = ""
params.truth_vcf = ""
params.truth_vcf_index = ""
params.interval = ""
params.gatk_rs_image = ""

process HaplotypeCallerRs {
    container "${params.gatk_rs_image}"
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
        path 'output.vcf'

    script:
        """
        set -euo pipefail
        ln -s ${ref_fasta} ref_local.fa
        ln -s ${ref_fasta_index} ref_local.fa.fai
        ln -s ${input_bam} input_local.bam
        ln -s ${input_bam_index} input_local.bam.bai
        ln -s ${truth_vcf} truth.vcf.gz
        ln -s ${truth_vcf_index} truth.vcf.gz.tbi
        # gatk-rs Alpha: no CreateSequenceDictionary. Caller is blind to truth VCF.
        gatk-rs HaplotypeCaller \\
            -R ref_local.fa \\
            -I input_local.bam \\
            -O output.vcf \\
            -L ${interval} \\
            --standard-min-confidence-threshold-for-calling 10.0
        """
}

process CompressIndex {
    container 'quay.io/biocontainers/htslib:1.19--h5e77b09_0'
    cpus 1
    memory '1 GB'

    input:
        path 'output.vcf'

    output:
        path 'output.vcf.gz'
        path 'output.vcf.gz.tbi'

    script:
        """
        set -euo pipefail
        bgzip -c output.vcf > output.vcf.gz
        tabix -p vcf output.vcf.gz
        """
}

workflow {
    called = HaplotypeCallerRs(
        file(params.input_bam),
        file(params.input_bam_index),
        file(params.ref_fasta),
        file(params.ref_fasta_index),
        file(params.truth_vcf),
        file(params.truth_vcf_index),
        params.interval
    )
    CompressIndex(called)
}
