#!/bin/bash
#SBATCH -J 2_loss_ablation_weighted_mean_a100
#SBATCH --gpus-per-node=h100:4
#SBATCH --time=00:40:00
#SBATCH --output=logs/%N-%j.out   # Terminal output to file named (hostname)-(jobid).out
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=48
#SBATCH --mem=0
#SBATCH --exclusive
#SBATCH --account=rrg-msavva
rsync -avhP ~/projects/rrg-msavva/zmgong/data/BIOSCAN_5M/BIOSCAN_5M.hdf5 $SLURM_TMPDIR/
rsync -avhP ~/scratch/research/clibd_hyperbolic/data/BIOSCAN_5M/*.json $SLURM_TMPDIR/

cd ~/scratch/research/clibd_hyperbolic
module load python/3.11
module load StdEnv/2023
module load cuda/12.2
module load faiss/1.7.4
source ~/venvs/clibd-hyperbolic/bin/activate
git checkout intra_ablation
git pull
pip install -e .

export OMP_NUM_THREADS=12

srun python scripts/train_cl.py 'model_config=for_bioscan_5m/hyperbolic/intra_level_exp/ablation_loss_func/a100/2_loss_ablation_weighted_mean_a100.yaml' bioscan_5m_data.path_to_hdf5_data=$SLURM_TMPDIR/BIOSCAN_5M.hdf5