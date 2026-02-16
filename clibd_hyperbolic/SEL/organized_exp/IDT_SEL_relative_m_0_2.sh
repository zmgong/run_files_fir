#!/bin/bash
#SBATCH -J IDT_SEL_relative_m_0_2
#SBATCH --gpus-per-node=h100:4
#SBATCH --time=50:00:00
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=48
#SBATCH --output=logs/%N-%j.out
#SBATCH --mem=0
#SBATCH --exclusive
#SBATCH --account=rrg-msavva

rsync -avhP ~/projects/rrg-msavva/zmgong/data/BIOSCAN_5M/* $SLURM_TMPDIR/
rsync -avhP ~/scratch/research/clibd_hyperbolic/data/BIOSCAN_5M/*.json $SLURM_TMPDIR/

cd ~/scratch/research/clibd_hyperbolic
module load python/3.11
module load StdEnv/2023
module load cuda/12.2
module load faiss/1.7.4
module load arrow/21.0.0
source ~/venvs/clibd-hyperbolic/bin/activate
git checkout main
git pull
pip install -e .

export OMP_NUM_THREADS=12

srun python scripts/train_cl.py 'model_config=for_bioscan_5m/hyperbolic/stacked_entailment_loss/organized_exp/IDT_SEL_relative_m_0_2.yaml' bioscan_5m_data.path_to_hdf5_data=$SLURM_TMPDIR/BIOSCAN_5M.hdf5
srun python scripts/inference_and_eval.py 'model_config=for_bioscan_5m/hyperbolic/stacked_entailment_loss/organized_exp/IDT_SEL_relative_m_0_2.yaml' bioscan_5m_data.path_to_hdf5_data=$SLURM_TMPDIR/BIOSCAN_5M.hdf5 inference_and_eval_setting.eval_on=val
srun python scripts/encode_embeddings_to_parquet.py 'model_config=for_bioscan_5m/hyperbolic/stacked_entailment_loss/organized_exp/IDT_SEL_relative_m_0_2.yaml' bioscan_5m_data.path_to_hdf5_data=$SLURM_TMPDIR/BIOSCAN_5M.hdf5
srun python scripts/check_taxonomy_cone_statistics.py --parquet_path ./parquet_embeddings/bioscan_5m/IDT_SEL_relative_m_0_2/val --output_dir ./cone_check_results/IDT_SEL_relative_m_0_2
