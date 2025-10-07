#!/bin/bash
#SBATCH -J IDT_SEL_with_full_CL_OpenCLIP_5m.sh
#SBATCH --gpus-per-node=h100:4
#SBATCH --time=40:00:00
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=48
#SBATCH --output=logs/%N-%j.out
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
git pull
pip install -e .

export OMP_NUM_THREADS=12

srun python scripts/train_cl.py 'model_config=for_bioscan_5m/hyperbolic/stacked_entailment_loss/abalation_with_diff_text_input/IDT_SEL_with_full_CL_OpenCLIP_5m.sh.yaml' bioscan_5m_data.path_to_hdf5_data=$SLURM_TMPDIR/BIOSCAN_5M.hdf5
