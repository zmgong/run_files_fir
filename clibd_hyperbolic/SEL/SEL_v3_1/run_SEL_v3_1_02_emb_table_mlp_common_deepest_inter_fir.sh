#!/bin/bash
#SBATCH -J SEL_v31_02
#SBATCH --gpus-per-node=h100:4
#SBATCH --time=40:00:00
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=48
#SBATCH --output=%x_%j.out
#SBATCH --mem=0
#SBATCH --exclusive
#SBATCH --account=rrg-msavva

set -euo pipefail

cfg="2_emb_table_mlp_common_deepest_inter"
name="SEL_v3_1_02_emb_table_mlp_common_deepest_inter"

rsync -avhP ~/projects/rrg-msavva/zmgong/data/BIOSCAN_5M/BIOSCAN_5M.hdf5 $SLURM_TMPDIR/
rsync -avhP ~/scratch/research/clibd_hyperbolic/data/BIOSCAN_5M/*.json $SLURM_TMPDIR/
rsync -avhP ~/projects/rrg-msavva/zmgong/data/BIOSCAN_5M/*.csv $SLURM_TMPDIR/

cd ~/scratch/research/clibd_hyperbolic
module load python/3.11
module load StdEnv/2023
module load cuda/12.2
module load faiss/1.7.4
source ~/venvs/clibd-hyperbolic/bin/activate
git checkout main
git pull
pip install -e .

export OMP_NUM_THREADS=12
export HYDRA_FULL_ERROR=1

CONFIG_BASE="model_config=for_bioscan_5m/hyperbolic/SEL_v3_1"
MC="${CONFIG_BASE}/${cfg}.yaml"
DATA_OVERRIDES=(bioscan_5m_data.dir=$SLURM_TMPDIR)

echo "================================================================================"
echo "Experiment: ${cfg} (${name})"
echo "================================================================================"

srun python scripts/train_cl.py "${MC}" "${DATA_OVERRIDES[@]}"

srun python scripts/inference_and_eval.py "${MC}" "${DATA_OVERRIDES[@]}" inference_and_eval_setting.eval_on=test
srun python scripts/inference_and_eval.py "${MC}" "${DATA_OVERRIDES[@]}"

srun python scripts/result_processing_cone_check/encode_embeddings_to_parquet.py \
  "${MC}" \
  "${DATA_OVERRIDES[@]}" \
  inference_and_eval_setting.cone_check_split=val \
  inference_and_eval_setting.cone_check_val_subsplit=seen

python scripts/result_processing_cone_check/check_taxonomy_cone_statistics.py \
  --parquet_path "./parquet_embeddings/bioscan_5m/${name}/val" \
  --output_dir "./cone_check_results/${name}" \
  --split val

srun python scripts/result_processing_cone_check/encode_embeddings_to_parquet.py \
  "${MC}" \
  "${DATA_OVERRIDES[@]}" \
  inference_and_eval_setting.cone_check_split=no_split_and_seen_train

python scripts/result_processing_cone_check/check_taxonomy_cone_statistics.py \
  --parquet_path "./parquet_embeddings/bioscan_5m/${name}/no_split_and_seen_train" \
  --output_dir "./cone_check_results/${name}_train" \
  --split no_split_and_seen_train

echo "Experiment finished: ${cfg}"
