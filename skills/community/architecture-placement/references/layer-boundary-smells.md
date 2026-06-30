# Layer Boundary Smells

Use this reference when reviewing or challenging an existing design, TechSpec, task breakdown, or implementation.

## Domain Logic Outside Domain

| Smell | Signal | Correction |
| --- | --- | --- |
| Use case owns formula | Application service calculates KPI, price, eligibility, score, commission, or policy | Move formula to value object, entity, or domain service |
| Presentation owns business rule | Controller/schema rejects semantic business states | Move rule to domain; keep presentation syntactic |
| SQL owns business policy | Query filters by policy terms instead of returning facts | Return facts from reader; apply policy in domain |
| Adapter owns domain decision | External adapter decides business classification | Adapter maps data; domain classifies |
| Domain service orchestrates workflow | Domain service opens transactions, calls ports, publishes events | Move flow to use case; keep domain service pure |

## Boundary Leaks

| Smell | Signal | Correction |
| --- | --- | --- |
| ORM leaks inward | Application/domain signatures use ORM rows/models | Add mapper or host-facing DTO |
| SDK leaks inward | Use case/domain accepts vendor SDK response types | Add gateway/adapter mapping |
| Transport leaks inward | Domain knows HTTP status, request, response, queue message, or framework type | Move transport concern to presentation/adapter |
| Foreign vocabulary spreads | Vendor codes or external names appear across domain/use cases | Use gateway or anti-corruption translation |
| Domain imports infrastructure | Domain imports database, HTTP client, filesystem, SDK, cache | Introduce port/gateway; implement outside |

## Gateway Smells

| Smell | Signal | Correction |
| --- | --- | --- |
| Missing gateway | External SDK/API/file access appears in multiple use cases | Add gateway with host-facing operations |
| Gateway as business service | Gateway calculates eligibility, pricing, KPI, commission, or state transition | Gateway translates; domain decides |
| Gateway as vendor facade | Gateway exposes every vendor operation unchanged | Expose only host application needs |
| Gateway returns foreign DTOs | Callers must know vendor fields, codes, or wire format | Map to host-facing data |
| Gateway wraps accepted vocabulary | Wrapper adds no translation, test seam, or isolation | Use the external API directly if it is local vocabulary |
| API gateway confusion | Provider-side API gateway is treated as domain/application gateway | Classify provider gateway as facade/infrastructure unless it protects host model |

## Naming Smells

| Name | Risk | Reclassification Question |
| --- | --- | --- |
| `Manager` | hides too many reasons to change | Is it use case, domain service, repository, or adapter? |
| `Processor` | hides flow vs policy | Is it application orchestration or domain transformation? |
| `Handler` | may be framework handler, event handler, or use case | Who calls it and what boundary does it cross? |
| `Helper` / `Util` | hides domain concept | Is there a value object, policy, or mapper name? |
| `Materializer` | describes effect, not layer | Is it refresh use case, read model repository, or projection writer? |
| `Gateway` | can be overused | What external system/resource does it encapsulate? |

## Review Output Format

For each finding, include:

- location
- current placement
- violated boundary
- recommended placement
- reason
- risk if left unchanged

