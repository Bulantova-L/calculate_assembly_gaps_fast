version 1.0
workflow countNs {
    meta {
        description: "Splits a FASTA file, counts N bases per sequence, and sums the total"
        author: "Lucie Bulantová"
        email: "474241@mail.muni.cz"
    }
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
        seqtk comp ~{fasta} | awk '{sum += $6} END {print sum ? sum : 0}' > ./n_count.txt
    >>>

    output {
        Int n_counts = read_int("./n_count.txt")
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
        # Debug: show the counts file path and content
        echo "Counts file: ~{write_lines(counts)}" >&2
        cat ~{write_lines(counts)} >&2

        # Sum the integers, one per line
        awk '{s+=$1} END {print s}' ~{write_lines(counts)} > total.txt
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
