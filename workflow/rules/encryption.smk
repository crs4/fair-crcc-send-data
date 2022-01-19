

def expand_repo_path(wildcard):
    full_path = (get_source_base_dir() / wildcard.filename).with_suffix('.c4gh')
    return str(full_path)


rule reencrypt:
    """
    Reencrypt the c4gh-encrypted data files to be sent using the recipient's
    public key.  Reencryptions is an action implemented by crypt4gh: it does
    not reencrypt the data, but creates a new file that can *also* be decrypted
    using the recipient's key.
    """
    input: expand_repo_path
    output:
        temp(crypt = "reencrypted/{filename}.c4gh")),
        checksum = "reencrypted/{filename}.sha"
    log:
        "logs/{filename}.c4gh.log"
    benchmark:
        "benchmark/{filename}.c4gh.bench"
    params:
        checksum_alg = 256,
        recipient_key = config['recipient_key'],
        master_pk = config['master_keypair']['private'],
        master_pubk = config['master_keypair']['public']
    resources:
        mem_mb = 1024 # guessed and probably overestimated
    container:
        "docker://ilveroluca/crypt4gh:1.5"
    shell:
        #Do we need to create the output directory??
        # mkdir -p $(dirname {output.crypt}) $(dirname {output.checksum}) &&
        """
        crypt4gh reencrypt \
                --sk {params.master_pk:q} \
                --recipient_pk {params.master_pubk:q} \
                --recipient_pk {params.recipient_key:q} \
                < {input:q} > {output.crypt:q} 2> {log:q} &&
        sha{params.checksum_alg}sum {output.crypt:q} > {output.checksum:q} 2>> {log:q}
        """

rule encrypt_index:
    input:
        index = rules.final_index.output.index
    output:
        index = "reencrypt/index.tsv.c4gh"
    log:
        "logs/index.tsv.c4gh.log"
    benchmark:
        "benchmark/index.tsv.c4gh.bench"
    params:
        recipient_key = config['recipient_key'],
        master_pk = config['master_keypair']['private'],
        master_pubk = config['master_keypair']['public']
    container:
        "docker://ilveroluca/crypt4gh:1.5"
    shell:
        """
        crypt4gh encrypt \
                --sk {params.master_pk:q} \
                --recipient_pk {params.master_pubk:q} \
                --recipient_pk {params.recipient_key:q} \
                < {input:q} > {output:q} 2> {log}
        """
