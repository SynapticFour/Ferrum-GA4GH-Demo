version 1.0

# Minimal single-sample HaplotypeCaller WDL executed by Cromwell (TES) + GATK Docker.
# Pipeline smoke — not a GIAB publication benchmark. Caller does not see the truth VCF.
# Dockstore TRS fetch (scripts/fetch_dockstore_trs.sh) is descriptor-only; this WDL is what WES runs.

workflow TinyGermlineHC {
  input {
    File input_bam
    File input_bam_index
    File ref_fasta
    File ref_fasta_index
    File truth_vcf
    File truth_vcf_index
    String interval
  }

  call HaplotypeCaller {
    input:
      bam = input_bam,
      bai = input_bam_index,
      ref = ref_fasta,
      fai = ref_fasta_index,
      truth_vcf = truth_vcf,
      truth_vcf_index = truth_vcf_index,
      interval = interval
  }

  output {
    File output_vcf = HaplotypeCaller.vcf
    File output_vcf_index = HaplotypeCaller.vcf_idx
  }
}

task HaplotypeCaller {
  input {
    File bam
    File bai
    File ref
    File fai
    File truth_vcf
    File truth_vcf_index
    String interval
  }

  # Cromwell HTTP localization uses extensionless hash filenames; GATK infers format from suffix.
  command <<<
    set -euo pipefail
    ln -s ~{ref} ref_local.fa
    ln -s ~{fai} ref_local.fa.fai
    ln -s ~{bam} input_local.bam
    ln -s ~{bai} input_local.bam.bai
    ln -s ~{truth_vcf} truth.vcf.gz
    ln -s ~{truth_vcf_index} truth.vcf.gz.tbi
    gatk CreateSequenceDictionary -R ref_local.fa -O ref_local.dict
    # Caller is blind to the truth VCF. Truth is localized via DRS only to prove
    # VCF ingest/stream; hap.py on the host is the comparison. Do not pass --alleles.
    gatk --java-options "-Xmx3g" HaplotypeCaller \
      -R ref_local.fa \
      -I input_local.bam \
      -O output.vcf.gz \
      -L ~{interval} \
      --standard-min-confidence-threshold-for-calling 10.0
  >>>

  output {
    File vcf = "output.vcf.gz"
    File vcf_idx = "output.vcf.gz.tbi"
  }

  runtime {
    docker: "broadinstitute/gatk:4.4.0.0@sha256:044112d3d70603732d4a654ecaee33919cf9d45332d47268f5f1697b6ed558ed"
    memory: "4 GB"
    cpu: 2
  }
}
