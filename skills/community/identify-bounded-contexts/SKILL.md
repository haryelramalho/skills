---
name: identify-bounded-contexts
description: Identify probable bounded contexts in a codebase using Eric Evans-style Domain-Driven Design heuristics. Use when Codex needs to map domain boundaries, evaluate module ownership, prepare a context map, review whether a service or package split matches the business model, or explain where ubiquitous language changes across folders, services, events, schemas, repositories, handlers, or teams.
---

# Identify Bounded Contexts

## Overview

Identify bounded contexts from source code, tests, docs, events, schemas, and naming patterns.
Ground the analysis in Eric Evans concepts: ubiquitous language, model consistency, context boundaries, relationships between contexts, and translation at integration points.

## Workflow

1. Inspect the codebase shape first.
Use `rg --files`, `rg`, package trees, module manifests, event names, schema names, ADRs, docs, and test folders to find domain seams before proposing any contexts.

2. Extract the domain language.
List recurring nouns, verbs, aggregates, policies, workflows, commands, events, and external actors. Look for places where the same word means different things or where different words refer to the same concept.

3. Propose candidate bounded contexts.
Group code by consistent model plus business purpose, not by technical layer alone. A candidate context should have a coherent language, core workflows, invariants, and integration surface.

4. Test each boundary.
For every candidate context, ask:
- Does the model stay internally consistent?
- Are invariants and business rules mostly local to this area?
- Does the language shift when crossing into adjacent code?
- Is translation needed at events, APIs, persistence mappings, or adapters?
- Would merging this area with its neighbor create contradictory meanings?

5. Identify relationships between contexts.
Look for upstream/downstream flows, published language, anti-corruption layers, conformist integrations, shared kernels, or open host style interfaces. Name the relationship only when the evidence is strong.

6. Report confidence and uncertainty.
Mark each proposed context as strong, medium, or weak confidence. If the evidence is ambiguous, present alternatives instead of forcing a single partition.

## Heuristics

Prefer business capability boundaries over folder boundaries.
The folder tree is evidence, not truth.

Prefer language changes over dependency graph changes.
If two areas use the same entity name with different rules or meanings, that is a strong boundary signal.

Prefer local invariants over shared data shape.
Shared IDs or tables do not prove a single context if the rules, use cases, and meaning diverge.

Prefer translation seams.
Mappers, adapters, event translators, DTO conversion, and handoff objects often indicate context boundaries.

Prefer team and ownership clues when available.
Separate teams, release cycles, and roadmaps often align with bounded contexts, but business language still wins over org charts.

Treat persistence and transport models carefully.
Mongo collections, SQL tables, protobufs, and event payloads can cross context boundaries and should not define the domain model by themselves.

Do not mistake technical layers for contexts.
`domain`, `application`, `infra`, `api`, and `bootstrap` are architecture layers, not bounded contexts.

Do not carve out value objects or shared utilities as standalone contexts unless they carry an independent model with their own language and rules.

## Output Format

When presenting the result, include:

1. Candidate bounded contexts.
For each one, provide name, purpose, main concepts, key files or modules, confidence, and why it is separate.

2. Boundary evidence.
Show the concrete code or naming signals that support the split: terms, events, repositories, handlers, schemas, packages, adapters, or tests.

3. Context relationships.
Describe likely upstream/downstream flows and where translation happens.

4. Ambiguities and alternative cuts.
If the codebase is mid-refactor or the model is inconsistent, say so clearly.

5. Recommendations.
Suggest the smallest next steps to clarify the model, such as renaming terms, moving handlers, isolating repositories, or introducing translation objects.

## Evidence Threshold

Do not claim a bounded context from one weak signal.
Prefer a combination of language, rules, workflows, ownership, and integration boundaries.
If the codebase is too thin to support a confident answer, say that you found candidate contexts rather than established ones.

## Reference

Read [references/evans-bounded-context-signals.md](references/evans-bounded-context-signals.md) when you need a deeper checklist of signals, anti-signals, and relationship patterns.
