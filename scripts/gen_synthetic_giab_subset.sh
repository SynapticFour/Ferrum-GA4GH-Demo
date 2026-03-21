#!/usr/bin/env bash
# Tiny synthetic chr22-style slice: reference, BAM, truth VCF, confident BED (host Python + container samtools/bcftools).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DATA="${DATA_DIR:-$ROOT/data}"
mkdir -p "$DATA"
SAMTOOLS_IMAGE="${SAMTOOLS_IMAGE:-quay.io/biocontainers/samtools:1.20--h50ea8bc_0}"
BCFTOOLS_IMAGE="${BCFTOOLS_IMAGE:-quay.io/biocontainers/bcftools:1.20--h8b25389_0}"
PLATFORM="${DOCKER_PLATFORM:---platform linux/amd64}"

python3 - "$DATA" <<'PY'
import os, random, subprocess, sys
from pathlib import Path

data = Path(sys.argv[1])
seq = (
    "A" * 500 + "C" * 500 + "G" * 500 + "T" * 500 + "N" * 1000 + "A" * 1000
)
assert len(seq) == 4000
snp_pos = 2000
ref_base = seq[snp_pos - 1]
alt_base = "G" if ref_base != "G" else "C"

fa = data / "ref_slice.fa"
fa.write_text(">22\n" + "\n".join(seq[i : i + 60] for i in range(0, len(seq), 60)) + "\n")

sam_lines = [
    "@HD\tVN:1.6\tSO:coordinate",
    "@RG\tID:rg1\tSM:NA12878",
    f"@SQ\tSN:22\tLN:{len(seq)}",
]
random.seed(1)
read_len = 80
for i in range(120):
    start = snp_pos - read_len // 2 + (i % 7) - 3
    start = max(1, min(start, len(seq) - read_len + 1))
    read_seq = list(seq[start - 1 : start - 1 + read_len])
    idx = snp_pos - start
    if 0 <= idx < read_len:
        read_seq[idx] = alt_base
    read_seq = "".join(read_seq)
    qual = "I" * read_len
    sam_lines.append(
        f"r{i}\t0\t22\t{start}\t60\t{read_len}M\t*\t0\t0\t{read_seq}\t{qual}\tRG:Z:rg1"
    )
(data / "reads.sam").write_text("\n".join(sam_lines) + "\n")

vcf = f"""##fileformat=VCFv4.2
##contig=<ID=22,length={len(seq)}>
##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">
#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\tSAMPLE
22\t{snp_pos}\t.\t{ref_base}\t{alt_base}\t60\t.\t.\tGT\t1/1
"""
(data / "truth_raw.vcf").write_text(vcf)

reg_start, reg_end = snp_pos - 300, snp_pos + 300
(data / "bench_slice.bed").write_text(f"22\t{reg_start-1}\t{reg_end}\n")
(data / "synthetic_manifest.txt").write_text(
    f"synthetic=1 chrom=22 snp_pos={snp_pos} ref={ref_base} alt={alt_base}\n"
)
PY

docker run --rm $PLATFORM --user "$(id -u):$(id -g)" -v "$DATA:/work" "$SAMTOOLS_IMAGE" \
  sh -ceu "samtools faidx /work/ref_slice.fa && samtools view -b -o /work/na12878_slice.bam /work/reads.sam && samtools sort -o /work/na12878_slice.sorted.bam /work/na12878_slice.bam && mv /work/na12878_slice.sorted.bam /work/na12878_slice.bam && samtools index /work/na12878_slice.bam"

docker run --rm $PLATFORM --user "$(id -u):$(id -g)" -v "$DATA:/work" "$BCFTOOLS_IMAGE" \
  sh -ceu "bcftools view -Oz -o /work/truth_slice.vcf.gz /work/truth_raw.vcf && tabix -f /work/truth_slice.vcf.gz"

echo "[synth] wrote synthetic GIAB-style subset in $DATA"
