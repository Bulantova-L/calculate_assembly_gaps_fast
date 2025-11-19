version 1.0
workflow countNs {
    meta {
        description: "Splits a FASTA file, counts N bases per sequence, and sums the total"
        author: "Lucie Bulantová"
        email: "474241@mail.muni.cz"
    }
    input {
        File fasta
    }

    call SplitFasta { 
        input: fasta = fasta
        }

    scatter (f in SplitFasta.split_fastas) {
        call CountNs {
            input: fasta = f
            }
    }
    call SumCounts {
        input: counts = CountNs.n_counts
    }

    output {
        Int total_Ns = SumCounts.total_Ns
    }
}

# --- Split the FASTA file into one sequence per file ---
task SplitFasta {
    input {
        File fasta
    }

    command <<<
        set -euo pipefail

        seqtk seq ~{fasta} | awk '/^>/{f="seq_" ++i ".fa"} {print > f}'
    >>>

    output {
           Array[File] split_fastas = glob("*.fa")

    }

    runtime {
        docker: "quay.io/biocontainers/seqtk:1.3--hed695b0_2"
    }
}

# --- Count unknown bases (Ns) using seqtk gap ---
task CountNs {
    input {
        File fasta
    }

    command <<<
        grep -o -i "N" ~{fasta} | wc -l > n_count.txt || echo 0 > n_count.txt
    >>>

    output {
        Int n_counts = read_int("n_count.txt")
    }

    runtime {
        docker: "ubuntu:22.04"
    }
}

# --- Sum counts from multiple sequences ---
task SumCounts {
    input {
        Array[Int] counts
    }

    command <<< 
        echo "~{sep='\n' counts}" | awk '{s+=$1} END {print s}' > total.txt
    >>>
    output {
        Int total_Ns = read_int("./total.txt")
    }

    runtime {
        docker: "ubuntu:22.04"
    }
}
