# Trigger Lexicon and Override Modifiers

## Activation phrases (case-insensitive, ignore punctuation)

The skill activates ONLY when the user's message contains one of these explicit imperative phrases. Substring match against the user's message after normalization (lowercase, collapsed whitespace).

### Portuguese (pt-br)
- `cria issue` · `cria uma issue` · `criar issue`
- `abre ticket` · `abre uma issue` · `abre uma task`
- `nova issue` · `nova task` · `novo ticket`
- `cria task`
- `manda pro linear` · `vamos pro linear`

### English
- `create issue` · `create a ticket` · `create an issue`
- `open an issue` · `open a ticket`
- `new linear issue` · `new ticket`

### Slash form
- `/issue` (anywhere in message; treat following text as the issue brief)

## Phrases that MUST NOT activate the skill

These are descriptive, not imperative. Do NOT activate even if the topic seems related.

- `tem um bug` · `existe um bug` · `é um bug`
- `essa feature` · `nessa feature` · `tem uma feature`
- `isso é dívida técnica` · `é tech debt`
- Any phrase that mentions a bug/feature/improvement without explicit create-intent verbs from the activation list above.

If the user describes a problem in passing during a different task (e.g., "tem um bug nessa função, mas vamos focar em X"), do not interrupt with this skill.

## Issue type detection (verb → type)

Apply after activation. Match against the user's brief (the part of the message after the trigger phrase).

| Verb cue (pt-br / en) | Type |
|---|---|
| `está quebrado` · `dando erro` · `não funciona` · `bugado` · `quebrou` · `zera` · `apaga` · `perde` · `some` · `desaparece` · `is broken` · `is failing` · `crashing` · `errors out` · `clears` · `loses` · `vanishes` | **bug** |
| `quero adicionar` · `implementar` · `criar nova` · `vamos adicionar` · `add` · `implement` · `create a new` · `build` | **feature** |
| `refatorar` · `limpar` · `remover legado` · `migrar` · `consolidar` · `refactor` · `clean up` · `remove legacy` · `migrate` | **tech-debt** |
| `investigar` · `descobrir` · `explorar` · `entender se` · `pesquisar` · `investigate` · `explore` · `spike on` · `find out if` | **spike** |
| Ambiguous or no verb cue | ASK once |

When ambiguous, ask exactly: "É bug, feature, tech-debt ou spike?". Wait for one-word answer. Do NOT guess.

## Inline override modifiers (parsed from user's message)

Modifiers can appear anywhere in the brief. Extract and remove from the brief before applying templates.

**Disambiguation rule:** modifiers whose keyword could appear naturally inside an issue brief (`label`, `assignee`) MUST use a sigil prefix (`--`) or bracket form (`[key: value]`) to be recognized. Bare keywords are treated as content, not as modifiers. This avoids stripping the word "label" or "assignee" out of legitimate problem descriptions like "label aparece errado no checkout".

| Pattern (regex-like) | Effect |
|---|---|
| `\bgo\b$` or `cria já$` or `--no-preview$` | Skip preview, post directly |
| `in english$` or `--en$` | Generate issue title and body in English |
| `em <TEAM_KEY>` (e.g., `em ENG`, `em SAL`) | Override default team |
| `no projeto <NAME>` or `in project <NAME>` | Override default project |
| `--label <NAME>` or `[label: <NAME>]` (repeatable) | Append additional label by leaf name |
| `--assignee <NAME>` or `[assignee: <NAME>]` or `pra @<user>` | Override default assignee |
| `inclui trecho de <FUNC>` or `include snippet of <FUNC>` | Embed code snippet for that function (best-effort) in `## Código relacionado` |
| `aprofunda` (during draft confirmation) | Enter deep interview, regenerate draft |
| `severidade alta` / `urgent` / `bloqueia` (bug only) | Set severity field accordingly |

**Examples that DO trigger modifiers:**
- `cria issue: filtro do checkout zera o estado --label backend --assignee fulano go`
- `cria issue: feature de export CSV [label: frontend] [assignee: maria]`
- `cria issue: bug urgent no login pra @joao`

**Examples that DO NOT trigger modifiers (bare keywords stay as content):**
- `cria issue: o label aparece errado no carrinho` → "label" is part of the problem description, not a modifier.
- `cria issue: o assignee não está recebendo notificação` → "assignee" stays in the brief.
- `cria issue: bug no botão "Add Label"` → bare "Label" without `--` or `[]` is content.

## Path detection (auto-link, no opt-in needed)

Apply path-like regex to the user's brief (case-sensitive):

```
(?:[a-zA-Z0-9_\-./]+)?(?:src|apps|packages|lib|tests|specs|cmd|internal|pkg)/[a-zA-Z0-9_\-./]+\.[a-zA-Z]{1,5}
```

For each matched path:
1. Verify the file exists in current working directory.
2. If exists, run `scripts/code-context.sh <path>` to produce the markdown block.
3. Append to the issue body under `## Código relacionado` heading.

If a matched path does not exist, ignore silently (no false positives).
