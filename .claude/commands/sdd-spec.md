---
description: Gera a especificação técnica (02-SPEC.md) a partir de um PRD aprovado, com rollback obrigatório e ADRs numerados sequencialmente
argument-hint: <slug-da-feature>
allowed-tools: Bash(git:*), Bash(date:*), Bash(find:*), Bash(ls:*), Bash(wc:*), Bash(test:*), Read, Grep, Glob, Write, WebSearch, WebFetch, Task
---

# Comando /sdd-spec

Você gera a **SPEC (especificação técnica)** de uma feature, no workflow Spec-Driven local. A SPEC traduz o PRD (negócio) em um plano técnico executável: arquitetura, componentes, decisões, edge cases, estratégia de rollback e a lista de arquivos a tocar. É a base que o `/sdd-tasks` vai decompor.

Argumento recebido (slug): `$ARGUMENTS`

Contexto carregado automaticamente:
- Branch atual: !`git branch --show-current`
- Data: !`date +%Y-%m-%d`
- Features candidatas: !`find docs/changes -maxdepth 1 -type d -name 'feat-*' 2>/dev/null || echo "(nenhuma)"`
- ADRs existentes: !`ls -1 docs/adr/ADR-*.md 2>/dev/null | grep -oE 'ADR-[0-9]+' | sort -t- -k2 -n | tail -3 || echo "(nenhum ADR ainda)"`

---

## Regras gerais

1. **A SPEC é técnica, mas ancorada no PRD.** Tudo na SPEC serve a um objetivo do PRD. Não invente escopo que o PRD não pediu.
2. **Siga os patterns do projeto.** Antes de propor estrutura, leia `docs/patterns/`. A SPEC deve produzir código que parece com o resto da codebase, não um estilo novo inventado.
3. **Rollback é seção obrigatória.** Nenhuma SPEC fica pronta sem estratégia de rollback. Produção crítica não tolera "não pensei nisso".
4. **Decisões arquiteturais duráveis viram ADR.** Escolha de biblioteca, padrão de persistência, trade-off estrutural — cada um vira um ADR numerado.
5. **Limite de ~600 linhas.** Se passar, a feature provavelmente deveria ser quebrada em features menores. Sinalize.
6. **Não implemente código.** Este comando produz a SPEC e os ADRs, nada mais.

---

## Fase 0 — Resolver a feature

1. Se `$ARGUMENTS` tem um slug, localize a pasta `docs/changes/feat-*-{slug}`.
2. Se vazio ou ambíguo, liste as features candidatas e pergunte qual. Encerre o turno e espere resposta.
3. Confirme que a pasta tem um `01-PRD.md`. Se não tem, oriente: "Não há PRD aqui — rode `/sdd-prd {slug}` primeiro." Encerre.

---

## Fase 1 — Validar pré-condições

1. **Tipo:** confira `kind: feature` no frontmatter do PRD. Se for fix/chore, avise que o fluxo rápido dedicado ainda não existe nesta versão e pergunte se quer prosseguir como feature ou pausar. Só siga com confirmação.
2. **PRD aprovado:** confira `status` no frontmatter do `01-PRD.md`.
   - Se `approved`: prossiga.
   - Se `draft`: avise — "O PRD está `draft`. Rode `/sdd-approve {slug}` para aprovar formalmente (vai gravar `approved_by`/`approved_at`). Quer parar agora e aprovar, ou prosseguir mesmo em draft (não recomendado)?" Encerre o turno e espere decisão.
3. **SPEC existente:** se já houver `02-SPEC.md` com `status: validated`, avise e pergunte se deseja regenerar antes de sobrescrever.

---

## Fase 2 — Carregar contexto

Leia, nesta ordem:

1. `01-PRD.md` da feature — a fonte do que precisa ser feito, incluindo a seção "Decisões em aberto" que esta SPEC deve resolver.
2. **Constitution** — leia `docs/constitution.md` (ou `docs/explanation/constitution.md` em layouts antigos): stack, padrões, anti-hallucination, regras de teste, regra de paralelismo/recursos compartilhados. **A SPEC deve respeitar tudo isso.**
3. **Skills das stacks ativas** (anti-alucinação — ver bloco abaixo). Carregue antes de propor qualquer arquitetura.
4. `docs/patterns/` — leia os patterns relevantes ao que a feature provavelmente cria. Infira a partir do PRD e das stacks ativas: lógica de negócio → `service.md`; endpoints → `controller.md`; autorização → `policy.md`; processamento assíncrono → `job.md`; e sempre o pattern de teste da stack.
5. **Arquivos reais da codebase** citados no PRD (seção "Achados da pesquisa → Codebase"). Leia-os para basear decisões na realidade, não em suposição.

