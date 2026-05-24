---
description: Mostra o estado de todas as changes (ou de uma) lendo os frontmatters; deriva o estágio e sugere a próxima ação. Read-only.
argument-hint: [slug-opcional]
allowed-tools: Bash(find:*), Bash(grep:*), Bash(ls:*), Bash(cat:*), Bash(test:*), Bash(date:*), Bash(basename:*), Bash(sed:*), Read, Grep, Glob
---

# Comando /sdd-status

Você é o "kanban de terminal" do workflow Spec-Driven local. Sem board externo, o estado de cada change vive no frontmatter dos artefatos. Sua função é varrer `docs/changes/`, ler esses frontmatters, e apresentar uma visão clara de onde tudo está — destacando o que precisa de ação.

Argumento (slug opcional): `$ARGUMENTS`

Contexto:
- Data: !`date +%Y-%m-%d`
- Changes existentes: !`find docs/changes -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort || echo "(nenhuma)"`

---

## Regras

1. **Read-only.** Este comando NUNCA modifica arquivos, status, branches ou qualquer coisa. Só lê e apresenta.
2. **Rápido e compacto.** É um comando que se roda toda hora. A saída deve ser escaneável em segundos, não um relatório longo.
3. **Acionável.** Não basta mostrar o estado — diga qual é a próxima ação para cada change que precisa de uma.
4. **Tolerante a dados incompletos.** Artefato faltando ou frontmatter malformado não deve quebrar a visão; mostre `?` e siga.

---

## Fase 0 — Escopo

- Se `$ARGUMENTS` tem um slug: foque numa change só (`docs/changes/*-{slug}`), em modo **detalhado** (expanda as tasks).
- Se vazio: mostre **todas** as changes, em modo **resumo** (uma linha-síntese por change), agrupando por estágio.

---

## Fase 1 — Coletar estado

Rode este script para extrair os frontmatters relevantes de uma vez (ajuste o filtro de pasta se o escopo for um slug específico):

```bash
for dir in docs/changes/*/; do
  [ -d "$dir" ] || continue
  name=$(basename "$dir")
  echo "### $name"
  for f in README.md 00-idea.md 01-PRD.md 02-SPEC.md FIX.md NOTE.md; do
    if [ -f "$dir$f" ]; then
      st=$(grep -m1 -E '^status:' "$dir$f" 2>/dev/null | sed 's/status:[[:space:]]*//')
      kind=$(grep -m1 -E '^kind:' "$dir$f" 2>/dev/null | sed 's/kind:[[:space:]]*//')
      echo "  $f | status=${st:-?} kind=${kind:-}"
    fi
  done
  if [ -d "${dir}tasks" ]; then
    for t in "${dir}tasks"/*.md; do
      [ -f "$t" ] || continue
      id=$(grep -m1 -E '^id:' "$t" 2>/dev/null | sed 's/id:[[:space:]]*//')
      st=$(grep -m1 -E '^status:' "$t" 2>/dev/null | sed 's/status:[[:space:]]*//')
      par=$(grep -m1 -E '^parallelism:' "$t" 2>/dev/null | sed 's/parallelism:[[:space:]]*//')
      dep=$(grep -m1 -E '^depends_on:' "$t" 2>/dev/null | sed 's/depends_on:[[:space:]]*//')
      echo "  TASK ${id:-?} | status=${st:-?} par=${par:-?} deps=${dep:-[]}"
    done
  fi
done
```

Se o output for vazio, informe que não há changes ainda e sugira começar com `/sdd-new`. Encerre.

---

## Fase 2 — Derivar estágio e próxima ação

Para cada change, derive o **estágio atual** a partir dos status coletados, e a **próxima ação**. Use o prefixo da pasta (`feat-`/`fix-`/`chore-`) para saber o tipo.

**Para FEATURE:**

