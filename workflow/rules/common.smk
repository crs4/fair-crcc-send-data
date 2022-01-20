

from pathlib import Path
from typing import List

from snakemake.utils import validate

#### Configuration ####
validate(config, schema="../schemas/config.schema.yml") # also sets default values

source_ext = config['sources'].get('glob_extension', '.tiff.c4gh')
if not source_ext.startswith('.'):
    raise ValueError("sources.glob_extension must start with a '.'")


#### Environment configuration ####
shell.prefix("set -o pipefail; ")
if workflow.use_singularity:
    # Bind mount the repository path into container.
    # Ideally we want to mount the repository in read-only mode.
    # To avoid making the working directory read-only should it be inside
    # or the same path as the working directory, we check for this case
    # and if true we mount read-write.
    repository = Path(config['repository']['path'])
    work_dir = Path.cwd()
    if repository == work_dir or repository in work_dir.parents:
        mount_options = "rw"
    else:
        mount_options = "ro"
    workflow.singularity_args += f" --bind {config['repository']['path']}:{config['repository']['path']}:{mount_options}"


from snakemake.remote.S3 import RemoteProvider as S3RemoteProvider
# TODO:  generalize to different types connection
RP = S3RemoteProvider(**config['destination']['connection'])


##### Helper functions #####

def get_repository_path() -> Path:
    return Path(config['repository']['path'])


def get_remote_path(path: str):
    destination_root = Path(config['destination']['root_path'])
    return RP.remote(str(destination_root / path))


def glob_source_paths() -> List[Path]:
    base_dir = str(get_repository_path())
    source_paths = [ Path(p) for p in config['sources']['items'] ]
    if any(p.is_absolute() for p in source_paths):
        raise ValueError("Source paths must be relative to repository.path (absolute paths found).")
    # glob any directories for files that end with source_ext
    try:
        cwd = os.getcwd()
        os.chdir(str(base_dir))
        source_files = \
            [ slide for p in source_paths if p.is_dir() for slide in p.rglob(f"*{source_ext}") ] + \
            [ p for p in source_paths if p.is_file() and p.match(f"*{source_ext}") ]
    finally:
        os.chdir(cwd)
    return source_files


##### Glob input ####

source_files = glob_source_paths()
