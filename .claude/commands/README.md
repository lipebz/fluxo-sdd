# SDD — Spec-Driven Development

> Fluxo de desenvolvimento com IA, local-first, onde cada mudança no sistema nasce de uma especificação versionada e termina em documentação atualizada. Sem board externo — o estado vive nos arquivos.

---

## O que é

O SDD transforma cada alteração no código em uma **change** rastreável, que passa por etapas claras: ideia → especificação → tasks → implementação → documentação. Agentes de IA (Claude Code, Codex, Gemini) executam cada etapa via comandos `/`, sempre dentro de trilhos definidos por você.

O objetivo: aproveitar a velocidade da IA sem perder controle, rastreabilidade nem documentação.

---

## Conceitos-chave

- **Change** — qualquer alteração no sistema. Nesta versão, todas as changes passam pelo fluxo completo de feature. (Fluxos rápidos para fix e chore voltarão em outra iteração.)
- **Artefatos** — arquivos `.md` versionados que descrevem a change: ideia, PRD, SPEC, plano de execução, tasks. São a fonte de verdade.
- **Estado no frontmatter** — não há board. O `status` no YAML de cada arquivo é onde a change "está".
- **Branch por change** — toda change vive em sua própria branch (`feat/slug`, `fix/slug`, `chore/slug`). A `main` recebe um commit limpo por change no final.
- **Constitution** — `docs/constitution.md` define a identidade do projeto e as regras imutáveis (stack, modelo de dados, segurança, anti-alucinação).
- **AGENTS.md** — `docs/AGENTS.md` traz as instruções operacionais que todo agente de IA lê no boot (como rodar, fluxo SDD, checklist pré-entrega). Atalhado na raiz como `CLAUDE.md` / `CODEX.md` / `GEMINI.md` / `AGENTS.md`, dependendo das ferramentas usadas.
- **Patterns** — `docs/patterns/` tem exemplares reais do seu código. A IA aprende por exemplo, não por regra abstrata.

---

## Estrutura de pastas

```
docs/
├── CHANGELOG.md                    # registro de tudo que foi entregue
├── constitution.md                 # identidade e regras do projeto
├── AGENTS.md                       # instruções operacionais para agentes IA
├── patterns/                       # exemplares canônicos (Service, Controller…)
├── adr/                            # decisões arquiteturais (ADR-001…)
├── guides/                         # como usar (how-to)
├── reference/                      # API, permissions, schemas
└── changes/
    └── feat-2026-05-minha-feature/
        ├── README.md               # dossiê vivo da change
        ├── 00-idea.md
        ├── PRD.md
        ├── SPEC.md
        └── tasks/
            ├── TASK-001-*.md
            └── TASK-002-*.md

# Na raiz do projeto (gerados por /sdd-init como atalhos ao docs/AGENTS.md):
CLAUDE.md     # auto-carregado pelo Claude Code
AGENTS.md     # padrão aberto (Codex, Cursor, Jules…)
CODEX.md      # opcional
GEMINI.md     # opcional
```

---

## Instalação em um projeto

O kit é só arquivos `.md` em `.claude/` — sem build, sem dependência. Use o instalador (recomendado) ou copie à mão.

### Instalador (recomendado)

```bash
# da raiz do seu projeto:
curl -fsSL https://raw.githubusercontent.com/lipebz/fluxo-sdd/main/install.sh | bash

# ou, se já clonou este repo:
bash /caminho/do/fluxo-sdd/install.sh /caminho/do/seu-projeto
```

O `install.sh` clona o kit do GitHub e copia `commands/` e `skills/` para o `.claude/` do projeto, de forma segura: nunca apaga skills próprias do seu projeto, faz backup (`.bak-TIMESTAMP`) de qualquer arquivo que já exista e difira, e mescla o `.claude/.gitignore` em vez de sobrescrever. Rodar de novo é idempotente.

### À mão

```bash
git clone https://github.com/lipebz/fluxo-sdd.git /tmp/fluxo-sdd
mkdir -p .claude
cp -r /tmp/fluxo-sdd/.claude/commands .claude/
cp -r /tmp/fluxo-sdd/.claude/skills   .claude/
cp /tmp/fluxo-sdd/.claude/.gitignore  .claude/.gitignore
```

