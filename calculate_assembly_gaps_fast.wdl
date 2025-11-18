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
        Int preemptible
    }

    command <<<
        set -euo pipefail
        mkdir -p sequences

        seqtk seq ~{input_file} | awk '/^>/{f="sequences/seq_" ++i ".fa"} {print > f}'

        ls -l sequences
    >>>

    output {
           Array[File] split_fastas = glob("sequences/*.fa")

    }

    runtime {
        docker: "biocontainers/seqtk:v1.3-1-deb_cv1"
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
    }
}
