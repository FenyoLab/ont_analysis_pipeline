import click
from environs import env
import datetime
import subprocess
from dataclasses import dataclass

from pathlib import Path


@dataclass
class PipelineConfig:
    skip_copy: bool
    skip_basecall: bool
    skip_demux: bool
    skip_fasta: bool
    skip_merge: bool
    skip_align: bool
    skip_bed: bool
    skip_sv: bool
    skip_methylation: bool


def bundle_skip_flags(f):
    """Decorator to bundle individual skip flags into a single config object."""
    # 1. Apply the click options to the function
    f = click.option("--skip-copy", is_flag=True, help="Skip data copy")(f)
    f = click.option("--skip-basecall", is_flag=True, help="Skip data basecalling")(f)
    f = click.option("--skip-demux", is_flag=True, help="Skip demux")(f)
    f = click.option("--skip-fasta", is_flag=True, help="Skip fasta preprocessing")(f)
    f = click.option("--skip-merge", is_flag=True, help="Skip merge")(f)
    f = click.option("--skip-align", is_flag=True, help="Skip align")(f)
    f = click.option("--skip-bed", is_flag=True, help="Skip bed")(f)
    f = click.option("--skip-sv", is_flag=True, help="Skip structural variant calling")(
        f
    )
    f = click.option("--skip-methylation", is_flag=True, help="Skip methylation")(f)

    # 2. Intercept the kwargs and bundle them
    import functools

    @functools.wraps(f)
    def wrapper(*args, **kwargs):
        # Extract the flags from kwargs
        config = PipelineConfig(
            skip_copy=kwargs.pop("skip_copy"),
            skip_basecall=kwargs.pop("skip_basecall"),
            skip_demux=kwargs.pop("skip_demux"),
            skip_fasta=kwargs.pop("skip_fasta"),
            skip_merge=kwargs.pop("skip_merge"),
            skip_align=kwargs.pop("skip_align"),
            skip_bed=kwargs.pop("skip_bed"),
            skip_sv=kwargs.pop("skip_sv"),
            skip_methylation=kwargs.pop("skip_methylation"),
        )
        # Pass the bundled object to the actual command
        return f(*args, pipeline_config=config, **kwargs)

    return wrapper


def setup_env(
    run_id: str,
    species: str,
    grid_path: str,
    reference: tuple[tuple[str, str, str]],
    sample: tuple[tuple[str, str, str, str]],
):

    env.read_env("variables.conf")

    current_year = datetime.date.today().year

    env_variables: dict[str, str | Path] = {
        "RAW_DATA": env.path("RAW_DATA"),
        "PROCESSED_DATA": env.path("PROCESSED_DATA"),
        "REFERENCE_LINKS": env.path("REFERENCE_LINKS"),
        "MODELS_DIR": env.path("MODELS_DIR"),
        "ANNOTATIONS_DIR": env.path("ANNOTATIONS_DIR"),
    }

    reference_links = env_variables["REFERENCE_LINKS"]

    processed_data_dir = Path(
        f"{env_variables['PROCESSED_DATA']}/{current_year}/{run_id}"
    )
    env_variables["PROCESSED_DATA_DIR"] = processed_data_dir

    raw_destination = Path(f"{env_variables['RAW_DATA']}/{current_year}/{run_id}")
    env_variables["RAW_DESTINATION"] = raw_destination

    rmsk_bed = env_variables["ANNOTATIONS_DIR"] / species / "rmsk.sorted.bed"
    env_variables["RMSK_BED"] = rmsk_bed

    env_variables["REMOTE_DIR"] = grid_path
    env_variables["RUN_ID"] = run_id
    env_variables["SPECIES"] = species

    job_variables = processed_data_dir / "pipeline_vars.env"
    env_variables["JOB_VARIABLES"] = job_variables

    basecalled_bam = processed_data_dir / "all_barcodes_methylation.bam"
    env_variables["BASECALLED_BAM"] = basecalled_bam

    demux_dir = processed_data_dir / "demux"
    env_variables["DEMUX_DIR"] = demux_dir

    logs_dir = processed_data_dir / "logs"
    env_variables["LOGS_DIR"] = logs_dir

    log_out = logs_dir / "%j_%x.out"
    env_variables["LOG_OUT"] = log_out

    raw_destination.mkdir(parents=True, exist_ok=True)
    processed_data_dir.mkdir(parents=True, exist_ok=True)
    logs_dir.mkdir(parents=True, exist_ok=True)

    for _, reference_base, reference_bed in reference:
        for _, sample_id, _, sample_reference in sample:
            if sample_reference.startswith(reference_base):
                env_variables[f"TARGETS_BED_{sample_id}"] = (
                    f"{reference_links}/{reference_base}/{reference_bed}"
                )

    for reference_dir, reference_base, _ in reference:
        if (reference_links / reference_base).is_symlink():
            click.echo(
                f"Symlink exists: {raw_destination / reference_dir} -> {reference_links / reference_base}"
            )

        else:
            (reference_links / reference_base).symlink_to(
                raw_destination / reference_dir
            )
            click.echo(
                f"Created symlink: {raw_destination / reference_dir} -> {reference_links / reference_base}"
            )

    with open(job_variables, "w") as job_vars:
        for key, value in env_variables.items():
            job_vars.write(f"{key}={value}\n")

    return env_variables


