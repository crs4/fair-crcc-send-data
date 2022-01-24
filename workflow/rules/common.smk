

from pathlib import Path
from typing import List, Mapping

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


##### Helper functions #####

from snakemake.remote import AbstractRemoteProvider

def create_remote_provider(destination_config: Mapping[str, str]) -> AbstractRemoteProvider:
    """
    Create a snakemake remote provider from config['destination'].
    """
    # LP: The snakemake.remote.AutoRemoteProvider seems like the ideal solution
    # for the problem of easily mapping a destination type to a concrete
    # RemoteProvider class.  However, as of snakemake v6.12.3 I was not able to
    # get it work.  So, we provide our own implementation here.
    import importlib
    ProviderMap = {
        "azblob": "AzBlob",
        "dropbox": "dropbox",
        "ega": "EGA",
        "ftp": "FTP",
        "gfal": "gfal",
        "gridftp": "gridftp",
        "gs": "GS",
        "http": "HTTP",
        "irods": "iRODS",
        "ncbi": "NCBI",
        "s3": "S3",
        "sftp": "SFTP",
        "webdav": "",
        "xrootd": "XRootD",
    }

    destination_type = destination_config['type'].lower()
    module_name = f"snakemake.remote.{ProviderMap[destination_type]}"
    provider_module = importlib.import_module(module_name)
    return provider_module.RemoteProvider(**destination_config['connection'])


# Create the remote provider for the results.  This object is used by
# the get_remote_path function
RProvider = create_remote_provider(config['destination'])


def get_remote_path(path: str):
    destination_root = Path(config['destination']['root_path'])
    return RProvider.remote(str(destination_root / path), **config['destination']['connection'])


def get_repository_path() -> Path:
    return Path(config['repository']['path'])


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
