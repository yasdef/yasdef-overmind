## ADDED Requirements

### Requirement: Step 7.1 reads configured external sources
Step `7.1` SHALL read staged external-source configuration from `.setup/external_sources.yaml` in the ASDLC workspace. It SHALL use only sources listed in that file when deciding whether MCP-backed placeholder enrichment is available.

#### Scenario: Empty external sources disables enrichment
- **WHEN** `.setup/external_sources.yaml` has `sources: []`
- **THEN** Step `7.1` leaves placeholder candidates unchanged without attempting an MCP query

#### Scenario: Configured source can be considered
- **WHEN** `.setup/external_sources.yaml` lists a source with a name and type
- **THEN** Step `7.1` evaluates that source against the knowledge-base source-selection rules

### Requirement: Source name must clearly indicate knowledge base authority
Step `7.1` SHALL use only configured MCP sources whose source name clearly identifies the source as a knowledge base. A source name SHALL be accepted only when it contains a knowledge-base signal such as `knowledge`, `knowledge-base`, `knowledge_base`, or `kb`, case-insensitively. Sources whose names do not clearly identify knowledge-base authority SHALL NOT be used for surface-map placeholder replacement.

#### Scenario: Knowledge-base named source is eligible
- **WHEN** `.setup/external_sources.yaml` includes a source named `tech-standards-kb`
- **THEN** Step `7.1` may consider that source for placeholder enrichment

#### Scenario: Arbitrary MCP source is rejected
- **WHEN** `.setup/external_sources.yaml` includes a source named `github-tools`
- **THEN** Step `7.1` does not use that source as surface-shape authority

#### Scenario: Type alone is insufficient
- **WHEN** `.setup/external_sources.yaml` includes a source with type `stack_knowledge_base` but a name that does not clearly indicate knowledge-base authority
- **THEN** Step `7.1` does not use that source for placeholder enrichment

### Requirement: MCP reachability is checked only for eligible sources and placeholder candidates
Step `7.1` SHALL check MCP reachability only after a surface map has eligible placeholders and at least one configured source passes the knowledge-base name filter. If no eligible source exists, Step `7.1` SHALL leave placeholders unchanged without reachability checks.

#### Scenario: No eligible source avoids reachability check
- **WHEN** a surface map has placeholders but no configured source name passes the knowledge-base filter
- **THEN** Step `7.1` does not perform MCP reachability checks
- **AND** the placeholders remain unchanged

#### Scenario: Eligible source is checked after placeholders found
- **WHEN** a surface map has placeholders and a configured source named `product-knowledge-base`
- **THEN** Step `7.1` checks reachability for that source before requesting candidate replacements

### Requirement: Knowledge-base source binding is visible in prompt context
When Step `7.1` invokes a model or MCP-backed enrichment flow, the prompt or command context SHALL bind the selected knowledge-base source name and target surface-map artifact explicitly. It SHALL instruct that only confirmed MCP-backed replacements for existing placeholders may be applied.

#### Scenario: Prompt names source and target map
- **WHEN** Step `7.1` invokes the enrichment flow for `project_surface_struct_resp_map_frontend.md`
- **THEN** the prompt context includes the selected knowledge-base source name
- **AND** the prompt context includes the frontend surface-map artifact path

#### Scenario: Prompt forbids broad rewrites
- **WHEN** Step `7.1` invokes the enrichment flow
- **THEN** the prompt instructs the model not to rewrite non-placeholder surface-map content
