# Overmind Runtime Assets

This directory holds the source templates, rules, golden examples, setup defaults, and init-flow documentation packaged into ASDLC workspaces.

Project init runs through the installed TypeScript CLI:

```bash
node .overmind/overmind.js project init --path projects/<project-id>
```

For type `A` projects, step `1.1` is `Define Project Stack Blueprints And Agent Guidelines For Active Classes`. For each active `backend`, `frontend`, or `mobile` class, project init runs a stack-blueprint session followed by an agents-md session.
After step `1.1` returns, Overmind checkpoints the stack baseline and asks `Continue with common contract definition? [Y/n]`. Press Enter or answer yes to start step `2` in the same invocation; answer no to pause successfully and resume later with the same `project init --path projects/<project-id>` command. When `overmind run` reaches the step `3` boundary to start a new feature, it refuses pending init or reconciliation checkpoints before requesting feature input or creating feature files, naming the owning `project init` or `project reconcile` command.

Useful direct commands:

```bash
node .overmind/overmind.js context stack-blueprint projects/<project-id> --class backend
node .overmind/overmind.js gate stack-blueprint projects/<project-id>/project_stack_blueprint_backend.md
node .overmind/overmind.js context agents-md projects/<project-id> --class backend
node .overmind/overmind.js gate agents-md projects/<project-id>/project_agents_md_claude_md_backend.md
node .overmind/overmind.js gate common-contract projects/<project-id>
```

Step `2`, `Create Cross-Repository Contract Definition For This Project`, blocks for type `A` projects until every active class has both `project_stack_blueprint_<class>.md` and `project_agents_md_claude_md_<class>.md` at the project root.
