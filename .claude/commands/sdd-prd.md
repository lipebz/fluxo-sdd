---
description: Gera o PRD de uma feature a partir do 00-idea.md, usando research paralela (codebase + web + impacto) via subagents
argument-hint: <slug-da-feature>
allowed-tools: Bash(git:*), Bash(date:*), Bash(find:*), Bash(ls:*), Bash(wc:*), Bash(test:*), Read, Grep, Glob, Write, WebSearch, WebFetch, Task
---

# Comando /sdd-prd

Você gera o **PRD (Product Requirements Document)** de uma feature, no workflow Spec-Driven local. O PRD é o artefato de negócio: descreve o problema, quem afeta, objetivos, não-objetivos, critérios de aceite e métricas — em linguagem que a área de negócio entende. Não é especificação técnica (isso é o `/sdd-spec`).

Argumento recebido (slug da feature): `$ARGUMENTS`

Contexto carregado automaticamente:
- Branch atual: !`git branch --show-current`
- Data: !`date +%Y-%m-%d`
- Features candidatas: !`find docs/changes -maxdepth 1 -type d -name 'feat-*' 2>/dev/null || echo "(nenhuma)"`

---

## Regras gerais

1. **O PRD é de negócio, não técnico.** Nada de nomes de classe, schema, biblioteca. Fale de problema, valor, resultado. Decisões técnicas vão para o `/sdd-spec`.
2. **Limite de ~400 linhas.** Se passar disso, a feature é grande demais — sinalize que talvez precise ser quebrada em features menores.
3. **Não invente dados.** Se a `00-idea.md` não tem números (ex: "23 tentativas de invasão"), não fabrique. Use o que há e marque o que falta como "[a confirmar]".
4. **Research informa, não decide.** Os subagents trazem achados; você sintetiza no PRD de forma honesta, incluindo decisões em aberto para o `/sdd-spec` resolver.
5. **Não implemente código.** Este comando só produz o PRD e prepara a branch.

---

## Fase 0 — Resolver a feature

1. Se `$ARGUMENTS` contém um slug, procure a pasta correspondente em `docs/changes/feat-*-{slug}` (o slug pode estar no fim do nome da pasta, após o prefixo `feat-AAAA-MM-`).
2. Se `$ARGUMENTS` está vazio ou não bate com nenhuma pasta:
   - Liste as features candidatas (mostradas acima) e pergunte qual. Encerre o turno e espere a resposta.
3. Leia o `00-idea.md` da pasta encontrada.

---

## Fase 1 — Validar pré-condições

- **Confira o `kind` no frontmatter do `00-idea.md`.** Deve ser `feature`. Se for `fix` ou `chore`, avise: "Esta change foi classificada como `{kind}` no `/sdd-new`, mas o fluxo rápido dedicado ainda não existe nesta versão do SDD. Se quiser, prossiga tratando-a como feature (rodar `/sdd-prd` mesmo assim) ou pause e aguarde o fluxo dedicado." Aguarde decisão explícita antes de gerar PRD.
- Se já existir um `01-PRD.md` na pasta com `status: approved`
  - Avise que o PRD já foi aprovado e pergunte se deseja regenerar (sobrescrever) antes de prosseguir.

---

## Fase 2 — Carregar contexto do projeto

Leia (se existirem):
- `docs/explanation/constitution.md` — para respeitar restrições e linguagem do projeto
- `docs/patterns/README.md` — para entender o que já existe (ajuda a calibrar escopo realista)

Esses arquivos ancoram o PRD na realidade do projeto. Se não existirem, prossiga sem eles, mas note internamente que o contexto é menor.

---

## Fase 3 — Research paralela via subagents

Dispare **três subagents em paralelo** (via Task tool). Cada um recebe a ideia e a constitution como contexto, e retorna um resumo estruturado e curto (não o trabalho bruto). Se a Task tool não estiver disponível neste ambiente, rode as três investigações você mesmo, em sequência, mantendo cada uma enxuta.

**Subagent A — Codebase research:**
> Tarefa: investigar a codebase para informar este PRD. Use Grep/Glob/Read. Encontre: (1) features ou fluxos similares já existentes que sirvam de precedente; (2) componentes que provavelmente serão tocados; (3) convenções relevantes ao domínio da ideia. Retorne no máximo 10 bullets factuais com caminhos de arquivo. Não proponha solução técnica — isso é trabalho do /sdd-spec.

**Subagent B — Web research (se WebSearch disponível):**
> Tarefa: pesquisar boas práticas E **identificar dependências externas (libs, SaaS, APIs, serviços) que já resolvem este problema**. Sempre que possível, prefira sinalizar uma solução pronta a inventar do zero. Foque em:
> - padrões de produto comuns
> - armadilhas conhecidas / expectativas de usuário
> - **soluções de prateleira existentes** — para cada candidata, traga: nome, propósito, e nota curta sobre por que pode caber aqui (custo, licença, manutenção/comunidade, maturidade)
>
> Retorne no máximo 8 bullets, citando fontes. A escolha técnica final é do `/sdd-spec` — aqui só colocamos as opções na mesa para ele considerar. Se não encontrar nenhuma solução pronta razoável, diga explicitamente "nenhuma identificada" em vez de inventar.

**Subagent C — Análise de impacto:**
> Tarefa: mapear o impacto da feature. Identifique: (1) quem é afetado e em que volume; (2) que áreas do sistema mudam de comportamento; (3) riscos de adoção e mitigações de UX; (4) restrições legais/operacionais relevantes (LGPD, auditoria, etc, se aplicável ao domínio). Retorne no máximo 8 bullets.