def submit_job(log_out: str, script, args: str, dependency_id: int | None = None):
    # Construct the sbatch command
    options = f"--parsable --output={log_out}"
    if dependency_id is not None:
        options += f" --dependency=afterok:{dependency_id}"

    sbatch_cmd = f"sbatch {options} {script} {args}"
    # Execute and capture output
    job_id = subprocess.getoutput(sbatch_cmd)

    return job_id


def run_pipeline(
    env_variables: dict[str, str | Path],
    references: tuple[tuple[str, str, str]],
    samples: tuple[tuple[str, str, str, str]],
    pipeline_config: PipelineConfig,
):
    log_out = str(env_variables["LOG_OUT"])
    skip_barcodes = int(len(samples) == 1 and samples[0][0] == "00")

    click.echo("=== Submitting Global Steps ===")

    if not pipeline_config.skip_copy:
        # COPY
        click.echo("\t [ ] Submitting copy job")
        job_id = submit_job(
            log_out,
            "1_copy_from_grid.sbatch",
            f"{env_variables['REMOTE_DIR']} {env_variables['RAW_DESTINATION']} {env_variables['JOB_VARIABLES']}",
        )
    else:
        job_id = None
        click.echo("\t [X] Skippnig copy step")

    # # BASECALL
    if not pipeline_config.skip_basecall:
        click.echo(f"\t [ ] Submitting basecalling job (depends on {job_id})")
        job_id = submit_job(
            log_out,
            "2_1_dorado_basecall_methylation.sbatch",
            f"{env_variables['RAW_DESTINATION']} {skip_barcodes} {env_variables['JOB_VARIABLES']}",
            dependency_id=job_id,
        )
    else:
        click.echo("\t [X] Skipping basecalling job")

    # DEMUX
    if not pipeline_config.skip_demux and not skip_barcodes:
        click.echo(f"\t [ ] Submitting demux job (depends on {job_id})")
        job_id = submit_job(
            log_out,
            "3_dorado_demux.sbatch",
            f"{env_variables['BASECALLED_BAM']} {env_variables['DEMUX_DIR']} {env_variables['JOB_VARIABLES']}",
            dependency_id=job_id,
        )
    else:
        click.echo("\t [X] Skipping demux job")

    # PROCESS FASTA
    # # TODO: Use references to process this iteratively
    if not pipeline_config.skip_fasta:
        click.echo(f"\t [ ] Submitting fasta-preprocessing job (depends on {job_id})")
        job_id = submit_job(
            log_out,
            "3_1_format_fasta.sbatch",
            f"{env_variables['REFERENCE_LINKS']}/{samples[0][3]} {env_variables['JOB_VARIABLES']}",
            dependency_id=job_id,
        )
    else:
        click.echo("\t [X] Skipping fasta-preprocessing job")

    # # PER SAMPLE STEPS
    click.echo("\t=== Submitting Per Sample Steps ===")
    for barcode, sample_id, sample_name, sample_reference in samples:
        reference_fasta = f"{env_variables['REFERENCE_LINKS']}/{sample_reference}"

        base_name = f"{env_variables['PROCESSED_DATA_DIR']}/{sample_id}-{sample_name}"
        sample_bam = f"{base_name}.bam"
        sorted_bam_output = f"{base_name}.aligned.sorted.bam"

        #     # MERGE BARCODES
        if not pipeline_config.skip_merge:
            click.echo(f"\t\t [ ] Submitting merge job (depends on {job_id})")
            job_id = submit_job(
                log_out,
                "4_samtools_merge_barcode.sbatch",
                f"{skip_barcodes} {sample_bam} {barcode} {env_variables['DEMUX_DIR']} {env_variables['JOB_VARIABLES']}",
                dependency_id=job_id,
            )
        else:
            click.echo("\t\t [X] Skipping merge job")

        #     # ALIGN
        if not pipeline_config.skip_align:
            click.echo(f"\t\t [ ] Submitting align job (depends on {job_id})")
            job_id_align = submit_job(
                log_out,
                "5_dorado_align.sbatch",
                f"{sample_bam} {reference_fasta} {env_variables['JOB_VARIABLES']}",
                dependency_id=job_id,
            )
        else:
            click.echo("\t\t [X] Skipping align job")
            job_id_align = None

        #     # GENERATE COVERAGE
        if not pipeline_config.skip_bed:
            click.echo(f"\t\t [ ] Submitting bed job (depends on {job_id})")
            job_id = submit_job(
                log_out,
                "6_create_bigwig.sbatch",
                f"{sorted_bam_output} {reference_fasta} {env_variables['JOB_VARIABLES']}",
                dependency_id=job_id_align,
            )
        else:
            click.echo("\t\t [X] Skipping bed job")

        #     # SV CALLING
        if not pipeline_config.skip_sv:
            click.echo(f"\t\t [ ] Submitting SV job (depends on {job_id})")
            job_id = submit_job(
                log_out,
                "9_structural_variant_calling.sbatch",
                f"{sorted_bam_output} {reference_fasta} {env_variables['JOB_VARIABLES']}",
                dependency_id=job_id_align,
            )
        else:
            click.echo("\t\t [X] Skipping SV job")

        #     # METHYLATION
        if not pipeline_config.skip_methylation:
            click.echo(f"\t\t [ ] Submitting Methylation job (depends on {job_id})")
            job_id = submit_job(
                log_out,
                "10_methylation.sbatch",
                f"{sorted_bam_output} {reference_fasta} {env_variables['JOB_VARIABLES']}",
                dependency_id=job_id_align,
            )
        else:
            click.echo("\t\t [X] Skipping Methylation job")

    #     )


@click.command()
@click.argument("grid_path")
@click.argument("run_id")
@click.option(
    "--species",
    type=click.Choice(["hg38", "mm10", "ferret", "crigri"]),
    required=True,
)
@click.option(
    "--reference",
    "-r",
    type=(str, str, str),
    multiple=True,
    required=True,
    help="Details to set up a reference. (source directory in 'grid_path', link name in 'references' [run_id_{fa_name}], bed file name)",
)
@click.option(
    "--sample",
    "-s",
    type=(str, str, str, str),
    multiple=True,
    required=True,
    help="Per sample details. (barcode or 00 for no barcode, sample_id, sample name, refernece path [run_id_{fa_name}/{fa_name}.fa])",
)
@bundle_skip_flags
def submit(
    grid_path: str,
    run_id: str,
    species: str,
    reference: tuple[tuple[str, str, str]],
    sample: tuple[tuple[str, str, str, str]],
    pipeline_config: PipelineConfig,
):
    env_variables = setup_env(run_id, species, grid_path, reference, sample)

    run_pipeline(env_variables, reference, sample, pipeline_config)


if __name__ == "__main__":
    submit()
