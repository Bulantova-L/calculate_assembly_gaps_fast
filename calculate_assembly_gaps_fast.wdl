version 1.2

workflow countNs {
    input {
        File fasta
        Int preemptible = 1
    }

    call SplitFasta { 
        input: fasta = fasta, 
            preemptible = preemptible    
        }
    scatter (f in SplitFasta.split_fastas) {
        call CountNs {
            input: fasta = f, 
                preemptible = preemptible
            }
    }
    call SumCounts {
        input: counts = CountNs.n_counts,
            preemptible = preemptible
    }

    output {
        Int total_Ns = SumCounts.total_Ns
    }
}

# --- Split the FASTA file into one sequence per file ---
task SplitFasta {
    input {
        File fasta
        Int preemptible
    }

    command <<<
        awk '/^>/{if(f){close(f)}; f=substr($0,2); gsub(/[ \t]/,"_",f); f=f".fa"} {print > f}' ~{fasta}
        ls *.fa > fasta_list.txt
    >>>

    output {
        Array[File] split_fastas = read_lines("fasta_list.txt")
    }

    runtime {
        docker: "quay.io/biocontainers/seqtk:1.3--hed695b0_2"
        cpu: 1
        memory: "1G"
        preemptible: preemptible
    }
}

# --- Count unknown bases (Ns) using seqtk gap ---
task CountNs {
    input {
        File fasta
        Int preemptible
    }

    command <<<
        seqtk comp ~{fasta} | awk '{sum += $6} END {print sum ? sum : 0}' > n_count.txt
    >>>

    output {
        Int n_counts = read_int("n_count.txt")
    }

    runtime {
        docker: "quay.io/biocontainers/seqtk:1.3--hed695b0_2"
        cpu: 1
        memory: "512M"
        preemptible: preemptible
    }
}

# --- Sum counts from multiple sequences ---
task SumCounts {
    input {
        Array[Int] counts
        Int preemptible
    }

    command <<<
        echo "~{sep=' ' counts}" | awk '{s=0; for(i=1;i<=NF;i++) s+=$i; print s}' > total.txt
    >>>

    output {
        Int total_Ns = read_int("total.txt")
    }

    runtime {
        docker: "quay.io/biocontainers/seqtk:1.3--hed695b0_2"
        cpu: 1
        memory: "512M"
        preemptible: preemptible
    }
}
