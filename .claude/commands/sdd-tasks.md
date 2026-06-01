---
description: Decompõe uma SPEC validada em tasks pequenas com files_touched, depends_on, shared_resources e DoD; marca paralelismo automaticamente
argument-hint: <slug-da-feature>
allowed-tools: Bash(git:*), Bash(date:*), Bash(find:*), Bash(ls:*), Bash(wc:*), Bash(test:*), Bash(shasum:*), Bash(sha256sum:*), Bash(awk:*), Read, Grep, Glob, Write
---

# Comando /sdd-tasks

Você decompõe uma **SPEC validada** em **tasks de implementação**, no workflow Spec-Driven local. Cada task é uma unidade pequena, testável, com fronteira de arquivos explícita (`files_touched`) e dependências declaradas (`depends_on`). O paralelismo é calculado automaticamente a partir dos recursos compartilhados. As tasks são só arquivos `.md` — não há board nem issues neste fluxo.

Argumento recebido (slug): `$ARGUMENTS`

Contexto carregado automaticamente:
- Branch atual: !`git branch --show-current`
- Data: !`date +%Y-%m-%d`
- Features candidatas: !`find docs/changes -maxdepth 1 -type d -name 'feat-*' 2>/dev/null || echo "(nenhuma)"`

---

## Regras gerais

1. **Uma task = uma unidade coesa.** Uma camada (dados, lógica, http) ou um domínio. Nunca misture domínios diferentes na mesma task, nunca misture refactor de código não-tocado com feature nova.
2. **`files_touched` é a fronteira dura.** Toda task declara exatamente os arquivos que pode tocar. Tasks que rodam em paralelo NÃO podem compartilhar arquivos em `files_touched`.
3. **Recurso compartilhado → sequential.** Migrations, seeds estruturais, configs globais (`.env`, settings), filas/Redis/S3/storage, arquivos centrais de roteamento, containers/providers globais — qualquer arquivo ou recurso que múltiplas tasks tocariam ao mesmo tempo. Toda task que toca isso é `parallelism: sequential` e declara em `shared_resources`. Veja o constitution (`docs/constitution.md`) e o `SKILL.md` da stack para a lista específica de recursos compartilhados do projeto.
4. **Tasks pequenas.** Máximo ~200 linhas de spec por task, máximo ~10 arquivos em `files_touched`, máximo ~4h de implementação humana equivalente. Estourou qualquer limite → quebre em mais tasks.
5. **Toda task carrega seu DoD.** Definition of Done embutido, não documento separado.
6. **Não implemente.** Este comando só gera os arquivos de task.

---

## Fase 0 — Resolver a feature

1. Localize a pasta `docs/changes/feat-*-{slug}` a partir de `$ARGUMENTS`.
2. Se vazio ou ambíguo, liste candidatas e pergunte. Encerre o turno.
3. Confirme que há `02-SPEC.md` na pasta. Se não, oriente a rodar `/sdd-spec {slug}` primeiro. Encerre.

---

## Fase 1 — Validar pré-condições

1. **Tipo:** `kind: feature` no frontmatter. Fix/chore não passam por `/sdd-tasks` (fix é uma unidade só, no FIX.md). Redirecione e encerre se for o caso.
2. **SPEC validada:** confira `status` no frontmatter do `02-SPEC.md`.
   - `validated`: prossiga.
   - `draft`: avise — "A SPEC está em `draft`. Revise as decisões técnicas e mude `status: validated` antes de decompor. Quer validar agora ou prosseguir mesmo assim (não recomendado)?" Encerre e espere decisão.
3. **Tasks existentes:** se já houver `tasks/` com arquivos, avise e pergunte se deseja regenerar (isso descarta a decomposição anterior).

---

## Fase 2 — Carregar contexto

Leia:
1. `02-SPEC.md` — especialmente a seção **"Arquivos a criar/modificar"**, que é o insumo principal da decomposição.
2. `01-PRD.md` — para entender os objetivos (uma task nunca deve existir sem servir a um objetivo).
3. **Constitution** — `docs/constitution.md` (ou `docs/explanation/constitution.md` em layouts antigos): **especialmente a seção de paralelismo/recursos compartilhados.** É a regra que determina o que é `sequential`. Internalize a lista de recursos compartilhados do projeto.
4. **Skill de arquitetura das stacks ativas** — para decompor por camada corretamente, você precisa saber como a stack organiza as camadas. Leia a seção `## Active Stacks` do constitution; para cada stack ativa, leia `.claude/skills/stacks/<skill>/references/architecture.md`. É o que diz se "foundation → lógica → HTTP" mapeia para `migration → service → controller` (Laravel), `domain → use-case → handler` (node-typescript), `route → load → component` (svelte), etc. Sem `## Active Stacks`, decomponha pela estrutura visível na SPEC e avise que `/sdd-analyze` daria decomposição mais precisa.

