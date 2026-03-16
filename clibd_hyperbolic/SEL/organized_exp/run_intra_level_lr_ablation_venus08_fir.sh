#!/bin/bash
#SBATCH -J intra_lr_ablation_venus08
#SBATCH --gpus-per-node=h100:4
#SBATCH --time=50:00:00
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=48
#SBATCH --output=logs/%N-%j.out
#SBATCH --mem=0
#SBATCH --exclusive
#SBATCH --account=rrg-msavva

# Run: sbatch run_intra_level_lr_ablation_venus08_fir.sh
# Or run a single config: sbatch run_intra_level_lr_ablation_venus08_fir.sh default_set_stage1_60epochs
# Must run via sbatch (do not paste srun commands in an interactive shell without salloc).
#
# One-time: pack venv for fast transfer (on login node, after venv is ready):
#   venv-pack -p ~/venvs/clibd-hyperbolic -o ~/scratch/research/clibd_hyperbolic/clibd_venv.tar.gz

PACKED_VENV=${PACKED_VENV:-$HOME/scratch/research/clibd_hyperbolic/clibd_venv.tar.gz}

rsync -avhP ~/projects/rrg-msavva/zmgong/data/BIOSCAN_5M/* $SLURM_TMPDIR/
rsync -avhP ~/scratch/research/clibd_hyperbolic/data/BIOSCAN_5M/*.json $SLURM_TMPDIR/

# Unpack venv to node-local $SLURM_TMPDIR (venv-pack archive is relocatable; faster than rsync many small files)
echo "Unpacking venv to \$SLURM_TMPDIR ..."
cp "$PACKED_VENV" $SLURM_TMPDIR/clibd_venv.tar.gz
mkdir -p $SLURM_TMPDIR/venv_clibd
tar -xzf $SLURM_TMPDIR/clibd_venv.tar.gz -C $SLURM_TMPDIR/venv_clibd

cd ~/scratch/research/clibd_hyperbolic
module load python/3.11
module load StdEnv/2023
module load cuda/12.28
module load faiss/1.7.4
module load arrow/21.0.0
source $SLURM_TMPDIR/venv_clibd/bin/activate
git checkout intra_ablation
git pull
pip install -e .

# Numba (used by umap/pynndescent via inference_and_eval) can hang on first import if cache dir is on slow/shared fs. Set before any python run.
export NUMBA_CACHE_DIR=${SLURM_TMPDIR:-$HOME/.cache}/numba_cache
mkdir -p "$NUMBA_CACHE_DIR"

export OMP_NUM_THREADS=12

# Config keys = YAML basenames = model_output_name = directory names.
CONFIGS=(
    default_set
    default_set_stage1_60epochs
    default_set_stage1_60epochs_fd1e5
    default_set_stage1_60epochs_fd1e6
)

CONFIG_BASE="model_config=for_bioscan_5m/hyperbolic/intra_level_exp/ablation_on_venus_08"

if [ -n "$1" ]; then
    CONFIGS=("$1")
fi

for cfg in "${CONFIGS[@]}"; do
    echo "=========================================="
    echo "Running intra-level LR ablation (fir): $cfg"
    echo "=========================================="

    TRAIN_PARQUET_DIR=./parquet_embeddings/bioscan_5m/${cfg}/no_split_and_seen_train
    TRAIN_CONE_DIR=./cone_check_results/${cfg}_train/no_split_and_seen_train

    # 1) Stage 1 training
    srun python scripts/train_cl.py \
        "${CONFIG_BASE}/${cfg}.yaml" \
        bioscan_5m_data.path_to_hdf5_data=$SLURM_TMPDIR/BIOSCAN_5M.hdf5 \
        model_config.hyperbolic_space.log_in_cone_rate=false \
        model_config.hyperbolic_space.log_wrong_cone_rate=false

    # 2) Cone check on train split: no_split_and_seen_train
    srun python scripts/result_processing_cone_check/encode_embeddings_to_parquet.py \
        "${CONFIG_BASE}/${cfg}.yaml" \
        bioscan_5m_data.path_to_hdf5_data=$SLURM_TMPDIR/BIOSCAN_5M.hdf5 \
        inference_and_eval_setting.cone_check_split=no_split_and_seen_train

    srun python scripts/result_processing_cone_check/check_taxonomy_cone_statistics.py \
        --parquet_path "${TRAIN_PARQUET_DIR}" \
        --output_dir "${TRAIN_CONE_DIR}" \
        --split no_split_and_seen_train \
        --no-visualization
done

# 3) Aggregate and export LaTeX table for train split
srun python scripts/result_processing_cone_check/result_processing_cone_check.py \
    --config bioscanclip/config/result_processing_cone_check_config/0313_intra_level_lr_train_venus08.json \
    --output latex_tables/intra_level_lr_train_venus08.tex
