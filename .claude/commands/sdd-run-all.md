---
description: Executa todas as tasks de uma feature em modo autônomo — sequencial, 1 commit por task, sem pausa para revisão. Para apenas em ambiguidade real, teste sem solução, files_touched violation ou dependência não satisfeita. É retomável: roda de onde parou.
argument-hint: <slug-da-feature>
allowed-tools: Bash, Read, Grep, Glob, Write, Edit, WebSearch, WebFetch
---

# Comando /sdd-run-all

Você executa **todas as tasks** de uma feature de uma vez, no workflow Spec-Driven local. O `/sdd-run-all` é o executor autônomo: lê o `03-PLAN-EXEC.md`, percorre o DAG na ordem correta, implementa task por task **na mesma branch `feat/{slug}`**, commita cada uma, e segue até concluir — sem pedir revisão entre tasks.

Você só **para** quando há algo que exige decisão humana (ver Fase 5). Quando o usuário resolve e roda `/sdd-run-all {slug}` de novo, você **retoma de onde parou** (releitura completa do estado).

Argumento (slug): `$ARGUMENTS`

Contexto carregado automaticamente:
- Branch atual: !`git branch --show-current`
- Working tree: !`git status --short 2>/dev/null || echo "(fora de repo git)"`
- Data: !`date +%Y-%m-%d`
- Features candidatas: !`find docs/changes -maxdepth 1 -type d -name 'feat-*' 2>/dev/null || echo "(nenhuma)"`

---

## Regras invioláveis

1. **Modo autônomo, com guardas duras.** Não pausa para revisão estética. Para apenas em: ambiguidade real, teste quebrado sem solução clara, arquivo fora de `files_touched`, dependência não satisfeita.
2. **Sequencial total, in-place.** 1 task por vez, na branch `feat/{slug}`. **Sem worktrees**, **sem bancos isolados**. Paralelismo previsto no DAG é desconsiderado aqui — execução autônoma single-process roda em ordem topológica.
3. **1 commit por task.** Cada task vira 1 commit `feat({slug}): TASK-NNN — título` com o relatório no corpo, seguido de 1 commit `chore({slug}): mark TASK-NNN as done`.
4. **Retomável.** Estado vive nos frontmatters. A cada início, releia tudo; comece da primeira task ainda não `done`.
5. **`files_touched` é fronteira dura.** Se precisar tocar algo fora, PARE e pergunte.
6. **Testes são intocáveis.** Nunca delete/comente/skipe para fazer outro passar. Se um teste existente quebra, investigue.
7. **Anti-hallucination.** Nunca invente nome de método/classe/coluna — grep antes. Nunca crie endpoint, env var, config que a SPEC não previu.
8. **PLAN-EXEC aprovado.** Antes de rodar, confira que o `03-PLAN-EXEC.md` está `status: approved`. Se ainda está `draft`, oriente o usuário a rodar `/sdd-approve {slug}` primeiro e encerre.

---

## Fase 0 — Resolver a feature

1. Localize `docs/changes/feat-*-{slug}` a partir de `$ARGUMENTS`.
2. Se vazio/ambíguo, liste candidatas e pergunte. Encerre.
3. Confirme que há `tasks/` com arquivos e `03-PLAN-EXEC.md`. Se não, oriente a rodar `/sdd-tasks {slug}` primeiro. Encerre.
4. Confirme que `03-PLAN-EXEC.md` tem `status: approved`. Se ainda está `draft`, oriente: "O plano de execução não foi aprovado. Rode `/sdd-approve {slug}` antes." Encerre.

---

## Fase 1 — Carregar tasks e validar DAG

Leia o frontmatter de cada `tasks/TASK-NNN-*.md`: `id`, `status`, `parallelism`, `depends_on`, `shared_resources`, `files_touched`, `estimated_complexity`, `prd_hash`, `spec_hash`.

Valide:
- **Sem ciclos** no grafo de `depends_on`.
- **Referências válidas** — todo ID em `depends_on` existe.

