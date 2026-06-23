# Implementation Plan - Golden Example

This example shows a single cross-repo plan grounded in technical requirements, with explicit repo ownership, concrete component work, mixed implemented/remaining status, and correct ordering.
It also keeps required operator-facing surface delivery explicit in plan steps; supporting-only API/auth/contract work is not treated as sufficient replacement coverage.
Step-heading `REQ-*` / `NFR-*` links are the canonical FR traceability surface and reuse ids from `requirements_ears.md`; `#### Evidence:` carries technical-requirements links at step scope, including `gap/TECH_REQ-NFR-*` tokens for NFR-backed requirement gaps, and checklist bullets stay execution detail only.

### Step 1.1 Order projection persistence foundation [REQ-6] [REQ-7]
#### Repo: backend
#### Depends on: none
#### Evidence: gap/TECH_REQ-6, comp/backend-projection-persistence
#### Preserved Surface: none
#### Assigned: 2fe775aa-92d5-4074-a3c2-c90bc8848897
- [x] Plan and discuss the step
- [x] Add projection table changeSet and repository mappings
- [x] Implement projection rebuild service path and integration coverage
- [x] Review step implementation

### Step 1.2 Order query endpoint read-path completion [REQ-6] [NFR-1]
#### Repo: backend
#### Depends on: 1.1
#### Evidence: gap/TECH_REQ-6, gap/TECH_REQ-NFR-1
#### Preserved Surface: none
#### Assigned: 4agrf5aa-1145-4874-s2d2-c90as2147711
- [ ] Plan and discuss the step
- [ ] Add query repository criteria and projection-backed read service
- [ ] Implement query controller DTO mapping and stable error responses
- [ ] Add query integration tests, latency verification, and update consumer-facing docs
- [ ] Review step implementation

### Step 1.3 Frontend order projection client alignment [REQ-4] [REQ-6]
#### Repo: frontend
#### Depends on: 1.2
#### Evidence: gap/TECH_REQ-4, comp/frontend-order-projection-client
#### Preserved Surface: Protected operator workspace shell
#### Assigned: 2ferf5aa-9565-4874-a3c2-c90as2143345
- [ ] Plan and discuss the step
- [ ] Update order API client mapping for projection fields added by backend
- [ ] Update order creation screen state and rendering for projection-backed status
- [ ] Add component and adapter tests for projection field handling
- [ ] Review step implementation

### Step 1.4 Mobile order projection client alignment [REQ-4] [REQ-6]
#### Repo: mobile
#### Depends on: 1.2
#### Evidence: gap/TECH_REQ-4, comp/mobile-order-projection-client
#### Preserved Surface: Operator order lookup screen
#### Assigned: 3tgrf5aa-3345-4874-s2d2-c90as2142254
- [ ] Plan and discuss the step
- [ ] Update mobile order API mapper for projection fields added by backend
- [ ] Update mobile order screen state and rendering for projection-backed status
- [ ] Add mobile view-model and screen tests for projection field handling
- [ ] Review step implementation
