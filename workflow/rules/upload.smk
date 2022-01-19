
rule upload_file:
    input:
        "reencrypted/{filename}"
    output:
        remote = get_remote_path("{filename}")
    shell:
      """
      cp --link --verbose {input:q} {output:q}
      """