### Carregar skills das stacks ativas (anti-alucinação)

A SPEC só fica fiel ao projeto se respeitar a stack real. Antes de desenhar a arquitetura:

1. Leia a seção `## Active Stacks` do constitution. Ela lista as stacks ativas e a skill de cada uma (ex: `php-laravel → skill: php-laravel`).
2. Para cada stack ativa, leia `.claude/skills/stacks/<skill>/SKILL.md` — golden rules e índice de references.
3. Leia os `references/` **relevantes ao que a feature toca**, não todos:
   - feature mexe em arquitetura/camadas → `references/architecture.md`
   - feature define convenções de código novo → `references/conventions.md`
   - feature exige estratégia de teste → `references/testing.md`
4. **Sem `## Active Stacks` no constitution** (analyze nunca rodou): avise — "Nenhuma stack ativa no constitution. Rode `/sdd-analyze` para que a SPEC siga a stack real do projeto. Prosseguindo com SPEC genérica." E siga, sem bloquear.
5. **Precedência quando há conflito:** `docs/patterns/` (o que o time realmente faz) > `SKILL.md` (boas práticas universais da stack). A SPEC segue o projeto, não o livro.

---

## Fase 3 — Decisão técnica via subagents

Dispare subagents em paralelo (via Task tool). Se indisponível, rode em sequência você mesmo, mantendo cada um enxuto. Reutilize os subagents de `.claude/agents/` se existirem.

**Subagent A — Arquitetura e decisões técnicas:**
> Com base no PRD, constitution e patterns, proponha a arquitetura: que componentes criar (Services, Controllers, Models, Jobs, Middlewares...), como se relacionam, modelo de dados (sem inventar schema — basear em migrations existentes), e como cada decisão serve um objetivo do PRD. Respeite os patterns do projeto. Resolva as "Decisões em aberto" do PRD. Retorne estruturado.

**Subagent B — Candidatos a ADR:**
> Identifique decisões arquiteturais DURÁVEIS nesta feature (escolha de biblioteca, padrão de persistência, trade-off estrutural que alguém vai questionar em 6 meses). Para cada uma: contexto, decisão recomendada, alternativas consideradas, consequências. Ignore decisões triviais ou reversíveis sem custo. Retorne a lista (pode ser vazia).

**Subagent C — Edge cases:**
> Liste edge cases e condições de corrida relevantes: entradas extremas, concorrência, falhas de dependência externa, estados vazios, dados unicode/grandes. Para cada um, a mitigação. Foque no que realmente pode quebrar, não em exaustividade teórica.

**Subagent D — Rollback thinking:**
> Responda concretamente para esta feature: Como desfazer? Qual o impacto de rollback após X dias (dados órfãos, cache populado)? Precisa de feature flag — qual nome, qual default? A migration é reversível? Há breaking change ou período de coexistência necessário? Retorne preenchendo esses pontos.

Aguarde todos retornarem antes de sintetizar.

---

## Fase 4 — Sintetizar a SPEC

Crie `docs/changes/{pasta}/02-SPEC.md` com o template. A seção "Estratégia de rollback" é **obrigatória** e vem do subagent D.

```markdown
---
type: spec
kind: feature
slug: {slug}
status: draft
external_id: null
prd: ./01-PRD.md
adrs: [{lista de ADRs gerados, ex: ADR-023; vazio se nenhum}]
created: {YYYY-MM-DD}
---

# SPEC — {Título da feature}

## Decisões de stack
{bibliotecas/abordagens escolhidas e justificativa; referencie os ADRs}

## Modelo de dados
{tabelas/campos novos ou alterados; baseado em migrations reais; "sem mudança de schema" se for o caso}

## Arquitetura
### Componentes novos
{Services, Controllers, Models, Jobs, Middlewares, Form Requests, etc, com responsabilidade de cada um — seguindo os patterns do projeto}

### Rotas / endpoints
{se aplicável}

### Fluxo principal
{passo a passo do caminho feliz}

## Decisões técnicas
{window/timeouts/limites/locks/rate-limits e suas justificativas; referencie ADRs onde couber}

## Edge cases tratados
{do subagent C — caso + mitigação}

## Estratégia de rollback
- **Como desfazer:** {feature flag? migration reverse? config?}
- **Impacto se rollback após X dias:** {dados órfãos? cache?}
- **Feature flag necessária:** {sim/não, nome, default}
- **Migration reversível:** {sim/não, por quê}
- **Backwards compatibility:** {breaking change? período de coexistência?}

## Performance esperada
{estimativas para os caminhos críticos; ou "sem impacto relevante"}

## Riscos
{risco + probabilidade + mitigação}

## Arquivos a criar/modificar
**Criar:**
- {caminho}
**Modificar:**
- {caminho}
```

