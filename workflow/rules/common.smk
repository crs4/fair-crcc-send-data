

from pathlib import Path
from typing import List

from snakemake.utils import validate

#### Configuration ####
validate(config, schema="../schemas/config.schema.yaml") # also sets default values

source_ext = config['sources'].get('extension', '.tiff.c4gh')
if not source_ext.startswith('.'):
    raise ValueError("source_ext must start with a '.'")

source_files = glob_source_paths()


#### Environment configuration ####
shell.prefix("set -o pipefail; ")
if workflow.use_singularity:
    workflow.singularity_args += f" --bind {config['repository_path']}:/repository:ro"


from snakemake.remote.S3 import RemoteProvider as S3RemoteProvider
# TODO:  generalize to different types connection
RP = S3RemoteProvider(**config['destination']['connection'])


##### Helper functions #####

def get_source_base_dir() -> Path:
    return Path(config['sources']['base_dir'])


def get_remote_path(path: str):
    destination_root = Path(config['destination']['root_path'])
    return RP.remote(str(destination_root / path))


def glob_source_paths() -> List[Path]:
    base_dir = str(get_source_base_dir())
    source_paths = [ Path(p) for p in config['sources']['items'] ]
    if any(p.is_absolute() for p in source_paths):
        raise ValueError("Source paths must be relative to sources.base_dir (absolute paths found).")
    # glob any directories for files that end with source_ext
    try:
        cwd = os.getcwd()
        os.chdir(str(base_dir))
        source_files = \
            [ slide for d in source_paths if p.is_dir() for slide in d.rglob(f"*{source_ext}") ]
            [ p for p in source_paths if p.is_file() and p.match(f"*{source_ext}") ]
    finally:
        os.chdir(cwd)
    return source_files


#rule checksum_file:
#    input:
#        "{filename}"
#    output:
#        "{filename}.sha"
#    log:
#        "{filename}.sha.log"
#    benchmark:
#        "{filename}.sha.bench"
#    params:
#        checksum_alg = 256
#    resources:
#        mem_mb = 64
#    container:
#        "docker://ilveroluca/crypt4gh:1.5"
#    shell:
#        """
#        sha{params.checksum_alg}sum {input:q} > {output:q} 2> {log:q}
#        """