Se algo falhar, PARE e reporte. Não prossiga.

### Checagem de drift (PRD/SPEC mudaram desde a decomposição?)

Se as tasks têm `prd_hash`/`spec_hash` no frontmatter (geradas por uma versão recente do `/sdd-tasks`), recompute e compare:

```bash
shasum -a 256 docs/changes/{pasta}/01-PRD.md | awk '{print $1}'   # compare com prd_hash
shasum -a 256 docs/changes/{pasta}/02-SPEC.md | awk '{print $1}'  # compare com spec_hash
```

- **Hashes batem** → ok, prossiga silenciosamente.
- **`spec_hash` divergiu** → a SPEC mudou depois de gerar as tasks. **AVISE** (não bloqueie):
  ```
  ⚠ Drift detectado: a SPEC mudou desde que as tasks foram geradas.
    As tasks podem não refletir mais o plano técnico atual.
    Opções:
      1. Regenerar as tasks: /sdd-tasks {slug} (descarta a decomposição atual)
      2. Prosseguir mesmo assim (as tasks podem estar desatualizadas)
    Como deseja prosseguir?
  ```
  Encerre o turno e espere a decisão. Não execute por cima de drift sem o usuário saber.
- **Só `prd_hash` divergiu** (SPEC intacta) → drift mais leve (o negócio mudou mas o plano técnico não). Avise em uma linha e pergunte se quer prosseguir.
- **Tasks sem `prd_hash`/`spec_hash`** (geradas por versão antiga) → não há baseline para comparar. Siga normalmente, sem aviso.

Calcule a **ordem topológica** (linearização do DAG):
- Tasks sem `depends_on` primeiro.
- Em seguida, tasks cujas dependências estão à frente na lista.
- Em empates de dependências, ordene pelo `id` numérico (TASK-001 antes de TASK-002).

Essa lista é a ordem de execução do `/sdd-run-all`. Ela ignora `parallelism` — paralelismo é coisa do `/preparar-lote` (multi-process). Aqui, tudo roda em fila.

---

## Fase 2 — Detectar ponto de retomada

A partir da ordem topológica:

1. **Pular tasks `done`** — já finalizadas, nada a fazer.
2. **Encontrar a próxima task a executar:**
   - Se há task `in-progress`: **retomar essa**. Provavelmente uma execução anterior foi interrompida no meio. Verifique o que já foi feito (git status, git diff) antes de continuar; complete o que falta.
   - Se há task `in-review`: tratada como pronta para fechar. **Auto-aprove** (Fase 4f-h) e prossiga.
   - Se há task `blocked`: PARE. Mostre o motivo registrado e oriente: "Resolva o bloqueio (edite a task removendo o status `blocked` para `ready`, ou ajuste a SPEC) e rode `/sdd-run-all {slug}` de novo." Encerre.
   - Senão, a primeira `ready` com todas as `depends_on` em `done` é a próxima.

3. **Validar pré-condições da próxima task:**
   - `depends_on` todas `done` (deve ser, pela ordem topológica — mas confirme).
   - Se alguma dep não está `done`: deadlock no DAG. PARE e reporte.

4. Se **não há nenhuma task pendente** (tudo `done`): vá direto para Fase 6 — execução concluída.

---

## Fase 3 — Preparar a branch

1. **Confirmar/criar branch da feature.** Você deve estar em `feat/{slug}`. Se não:
   - Se a branch existe localmente: `git checkout feat/{slug}`.
   - Se não existe: `git checkout main && git pull && git checkout -b feat/{slug}`.
   - Se há working tree sujo que impeça checkout: PARE e avise. Não force.

2. **Não crie sub-branches** (`feat/{slug}/task-NNN`). O `/sdd-run-all` opera in-place: todas as tasks vão direto em `feat/{slug}`.