| Situação | Estágio | Próxima ação |
|---|---|---|
| Só `00-idea.md` | Ideia | `/sdd-prd {slug}` |
| PRD `draft` | Discovery | `/sdd-approve {slug}` para aprovar o PRD |
| PRD `approved`, sem SPEC | Pronto p/ Spec | `/sdd-spec {slug}` |
| SPEC `draft` | Spec | `/sdd-approve {slug}` para validar a SPEC |
| SPEC `validated`, sem tasks | Pronto p/ Tasks | `/sdd-tasks {slug}` |
| Tasks existem, PLAN-EXEC `draft` | Plano gerado | `/sdd-approve {slug}` para aprovar PLAN-EXEC + carimbar tasks |
| Tasks existem, PLAN-EXEC `approved`, nem todas tasks `done` | Implementação (X/N done) | `/sdd-run-all {slug}` |
| Alguma task `blocked` | Bloqueada | resolver o bloqueio da TASK-NNN |
| Todas as tasks `done`, change não entregue | Pronto p/ docs/merge | `/sdd-archive {slug}` |
| README `status: delivered` | Entregue | — |

**Para FIX / CHORE (legado):**

| Situação | Estágio | Próxima ação |
|---|---|---|
| Só `00-idea.md` (fix/chore) | Ideia | ⚠ fluxo rápido ainda não existe — tratar como feature (`/sdd-prd {slug}`) ou aguardar |
| `FIX.md`/`NOTE.md` presente | Em correção / manutenção | implementar manualmente; depois `/sdd-archive {slug}` |
| Entregue | Entregue | — |

---

## Fase 3 — Renderizar

Use ícones de status para leitura rápida:
- ✅ done / approved / validated / delivered
- 🔄 draft / in-progress
- ⏳ ready / pending
- 👀 in-review
- 🚫 blocked

**Modo resumo (todas as changes)** — agrupe por estágio, uma linha por change:

```
📋 Changes ativas

EM IMPLEMENTAÇÃO
  feat 2fa-totp        ▸ 2/4 tasks ✅✅⏳⏳     próximo: /sdd-run-all 2fa-totp

AGUARDANDO APROVAÇÃO
  feat export-pdf      ▸ PRD 🔄 draft          próximo: /sdd-approve export-pdf
  feat csv-import      ▸ PLAN-EXEC 🔄 draft    próximo: /sdd-approve csv-import

ENTREGUES (recentes)
  feat audit-log       ✅ entregue 2026-05-15
```

**Modo detalhado (um slug)** — expanda tudo:

```
feat 2fa-totp · Implementação (2/4)
  Branch: feat/2fa-totp

  00-idea     ✅
  PRD         ✅ approved (Filipe Souza)
  SPEC        ✅ validated · ADR-022
  PLAN-EXEC   ✅ approved (Filipe Souza)
  Tasks:
    ✅ TASK-001 foundation        (sequential)
    ✅ TASK-002 service-layer     (parallel, deps: 001)
    ⏳ TASK-003 http-layer        (parallel, deps: 001,002) — ready
    ⏳ TASK-004 middleware-admin  (parallel, deps: 001,002) — ready

  Próxima ação: /sdd-run-all 2fa-totp (retoma a partir de TASK-003)
```

Mantenha compacto. Não inclua conteúdo dos artefatos, só estados.

---

## Fase 4 — Destacar pendências

Ao final, se houver, liste em uma seção curta "⚠ Precisa de você":
- Tasks `blocked` (com a feature a que pertencem)
- Documentos em `draft` aguardando `/sdd-approve` (PRD, SPEC, PLAN-EXEC)

Se nada precisa de ação imediata, diga apenas "Nada pendente de você no momento."

---

## Notas de instalação

Salve como **`.claude/commands/sdd-status.md`**. Invoque com `/sdd-status` (visão geral) ou `/sdd-status {slug}` (detalhe).

`allowed-tools` é deliberadamente read-only (sem `Write`, sem `git` de escrita) — `/sdd-status` é seguro de rodar a qualquer momento e nunca altera estado. Essa é uma propriedade importante: você deve poder espiar o estado sem risco.

No loop de trabalho diário, `/sdd-status` não é passo obrigatório — ele brilha quando você volta ao projeto depois de um tempo, ou quando tem várias changes rolando e quer a visão cross-feature. É o "abrir o board", não uma etapa do pipeline.

Modelo recomendado: por ser leve (leitura + formatação), pode rodar em modelo barato. Adicione `model: claude-haiku-4-5-20251001` ao frontmatter se quiser garantir velocidade e custo baixo.
