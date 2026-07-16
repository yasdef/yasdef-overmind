# Missing Business Data

## 1. Gate Status
- generated_at: {{GENERATED_AT}}
- gate_name: Business Context Completeness Gate
- gate_result: failed
- target_file: {{TARGET_FILE}}
- helper_script: {{HELPER_SCRIPT}}
- loop_round: {{LOOP_ROUND}}
- helper_exit_code: 1

## 2. Missing Business Fields
{{MISSING_ITEMS}}

## 3. Unresolved Items Ledger (Rised)
> Use deterministic format:
> `- rised_item_N: source=<section> -> <field>[, <section> -> <field>]; rised=false; unresolved_item=<text>`
{{RISED_ITEMS}}

## 6. Latest User Answers
> Keep `[UNFILLED]` while no ledger item has been discussed with user.
> After discussion starts, replace the placeholder with one or more repeated `- answers:` entries.
> Canonical format:
> `- answers: This was recorded in ## <section-number>. <section-title> - <field/item-id>.`
- answers: [UNFILLED]

## 7. Loop Decision
- unresolved_after_stop: [UNFILLED]
