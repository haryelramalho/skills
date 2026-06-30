# Architecture Guidelines

Use this reference when a project architecture is unclear or when explaining placement decisions in Clean Architecture, Hexagonal Architecture, Gateway, or DDD vocabulary.

## Applicability Gate

Apply the full placement workflow when the project has at least two of:

- domain entities, value objects, aggregate roots, or domain services
- explicit use cases/application services
- ports/adapters, repositories, gateways, or dependency inversion
- bounded contexts or named business modules
- domain events or event-driven workflow
- complex business rules beyond CRUD validation

For CRUD-only apps, scripts, utility libraries, or architecture-agnostic documentation, avoid forcing DDD/Clean patterns. Prefer the project's existing simple structure and state that the full placement gate is not applicable.

## Clean Architecture

Source: Robert C. Martin, "The Clean Architecture" - https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html

Core placement rules:

- Entities hold the most general business rules.
- Use cases hold application-specific orchestration and direct entities to achieve actor goals.
- Interface adapters translate between inner models and external formats such as web, database, UI, and framework models.
- Dependencies point inward. Inner layers must not name outer-layer details.
- Data crossing boundaries should be simple and shaped for the inner layer, not ORM rows, framework objects, SDK responses, or transport objects.

## Hexagonal Architecture / Ports and Adapters

Source: Alistair Cockburn, "Hexagonal Architecture" - https://alistair.cockburn.us/hexagonal-architecture

Core placement rules:

- The application core communicates with the outside through ports.
- Adapters translate external technologies into calls/messages the application understands.
- The application should be testable without the real UI, database, remote service, batch runner, or file system.
- Ports are purposeful conversations, not one interface for every class by default.
- Adapters are technology-specific. The core should not depend on adapter types.

## Gateway

Source: Martin Fowler, "Gateway" - https://martinfowler.com/articles/gateway-pattern.html

Use a gateway when external software or resources are awkward from the host application's perspective: remote services, SDKs, files, database APIs, vendor systems, legacy systems, or foreign bounded contexts.

Gateway placement rules:

- A gateway encapsulates access to an external system or resource.
- The gateway interface should speak the host application's vocabulary.
- The gateway translates host-facing calls into the foreign API and translates results back.
- Gateway logic should be limited to translation and access concerns.
- Domain policy built on top of external data belongs in the gateway's clients, usually use cases plus domain objects/services.
- A remote gateway may split translation from connection mechanics: the gateway translates vocabulary, while a connection object handles transport details and gives tests a seam.
- Do not wrap an external vocabulary just because names are disliked. If the project intentionally adopts the external vocabulary as local vocabulary, wrapping may be unnecessary.
- Fowler distinguishes this from a general API gateway: a client-side gateway is written for the host application's specific use, while a provider-side API gateway is usually closer to a facade.

## DDD Vocabulary

Use DDD terms only when they clarify business ownership:

- Bounded context: a boundary where a business language/model is internally consistent.
- Ubiquitous language: the terms used by the business and code within a context.
- Entity: identity-bearing domain object with lifecycle and invariants.
- Value object: immutable domain concept compared by value.
- Aggregate: consistency boundary around entities/value objects.
- Domain service: stateless domain operation that does not naturally belong to one entity/value object.
- Anti-corruption layer: translation boundary that protects one model from a foreign model; gateways often implement this role.

Do not introduce DDD labels when the project has no domain model or when simpler language is clearer.

## Placement Decision Order

1. Identify the business language and bounded context.
2. Separate domain rules from application orchestration.
3. Separate host vocabulary from foreign vocabulary.
4. Assign rules to entities, value objects, or domain services.
5. Assign actor-goal flow to use cases/application services.
6. Assign external conversations to ports.
7. Assign awkward external resources to gateways.
8. Assign concrete technology to adapters/connections.
9. Assign transport shape to presentation.
10. Verify dependencies point inward.
