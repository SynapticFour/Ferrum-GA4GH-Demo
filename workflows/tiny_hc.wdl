version 1.0

# Minimal single-sample HaplotypeCaller WDL executed by Cromwell (TES) + GATK Docker.
# Dockstore TRS still caches the broader gatk4-germline-snps-indels bundle separately (see scripts).

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
    gatk --java-options "-Xmx3g" HaplotypeCaller \
      -R ref_local.fa \
      -I input_local.bam \
      -O output.vcf.gz \
      -L ~{interval} \
      --alleles truth.vcf.gz \
      --standard-min-confidence-threshold-for-calling 10.0 \
      --minimum-mapping-quality 0
  >>>

  output {
    File vcf = "output.vcf.gz"
    File vcf_idx = "output.vcf.gz.tbi"
  }

  runtime {
    docker: "broadinstitute/gatk:4.4.0.0"
    memory: "4 GB"
    cpu: 2
  }
}
