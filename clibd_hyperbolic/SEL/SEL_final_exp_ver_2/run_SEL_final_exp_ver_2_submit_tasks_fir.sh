#!/bin/bash
# Submit SEL_final_exp_ver_2 tasks to fir.
# Usage:
#   bash run_SEL_final_exp_ver_2_submit_tasks_fir.sh                 # submit all 7
#   bash run_SEL_final_exp_ver_2_submit_tasks_fir.sh <cfg_stem>      # submit one (e.g. 5a_mean_with_batch_size_clw_0_1)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# Pre-create the SLURM output directory. SBATCH --output is resolved (and the
# file opened) before the job script body runs, so "mkdir -p" inside the task
# script is too late if the parent directory does not exist yet.
mkdir -p logs/SEL_final_exp_ver_2

declare -A TASK_SCRIPT=(
  ["1_baseline_common_deepest"]="run_SEL_final_exp_ver_2_task_1_baseline_common_deepest_fir.sh"
  ["2_add_inter_warmup"]="run_SEL_final_exp_ver_2_task_2_add_inter_warmup_fir.sh"
  ["3_switch_to_parent_label"]="run_SEL_final_exp_ver_2_task_3_switch_to_parent_label_fir.sh"
  ["4_add_dna_bin_memory_bank"]="run_SEL_final_exp_ver_2_task_4_add_dna_bin_memory_bank_fir.sh"
  ["5a_mean_with_batch_size_clw_0_1"]="run_SEL_final_exp_ver_2_task_5a_mean_with_batch_size_clw_0_1_fir.sh"
  ["5b_mean_with_batch_size_clw_0_3"]="run_SEL_final_exp_ver_2_task_5b_mean_with_batch_size_clw_0_3_fir.sh"
  ["5c_mean_with_batch_size_clw_1_0"]="run_SEL_final_exp_ver_2_task_5c_mean_with_batch_size_clw_1_0_fir.sh"
)

TASKS_ORDER=(
  "run_SEL_final_exp_ver_2_task_1_baseline_common_deepest_fir.sh"
  "run_SEL_final_exp_ver_2_task_2_add_inter_warmup_fir.sh"
  "run_SEL_final_exp_ver_2_task_3_switch_to_parent_label_fir.sh"
  "run_SEL_final_exp_ver_2_task_4_add_dna_bin_memory_bank_fir.sh"
  "run_SEL_final_exp_ver_2_task_5a_mean_with_batch_size_clw_0_1_fir.sh"
  "run_SEL_final_exp_ver_2_task_5b_mean_with_batch_size_clw_0_3_fir.sh"
  "run_SEL_final_exp_ver_2_task_5c_mean_with_batch_size_clw_1_0_fir.sh"
)

if [[ -n "${1:-}" ]]; then
  cfg_stem="$1"
  task="${TASK_SCRIPT[${cfg_stem}]:-}"
  if [[ -z "${task}" ]]; then
    echo "ERROR: unknown cfg stem: ${cfg_stem}" >&2
    echo "Known stems:" >&2
    for k in "${!TASK_SCRIPT[@]}"; do echo "  ${k}" >&2; done
    exit 1
  fi
  echo "Submitting: ${task}"
  sbatch "./${task}"
  exit 0
fi

for task in "${TASKS_ORDER[@]}"; do
  echo "Submitting: ${task}"
  sbatch "./${task}"
done
