#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

declare -A TASK_SCRIPT=(
  ["0_plain_sel_one_stage_all_loss"]="run_SEL_embed_table_clw0_1_task_0_plain_sel_one_stage_all_loss_fir.sh"
  ["0_5_two_stage_no_dna_bin"]="run_SEL_embed_table_clw0_1_task_0_5_two_stage_no_dna_bin_fir.sh"
  ["1_two_stage_instance_level_with_dna_bin"]="run_SEL_embed_table_clw0_1_task_1_two_stage_instance_level_with_dna_bin_fir.sh"
  ["2_two_stage_common_deepest_with_dna_bin"]="run_SEL_embed_table_clw0_1_task_2_two_stage_common_deepest_with_dna_bin_fir.sh"
  ["3_two_stage_common_deepest_without_dna_bin"]="run_SEL_embed_table_clw0_1_task_3_two_stage_common_deepest_without_dna_bin_fir.sh"
)

TASKS_ORDER=(
  "run_SEL_embed_table_clw0_1_task_0_plain_sel_one_stage_all_loss_fir.sh"
  "run_SEL_embed_table_clw0_1_task_0_5_two_stage_no_dna_bin_fir.sh"
  "run_SEL_embed_table_clw0_1_task_1_two_stage_instance_level_with_dna_bin_fir.sh"
  "run_SEL_embed_table_clw0_1_task_2_two_stage_common_deepest_with_dna_bin_fir.sh"
  "run_SEL_embed_table_clw0_1_task_3_two_stage_common_deepest_without_dna_bin_fir.sh"
)

if [[ -n "${1:-}" ]]; then
  cfg_stem="$1"
  task="${TASK_SCRIPT[${cfg_stem}]:-}"
  if [[ -z "${task}" ]]; then
    echo "ERROR: unknown cfg stem: ${cfg_stem}" >&2
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