> O `.claude/.gitignore` garante que `commands/` e `skills/` sejam versionados (compartilhados com o time). Se o seu projeto já tem um, mescle as regras `!commands/` e `!skills/`.

---

## Setup inicial (uma vez só)

1. Rode `/sdd-init` — gera `docs/constitution.md`, `docs/AGENTS.md` e os atalhos na raiz (`CLAUDE.md`, `AGENTS.md`, etc.) para os agentes que você usa.
2. Rode `/sdd-analyze` — analisa a codebase (stack, arquitetura, modelo de dados, patterns reais, convenções) e preenche `docs/constitution.md` e `docs/patterns/` automaticamente. Em projetos com código existente, substitui o passo manual abaixo.
3. Revise `docs/constitution.md` — confirme identidade, modelo de dados e regras anti-alucinação detectadas. Preencha o que o analyze deixou como `[a confirmar]`.
4. [Opcional, se não rodou `/sdd-analyze`] Crie 3-4 arquivos em `docs/patterns/` apontando para exemplares reais do seu código.
5. Coloque os comandos em `.claude/commands/` (versionados, compartilhados com o time).
6. (Opcional) Configure preview do VitePress/Fumadocs em PRs, se quiser revisão renderizada.

---

## Comandos

| Comando | O que faz |
|---|---|
| `/sdd-init` | Inicializa um projeto novo: gera `constitution.md`, `AGENTS.md` e os atalhos na raiz para os agentes IA escolhidos |
| `/sdd-analyze [--incremental] [caminho]` | Analisa o projeto em profundidade (5 camadas: identidade, arquitetura, dados, patterns reais, convenções); ativa skills da stack detectada; preenche `docs/constitution.md` e `docs/patterns/` automaticamente. `--incremental` re-analisa só o que mudou desde a última execução |
| `/sdd-status [slug]` | Mostra onde cada change está e qual a próxima ação (read-only) |
| `/sdd-new <texto>` | Entrevista curta, classifica em feat/fix/chore e cria o `00-idea.md` |
| `/sdd-prd <slug>` | Gera o PRD (requisitos de negócio) com pesquisa na codebase e web |
| `/sdd-approve <slug>` | Aprova documentos da change (PRD, SPEC, PLAN-EXEC) — grava `approved_by`/`approved_at` e, no caso do PLAN-EXEC, carimba todas as tasks |
| `/sdd-spec <slug>` | Gera a SPEC (plano técnico) + ADRs, com estratégia de rollback |
| `/sdd-tasks <slug>` | Decompõe a SPEC em tasks pequenas com dependências, paralelismo e gera o `03-PLAN-EXEC.md` |
| `/sdd-run-all <slug>` | Executa todas as tasks sequencialmente, 1 commit por task, sem pausa entre elas. **Retomável.** |
| `/sdd-archive <slug>` | Fecha a change: dossiê final, sincroniza docs e atualiza CHANGELOG |
| `/sdd-direct <texto>` | **Fluxo Direto:** pula PRD/SPEC/tasks/approve e começa a implementar direto em branch `feat/{slug}`. Documentação materializada retroativamente pelo `/sdd-direct-close`. Indicado para mudanças pequenas/médias onde o problema já está claro |
| `/sdd-direct-close <slug>` | Fecha uma change iniciada com `/sdd-direct` — faz engenharia reversa do diff e commits para materializar PRD, SPEC, tasks (1 por commit), README e CHANGELOG retroativamente, tudo já em estado terminal. Remove a nota WIP |

> Fluxos rápidos para fix e chore ainda não existem nesta versão. Todas as changes passam pelo fluxo de feature por enquanto. Um fluxo dedicado para bugs/pequenas alterações será reintroduzido depois.

---

## Fluxo Completo — Feature

