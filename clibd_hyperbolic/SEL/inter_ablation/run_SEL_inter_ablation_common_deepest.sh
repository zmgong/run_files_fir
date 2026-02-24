#!/bin/bash
#SBATCH -J SEL_inter_ablation_common_dp
#SBATCH --gpus-per-node=h100:4
#SBATCH --time=06:00:00
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=48
#SBATCH --output=logs/%N-%j.out
#SBATCH --mem=0
#SBATCH --exclusive
#SBATCH --account=rrg-msavva

GRACE_SEC=9000
PROJECT_ROOT="${PROJECT_ROOT:-$HOME/scratch/research/clibd_hyperbolic}"
CHAIN_CHECKPOINT_DIR="${CHAIN_CHECKPOINT_DIR:-$PROJECT_ROOT/ckpt/bioscan_clip/ver_1_0/bioscan_5m/SEL_inter_ablation_common_deepest}"

set -e
mkdir -p logs

rsync -avhP ~/projects/rrg-msavva/zmgong/data/BIOSCAN_5M/* $SLURM_TMPDIR/
rsync -avhP "$PROJECT_ROOT/data/BIOSCAN_5M/"*.json "$SLURM_TMPDIR/" 2>/dev/null || true

cd "$PROJECT_ROOT"
module load python/3.11
module load StdEnv/2023
module load cuda/12.2
module load faiss/1.7.4
module load arrow/21.0.0
source ~/venvs/clibd-hyperbolic/bin/activate
git checkout embed_table_and_debug_sel
git pull
pip install -e . -q

export OMP_NUM_THREADS=12

train_pid=
cleanup() {
  if [ -n "$train_pid" ] && kill -0 "$train_pid" 2>/dev/null; then
    echo "Sending SIGTERM to training process $train_pid (graceful stop)..."
    kill -TERM "$train_pid" 2>/dev/null || true
    wait "$train_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT

(
  sleep $(( 6 * 3600 - GRACE_SEC ))
  if kill -0 "$train_pid" 2>/dev/null; then
    echo "Approaching time limit (2.5h left); sending SIGTERM to training ($train_pid)."
    kill -TERM "$train_pid" 2>/dev/null || true
  fi
) &
timer_pid=$!

srun python scripts/train_cl.py 'model_config=for_bioscan_5m/hyperbolic/stacked_entailment_loss/inter_ablation/SEL_inter_ablation_common_deepest.yaml' bioscan_5m_data.path_to_hdf5_data=$SLURM_TMPDIR/BIOSCAN_5M.hdf5 &
train_pid=$!
wait $train_pid
train_exit=$?
train_pid=""
kill $timer_pid 2>/dev/null || true
trap - EXIT

FINISHED="False"
if [ -f "$CHAIN_CHECKPOINT_DIR/.training_finished" ]; then
  FINISHED="True"
elif [ -f "$CHAIN_CHECKPOINT_DIR/last_full.pth" ]; then
  FINISHED=$(python -c "
import torch
try:
    c = torch.load('$CHAIN_CHECKPOINT_DIR/last_full.pth', map_location='cpu')
except Exception:
    c = {}
print(c.get('finished', False))
" 2>/dev/null || echo "False")
fi

if [ "$FINISHED" != "True" ]; then
  echo "Training not finished. Submitting next 6h job..."
  export CHAIN_CHECKPOINT_DIR
  export PROJECT_ROOT
  sbatch --export=ALL,CHAIN_CHECKPOINT_DIR,PROJECT_ROOT "$(dirname "$0")/run_SEL_inter_ablation_common_deepest.sh"
  exit 0
fi

echo "Training finished. Running inference, encode and cone check..."
srun python scripts/inference_and_eval.py 'model_config=for_bioscan_5m/hyperbolic/stacked_entailment_loss/inter_ablation/SEL_inter_ablation_common_deepest.yaml' bioscan_5m_data.path_to_hdf5_data=$SLURM_TMPDIR/BIOSCAN_5M.hdf5 inference_and_eval_setting.eval_on=val
srun python scripts/encode_embeddings_to_parquet.py 'model_config=for_bioscan_5m/hyperbolic/stacked_entailment_loss/inter_ablation/SEL_inter_ablation_common_deepest.yaml' bioscan_5m_data.path_to_hdf5_data=$SLURM_TMPDIR/BIOSCAN_5M.hdf5
srun python scripts/check_taxonomy_cone_statistics.py --parquet_path ./parquet_embeddings/bioscan_5m/SEL_inter_ablation_common_deepest/val --output_dir ./cone_check_results/SEL_inter_ablation_common_deepest
