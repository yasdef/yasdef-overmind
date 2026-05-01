# Phase | Command | Model | Extra Arg 1 (optional) | Extra Arg 2 (optional) | ...
# Example: implementation | codex | gpt-5.2-codex | --config | model_reasoning_effort='high'
# Tip for CRs that add a new overmind phase:
# Start the request with `Use $overmind-new-pipeline-step ...` to enforce the full scaffold checklist.

task_to_br | codex | gpt-5.4 | --config | model_reasoning_effort='high'
br_to_ears | codex | gpt-5.4 | --config | model_reasoning_effort='high'
requirements_ears_review | codex | gpt-5.4 | --config | model_reasoning_effort='high'
feature_contract_delta | codex | gpt-5.4 | --config | model_reasoning_effort='high'
feature_repo_surface_and_exec_context | codex | gpt-5.4 | --config | model_reasoning_effort='high'
feature_surface_map_mcp_placeholder_enrichment | codex | gpt-5.4 | --config | model_reasoning_effort='high'
feature_technical_requirements | codex | gpt-5.4 | --config | model_reasoning_effort='high'
repository_implementation_slices | codex | gpt-5.4 | --config | model_reasoning_effort='high'
prerequisite_gap_trace | codex | gpt-5.4 | --config | model_reasoning_effort='high'
repository_implementation_plan | codex | gpt-5.4 | --config | model_reasoning_effort='high'
implementation_plan_semantic_review | codex | gpt-5.4 | --config | model_reasoning_effort='high'
user_br_clarification | codex | gpt-5.4 | --config | model_reasoning_effort='medium'
repo_analyse | codex | gpt-5.4 | --config | model_reasoning_effort='high'
common_contract_definition | codex | gpt-5.4 | --config | model_reasoning_effort='high'
project_stack_blueprint | codex | gpt-5.4 | --config | model_reasoning_effort='medium'
