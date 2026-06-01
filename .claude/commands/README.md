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
2. **Rode `/sdd-analyze`** — descobre a stack, mapeia a arquitetura, extrai patterns reais do seu código e ativa as skills da(s) stack(s). É o passo que faz a IA gerar código no padrão do seu projeto em vez de genérico. Em projeto novo (vazio), ele redireciona pro `/sdd-init` e você roda o analyze depois que houver código.
3. Revise o `docs/constitution.md` gerado e qualquer skill auto-gerada via web (vêm marcadas pra revisão).
4. Coloque os comandos em `.claude/commands/` e as skills em `.claude/skills/` (versionados, compartilhados com o time).
5. (Opcional) Configure preview do VitePress/Fumadocs em PRs, se quiser revisão renderizada.

> Quando o projeto evoluir (deps novas, módulo novo), rode `/sdd-analyze --incremental` — ele atualiza só o que mudou.

---

## Skills de stack (anti-alucinação)

O que mais faz a IA alucinar não é falta de boas práticas universais — é não saber **como este projeto específico escreve**. O SDD ataca isso em duas camadas:

- **Skills de stack** em `.claude/skills/stacks/<nome>/` — base de conhecimento técnico por stack (`SKILL.md` com golden rules + `references/` sobre arquitetura, convenções, testes). Vêm 5 curadas: `typescript`, `react`, `svelte`, `node-typescript`, `php-laravel`. Stacks não cobertas são sintetizadas da web pelo `/sdd-analyze` (marcadas `auto-gerada`).
- **Patterns reais** em `docs/patterns/<stack>/` — esqueletos extraídos do **seu** código pelo `/sdd-analyze`. Quando há conflito, o pattern do projeto vence a regra universal da skill.

Os comandos `/sdd-spec`, `/sdd-tasks`, `/sdd-run-all`, `/sdd-direct` e `/sdd-direct-close` carregam skill + patterns antes de gerar/implementar. Sem `/sdd-analyze`, eles ainda funcionam — só geram código mais genérico e avisam.

---

## Comandos

| Comando | O que faz |
|---|---|
| `/sdd-init` | Inicializa um projeto novo: gera `constitution.md`, `AGENTS.md` e os atalhos na raiz para os agentes IA escolhidos |
| `/sdd-analyze [--incremental]` | Analisa o projeto em 5 camadas (identidade, arquitetura, dados, patterns reais, convenções), ativa skills da stack (locais ou da web) e materializa a base de conhecimento que o fluxo usa para não alucinar |
| `/sdd-status [slug]` | Mostra onde cada change está e qual a próxima ação (read-only) |
| `/sdd-new <texto>` | Entrevista curta, classifica em feat/fix/chore e cria o `00-idea.md` |
| `/sdd-prd <slug>` | Gera o PRD (requisitos de negócio) com pesquisa na codebase e web |
| `/sdd-approve <slug>` | Aprova documentos da change (PRD, SPEC, PLAN-EXEC) — grava `approved_by`/`approved_at` e, no caso do PLAN-EXEC, carimba todas as tasks |
| `/sdd-spec <slug>` | Gera a SPEC (plano técnico) + ADRs, com estratégia de rollback |
| `/sdd-tasks <slug>` | Decompõe a SPEC em tasks pequenas com dependências, paralelismo e gera o `03-PLAN-EXEC.md` |
| `/sdd-run-all <slug>` | Executa todas as tasks sequencialmente, 1 commit por task, sem pausa entre elas. **Retomável.** |
| `/sdd-archive <slug>` | Fecha a change: dossiê final, sincroniza docs e atualiza CHANGELOG |
| `/sdd-direct <descrição>` | **Fast path** — pula PRD/SPEC/tasks/approve, cria branch + nota WIP e começa a implementar direto |
| `/sdd-direct-close [slug]` | Fecha o fast path — engenharia reversa do diff/commits para materializar PRD, SPEC, tasks (1 por commit), ADRs e CHANGELOG retroativamente |

> Fluxos rápidos para fix e chore ainda não existem nesta versão. Todas as changes passam pelo fluxo de feature por enquanto. Um fluxo dedicado para bugs/pequenas alterações será reintroduzido depois.

---

## Fluxo único — Feature

```bash
/sdd-init                                     # uma vez por projeto
/sdd-analyze                                  # uma vez por projeto (re-rode com --incremental quando mudar)
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

## Fluxo rápido — Fast path (direct)

Para mudanças pequenas/médias onde você já sabe o que fazer e não precisa de discovery, ADR explícito ou decomposição prévia:

```bash
/sdd-direct "alterar foto no perfil do usuário"   # cria feat/perfil-foto + nota WIP
                                                  # você (ou a IA) implementa direto, commita por escopo
                                                  # cada commit deve ter mensagem clara — vira 1 TASK retroativa
/sdd-direct-close perfil-foto                     # engenharia reversa do diff: gera PRD, SPEC, tasks (1 por commit),
                                                  # ADRs se houver, README delivered, CHANGELOG. Remove nota WIP.
# merge final na main (squash) — igual ao fluxo normal
```

A change resultante é **indistinguível** de uma que passou pelo fluxo completo, exceto por marcas visíveis (`mode: direct`, `note: gerado retroativamente`, `(via fast path)` no CHANGELOG) — honestidade documental.

**Quando usar fast path:** problema claro, escopo conhecido, sem decisão arquitetural durável.
**Quando NÃO usar:** discovery de negócio (PRD com pesquisa), decisão de stack/arquitetura que merece debate prévio, coordenação entre múltiplas pessoas.

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

Você descreve o que quer (`/sdd-new`), valida o plano que a IA propõe a cada etapa com `/sdd-approve` (`/sdd-prd` → `/sdd-spec` → `/sdd-tasks`), e deixa a IA implementar em batch autônomo (`/sdd-run-all`), fechando com a documentação em dia (`/sdd-archive`). O Git e os arquivos guardam todo o histórico — sem board, sem ferramenta externa.