---

## Fase 3 — Decompor (a lógica central)

Transforme a lista de arquivos da SPEC em tasks seguindo estes princípios, nesta ordem de raciocínio:

**1. Agrupe por camada/coesão.** Arquivos que mudam juntos e formam uma unidade testável viram uma task. Padrão típico de decomposição (adapte ao que a SPEC pede):
- **Foundation** — migration, model, instalação de lib, config/flag, permissions. Quase sempre a primeira task.
- **Lógica de negócio** — Services, DTOs, regras. Depende da foundation.
- **HTTP** — Controllers, Form Requests, Views, rotas. Depende de foundation + lógica.
- **Transversais** — Middlewares, comandos, jobs, ações de admin. Dependem de foundation + lógica.

**2. Estabeleça as dependências (`depends_on`).** Uma task B depende de A se B precisa de algo que A cria. Foundation tipicamente não depende de nada; as demais dependem dela. Use os IDs (`TASK-001`), não nomes de arquivo. `depends_on` é um array — uma task pode depender de várias.

**3. Marque recursos compartilhados e paralelismo.**
- Para cada task, liste em `shared_resources` qualquer recurso compartilhado que ela toca (migration, arquivo central de rotas, config global, seeder, etc — termos exatos variam por stack; veja a constitution).
- Se `shared_resources` não está vazio → `parallelism: sequential`.
- Se está vazio E os `files_touched` não colidem com nenhuma task irmã (mesmo nível de dependência) → `parallelism: parallel`.

**4. Garanta não-sobreposição entre paralelas.** Tasks que podem rodar ao mesmo tempo (mesmo conjunto de `depends_on`, ambas `parallel`) NÃO podem ter arquivos em comum no `files_touched`. Se duas tasks paralelas precisam tocar o mesmo arquivo, ou você as serializa (uma depende da outra), ou move o arquivo compartilhado para uma task de foundation que ambas dependem.

**5. Respeite os limites.** Se uma task passa de ~10 arquivos ou ~4h estimadas, quebre. Atribua `estimated_complexity` (small/medium/large) honestamente — large é sinal de que talvez devesse ser duas tasks.

---

## Fase 3.5 — Calcular hashes de drift (PRD e SPEC)

As tasks nascem amarradas à versão do PRD e da SPEC que as geraram. Se o PRD/SPEC mudar depois (alguém edita a SPEC mas não regenera as tasks), as tasks ficam órfãs — implementando um plano que não bate mais com a fonte. Para detectar isso, grave o hash do PRD e da SPEC no frontmatter de **toda** task.

Compute uma vez (o mesmo valor vai em todas as tasks deste lote):

```bash
shasum -a 256 docs/changes/{pasta}/01-PRD.md | awk '{print $1}'
shasum -a 256 docs/changes/{pasta}/02-SPEC.md | awk '{print $1}'
```

(Se `shasum` não existir, use `sha256sum`.)

Use os valores nos campos `prd_hash` e `spec_hash` do template abaixo. Eles são lidos por `/sdd-run-all` (antes de executar) e `/sdd-status` (relatório) para avisar de drift. Não bloqueiam — só alertam.

---

## Fase 4 — Gerar os arquivos de task

Crie a pasta `docs/changes/{pasta}/tasks/` e, dentro, um arquivo por task: `TASK-NNN-{slug-curto}.md` (NNN com zero-padding: 001, 002...). Use este template:

```markdown
---
type: task
id: TASK-NNN
slug: {slug-da-feature}
spec: ../02-SPEC.md
parallelism: parallel | sequential
depends_on: [TASK-001]          # array de IDs; [] se nenhuma
status: ready
estimated_complexity: small | medium | large
files_touched:                   # OBRIGATÓRIO, não-vazio
  - {caminho/exato/arquivo.ext}
  - {caminho/com/wildcard/*}
shared_resources: []             # migration, rotas centrais, config, seeder... ou []
prd_hash: {sha256-do-01-PRD.md}  # detecção de drift — ver Fase 3.5
spec_hash: {sha256-do-02-SPEC.md}
---

# TASK-NNN — {Título curto da task}

## Objetivo
{o que esta task entrega, em 1-3 frases; qual objetivo do PRD/SPEC ela serve}

## Pré-condição
{o que precisa estar pronto — derive de depends_on; "nenhuma" se sem deps}

## Escopo (o que fazer)
{passos concretos derivados da SPEC, restritos aos files_touched}

## Restrições
- NÃO tocar arquivos fora de files_touched
- NÃO {coisas específicas que pertencem a outras tasks, ex: "criar endpoints — isso é TASK-003"}

## Critérios de aceite
- [ ] {condição verificável}
- [ ] ...

## DoD
- [ ] Critérios de aceite marcados
- [ ] Quality gate passando — testes (em banco isolado se a task tocar dados) **OU**, se o projeto não tem testes (ver constitution §7), o gate real: type-check / `check` / `lint` / `build`
- [ ] Sem TODO temporário
- [ ] Observabilidade adicionada onde a SPEC pede
- [ ] Segurança: conforme constitution (authorize via Policy/auth, inputs validados)
- [ ] ADR referenciada se a task materializa uma decisão registrada
- [ ] files_touched bate com o diff
- [ ] Nenhum teste deletado/comentado/skipado sem justificativa (N/A se projeto sem testes)
- [ ] Doc: deferida para /sdd-archive no fim da feature
```

Mantenha cada arquivo abaixo de ~200 linhas.

---

## Fase 4.5 — Gerar o plano de execução (`03-PLAN-EXEC.md`)

Após validar o conjunto de tasks, gere um arquivo `03-PLAN-EXEC.md` na raiz `docs/changes/{pasta}/` que documente o **plano de execução em lotes**. Este arquivo é o mapa de roteamento que guia a implementação e a orquestração automática.

**Passos:**

1. **Calcule os lotes** a partir do grafo de dependências:
   - Lote 1: todas as tasks sem `depends_on` (geralmente foundation).
   - Lote N+1: todas as tasks cujas dependências foram satisfeitas no lote N. Se várias tasks têm as mesmas dependências satisfeitas E `parallelism: parallel`, agrupam-se no mesmo lote (rodam em paralelo).

2. **Gere um diagrama Mermaid** representando o DAG (directed acyclic graph) de dependências. Exemplo:
   ```mermaid
   graph TD
     T1["TASK-001<br/>(foundation)"]
     T2["TASK-002<br/>(logic)"]
     T3["TASK-003<br/>(http)"]
     T4["TASK-004<br/>(logic)"]
     T1 --> T2
     T1 --> T4
     T2 --> T3
     T4 --> T3
   ```

3. **Use este template:**

```markdown
---
type: plan
slug: {slug-da-feature}
status: draft
spec: ../02-SPEC.md
generated_at: {data-e-hora}
total_lotes: N
approved_by: null
approved_at: null
---

# PLAN-EXEC — {Título da feature}

## Resumo executivo

- **Total de tasks:** N
- **Total de lotes:** N
- **Paralelismo:** até M tasks simultâneas (lote com maior paralelismo)
- **Tempo estimado:** ~{soma dos lotes, reconhecendo paralelismo} (humano equivalente)
- **Crítico:** {lista de tasks no caminho crítico, ou "nenhum"}

---

## Lotes de execução

### Lote 1 — Foundation
**Tasks:** TASK-001 (sequential)  
**Paralelismo:** 1 task  
**Depende de:** nada  
**Tempo estimado:** ~2h  
**Observação:** Cria estrutura base; todas as demais dependem dela.

### Lote 2 — Lógica de negócio
**Tasks:** TASK-002, TASK-004 (parallel)  
**Paralelismo:** 2 tasks simultâneas  
**Depende de:** Lote 1  
**Tempo estimado:** ~3h  
**Observação:** Rodam em paralelo — nenhuma colisão de arquivos.

### Lote 3 — HTTP
**Tasks:** TASK-003 (sequential)  
**Paralelismo:** 1 task  
**Depende de:** Lote 2  
**Tempo estimado:** ~1h  

---

## Grafo de dependências

\`\`\`mermaid
graph TD
  T1["TASK-001<br/>Foundation"]
  T2["TASK-002<br/>Lógica A"]
  T3["TASK-003<br/>HTTP"]
  T4["TASK-004<br/>Lógica B"]
  T1 --> T2
  T1 --> T4
  T2 --> T3
  T4 --> T3
\`\`\`

---

## Observações

- {Se houver tasks `large`: "TASK-NNN foi marcada como `large` — revisar se vale quebrar em subtasks"}
- {Se houver recursos compartilhados: "Tarefas sequenciais (TASK-NNN, TASK-MMM) compartilham recursos — ordem respeitada"}
- {Qualquer outra observação sobre viabilidade ou risco}

---

## Execução

- `/sdd-run-all {slug}` — executor autônomo: roda todas as tasks em sequência, 1 commit por task, sem pausa. Retomável.
```

