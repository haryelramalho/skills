---
name: architecture-placement
description: Guides architecture placement decisions for codebases using Domain-Driven Design, Clean Architecture, Onion Architecture, or Ports and Adapters. Use when planning, reviewing, specifying, refactoring, or implementing behavior that must be assigned to entities, value objects, domain services, use cases, ports, adapters, gateways, repositories, readers, controllers, or schemas. Do not use for simple mechanical edits, formatting-only changes, or architecture-agnostic documentation.
---

# Architecture Placement

Use this skill to decide where responsibilities belong before specification, implementation, refactoring, or review in DDD/Clean/Onion/Ports-and-Adapters codebases.

## Core Rule

Keep domain decisions in the domain.

Use cases coordinate actor goals, transactions, ports, and persistence boundaries. They must not own formulas, invariants, eligibility decisions, semantic validation, state transitions, or business policies.

Gateways encapsulate access to external systems or resources. They translate between the host application's vocabulary and the foreign API; they must not own domain policy.

## Workflow

1. Inspect the local architecture source of truth before deciding: `AGENTS.md`, architecture docs, existing modules, TechSpecs, ADRs, and nearby code patterns.
2. Apply the applicability gate: if the project is CRUD-only, utility-only, or architecture-agnostic, avoid forcing DDD/Clean patterns and state the lighter approach.
3. Read `references/architecture-guidelines.md` when the project architecture is unclear or when explaining Clean, Hexagonal, Gateway, or DDD vocabulary.
4. Identify the bounded context and write the business language used by the codebase, not generic architecture labels.
5. List the domain concepts, invariants, calculations, policies, state transitions, and external dependencies involved.
6. Classify each responsibility into one architectural role using `references/placement-rubric.md` when placement is non-trivial.
7. Read `references/layer-boundary-smells.md` when reviewing or challenging an existing design.
8. Produce an Architecture Placement Plan before edits for non-trivial changes, using `assets/architecture-placement-plan-template.md` when a full plan is useful.
9. Implement or review only after the plan makes layer ownership explicit.

## Architecture Placement Plan

For non-trivial work, produce this plan before editing code:

```text
Architecture Placement Plan

Bounded context:
User/application goal:
Domain concepts:
Invariants and business rules:
Value objects:
Entities/aggregates:
Domain services:
Domain events:
Use cases/application services:
Ports:
Gateways:
Adapters:
Repositories/readers:
Presentation/API/schema responsibilities:
Prohibited placements:
Expected files:
Expected tests:
Open questions:
```

Keep the plan short. Use `None` only after verifying the category is genuinely not involved.

## Placement Heuristics

- Put identity, lifecycle, and invariant protection in entities or aggregates.
- Put immutable named concepts, constrained values, formulas over one concept, and equality-by-value behavior in value objects.
- Put domain policies or calculations spanning multiple entities/value objects in domain services.
- Put actor-goal orchestration, unit-of-work ownership, retries, permissions handoff, and calls to ports in use cases/application services.
- Put external dependency contracts in ports.
- Put awkward external systems and foreign vocabularies behind gateways.
- Put framework, database, HTTP, queue, cache, vendor, and file-format mechanics in adapters.
- Put aggregate persistence behind repositories.
- Put reporting, dashboards, read models, and analytic projections behind readers or query adapters.
- Put transport parsing, authentication dependency wiring, status-code mapping, and response shape in presentation.

## Review Gate

Before accepting a design, check for these placement failures:

- A use case calculates domain formulas or decides eligibility.
- A controller, schema, serializer, or adapter contains business rules.
- A repository hides domain policy inside SQL instead of returning facts or persisting aggregates.
- A gateway contains business policy instead of translation and external access concerns.
- Foreign DTOs, SDK types, ORM rows, or vendor vocabulary leak inward.
- A domain service calls another domain service as an orchestration chain.
- An adapter type leaks inward into application or domain signatures.
- A generic name such as `Manager`, `Processor`, `Handler`, `Helper`, `Materializer`, or `Util` hides the actual architectural role.
- A refactor only splits files but leaves ownership unclear.

When one appears, rename or move the responsibility by role before proceeding.

## Naming Rule

Name components by architectural responsibility:

- Use case/application service: verb phrase ending in `UseCase` or existing project convention.
- Domain service: domain policy/calculation name, not technical action.
- Value object: domain noun.
- Entity/aggregate: identity-bearing domain noun.
- Port: capability contract from the inner layer's perspective.
- Gateway: external system/resource name plus host-facing capability.
- Adapter: concrete technology plus port name.
- Repository/reader: persistence/read concern and aggregate or projection.

Avoid names that describe an implementation effect without a layer role. If a name seems necessary, first classify what it really is.

## Outputs by Task Type

- For TechSpecs: add a "Layer Ownership" or "Architecture Placement" section and map every important behavior to a role.
- For implementation: present the Architecture Placement Plan before edits unless the change is trivial.
- For review: lead with placement violations and file/line references, then suggest role-correct moves.
- For refactoring: distinguish moving logic to the right layer from merely extracting files.

## Error Handling

- If the project architecture conflicts with this skill, follow the project's explicit source of truth and call out the conflict.
- If bounded context or business language is unclear, inspect nearby code and ask one focused question only if a reasonable assumption would be risky.
- If legacy code violates the desired architecture, do not copy the violation unless the task is explicitly compatibility-only.
- If the user asks for code immediately, still perform the smallest useful placement check before editing.