Aguarde os três retornarem antes de sintetizar.

---

## Fase 4 — Sintetizar o PRD

Crie `docs/changes/{pasta}/01-PRD.md` usando o template abaixo. Preencha com base na `00-idea.md` + achados dos subagents. Mantenha linguagem de negócio.

```markdown
---
type: prd
kind: feature
slug: {slug}
status: draft
external_id: null
idea: ./00-idea.md
created: {YYYY-MM-DD}
approved_by: null
approved_at: null
---

# PRD — {Título da feature}

> {Uma linha: o que a feature entrega e para quem}

## Problema
{problema concreto, com dados se houver na idea; marque [a confirmar] o que faltar}

## Usuários afetados
{quem, quantos, com que frequência — do subagent C e da idea}

## Objetivos
1. {objetivo mensurável}
2. ...

## Não-objetivos
- {o que explicitamente NÃO está no escopo desta entrega}
- ...

## Critérios de aceite
- {condição verificável de "pronto", em linguagem de negócio}
- ...

## Métricas de sucesso
- {como saberemos que deu certo, com números/metas quando possível}

## Restrições legais e operacionais
{LGPD, auditoria, retenção, compliance — do subagent C; ou "Nenhuma identificada"}

## Achados da pesquisa
**Codebase (precedentes e contexto):**
- {bullets do subagent A}

**Boas práticas / expectativas de usuário:**
- {bullets do subagent B sobre padrões e armadilhas}

**Soluções externas candidatas (para o /sdd-spec avaliar):**
- {libs, SaaS, APIs, serviços identificados pelo subagent B que poderiam resolver o problema — cada uma com nome, propósito, e nota curta sobre adequação; ou "nenhuma identificada"}

## Decisões em aberto (para o /sdd-spec resolver)
- {questões técnicas que surgiram mas não são de negócio}
- ...
```

---

## Fase 5 — Validar o PRD

1. **Tamanho:** rode `wc -l docs/changes/{pasta}/01-PRD.md`. Se passar de ~400 linhas, avise o usuário que a feature pode estar grande demais e sugira considerar quebrá-la — mas não bloqueie.
2. **Completude:** confira que não há seção vazia. Se algum campo ficou sem informação real, mantenha o marcador `[a confirmar]` em vez de inventar.
3. **Linguagem:** releia procurando vazamento técnico (nomes de classe, schema, lib). Se houver, mova para "Decisões em aberto" ou remova.

---

## Fase 6 — Branch, README e commit

1. **Branch.** Verifique se a branch `feat/{slug}` existe (`git branch --list feat/{slug}`).
   - Se não existe: crie a partir da `main` atualizada — `git checkout main && git pull && git checkout -b feat/{slug}`.
   - Se já existe: faça checkout nela.
   - (Se houver mudanças não commitadas que impeçam o checkout, pare e avise o usuário em vez de forçar.)

2. **README da change (dossiê vivo).** Crie ou atualize `docs/changes/{pasta}/README.md`. Se não existe, crie com este formato; se existe, atualize o sumário de arquivos e o estado.

```markdown
---
type: change
kind: feature
slug: {slug}
status: draft
external_id: null
created: {data-de-criacao-original-da-idea}
delivered_at: null
---

# {Título da feature}

> {uma linha}

## Estado atual
🔄 PRD gerado ({YYYY-MM-DD}), aguardando validação

## Sumário dos arquivos
- [00-idea.md](./00-idea.md) — ideia original
- [01-PRD.md](./01-PRD.md) — requisitos de produto (draft)

## Branch
feat/{slug}
```

3. **Commit.** Adicione os artefatos da change e commite, em conventional commits, usando o slug como escopo:
```
git add docs/changes/{pasta}/
git commit -m "docs({slug}): add 01-PRD"
```
(Se o `00-idea.md` ainda não estava commitado, ele entra no mesmo commit — sem problema.)

---

## Fase 7 — Confirmação e próximo passo

Mostre ao usuário, de forma concisa:

1. Caminho do `01-PRD.md` criado e número de linhas.
2. Branch ativa (`feat/{slug}`).
3. Se há marcadores `[a confirmar]` ou decisões em aberto, liste-os brevemente — são o que ele precisa resolver/validar.
4. **Validação:** lembre que o PRD nasce `status: draft`. Para aprovar formalmente, rode `/sdd-approve {slug}` (vai pedir o nome e gravar `approved_by`/`approved_at`).
5. **Próximo passo:** `/sdd-approve {slug}` para aprovar o PRD, depois `/sdd-spec {slug}`.

Opcional, mencione apenas se ele perguntar: se quiser preview renderizado para mostrar à chefia, pode empurrar a branch e abrir um PR pontual (`git push -u origin feat/{slug}` + PR) sem precisar de board.

Não repita o conteúdo inteiro do PRD na confirmação — ele pode abrir o arquivo.

---

## Notas de instalação

Salve como **`.claude/commands/sdd-prd.md`** na raiz do projeto. Invoque com `/sdd-prd <slug>`.

Como skill alternativa: `.claude/skills/sdd-prd/SKILL.md`, útil se quiser anexar uma pasta `agents/` com os três subagents de research pré-definidos (codebase, web, impacto) em vez de descrevê-los inline. Definir os subagents em `.claude/agents/` os torna reutilizáveis também pelo `/sdd-spec`.

Modelo recomendado: o PRD se beneficia de raciocínio mais forte na síntese. Deixe no modelo padrão da sessão (não force Haiku aqui, ao contrário do `/sdd-new`).
