---
description: Fast path do SDD — pula PRD/SPEC/tasks/approve e começa a implementar direto, em branch dedicada. A documentação é materializada retroativamente por /sdd-direct-close ao final.
argument-hint: <descrição livre do que você quer implementar>
allowed-tools: Bash(git:*), Bash(mkdir:*), Bash(date:*), Bash(ls:*), Bash(test:*), Bash(grep:*), Bash(cat:*), Bash(pwd:*), Read, Write, Edit, Grep, Glob
---

# Comando /sdd-direct

Você é o assistente do **fast path** do workflow Spec-Driven local. Em vez de seguir o fluxo completo (`/sdd-new → /sdd-prd → /sdd-approve → /sdd-spec → /sdd-approve → /sdd-tasks → /sdd-approve → /sdd-run-all`), este comando permite ao usuário implementar direto e documentar depois — preservando rastreabilidade SDD via `/sdd-direct-close`.

**Quando usar:** mudanças pequenas/médias onde o usuário já sabe o que fazer e não precisa de discovery, ADRs ou decomposição prévia. Mudanças grandes ou estruturais devem continuar usando o fluxo completo.

**Quando NÃO usar:** mudanças que exigem decisão arquitetural durável (ADR), discovery de negócio (PRD com pesquisa), ou coordenação entre múltiplas pessoas. Para essas, use `/sdd-new`.

O usuário descreveu:

<descricao_inicial>
$ARGUMENTS
</descricao_inicial>

Contexto:
- Branch atual: !`git branch --show-current`
- Working tree: !`git status --short 2>/dev/null || echo "(fora de repo)"`
- Data: !`date +%Y-%m-%d`
- Changes existentes (para evitar colisão de slug): !`ls -1 docs/changes/ 2>/dev/null || echo "(nenhuma)"`
- Nota WIP existente? !`test -f .sdd-direct-WIP.md && echo "SIM" || echo "NÃO"`

---

## Regras gerais

1. **Sem entrevista longa.** Este é o fast path — no máximo UMA pergunta se a descrição for muito vaga. Caso contrário, prossiga sem perguntar.
2. **Não gere PRD/SPEC/tasks agora.** Esse trabalho é feito retroativamente pelo `/sdd-direct-close`. Aqui só preparamos a pista.
3. **Branch dedicada é obrigatória.** Toda implementação direta vive em `feat/{slug}` — mesma convenção do fluxo normal, para o close funcionar.
4. **Nota efêmera no root.** A change ainda não existe em `docs/changes/`. O único rastro durante a implementação é `.sdd-direct-WIP.md` (gitignorado) — guarda slug, descrição inicial, timestamp.
5. **Você implementa em seguida, no mesmo turno se possível.** Após preparar a pista, o usuário (ou você, se ele pedir) faz a codificação. O foco é velocidade.

---

## Fase 0 — Validar entrada

1. **Descrição vazia ou genérica demais** ("preciso de ajuda", "muda lá", etc.):
   - Faça **uma** pergunta: "Descreve em uma frase o que você quer implementar?" Encerre o turno e espere.
2. **Branch atual não é `main`:**
   - Se já estiver numa `feat/{algum-slug}` E existir `.sdd-direct-WIP.md` apontando para esse slug: avise que já há um direct em curso ("Você já está em `feat/{slug-existente}`. Continue a implementação ali ou rode `/sdd-direct-close {slug-existente}` antes de iniciar outro.") e encerre.
   - Se estiver em outra branch com working tree sujo: PARE. "Working tree tem mudanças não commitadas em `{branch}`. Commita ou stash antes de iniciar um direct."
   - Se estiver em outra branch limpa: ok — vamos voltar para `main` e criar `feat/{slug}` a partir dali.

---

## Fase 1 — Gerar slug

A partir da `<descricao_inicial>`:

- kebab-case, sem acentos, sem caracteres especiais
- 2-4 palavras, captura a essência
- exemplos:
  - "alterar foto no perfil deste usuário" → `perfil-foto`
  - "endpoint pra listar pedidos do cliente" → `pedidos-cliente-endpoint`
  - "corrigir cor do botão no header" → `header-botao-cor`

**Colisão:** se o slug já existe em `docs/changes/` (qualquer prefixo) ou como branch `feat/{slug}`, adicione sufixo numérico (`perfil-foto-2`).

---

## Fase 2 — Preparar a branch

**Antes de mexer na branch, cheque o working tree:**

```bash
git status --porcelain
```

- **Saída vazia** (limpo) → siga normalmente.
- **Só arquivos `untracked` (`??`)** — caso comum quando o SDD acabou de ser instalado (kit + `docs/` do `/sdd-analyze` ainda não commitados). Não bloqueiam o `checkout -b`. Siga, mas **pule o `git pull`** (não force atualização com working tree não limpo) e avise no relatório que há arquivos não commitados (provavelmente o setup do SDD — o usuário decide commitar quando quiser).
- **Arquivos modificados/staged (`M`/`A`)** que não são do SDD → PARE. "Há mudanças não commitadas em `{branch}`. Commite ou faça stash antes de iniciar o direct." Não force.

```bash
# Se o working tree permite e branch atual != main, volte para main:
git checkout main
git pull --ff-only          # só se working tree limpo E houver remoto; ignore erro se não houver
git checkout -b feat/{slug}
```

Se não der pra voltar à `main` com segurança (untracked do setup), crie a branch a partir da atual mesmo: `git checkout -b feat/{slug}`. O importante é estar em `feat/{slug}`.

Se a branch `feat/{slug}` já existe localmente (caso raro de retomada): faça `git checkout feat/{slug}` em vez de criar.

---

## Fase 3 — Criar a nota WIP

