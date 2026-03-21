#!/usr/bin/env bash
# Small GIAB + Platinum subset (GRCh37) via containerised samtools/bcftools.
# URLs / coordinates mirror demo/config.yaml — keep them in sync.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DATA="${DATA_DIR:-$ROOT/data}"
mkdir -p "$DATA"

SAMTOOLS_IMAGE="${SAMTOOLS_IMAGE:-quay.io/biocontainers/samtools:1.20--h50ea8bc_0}"
BCFTOOLS_IMAGE="${BCFTOOLS_IMAGE:-quay.io/biocontainers/bcftools:1.20--h8b25389_0}"

REGION_BAM="22:16050000-16080000"
REGION_BCF="22:16050000-16080000"
PLATINUM_BAM="https://storage.googleapis.com/genomics-public-data/platinum-genomes/bam/NA12878_S1.bam"
REF_GZ="http://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/human_g1k_v37.fasta.gz"
TRUTH_VCF="https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/NA12878_HG001/NISTv3.3.2/GRCh37/HG001_GIAB_highconf_IllFB-IllGATKHC-Ion-10X-SOLID_CHROM1-22_v3.3.2_highconf.vcf.gz"
TRUTH_TBI="https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/NA12878_HG001/NISTv3.3.2/GRCh37/HG001_GIAB_highconf_IllFB-IllGATKHC-Ion-10X-SOLID_CHROM1-22_v3.3.2_highconf.vcf.gz.tbi"
GIAB_BED="https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/NA12878_HG001/NISTv3.3.2/GRCh37/HG001_GIAB_highconf_IllFB-IllGATKHC-Ion-10X-SOLID_CHROM1-22_v3.3.2_highconf_noinconsistent.bed"

echo "[fetch] Writing subset under $DATA"

if [[ ! -s "$DATA/na12878_slice.bam.bai" ]]; then
  echo "[fetch] Subsetting Platinum NA12878 BAM..."
  docker run --rm --user "$(id -u):$(id -g)" -v "$DATA:/work" "$SAMTOOLS_IMAGE" \
    sh -ceu "samtools view -b -o /work/na12878_slice.bam '${PLATINUM_BAM}' '${REGION_BAM}' && samtools index /work/na12878_slice.bam"
fi

if [[ ! -s "$DATA/ref_slice.fa.fai" ]]; then
  echo "[fetch] Reference FASTA slice (b37)..."
  docker run --rm --user "$(id -u):$(id -g)" -v "$DATA:/work" "$SAMTOOLS_IMAGE" \
    sh -ceu "curl -fsSL -o /work/g1k_v37.fa.gz '${REF_GZ}' && gzip -dc /work/g1k_v37.fa.gz > /work/g1k_v37.fa && samtools faidx /work/g1k_v37.fa && samtools faidx /work/g1k_v37.fa '${REGION_BAM}' | sed '1s/^>.*/>22/' > /work/ref_slice.fa && samtools faidx /work/ref_slice.fa"
fi

if [[ ! -s "$DATA/truth_slice.vcf.gz.tbi" ]]; then
  echo "[fetch] GIAB truth VCF slice (remote tabix; no full VCF download)..."
  docker run --rm --user "$(id -u):$(id -g)" -v "$DATA:/work" "$BCFTOOLS_IMAGE" \
    sh -ceu "(bcftools view -h '${TRUTH_VCF}' >/dev/null) && (bcftools view -r '${REGION_BCF}' -Oz -o /work/truth_slice.vcf.gz '${TRUTH_VCF}' || bcftools view -r 'chr${REGION_BCF}' -Oz -o /work/truth_slice.vcf.gz '${TRUTH_VCF}') && tabix -f /work/truth_slice.vcf.gz"
fi

if [[ ! -s "$DATA/bench_slice.bed" ]]; then
  echo "[fetch] Confident regions BED slice..."
  curl -fsSL -o "$DATA/giab_full.bed" "$GIAB_BED"
  awk '$1=="22" || $1=="chr22"' "$DATA/giab_full.bed" | awk -v s=16050000 -v e=16080000 '$2<e && $3>s' > "$DATA/bench_slice.bed"
fi

echo "[fetch] Complete."