3. **Carregar contexto comum** (apenas uma vez, no início; reaproveite para todas as tasks da execução):
   - `02-SPEC.md` — arquitetura geral.
   - `01-PRD.md` — objetivos.
   - **Constitution** — `docs/constitution.md` (ou `docs/explanation/constitution.md` em layouts antigos): stack, padrões, segurança, anti-hallucination, testes.
   - **Skills das stacks ativas** — leia a seção `## Active Stacks` do constitution. Para cada stack ativa, leia `.claude/skills/stacks/<skill>/SKILL.md` (golden rules + comando de teste/lint da stack). Os `references/` específicos são lidos sob demanda por task na Fase 4a. Sem `## Active Stacks`, avise que `/sdd-analyze` melhoraria a aderência e siga com conhecimento genérico.
   - ADRs referenciados na SPEC.
   - `docs/patterns/` — os patterns que se aplicam à feature (precedência sobre o SKILL.md em caso de conflito — o código do time vence).

---

## Fase 4 — Loop de execução (para cada task na ordem topológica)

Para cada task pendente, na ordem calculada, execute o subprocesso completo abaixo. Faça **uma task por vez**, completa, antes de seguir para a próxima.

### 4a — Carregar contexto da task

Leia o `TASK-NNN.md` inteiro: objetivo, escopo, restrições, `files_touched`, critérios de aceite, DoD.

Leia **os arquivos reais** que a task vai **modificar** (não os que vai criar). Mantenha o contexto enxuto.

**Carregue os references da skill relevantes a esta task** (não a feature inteira). Olhe os `files_touched`:
- toca controller/handler/rota/componente → `references/architecture.md` (camadas) + o pattern correspondente em `docs/patterns/`
- escreve/altera testes → `references/testing.md`
- cria código novo onde convenções importam → `references/conventions.md`

Carregue só o que a task precisa — o SKILL.md já está no contexto comum (Fase 3). Isso mantém a janela enxuta task a task.

### 4b — Marcar início

Edite o frontmatter da task: `status: ready` → `status: in-progress`.

### 4c — Implementar

Implemente o escopo, restrito aos `files_touched`. Regras (todas elas dos comandos manuais):

- **Antes de tocar qualquer arquivo**, confirme que está em `files_touched`. Se não está e você precisa, vá para **Fase 5b (parada por escopo)**.
- **Siga os patterns** do projeto. Estrutura, nomes, organização conforme `docs/patterns/`.
- **Respeite a constitution.** Authorize via Policy, valide inputs via Form Request, nunca logue dados sensíveis, etc.
- **Grep antes de referenciar.** Qualquer método/classe/coluna que você usa de outra parte do código — confirme que existe com grep antes.
- **Se aparecer ambiguidade** que SPEC e task não resolvem, vá para **Fase 5a (parada por ambiguidade)**.

### 4d — Quality gate (testes ou check/lint)

Use o **quality gate real do projeto**, definido na §7 do constitution (Fase 5.6 do `/sdd-analyze`). Dois cenários:

**Projeto COM testes** (há test runner configurado):
1. Escreva/atualize os testes que a task exige (critérios de aceite costumam mapear para asserts).
2. Rode a suíte relevante (use o banco da branch — sem isolamento; se a task altera schema, rode o comando de "reset+migrate" da stack — definido no constitution e no `SKILL.md` da stack — antes. Só faça isso se a task de fato envolve mudança de migration). O comando de teste é o definido na constitution / `SKILL.md` da stack (ex: `vitest`, `pytest`, `go test`, `php artisan test` / `pest`).
3. **Se um teste existente quebrar:** investigue.
   - Se a regra de negócio mudou (a SPEC pede isso): ajuste o teste com justificativa no commit. Prossiga.
   - Se você quebrou algo: corrija o código. Prossiga só quando os testes voltarem a passar.
   - Se não consegue resolver após investigação razoável: vá para **Fase 5c (parada por teste)**.
4. **Nunca** delete/comente/skipe teste para fazer outro passar.