```bash
/sdd-init                                     # uma vez por projeto
/sdd-analyze                                  # analisa codebase → preenche constitution + patterns
/sdd-status                                       # qualquer hora (read-only)

/sdd-new "adicionar exportação CSV"             # → 00-idea.md
/sdd-prd exportacao-csv                           # → 01-PRD.md (draft)
/sdd-approve exportacao-csv                       # → PRD approved + approved_by/approved_at
/sdd-spec exportacao-csv                          # → 02-SPEC.md + ADRs (draft)
/sdd-approve exportacao-csv                       # → SPEC validated + approved_by/approved_at
/sdd-tasks exportacao-csv                         # → TASK-001…N + 03-PLAN-EXEC.md (draft)
/sdd-approve exportacao-csv                       # → PLAN-EXEC approved + carimba todas as tasks
/sdd-run-all exportacao-csv                       # roda tudo: TASK-001 → 002 → 003 → …
                                              # 1 commit por task; retomável
/sdd-archive exportacao-csv                       # dossiê + docs + changelog
# merge final na main (squash)
```

O `/sdd-run-all` percorre o DAG em ordem topológica, in-place na `feat/{slug}`. Só **para** em ambiguidade real, teste sem solução, `files_touched` violation, ou dependência não satisfeita. Quando você resolve e roda de novo, ele **retoma de onde parou**.

---

## Fluxo Direto — mudanças pequenas/médias

Quando você já sabe o que fazer e não precisa de PRD, SPEC ou decomposição prévia:

```bash
/sdd-direct "corrigir bug no cálculo de desconto"
# → cria feat/{slug}, nota WIP efêmera, carrega stack e implementa
# commite por escopo coeso — cada commit vira 1 TASK retroativa

/sdd-direct-close desconto-bug
# → PRD/SPEC/tasks/CHANGELOG retroativos já em estado terminal
# → nota WIP removida
# merge final na main (squash)
```

Use o **Fluxo Completo** para mudanças grandes, decisões arquiteturais (ADR), ou quando há discovery de negócio. Use o **Fluxo Direto** para tudo que "você já sabe como fazer".

**Trade-offs aceitos:**
- Sem PRD aprovado antes de codar — sem rede de segurança de negócio.
- Sem SPEC antes de codar — sem ADR explícito (ainda pode ser gerado no close).
- Sem `files_touched` declarado — você toca onde precisar; o close reconstrói a partir do diff.

---

## Regras de ouro

1. **A SPEC é a fonte de verdade.** O código materializa a spec.
2. **Contexto enxuto.** Cada etapa é uma janela nova, só com o necessário.
3. **`files_touched` é fronteira dura.** Um agente nunca toca arquivo fora do escopo da task.
4. **Pare em ambiguidade.** A IA pergunta em vez de inventar.
5. **Teste é intocável.** Nunca deletar/comentar/skipar para fazer outro passar.
6. **Recurso compartilhado → sequencial.** Migrations, rotas e configs globais não rodam em paralelo.
7. **Rollback não é opcional.** Toda SPEC responde "como desfazer".
8. **Doc anda junto.** Nenhuma change fecha sem `/sdd-archive`.
9. **Manual antes de automático.** Só automatize o que doeu 3 vezes.
10. **Aprovação registrada.** Antes do `/sdd-run-all`, o PRD, a SPEC e o PLAN-EXEC passam por `/sdd-approve` — cada um grava quem aprovou e quando. É o que dá rastreabilidade ao plano.

---

## Estados (referência rápida)

| Artefato | Estados |
|---|---|
| PRD | `draft` → `approved` |
| SPEC | `draft` → `validated` |
| PLAN-EXEC | `draft` → `approved` |
| TASK | `ready` → `in-progress` → `in-review` → `done` (ou `blocked`) — o carimbo de aprovação fica em `approved_by`/`approved_at`, status não muda no `/sdd-approve` |
| Change (README) | `draft` → `in-progress` → `delivered` |

Rode `/sdd-status` a qualquer momento para ver tudo de uma vez.

---

## Em uma frase

Você descreve o que quer (`/sdd-new`), valida o plano que a IA propõe a cada etapa com `/sdd-approve` (`/sdd-prd` → `/sdd-spec` → `/sdd-tasks`), e deixa a IA implementar em batch autônomo (`/sdd-run-all`), fechando com a documentação em dia (`/sdd-archive`). Para mudanças pequenas onde você já sabe o que fazer, o Fluxo Direto (`/sdd-direct` → implementar → `/sdd-direct-close`) pula as etapas de descoberta e materializa a documentação retroativamente. O Git e os arquivos guardam todo o histórico — sem board, sem ferramenta externa.