A seção "Arquivos a criar/modificar" é importante: o `/sdd-tasks` vai usá-la para distribuir `files_touched` entre as tasks. Seja específico nos caminhos.

---

## Fase 5 — Gerar ADRs

Para cada candidato a ADR do subagent B:

1. **Numere sequencialmente.** Olhe os ADRs existentes (mostrados no contexto acima), pegue o maior número e incremente. Se não há nenhum, comece em `ADR-001`. Se o subagent B trouxe 2 ADRs e o último existente é ADR-022, crie ADR-023 e ADR-024.
2. Crie `docs/adr/ADR-NNN-{slug-curto}.md`:

```markdown
# ADR-NNN — {Título da decisão}

**Status:** Aceito
**Data:** {YYYY-MM-DD}
**Contexto:** Feature {slug} ({pasta})

## Contexto
{por que essa decisão precisa ser tomada}

## Decisão
{o que foi decidido}

## Alternativas consideradas
- **{alternativa}:** {por que foi descartada}

## Consequências
**Positivas:**
- {...}
**Negativas:**
- {...}
**Mitigações:**
- {...}
```

3. Liste todos os ADRs criados no campo `adrs:` do frontmatter do SPEC.

Se o subagent B não trouxe nenhum candidato, pule esta fase e deixe `adrs: []` no SPEC.

---

## Fase 6 — Validar a SPEC

1. **Rollback presente:** confirme que a seção "Estratégia de rollback" está preenchida (não com placeholders). Se faltar, complete antes de prosseguir — é bloqueante.
2. **Arquivos listados:** confirme que "Arquivos a criar/modificar" tem caminhos concretos. Sem isso, o `/sdd-tasks` não consegue trabalhar.
3. **Tamanho:** `wc -l docs/changes/{pasta}/02-SPEC.md`. Se > ~600 linhas, avise que a feature pode estar grande demais e sugira quebrar — sem bloquear.
4. **Aderência à constitution:** releia procurando violações (dependência nova sem ADR, padrão fora dos patterns, regra de segurança ignorada). Corrija ou registre como ADR.

---

## Fase 7 — README e commit

1. **Atualize o README** da change (`docs/changes/{pasta}/README.md`):
   - Estado: "📐 SPEC validada/gerada ({data}), pronta para decomposição em tasks"
   - Sumário de arquivos: adicione `02-SPEC.md` e os ADRs gerados
   - Decisões-chave: liste as principais decisões técnicas e ADRs

2. **Commit** na branch `feat/{slug}` (já deve estar ativa; se não, faça checkout):
```
git add docs/changes/{pasta}/ docs/adr/
git commit -m "docs({slug}): add SPEC and ADRs"
```

---

## Fase 8 — Confirmação e próximo passo

Mostre de forma concisa:

1. Caminho do `02-SPEC.md` e número de linhas.
2. ADRs criados (se houver), com número e título.
3. Resumo de 2-3 linhas das decisões técnicas centrais.
4. **Validação:** a SPEC nasce `status: draft`. Rode `/sdd-approve {slug}` para aprovar (vai virar `status: validated` e gravar `approved_by`/`approved_at`). O `/sdd-tasks` exige SPEC validada.
5. **Próximo passo:** `/sdd-approve {slug}` para validar a SPEC, depois `/sdd-tasks {slug}`.

Não repita a SPEC inteira — o usuário abre o arquivo.

---

## Notas de instalação

Salve como **`.claude/commands/sdd-spec.md`**. Invoque com `/sdd-spec <slug>`.

Os subagents (arquitetura, ADR, edge cases, rollback) podem ser definidos uma vez em `.claude/agents/` e reaproveitados pelo `/sdd-prd` e `/sdd-spec`. Isso mantém consistência e evita reescrever os prompts de research em cada comando.

Modelo recomendado: a SPEC é o ponto de maior densidade de decisão técnica do fluxo. Use o modelo mais forte disponível na sessão (não Haiku). Se o seu Claude Code suporta override por comando e você quer garantir, adicione `model: claude-opus-4-7` ao frontmatter — mas isso aumenta custo; o padrão da sessão costuma bastar.
