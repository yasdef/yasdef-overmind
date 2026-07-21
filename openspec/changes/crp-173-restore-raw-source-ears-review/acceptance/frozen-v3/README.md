# Frozen measured v3 acceptance inputs

Frozen on 2026-07-21 from:

`/Users/aleksandrkalinin/repo/experiment_sdd_user_management_service/asdlc02/projects/umms03-e7cafd12-d837-452c-b8cb-406712651ea8/umss_core_functionality_v3-1784644643/`

| File | MD5 |
| --- | --- |
| `user_br_input.md` | `be2d32c17520adade9454c013e1e5070` |
| `feature_br_summary.md` | `668db54666f4cf8ea41be7a3f935e3cc` |
| `missing_br_data.md` | `6c3258b8f86bd8481fcdbffb5c933f33` |
| `requirements_ears.md` | `ad4731aa29632f55d091f4cb63ac202f` |
| `requirements_ears_review.md` | `fda1c7813e4f339a2febc1d1c97ce1df` |

`requirements_ears.md` is the **pre-review EARS state**: the measured v3 step 5.1 review ended with
`- no_findings: true` in `requirements_ears_review.md` and applied no EARS edits, so the stored EARS
file is identical to the one the review received as input. The v3 review ledger is frozen alongside
the inputs as evidence of that `no_findings: true` result; it is not an input to the acceptance runs.

These copies are the fixed acceptance inputs for the three-run step-5.1 batch and must not be
regenerated after CRP-172 changes the BR baseline.
