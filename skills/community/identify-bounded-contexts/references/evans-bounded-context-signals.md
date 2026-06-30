# Evans Bounded Context Signals

Use this checklist when the codebase is ambiguous or when several decompositions seem plausible.

## Strong signals

- Different ubiquitous languages for similar nouns.
- Different invariants or lifecycle rules for the same entity name.
- Translation code between modules, services, or event contracts.
- Separate workflows serving different business capabilities.
- Different actors, KPIs, or success criteria.
- Distinct event vocabularies and integration surfaces.
- Team ownership or roadmap separation that matches model separation.

## Weak signals

- Different folders without language drift.
- Separate databases or collections used only for scaling or deployment reasons.
- Different packages created only to satisfy clean architecture layering.
- Generic helpers, libraries, or shared DTOs.

## Anti-signals

- Splitting a value object into its own context.
- Treating every microservice as a bounded context by default.
- Using one context because two modules share an identifier or persistence schema.
- Mapping contexts around technical concerns such as `api`, `worker`, `consumer`, or `repository`.

## Relationship hints

- Upstream/downstream: one context publishes concepts another consumes.
- Anti-corruption layer: one side translates foreign concepts into its own language.
- Conformist: downstream adopts upstream language with little translation.
- Shared kernel: two contexts intentionally share a small, tightly-governed subset.
- Open host / published language: one context exposes a stable integration language for others.

## Questions to resolve ambiguity

- Which terms are overloaded across the codebase?
- Which business rules would become contradictory if merged?
- Where does translation already happen, even informally?
- Which modules could change independently without breaking the meaning of others?
- Where would a domain expert naturally draw a business boundary?