Crie `.sdd-direct-WIP.md` na raiz do repo (não em `docs/`). Esta nota é a única coisa que existe sobre a change até o close.

```markdown
---
type: direct-wip
slug: {slug}
branch: feat/{slug}
started_at: {YYYY-MM-DD HH:MM}
---

# Direct WIP — {slug}

> Esta é uma nota efêmera do fast path SDD. Ela existe apenas durante a implementação e será **removida** pelo `/sdd-direct-close`, que materializa a documentação retroativamente.

## Descrição inicial

{descrição_inicial — texto cru do usuário, sem polir}

## Branch

`feat/{slug}` (criada a partir de `main` em {data}).

## Próximo passo

1. Implementar.
2. Commitar por escopo coeso — cada commit vira uma TASK retroativa no `/sdd-direct-close`. Mensagem livre, mas use conventional commits (`feat:`, `fix:`, `refactor:`...) se possível, ajuda a documentação.
3. Quando terminar: `/sdd-direct-close {slug}` para gerar PRD/SPEC/tasks/CHANGELOG retroativamente e remover esta nota.
```

### 3.1 — Garantir gitignore

Se `.gitignore` não ignora `.sdd-direct-WIP.md`, adicione a linha. Não deve ser commitada — é estado local da sessão.

```bash
grep -qxF '.sdd-direct-WIP.md' .gitignore 2>/dev/null || echo '.sdd-direct-WIP.md' >> .gitignore
```

Se o `.gitignore` não existe, crie. Se a entrada já existe, não duplique.

Commite **só** a alteração do `.gitignore` (se houve), para que a entrada fique versionada:

```bash
if ! git diff --quiet .gitignore 2>/dev/null; then
  git add .gitignore
  git commit -m "chore({slug}): ignore .sdd-direct-WIP.md"
fi
```

A nota WIP em si **não** é commitada.

---

## Fase 3.5 — Carregar base de conhecimento da stack (antes de implementar)

O fast path pula PRD/SPEC, mas **não pula a aderência à stack**. Antes de escrever qualquer código:

1. Leia a seção `## Active Stacks` do constitution (`docs/constitution.md` ou `docs/explanation/constitution.md`).
2. Para cada stack ativa, leia `.claude/skills/stacks/<skill>/SKILL.md` (golden rules + comando de teste/lint).
3. Como o `/sdd-direct` não tem decomposição prévia, carregue os `references/` conforme você for tocando cada camada: ao criar um controller, leia `references/architecture.md`; ao escrever teste, `references/testing.md`; etc.
4. Leia `docs/patterns/` da(s) stack(s) — o estilo real do time tem precedência sobre o SKILL.md.
5. **Sem `## Active Stacks`** (analyze nunca rodou): avise — "Sem stack ativa no constitution. Recomendo rodar `/sdd-analyze` antes para o código sair no padrão do projeto. Prossigo com conhecimento genérico." E siga, sem bloquear (o fast path preza velocidade).

Anti-alucinação continua valendo no fast path: grep antes de referenciar método/classe/coluna; nunca inventar config/env/endpoint que não existe.

---

## Fase 4 — Resumo e handoff

Mostre, conciso:

1. ✅ Branch criada: `feat/{slug}`
2. 📝 Nota WIP criada em `.sdd-direct-WIP.md` (gitignorada)
3. 🎯 Próximo passo: **implementar**. Commite por escopo coeso (cada commit vira 1 task retroativa). Quando terminar: `/sdd-direct-close {slug}`.

**Dica de commits no fast path:**
- Um commit = um escopo lógico (ex: "feat(perfil-foto): add upload endpoint", depois "feat(perfil-foto): add storage adapter")
- Mensagem curta e descritiva — ela vira o título da TASK retroativa
- Não precisa ser perfeito, o close pode renomear/agrupar se necessário

Se o usuário sinalizar que quer começar a implementar **no mesmo turno** (mensagem do tipo "vamos lá", "pode começar", ou já descreveu o suficiente para você inferir o trabalho), prossiga implementando logo após este relatório. Senão, encerre o turno e espere.

---

## Notas de instalação

Salve como **`.claude/commands/sdd-direct.md`**. Invoque com `/sdd-direct <descrição>`.

**Relação com o resto do fluxo:**
- `/sdd-direct` substitui a sequência `/sdd-new → /sdd-prd → /sdd-approve → /sdd-spec → /sdd-approve → /sdd-tasks → /sdd-approve → /sdd-run-all` para mudanças pequenas/médias.
- Após o trabalho, `/sdd-direct-close` materializa a documentação retroativamente (PRD/SPEC/tasks/CHANGELOG) e remove a nota WIP.
- `/sdd-status` reconhece changes em modo direct pela presença da nota `.sdd-direct-WIP.md` (mostradas como "🚀 Direct em curso") — mas a integração formal com `/sdd-status` é opcional.

**Trade-offs aceitos pelo fast path:**
- Sem PRD aprovado antes de codar → sem rede de segurança de negócio. Use só quando o problema já está claro.
- Sem SPEC antes de codar → sem ADR explícito. Decisões arquiteturais relevantes ainda devem virar ADR no close, mas não há *gate*.
- Sem `files_touched` declarado → você pode tocar onde precisar. O close vai reconstruir `files_touched` a partir do diff real.
- A nota WIP **não** é commitada — se a sessão for perdida e a nota apagada, ainda dá pra reconstruir tudo a partir da branch + commits no close (a nota só facilita).

Modelo recomendado: o `/sdd-direct` em si é leve (cria branch + nota). Se você costuma implementar no mesmo turno, mantenha o modelo padrão da sessão (o trabalho de código pesa, não o setup).
