#!/bin/bash

# 初始化随机数种子
RANDOM=42

# 创建工作目录
mkdir -p data
cd data

# 检测并安装所需软件
check_and_install() {
    local cmd=$1
    local package=$2
    if ! command -v $cmd &> /dev/null; then
        echo "$cmd 未安装，正在安装 $package..."
        brew install $package
    else
        echo "$cmd 已安装，跳过安装。"
    fi
}

# 检测并安装 bowtie2
check_and_install "bowtie2" "bowtie2"

# 检测并安装 samtools
check_and_install "samtools" "samtools"

# 检测并安装 HTSeq
check_and_install "htseq-count" "htseq"

# 定义路径变量
GENOME_DIR="genome"
READS_DIR="reads"
ALIGNMENTS_DIR="alignments"

# 创建子目录
mkdir -p $GENOME_DIR $READS_DIR $ALIGNMENTS_DIR

# 1. 生成100kb的随机DNA序列作为参考基因组
echo ">chr1" > $GENOME_DIR/genome.fa
cat /dev/urandom | LC_ALL=C tr -dc 'ATCG' | fold -w 100000 | head -n 1 >> $GENOME_DIR/genome.fa

# 格式化FASTA文件，每行60个字符
awk '/^>/ {print; next} {print $0}' $GENOME_DIR/genome.fa | fold -w 60 > $GENOME_DIR/genome_formatted.fa
mv $GENOME_DIR/genome_formatted.fa $GENOME_DIR/genome.fa

# 2. 使用函数生成GTF格式的基因注释文件（模仿细菌注释格式）
generate_gtf() {
    local genome_size=$1
    local num_genes=$2
    local gtf_file=$3

    # 清空或创建GTF文件
    > "$gtf_file"

    # 计算每个基因的区间大小
    local interval_size=$((genome_size / num_genes))

    for ((i=1; i<=num_genes; i++)); do
        # 确定当前基因的区间范围
        local interval_start=$(((i-1) * interval_size + 1))
        local interval_end=$((i * interval_size))

        # 随机生成基因的起始位置和长度
        local gene_length=$((RANDOM % 1000 + 500)) # 基因长度在500-1500bp之间
        local gene_start=$((interval_start + RANDOM % (interval_size - gene_length)))
        local gene_end=$((gene_start + gene_length - 1))

        # 确保基因范围不超过区间边界
        if ((gene_end > interval_end)); then
            gene_end=$interval_end
        fi

        # 生成基因ID和转录本ID
        local gene_id="b$(printf "%04d" $i)"
        local transcript_id="NM_001365${i}"
        local gene_name="gene_$i"

        # 随机选择正链或负链
        local strand="+"
        if (( RANDOM % 2 == 0 )); then
            strand="-"
        fi

        # 写入GTF文件（模仿细菌注释格式）
        echo -e "chr1\tRefSeq\tgene\t$gene_start\t$gene_end\t.\t$strand\t.\tgene_id \"$gene_id\"; gene_name \"$gene_name\";" >> "$gtf_file"
        echo -e "chr1\tRefSeq\ttranscript\t$gene_start\t$gene_end\t.\t$strand\t.\tgene_id \"$gene_id\"; transcript_id \"$transcript_id\";" >> "$gtf_file"
        echo -e "chr1\tRefSeq\texon\t$gene_start\t$gene_end\t.\t$strand\t.\tgene_id \"$gene_id\"; transcript_id \"$transcript_id\"; exon_number \"1\";" >> "$gtf_file"
    done
}

# 生成100个基因的注释文件
generate_gtf 100000 100 $GENOME_DIR/annotation.gtf

# 3. 使用wgsim生成模拟RNA-seq数据，并压缩为.gz格式（减少突变率和reads数量）
for i in {1..3}; do
    # 处理组 reads
    wgsim -N 1000 -1 100 -2 100 -r 0.001 -R 0 -X 0 $GENOME_DIR/genome.fa \
          $READS_DIR/treated_${i}_1.fq $READS_DIR/treated_${i}_2.fq
    gzip $READS_DIR/treated_${i}_1.fq
    gzip $READS_DIR/treated_${i}_2.fq
    
    # 对照组 reads
    wgsim -N 1000 -1 100 -2 100 -r 0.001 -R 0 -X 0 $GENOME_DIR/genome.fa \
          $READS_DIR/control_${i}_1.fq $READS_DIR/control_${i}_2.fq
    gzip $READS_DIR/control_${i}_1.fq
    gzip $READS_DIR/control_${i}_2.fq
done

# 验证生成的 paired-end 数据
echo "验证生成的 paired-end 数据："
ls -lh $READS_DIR/*.fq.gz

# 4. 使用bowtie2构建基因组索引
bowtie2-build $GENOME_DIR/genome.fa $GENOME_DIR/genome_index

# 5. 比对RNA-seq数据到参考基因组（使用更宽松的比对参数）
for i in {1..3}; do
    # 处理组比对（直接使用 .fq.gz 文件）
    bowtie2 -x $GENOME_DIR/genome_index \
            -1 $READS_DIR/treated_${i}_1.fq.gz \
            -2 $READS_DIR/treated_${i}_2.fq.gz \
            -S $ALIGNMENTS_DIR/treated_${i}.sam
    
    # 对照组比对（直接使用 .fq.gz 文件）
    bowtie2 -x $GENOME_DIR/genome_index \
            -1 $READS_DIR/control_${i}_1.fq.gz \
            -2 $READS_DIR/control_${i}_2.fq.gz \
            -S $ALIGNMENTS_DIR/control_${i}.sam
done

# 将SAM文件转换为BAM文件并排序
for file in $ALIGNMENTS_DIR/*.sam; do
    samtools view -bS $file | samtools sort -o ${file%.sam}.bam
    samtools index ${file%.sam}.bam
done

# 6. 使用HTSeq-count计算基因表达量
mkdir -p counts

for bam_file in $ALIGNMENTS_DIR/*.bam; do
    sample_name=$(basename ${bam_file%.bam})
    htseq-count \
        -f bam \
        -r pos \
        -s no \
        -t exon \
        -i gene_id \
        $bam_file \
        $GENOME_DIR/annotation.gtf > counts/${sample_name}_counts.txt
done

## 使用featureCounts计算基因表达量
featureCounts -a $GENOME_DIR/annotation.gtf -o counts/counts.txt $ALIGNMENTS_DIR/*.bam

echo "数据生成完成！"