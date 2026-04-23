#!/bin/bash
#SBATCH -J SEL_ver2_1_1_baseline_fir
#SBATCH --gpus-per-node=h100:4
#SBATCH --time=23:59:00
#SBATCH --output=logs/SEL_final_exp_ver_2/1_baseline_common_deepest.output
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=48
#SBATCH --mem=0
#SBATCH --account=rrg-msavva

set -euo pipefail

mkdir -p logs/SEL_final_exp_ver_2

cfg="1_baseline_common_deepest"

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

CONFIG_BASE="model_config=for_bioscan_5m/hyperbolic/SEL_final_exp_ver_2"
CONFIG_DIR_REL="bioscanclip/config/model_config/for_bioscan_5m/hyperbolic/SEL_final_exp_ver_2"

YAML_PATH="${CONFIG_DIR_REL}/${cfg}.yaml"
name="$(grep -E '^model_output_name:' "${YAML_PATH}" | head -1 | sed 's/^model_output_name:[[:space:]]*//' | tr -d '\r')"
if [ -z "${name}" ]; then
  echo "ERROR: could not read model_output_name from ${YAML_PATH}" >&2
  exit 1
fi

echo "================================================================================"
echo "Experiment: ${cfg}  (model_output_name / parquet: ${name})"
echo "================================================================================"

MC="${CONFIG_BASE}/${cfg}.yaml"

# bioscan_5m_data.* 下的 hdf5 / csv / *.json 路径都默认相对 ${bioscan_5m_data.dir}，
# 上面已经把这些文件 rsync 到 $SLURM_TMPDIR，所以只需覆盖根目录这一处即可。
DATA_OVERRIDES=(bioscan_5m_data.dir=$SLURM_TMPDIR)

python scripts/train_cl.py "${MC}" "${DATA_OVERRIDES[@]}"

python scripts/inference_and_eval.py "${MC}" "${DATA_OVERRIDES[@]}"

# --- Parquet encode + cone check: val (seen) ---
python scripts/result_processing_cone_check/encode_embeddings_to_parquet.py \
  "${MC}" \
  "${DATA_OVERRIDES[@]}" \
  inference_and_eval_setting.cone_check_split=val \
  inference_and_eval_setting.cone_check_val_subsplit=seen

python scripts/result_processing_cone_check/check_taxonomy_cone_statistics.py \
  --parquet_path "./parquet_embeddings/bioscan_5m/${name}/val" \
  --output_dir "./cone_check_results/${name}" \
  --split val

# --- Parquet encode + cone check: train (no_split_and_seen_train) ---
python scripts/result_processing_cone_check/encode_embeddings_to_parquet.py \
  "${MC}" \
  "${DATA_OVERRIDES[@]}" \
  inference_and_eval_setting.cone_check_split=no_split_and_seen_train

python scripts/result_processing_cone_check/check_taxonomy_cone_statistics.py \
  --parquet_path "./parquet_embeddings/bioscan_5m/${name}/no_split_and_seen_train" \
  --output_dir "./cone_check_results/${name}_train" \
  --split no_split_and_seen_train

echo "Experiment finished: ${cfg}"
