# Issue Body Templates

The skill applies one template based on the detected type. Default language is Brazilian Portuguese (pt-br) with technical terms in English. If the `in english` modifier is present, translate field names to English.

Each placeholder in `[brackets]` must be filled with concrete content. If a value is inferred (not explicitly stated by the user), prefix the entire line with `[Assumption]`.

---

## Bug

### Fields collected
- `componente` — area of the system (UI screen, module, function name)
- `comportamento_atual` — what is happening now
- `comportamento_esperado` — what should happen
- `passos_repro` — ordered list of steps to reproduce
- `ambiente` — browser, OS, version, runtime (only if relevant)
- `severidade` — `Bloqueia` · `Degrada` · `Cosmético`

### Title format
`[componente]: [comportamento_atual resumido]` (max 80 chars)

Example: `Filtro de checkout: zera o estado ao trocar o mês`

### Body
```markdown
**Tipo:** Bug · **Severidade:** [severidade]

## Comportamento atual
[1-3 frases descrevendo o que acontece]

## Comportamento esperado
[1-2 frases descrevendo o que deveria acontecer]

## Como reproduzir
1. [passo 1]
2. [passo 2]
3. [passo 3]

## Ambiente
- [browser/OS/versão se relevante]

## Código relacionado
[bloco gerado por scripts/code-context.sh, omitir se nenhum path detectado]

## Notas
[Assumption] [campo inferido pela skill, repetir uma linha por inferência]
```

### Labels applied
- `bug` (sempre)
- `area/<X>` (se inferível pelo path detectado ou pela área mencionada)

---

## Feature

### Fields collected
- `persona` — quem usa
- `acao` — o que vai poder fazer
- `valor` — qual o benefício
- `criterios` — lista de Given/When/Then ou checklist
- `edge_cases` — 1-3 casos de borda
- `fora_de_escopo` — o que NÃO está incluído

### Title format
`[verbo no infinitivo + objeto direto]` (max 80 chars)

Example: `Adicionar exportação CSV no ranking`

### Body
```markdown
**Tipo:** Feature

## User Story
Como **[persona]**, quero **[acao]**, para **[valor]**.

## Critérios de aceite
- [ ] Dado [contexto], quando [ação], então [resultado]
- [ ] [...]

## Edge cases
- [caso 1]
- [caso 2]

## Fora de escopo
- [item 1]

## Código relacionado
[opcional, gerado por scripts/code-context.sh]

## Notas
[Assumption] [...]
```

### Labels applied
- `feature` (sempre)
- `area/<X>` (se inferível)

---

## Tech-debt

### Fields collected
- `divida_atual` — o problema estrutural
- `risco` — o que vai dar errado se não fizer
- `proposta` — o que mudar
- `escopo_afeta` — módulos/arquivos afetados
- `escopo_nao_afeta` — fronteira do refactor
- `nao_regressao` — checklist do que precisa continuar funcionando

### Title format
`[refator/limpeza/migração]: [escopo curto]` (max 80 chars)

Example: `Refator: extrair validação de schema do controller de checkout`

### Body
```markdown
**Tipo:** Tech debt

## Dívida atual
[1-3 frases descrevendo o problema estrutural]

## Risco se não fizer
- [risco 1]
- [risco 2]

## Proposta
[1-3 frases descrevendo a mudança]

## Escopo
- Afeta: [arquivos/módulos]
- Não afeta: [fronteira]

## Não-regressão
- [ ] [comportamento 1 continua funcionando]
- [ ] [comportamento 2 continua funcionando]

## Código relacionado
[gerado por scripts/code-context.sh]

## Notas
[Assumption] [...]
```

### Labels applied
- `tech-debt` (sempre)
- `area/<X>` (se inferível)

---

## Spike

### Fields collected
- `pergunta` — uma pergunta clara a responder
- `hipoteses` — 1-3 hipóteses iniciais
- `timebox` — `2h`, `4h`, `1 dia`, `2 dias`
- `criterio_feito` — qual artefato sai (decisão escrita, PoC, doc comparativo)

### Title format
`Spike: [pergunta resumida]` (max 80 chars)

Example: `Spike: vale migrar do tRPC pra GraphQL no novo módulo?`

### Body
```markdown
**Tipo:** Spike · **Timebox:** [timebox]

## Pergunta
[pergunta clara em uma frase]

## Hipóteses
- H1: [hipótese 1]
- H2: [hipótese 2]

## Critério de "feito"
- [ ] [artefato 1 — ex: doc curto comparando opções]
- [ ] [artefato 2 — ex: decisão recomendada com tradeoffs]

## Notas iniciais
[contexto inicial, se houver]
```

### Labels applied
- `spike` (sempre)
- `research` (se a pergunta é claramente de pesquisa de viabilidade)
- `area/<X>` (se inferível)

---

## English variants

When the `in english` modifier is present, translate section headers and field labels:

| pt-br | en |
|---|---|
| Comportamento atual | Current behavior |
| Comportamento esperado | Expected behavior |
| Como reproduzir | Reproduction steps |
| Ambiente | Environment |
| Código relacionado | Related code |
| Notas | Notes |
| Critérios de aceite | Acceptance criteria |
| Fora de escopo | Out of scope |
| Dívida atual | Current debt |
| Risco se não fizer | Risk if not addressed |
| Proposta | Proposal |
| Escopo | Scope |
| Não-regressão | Non-regression |
| Pergunta | Question |
| Hipóteses | Hypotheses |
| Critério de "feito" | Done criteria |
| Notas iniciais | Initial notes |

The User Story format becomes: `As a [persona], I want [action], so that [value].`

Given/When/Then becomes: `Given [context], when [action], then [result].`
