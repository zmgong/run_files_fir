#!/bin/bash
#SBATCH -J image_dna_text_no_init
#SBATCH --gpus-per-node=h100:4
#SBATCH --time=24:00:00
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=48
#SBATCH --output=logs/%N-%j.out
#SBATCH --mem=0
#SBATCH --exclusive
#SBATCH --account=rrg-msavva

rsync -avhP ~/projects/rrg-msavva/zmgong/data/BIOSCAN_1M/* $SLURM_TMPDIR/

cd ~/scratch/research/clibd
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

srun python scripts/train_cl.py 'model_config=for_bioscan_1m/final_experiments/image_dna_text_seed_42_no_init.yaml' bioscan_data.path_to_hdf5_data=$SLURM_TMPDIR/BioScan_data_in_splits.hdf5
srun python scripts/inference_and_eval.py 'model_config=for_bioscan_1m/final_experiments/image_dna_text_seed_42_no_init.yaml' bioscan_data.path_to_hdf5_data=$SLURM_TMPDIR/BioScan_data_in_splits.hdf5 inference_and_eval_setting.eval_on=val
srun python scripts/inference_and_eval.py 'model_config=for_bioscan_1m/final_experiments/image_dna_text_seed_42_no_init.yaml                                                                       ' bioscan_data.path_to_hdf5_data=$SLURM_TMPDIR/BioScan_data_in_splits.hdf5 inference_and_eval_setting.eval_on=test