Mantenha o arquivo abaixo de ~150 linhas (é referência rápida, não especificação completa).

---

## Fase 5 — Validar o conjunto de tasks

Antes de commitar, valide o grafo inteiro:

1. **Sem ciclos.** O grafo de `depends_on` deve ser acíclico. Se TASK-A depende de B e B depende de A, é erro — refaça.
2. **Referências válidas.** Todo ID em `depends_on` deve existir entre as tasks geradas.
3. **`files_touched` não-vazio** em todas.
4. **Paralelas não colidem.** Para cada conjunto de tasks com o mesmo `depends_on` e `parallelism: parallel`, confirme interseção vazia de `files_touched`. Se houver colisão, serialize ou mova o arquivo para foundation.
5. **Coerência de shared_resources.** Toda task com `shared_resources` não-vazio deve ser `sequential`. Toda task `sequential` deve justificar (shared_resources ou dependência forte).
6. **Cobertura.** Todos os arquivos da seção "Arquivos a criar/modificar" da SPEC aparecem em algum `files_touched`. Nenhum arquivo órfão, nenhum inventado.
7. **Limites.** Nenhuma task com > ~10 arquivos. Se houver, quebre.

Se algo falhar, corrija antes de prosseguir.

---

## Fase 6 — README e commit

1. **Atualize o README** da change:
   - Estado: "🔨 {N} tasks geradas ({data}), prontas para implementação"
   - Sumário de arquivos: adicione a pasta `tasks/` listando as tasks com seu paralelismo
   - Inclua o **plano de execução previsto** (ver Fase 7) como uma seção, para referência futura

2. **Commit** na branch `feat/{slug}`:
```
git add docs/changes/{pasta}/tasks/ docs/changes/{pasta}/03-PLAN-EXEC.md docs/changes/{pasta}/README.md
git commit -m "docs({slug}): decompose into {N} tasks + execution plan"
```

---

## Fase 7 — Confirmação, plano de execução, próximo passo

Mostre ao usuário:

1. Quantas tasks foram geradas e seus títulos.
2. **Arquivo de plano:** `03-PLAN-EXEC.md` foi gerado automaticamente com:
   - Lotes de execução (quais tasks rodam juntas)
   - Diagrama Mermaid do grafo de dependências
   - Tempo estimado total considerando paralelismo
   - Observações sobre tarefas grandes ou recursos compartilhados
3. Avise se alguma task ficou `large` — pode valer revisar a decomposição.
4. **Validação:** as tasks nascem `status: ready` e o `03-PLAN-EXEC.md` nasce `status: draft`. Revise a decomposição (especialmente dependências e paralelismo). Ajuste manualmente os `.md` se discordar de algum agrupamento.
5. **Próximo passo:**
   - `/sdd-approve {slug}` — aprova o `03-PLAN-EXEC.md` (draft → approved) e carimba `approved_by`/`approved_at` em todas as tasks. Status das tasks segue `ready`.
   - `/sdd-run-all {slug}` — depois da aprovação, executa tudo em sequência (1 commit por task, retomável).

Não despeje o conteúdo das tasks na confirmação — o usuário abre a pasta e consulta `03-PLAN-EXEC.md` para ver o roadmap.

---

## Notas de instalação

Salve como **`.claude/commands/sdd-tasks.md`**. Invoque com `/sdd-tasks <slug>`.

Este comando é trabalho de planejamento single-threaded — a decomposição se beneficia de coerência global, não de paralelismo. Por isso não usa subagents (ao contrário de `/sdd-prd` e `/sdd-spec`). Use o modelo padrão da sessão; raciocínio forte ajuda na qualidade do grafo de dependências.

**Artefatos gerados:**
- **TASK-NNN.md files** (em `tasks/`): especificação de cada tarefa, com DoD embutido. Frontmatter é o contrato que `/sdd-run-all` lê.
- **03-PLAN-EXEC.md**: mapa de roteamento dos lotes e diagrama do DAG. Nasce `status: draft` e é aprovado em bloco com as tasks via `/sdd-approve`.

Mantenha ambos sempre bem-formados — são o que guia a implementação e a orquestração.