**Projeto SEM testes** (constitution §7 diz "sem testes automatizados"):
1. **Não invente um test runner.** Não escreva testes "porque é boa prática" — não há runner pra rodá-los.
2. Rode o gate que existe: type-check / `check` / `lint` / `build` (o comando real definido na §7). Ex: `bun run check && bun run lint`.
3. Se o gate falhar (erro de tipo, lint), corrija antes de prosseguir — mesma régua de "teste quebrado". Se não conseguir resolver, vá para **Fase 5c**.
4. Se nem gate de check/lint existir (raro), faça uma revisão estática cuidadosa do diff e registre no relatório do commit que não houve gate automatizado disponível.

### 4e — Validar diff contra `files_touched`

1. `git status --short` e `git diff --name-only`.
2. Todo arquivo modificado (exceto o `TASK-NNN.md`) deve estar em `files_touched`.
3. Se algo escapou: ou reverta (era fora do escopo) ou vá para **Fase 5b (parada por escopo)** e peça decisão.
4. Se um arquivo previsto em `files_touched` não foi tocado sem motivo, anote no relatório do commit (talvez `files_touched` estava largo demais — não bloqueante).

### 4f — Marcar conclusão e revisão

No `TASK-NNN.md`:
1. Marque critérios de aceite atendidos (`- [x]`).
2. Marque itens do DoD atendidos. Não-aplicáveis: marque com nota (`- [x] Observabilidade — N/A`).
3. Status frontmatter: `in-progress` → `in-review`.

### 4g — Commit da task

Commit único na `feat/{slug}` com relatório estruturado no corpo:

```
git add {arquivos do files_touched} docs/changes/{pasta}/tasks/TASK-NNN-*.md
git commit -F - <<'EOF'
feat({slug}): TASK-NNN — {título curto}

## O que foi feito
- {bullets}

## Decisões tomadas
- {decisões, com ADR se aplicável}

## Arquivos alterados
{lista; confirma que bate com files_touched}

## Pendências
{nenhuma, ou lista}

## Riscos / atenção para o revisor
{pontos de atenção}

## Como testar manualmente
{passos}

## DoD
- [x] critérios marcados
- [x] testes passando
- [x] sem TODO temporário
- [x] segurança conforme constitution
- [x] files_touched bate com diff
- [x] nenhum teste deletado/comentado/skipado
EOF
```

Tipo do commit conforme o trabalho (`feat`, `fix`, `chore`, `test`, `refactor`).

### 4h — Auto-marcar como done

Em modo autônomo, NÃO há pausa para revisão humana entre tasks:

1. Edite o frontmatter da task: `status: in-review` → `status: done`.
2. Commit de bookkeeping:
```
git add docs/changes/{pasta}/tasks/TASK-NNN-*.md
git commit -m "chore({slug}): mark TASK-NNN as done"
```

Como o trabalho já está em `feat/{slug}` (sequencial in-place), não há merge a fazer.

### 4i — Próxima task

Volte ao topo da Fase 4 com a próxima task da ordem topológica. Se não houver mais, vá para a Fase 6.

---

## Fase 5 — Pontos de parada

Quando uma condição abaixo dispara, **PARE imediatamente**, registre o motivo, e encerre o turno com instruções claras de como o usuário pode resolver. Não tente "dar um jeito" — paradas existem para preservar a qualidade.

### 5a — Parada por ambiguidade

Se a SPEC e a task não resolvem uma decisão necessária:

1. **Não decida sozinho.** Mantenha a task em `status: in-progress`.
2. Mostre ao usuário:
   - Em qual TASK-NNN você está.
   - Qual o ponto ambíguo (citando o trecho da task/SPEC que falta clareza).
   - Quais são as opções razoáveis que você considerou.
3. Encerre o turno. Espere a resposta.

Quando o usuário responder na próxima invocação de `/sdd-run-all`, retome do mesmo ponto (Fase 2 detecta task `in-progress`).

### 5b — Parada por escopo (`files_touched`)

Se você precisa tocar um arquivo que não está em `files_touched`:

1. Mantenha a task em `status: in-progress`.
2. Mostre:
   ```
   ⚠ TASK-NNN precisa tocar {arquivo}, mas não está em files_touched.
   Opções:
     1. Remover essa necessidade (manter no escopo da task) — explique como
     2. Adicionar ao files_touched desta task + justificar
     3. Criar uma task separada para isso (vai exigir editar o TASK-NNN ou criar TASK-MMM)
   ```
3. Encerre o turno.

### 5c — Parada por teste

Se um teste quebra e você não consegue diagnosticar/corrigir após investigação razoável:

1. Marque a task como `status: blocked` no frontmatter.
2. Adicione no corpo da task uma seção `## Bloqueio` com:
   - O teste que falha.
   - O erro/diff observado.
   - O que você tentou.
   - Sua hipótese (se houver).
3. Commit dessa edição de bookkeeping:
   ```
   git add docs/changes/{pasta}/tasks/TASK-NNN-*.md
   git commit -m "chore({slug}): block TASK-NNN — {motivo curto}"
   ```
4. Mostre ao usuário o resumo do bloqueio.
5. Encerre o turno.

### 5d — Parada por dependência

Se uma `depends_on` não está `done` quando deveria (deadlock no DAG):

1. Não altere status da task atual.
2. Reporte: "TASK-NNN depende de TASK-XXX (status: {status}), mas TASK-XXX não está `done`. Provável deadlock no grafo. Revise os `depends_on` ou complete TASK-XXX manualmente."
3. Encerre.

---

## Fase 6 — Fim da execução

Quando todas as tasks estão `done`:

1. Mostre relatório final:
   - Quantas tasks foram executadas nesta invocação (vs. quantas já estavam `done` ao iniciar).
   - Branch atual (`feat/{slug}`) e número de commits gerados.
   - Resultado dos testes (passou/quantos no último run).
2. **Próximo passo:** `/sdd-archive {slug}` para gerar o dossiê final, sincronizar docs e atualizar o CHANGELOG. Depois, merge final na main.
3. Encerre o turno.

Não despeje diffs ou conteúdo das tasks no relatório — o usuário pode rodar `git log` ou `/sdd-status {slug}` para os detalhes.

---

## Resumo do ciclo (referência)

```
> /sdd-run-all minha-feature
  [Fase 1] valida DAG e calcula ordem topológica: 001 → 002 → 003 → 004
  [Fase 2] ponto de retomada: nenhuma done → começa em 001
  [Fase 4] TASK-001: implementa, testa, commit "feat: TASK-001 …", commit "chore: mark done"
  [Fase 4] TASK-002: implementa, testa, commit, commit "chore: mark done"
  [Fase 4] TASK-003: AMBIGUIDADE — encerra com pergunta
  ⏸ usuário responde a ambiguidade na conversa

> /sdd-run-all minha-feature
  [Fase 2] retoma: TASK-003 in-progress
  [Fase 4] TASK-003: completa, commit, mark done
  [Fase 4] TASK-004: implementa, testa, commit, mark done
  [Fase 6] 🎉 todas done → próximo: /sdd-archive minha-feature
```

---

## Notas de instalação

Salve como **`.claude/commands/sdd-run-all.md`**. Invoque com `/sdd-run-all <slug>`.

**Relação com `/sdd-approve` e `/sdd-tasks`:** o `/sdd-run-all` exige que o `03-PLAN-EXEC.md` esteja `approved`. Isso garante que o usuário revisou a decomposição e o DAG antes do executor começar. As TASKs em si seguem `status: ready` — o carimbo de aprovação fica no frontmatter delas (`approved_by`/`approved_at`), gravado pelo `/sdd-approve`. O `/sdd-run-all` apenas dispara a execução; toda parada é por guarda dura (ambiguidade, escopo, teste, deadlock).

**Allowed-tools:** `Bash` amplo porque a execução precisa rodar testes, git, e ferramentas da stack. As guardas são comportamentais (regras invioláveis acima), não de tooling.

Modelo recomendado: use o modelo mais forte disponível na sessão. `/sdd-run-all` toma muitas decisões de implementação seguidas sem revisão humana entre elas — qualidade do raciocínio paga.
