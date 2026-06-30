# Architecture Placement Rubric

Use this reference when a responsibility could plausibly fit more than one layer.

## Decision Table

| Question | Placement |
| --- | --- |
| Does it protect an invariant of an identity-bearing business object? | Entity or aggregate |
| Is it immutable, named in the domain, validated at construction, and compared by value? | Value object |
| Is it a domain rule, formula, policy, or eligibility decision spanning multiple domain objects? | Domain service |
| Is it the sequence required to satisfy an actor/application goal? | Use case or application service |
| Does it define what the inner layer needs from outside infrastructure? | Port |
| Does it encapsulate awkward access to an external system/resource and translate foreign vocabulary into host vocabulary? | Gateway |
| Does it implement a port using a database, HTTP API, queue, cache, file, or framework? | Adapter |
| Does it persist or retrieve aggregates? | Repository |
| Does it assemble read-only reports, dashboards, projections, or analytics? | Reader/query adapter |
| Does it parse transport input, map HTTP status codes, or shape API responses? | Controller/schema/presentation |
| Does it store a derived aggregate for fast reads? | Read model/snapshot, written by application flow and calculated by domain logic |

## Role Boundaries

### Entity or Aggregate

Use for identity-bearing business objects with lifecycle and invariants. Keep behavior close to the state it protects.

Examples:

- reservation status transition
- commission period closing invariant
- goal target invariant

### Value Object

Use for immutable domain concepts with validation and equality by value.

Examples:

- money amount
- period
- KPI identifier
- revenue basis
- percentage/rate

### Domain Service

Use when the rule is domain language but does not naturally belong to one entity or value object. Keep it pure: no database, HTTP, framework, logging requirement, or transaction ownership.

Examples:

- KPI formula service
- pricing policy
- eligibility policy
- reconciliation diff policy

### Use Case / Application Service

Use for one application goal. It coordinates transaction boundaries, ports, repositories, permissions handoff, idempotency, and domain calls.

It may:

- load data through ports/repositories
- call entities/value objects/domain services
- persist results
- publish events through ports
- decide operational flow

It must not:

- own business formulas
- validate domain semantics that belong to the model
- hide business decisions in orchestration branches
- become a generic processor

### Port

Use for an interface the inner layer needs to talk to something outside itself. Name it from the inner layer's perspective.

Examples:

- `CommissionInputsReader`
- `HotelPerformanceFactReader`
- `EventPublisher`
- `PaymentGateway`

### Gateway

Use for the boundary object that encapsulates access to an external system, resource, SDK, file format, remote service, database API, or vendor vocabulary. Design the gateway interface in the host application's terms, then translate to the foreign API internally.

It may:

- hide awkward arguments, codes, SDK types, wire formats, and remote-call mechanics
- translate foreign data into host-facing DTOs or value objects
- expose a test seam for slow or hard-to-control external systems
- combine a gateway-facing interface with a replaceable connection object for remote calls

It must not:

- own domain policy or formulas
- return foreign SDK/ORM/API types inward
- become a generic facade over every operation an external system offers
- wrap platform vocabulary that the project has intentionally adopted as local vocabulary

Gateway naming can overlap with adapter naming in some codebases. When both terms exist, treat the gateway as the host-facing external-system boundary and the adapter/connection as the concrete technology implementation.

### Adapter

Use for concrete technology implementations of ports. Technology details belong here.

Examples:

- `PgHotelPerformanceFactReader`
- `HttpPaymentGateway`
- `RedisSessionStore`
- `XlsxProductivityParser`

### Repository vs Reader

Use repositories for aggregate persistence and lifecycle. Use readers/query adapters for projections, reports, analytics, dashboards, and read models.

Prefer reader naming when the query is not reconstructing an aggregate for behavior.

### Presentation

Use presentation for transport concerns only.

Allowed:

- parse request types
- enforce syntactic format
- call use cases
- convert application errors to HTTP responses
- shape response DTOs

Not allowed:

- business validation
- formulas
- persistence decisions
- policy branching

## Naming Smells

Reclassify before accepting these names:

- `Manager`
- `Processor`
- `Handler`
- `Helper`
- `Util`
- `Materializer`
- `Coordinator`
- `Orchestrator`
- `Gateway` when no external system/resource is being encapsulated

These names can be legitimate in specific frameworks, but they often hide whether the component is a use case, domain service, port, adapter, repository, reader, or presentation handler.

## Common Corrections

| Smell | Better placement |
| --- | --- |
| Use case calculates KPI formula | Domain service or value object |
| SQL query decides eligibility | Reader returns facts; domain policy decides |
| Pydantic schema validates business rule | Value object/entity/domain service validates |
| Adapter returns ORM model inward | Mapper converts to application/domain data |
| Domain service calls repository | Use case loads facts, then calls pure domain service |
| `Materializer` recalculates snapshots | `Refresh...UseCase` coordinates; domain calculates; repository persists |
| Report endpoint contains grouping rules | Query object/value object validates supported grouping |
| External SDK calls scattered through use cases | Gateway hides SDK and exposes host-facing operations |
| Gateway contains eligibility rules | Gateway translates; domain policy decides eligibility |
| Gateway returns vendor DTOs | Gateway maps to host-facing DTOs/value objects |

## Minimal Review Checklist

- State the bounded context.
- State the actor/application goal.
- Identify all business rules.
- Assign every rule to entity, value object, or domain service.
- Assign orchestration to use cases.
- Assign infrastructure to ports/gateways/adapters.
- Verify dependencies point inward.
- Verify tests match the layer where behavior lives.
