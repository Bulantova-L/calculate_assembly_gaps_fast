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
        set -euo pipefail
        mkdir -p sequences
        awk '/^>/ {i++; if(f){close(f)}; f="sequences/seq_" i ".fa"} {print > f}' ~{fasta}
        ls sequences/seq_*.fa > fasta_list.txt
    >>>

    output {
        Array[File] split_fastas = read_lines("fasta_list.txt")
    }

    runtime {
        docker: "quay.io/biocontainers/seqtk:1.3--hed695b0_2"
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
        grep -o -i "N" ~{fasta} | wc -l > n_count.txt || echo 0 > n_count.txt
    >>>

    output {
        Int n_counts = read_int("./n_count.txt")
    }

    runtime {
        docker: "ubuntu:22.04"
    }
}

# --- Sum counts from multiple sequences ---
task SumCounts {
    input {
        Array[Int] counts
        Int preemptible
    }

    command <<< 
        for c in ~{counts}; do
            echo $c
        done > counts.txt

        awk '{s += $1} END {print s}' counts.txt > total.txt
    >>>
    output {
        Int total_Ns = read_int("total.txt")
    }

    runtime {
        docker: "ubuntu:22.04"
        preemptible: preemptible
    }
}
