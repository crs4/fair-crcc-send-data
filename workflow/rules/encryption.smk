
# The reencrypt rule is meant to fetch data files from the repository
# and re-encrypt them with crypt4gh.  However, the definition of the
# rule wildcard is general enough that it can also pick up the index.c4gh
# file if we one day decide to also compute its checksum. That would break the
# workflow.  To avoid any problems, we specify ruleorder to given the
# encrypt_index rule priority over reencrypt when both match.
ruleorder: encrypt_index > reencrypt

rule encrypt_index:
    input:
        index = rules.final_index.output.index
    output:
        index = "reencrypted/index.tsv.c4gh"
    log:
        "logs/index.tsv.c4gh.log"
    benchmark:
        "benchmark/index.tsv.c4gh.bench"
    params:
        recipient_key = config['recipient_key'],
        master_pk = str(get_repository_path() / config['repository']['private_key']),
        master_pubk = str(get_repository_path() / config['repository']['public_key'])
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


def get_original_file_path(wildcard):
    original_name = get_original_item_name(wildcard.filename + '.c4gh')
    full_path = get_repository_path() / original_name
    return str(full_path)


rule reencrypt:
    """
    Reencrypt the c4gh-encrypted data files to be sent using the recipient's
    public key.  Reencryptions is an action implemented by crypt4gh: it does
    not reencrypt the data, but creates a new file that can *also* be decrypted
    using the recipient's key.
    """
    input: get_original_file_path
    output:
        crypt = temp("reencrypted/{filename}.c4gh"),
        checksum = "reencrypted/{filename}.c4gh.sha"
    log:
        "logs/{filename}.c4gh.log"
    benchmark:
        "benchmark/{filename}.c4gh.bench"
    params:
        checksum_alg = 256,
        recipient_key = config['recipient_key'],
        master_pk = str(get_repository_path() / config['repository']['private_key']),
        master_pubk = str(get_repository_path() / config['repository']['public_key'])
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
