---
description: Aprova documentos de uma change (PRD, SPEC, PLAN-EXEC) e registra quem aprovou. Quando aprova o PLAN-EXEC, também grava approved_by/approved_at em cada TASK da feature.
---

# Aprovar Documentos de uma Change

Este comando aprova **documentos** de uma change e registra quem aprovou. Transições de estado por tipo:

| Documento | Transição de status | Observação |
|---|---|---|
| PRD (`01-PRD.md`) | `draft` → `approved` | — |
| SPEC (`02-SPEC.md`) | `draft` → `validated` | é o estado que o `/sdd-tasks` exige |
| PLAN-EXEC (`03-PLAN-EXEC.md`) | `draft` → `approved` | aprova o plano gerado por `/sdd-tasks` |
| TASKs (`tasks/TASK-*.md`) | **status não muda** (segue `ready`) | só grava `approved_by`/`approved_at` para registrar quem liberou o lote |

Em todos os casos é gravado `approved_by` e `approved_at` no frontmatter.

Siga **exatamente** estes passos em ordem, sem pular nenhum.

---

## Passo 1 — Pedir o slug da change

Pergunte ao usuário:

> 🏷️ **Qual é o slug da change?** (ex: `busca-cpf-rg`, `export-inquerito-pdf`)

Aguarde a resposta. **Não fixe o prefixo** — uma change pode ser `feat-`, `fix-` ou `chore-`. Procure qualquer pasta em `docs/changes/` cujo nome termine com `-<slug informado>`:

```
docs/changes/{feat|fix|chore}-<ANO>-<MÊS-2-DÍGITOS>-<slug informado>
```

Use um glob como `docs/changes/*-<slug>` (ou liste o diretório e filtre por sufixo) para localizar a pasta. Exemplos válidos:
- slug `busca-cpf-rg` → `docs/changes/feat-2026-05-busca-cpf-rg`
- slug `export-inquerito-pdf` → `docs/changes/feat-2026-05-export-inquerito-pdf`

Se houver mais de uma pasta com o mesmo slug (raro — datas diferentes), liste as candidatas e pergunte qual aprovar.

---

## Passo 2 — Detectar o que está pendente de aprovação

Dentro da pasta resolvida, identifique os "itens aprováveis":

1. **Documentos em `status: draft`** — leia o frontmatter de cada `.md` na raiz da pasta (`01-PRD.md`, `02-SPEC.md`, `03-PLAN-EXEC.md`, `FIX.md` se existir). Filtre os que têm `status: draft`.

2. **TASKs pendentes de carimbo** — se a pasta tem `tasks/` E o `03-PLAN-EXEC.md` está em `draft`, considere o conjunto inteiro de TASKs como pendente (elas são aprovadas em bloco junto com o PLAN-EXEC). Se o PLAN-EXEC já está `approved`, as TASKs já foram carimbadas — não reaprove a menos que o usuário peça explicitamente.

**Se a pasta não existir:**
```
❌ Pasta não encontrada: nenhuma docs/changes/*-<slug>
```
Pare.

**Se nada está pendente:**
```
✅ Nada pendente de aprovação nesta change.
```
Pare.

**Se há itens pendentes**, exiba um menu numerado. Inclua TASKs como uma única linha quando o PLAN-EXEC também estiver na fila:

```
📂 docs/changes/feat-2026-05-export-inquerito-pdf

Pendente de aprovação:

  [1] 01-PRD.md           — <title do frontmatter, se houver>
  [2] 02-SPEC.md          — <title>
  [3] 03-PLAN-EXEC.md + TASKs (N tasks)  — aprova o plano e carimba as tasks
  [4] Todos acima

Qual deseja aprovar?
```

Se apenas um item está pendente, ainda assim mostre o menu (1 opção + "todos") para preservar o fluxo de confirmação.

Aguarde a escolha antes de continuar.

---

## Passo 3 — Pedir o nome do aprovador

Pergunte ao usuário:

> 👤 **Qual é o seu nome completo para o campo `approved_by`?**

Aguarde a resposta antes de continuar.

---

## Passo 4 — Determinar o estado-alvo de cada arquivo

Antes do preview, identifique o **estado-alvo** de cada arquivo selecionado, lendo o campo `type` do frontmatter:

| `type` no frontmatter | Estado-alvo | Observação |
|---|---|---|
| `prd` | `approved` | — |
| `spec` | `validated` | — |
| `plan` | `approved` | PLAN-EXEC |
| `task` | **inalterado** (segue `ready`) | só grava `approved_by` / `approved_at` |
| `change` com `kind: fix` (FIX.md) | `approved` | — |

Se o arquivo não tem `type` reconhecido, default para `approved` e avise no preview.

Quando o usuário selecionou "PLAN-EXEC + TASKs" (ou "todos acima"), expanda o conjunto de arquivos: o `03-PLAN-EXEC.md` recebe transição de status; cada `tasks/TASK-NNN-*.md` é tratado como tipo `task` (carimbo apenas).

---

## Passo 5 — Exibir preview e pedir confirmação

Mostre o preview **sem modificar nada ainda**, agrupando por tipo de mudança. Exemplo:

```
📋 Preview das alterações:

── 01-PRD.md ──────────────────────────────
  status: draft  →  status: approved
  approved_by:      "Filipe Souza"
  approved_at:      2026-05-23

── 02-SPEC.md ─────────────────────────────
  status: draft  →  status: validated
  approved_by:      "Filipe Souza"
  approved_at:      2026-05-23

── 03-PLAN-EXEC.md ────────────────────────
  status: draft  →  status: approved
  approved_by:      "Filipe Souza"
  approved_at:      2026-05-23

── tasks/ (4 arquivos) ────────────────────
  status: ready  (inalterado)
  approved_by:      "Filipe Souza"
  approved_at:      2026-05-23
  → TASK-001-foundation.md
  → TASK-002-service.md
  → TASK-003-http.md
  → TASK-004-middleware.md

Confirmar aprovação? (s/n)
```

Aguarde a confirmação antes de continuar.

---

## Passo 6 — Aplicar as alterações (somente se confirmado)

Se o usuário confirmar com "s" ou "sim":

Para **cada arquivo** selecionado:
1. Se o tipo tem transição de status (`prd`, `spec`, `plan`, `change` com `kind: fix`): substitua `status: draft` pelo estado-alvo conforme a tabela do Passo 4.
2. Se o tipo é `task`: **não mexa no campo `status`**.
3. Em todos os casos, adicione ou atualize os campos (logo abaixo de `status`):
   ```yaml
   approved_by: "<nome informado>"
   approved_at: <data de hoje YYYY-MM-DD>
   ```
4. **Não altere nenhuma outra parte do arquivo.**
5. Exiba confirmação compacta:
   ```
   ✅ 01-PRD.md aprovado (status: approved)
   ✅ 02-SPEC.md validado (status: validated)
   ✅ 03-PLAN-EXEC.md aprovado (status: approved)
   ✅ 4 TASKs carimbadas (status: ready inalterado)
   ```

Se o usuário responder "n" ou "não":
```
🚫 Operação cancelada. Nenhuma alteração foi feita.
```
