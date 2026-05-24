---
description: Fecha uma change concluída — gera o dossiê final, sincroniza a documentação viva com o que mudou, registra no CHANGELOG global e marca como entregue
argument-hint: <slug-da-change>
allowed-tools: Bash(git:*), Bash(find:*), Bash(grep:*), Bash(ls:*), Bash(wc:*), Bash(test:*), Bash(date:*), Bash(basename:*), Read, Grep, Glob, Write, Edit, Task
---

# Comando /sdd-archive

Você fecha uma change concluída no workflow Spec-Driven local. Três responsabilidades: (1) consolidar o **dossiê final** (README da change), (2) **sincronizar a documentação viva** (guides/reference/explanation) com o que efetivamente mudou no código, e (3) registrar a entrega no **CHANGELOG global**. Ao final, marca a change como `delivered`. É o último passo antes do merge na main.

Argumento (slug): `$ARGUMENTS`

Contexto:
- Branch atual: !`git branch --show-current`
- Data: !`date +%Y-%m-%d`
- Changes candidatas: !`find docs/changes -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort || echo "(nenhuma)"`

---

## Regras

1. **Doc é prosa que humanos leem — não invente.** Toda atualização de documentação deve se basear no que realmente mudou (a SPEC, os commits, o diff). Nunca fabrique comportamento, número ou instrução que o código não suporta.
2. **Sincronize, não reescreva.** Atualize as páginas afetadas com cirurgia — mude o que ficou desatualizado, preserve o resto. Não reescreva páginas inteiras sem necessidade.
3. **O usuário revisa antes do merge.** Você commita na branch da change, mas a doc gerada deve ser revisada por ele antes do merge final na main. Deixe isso claro.
4. **Diagramas em Mermaid, nunca imagem.** Se precisar atualizar/criar diagrama, use Mermaid embutido (a IA consegue manter; PNG vira drift).
5. **Adapte ao tipo da change.** Feature é o único fluxo completo nesta versão. Pastas `fix-` ou `chore-` que tenham seguido o fluxo de feature são tratadas como feature aqui; o tratamento leve clássico de fix/chore voltará junto com o fluxo rápido dedicado.

---

## Fase 0 — Resolver a change

1. Localize `docs/changes/{feat|fix|chore}-*-{slug}` a partir de `$ARGUMENTS`.
2. Se vazio/ambíguo, liste candidatas e pergunte. Encerre.
3. Identifique o `kind` (pelo prefixo da pasta e pelo frontmatter do README/artefato principal).

---

## Fase 1 — Validar pré-condições e ramificar por tipo

Leia o frontmatter dos artefatos. O peso do archive depende do tipo:

**FEATURE:** confira que **todas** as tasks em `tasks/` estão `status: done`.
- Se alguma não está: PARE. Liste as pendentes e oriente — "Conclua a implementação (`/sdd-run-all {slug}`) antes de arquivar." Encerre.
- Se ok: tratamento completo (Fases 2–6).

**FIX/CHORE (pasta legada ou seguindo fluxo de feature):** se a pasta tem `tasks/`, trate como feature acima. Se tem apenas `FIX.md`/`NOTE.md` de versões anteriores, faça um dossiê curto + entrada no CHANGELOG e marque delivered manualmente. O fluxo rápido dedicado para fix/chore voltará em outra iteração.

Se a change já está `delivered`, avise e pergunte se deseja re-arquivar (regenerar dossiê/doc).

---

## Fase 2 — Coletar o estado final

Reúna o material que vai alimentar dossiê e doc:

1. **Artefatos da change:** `00-idea.md`, `01-PRD.md`, `02-SPEC.md` (ou `FIX.md`), todas as `tasks/*.md`, ADRs referenciados.
2. **Commits da change** — use o prefixo de branch correto conforme o `kind` (`feat`, `fix`, `chore`). Daqui em diante, `{branch}` = `{kind}/{slug}` (ex: `feat/export-pdf`, `fix/pdf-encoding`, `chore/bump-laravel`). Os relatórios de implementação estão nos corpos:
   ```
   git log main..{branch} --pretty=format:'%h %s%n%b'
   ```
3. **Diff agregado** — o que a change realmente mudou no código:
   ```
   git diff main...{branch} --stat
   git diff main...{branch} --name-only
   ```
   Use o `--stat` e `--name-only` para saber QUE arquivos mudaram; leia o diff completo de arquivos específicos só quando precisar entender uma mudança para documentá-la.

---

## Fase 3 — Gerar o dossiê final (README da change)

Atualize `docs/changes/{pasta}/README.md` para a versão final. Para FEATURE:

```markdown
---
type: change
kind: feature
slug: {slug}
status: delivered
external_id: null
created: {data-original}
delivered_at: {YYYY-MM-DD}
---

# {Título da feature}

> {uma linha}

## Estado
✅ Entregue em {YYYY-MM-DD} · branch feat/{slug}

## Sumário
{2-4 frases: o que foi entregue, do ponto de vista de produto}

## Artefatos
- 📋 [PRD](./01-PRD.md) — aprovado em {data}
- 📐 [SPEC](./02-SPEC.md) — validada
- 🏛️ ADRs: {lista com links, ou "nenhum"}

## Tasks executadas
| Task | Complexidade | Status |
|---|---|---|
| [TASK-001 …](./tasks/…) | small | ✅ |
| … | | |

## Mudanças de stack
{novas dependências, mudanças de config; ou "nenhuma"}

## Configuração pós-deploy
{passos obrigatórios após deploy — seeds, flags, permissions; ou "nenhuma"}

## Como reverter (rollback)
{resumo da estratégia de rollback da SPEC}

## Limitações conhecidas
{o que ficou de fora / para próximas iterações}
```

Para pastas legadas de fix/chore (sem fluxo de feature), um dossiê curto basta (sintoma/correção/arquivos, ou o que mudou e por quê).

---

## Fase 4 — Sincronizar a documentação viva

Esta é a parte que mantém a doc honesta. Trabalhe em três camadas (Diátaxis):

**1. Identifique o que mudou de comportamento.** A partir da SPEC + diff, liste os componentes e comportamentos novos/alterados que são observáveis ou relevantes para quem lê a doc.

**2. Encontre as páginas afetadas.** Para cada conceito/componente tocado, faça `grep` em `docs/guides/`, `docs/reference/`, `docs/explanation/` procurando menções. Use subagents (Task) para varrer em paralelo se houver muitas páginas.

**3. Atualize por camada:**

- **reference/** — se a change mexeu em API, endpoints, permissions, schema, config: atualize as tabelas/listas correspondentes. Baseie-se no diff real (ex: permission nova no seeder → linha nova em `reference/permissions.md`).

- **guides/** — se a change introduz algo que o usuário final faz (um novo fluxo, botão, capacidade): atualize o guia existente OU crie um guia novo passo-a-passo. Guias são didáticos e em linguagem do usuário, não do dev.

- **explanation/** — se a change altera a arquitetura ou introduz um padrão estrutural novo: atualize `explanation/architecture.md` (com diagrama Mermaid se ajudar) e referencie os ADRs relevantes. Mudanças pequenas raramente tocam aqui.

Para cada arquivo que você criar/editar, faça edição cirúrgica e fiel ao que mudou. Se não houver nada a atualizar numa camada, não invente conteúdo só para preencher.

---

## Fase 5 — Registrar no CHANGELOG global

Atualize `docs/CHANGELOG.md` (crie com cabeçalho se não existir), adicionando a entrada mais recente no topo:

```markdown
## {YYYY-MM-DD}
- **{kind}({slug})** — {uma linha do que mudou}. [Detalhes](./changes/{pasta}/README.md)
```

Agrupe por data. Se já houver entradas da mesma data, adicione à seção existente. O CHANGELOG global é o que vira release notes e o que o `llms.txt` expõe — mantenha as entradas concisas e em linguagem de produto.

---

## Fase 6 — Marcar entregue e commitar

1. Confirme que o frontmatter do README está com `status: delivered` e `delivered_at` preenchido.
2. Commit na branch da change (`{kind}/{slug}`):
   ```
   git add docs/
   git commit -m "docs({slug}): archive — dossiê, sync de docs e changelog"
   ```

---

## Fase 7 — Confirmação e próximo passo

Mostre ao usuário, conciso:

1. Dossiê finalizado (caminho do README).
2. **Páginas de doc tocadas** — liste-as explicitamente, separadas por camada (reference/guides/explanation), porque ele precisa **revisar essas** antes do merge (doc é prosa, IA pode errar tom ou precisão).
3. Entrada adicionada ao CHANGELOG.
4. **Próximo passo — merge final na main** (squash, mantém histórico limpo). Use o prefixo correto da branch da change (`feat/`, `fix/` ou `chore/`):
   ```
   # revise a doc gerada primeiro:
   git diff main...{kind}/{slug} -- docs/

   # depois:
   git checkout main && git pull
   git merge --squash {kind}/{slug}
   git commit -m "{kind}({slug}): {título da change}"
   git push
   ```
   (Opcional: se quiser preview/registro, abra um PR `{kind}/{slug} → main` em vez do squash local.)
5. Após o merge, o `llms.txt`/`llms-full.txt` são regenerados pelo plugin do VitePress no build — não precisa editar à mão.

Não despeje o conteúdo das páginas na confirmação — liste os caminhos; ele abre o que quiser revisar.

---

## Notas de instalação

Salve como **`.claude/commands/sdd-archive.md`**. Invoque com `/sdd-archive <slug>`.

Este comando edita documentação (`Write`/`Edit`) baseando-se no diff real da change. A guarda principal é comportamental: **fiel ao que mudou, revisão humana antes do merge**. Por isso ele commita na branch da change (não na main) — a doc gerada passa pelo seu olhar no diff final.

`Task` está em `allowed-tools` para varrer páginas de doc em paralelo na Fase 4 (útil em projetos com documentação extensa); se não estiver disponível, faça a varredura com `grep` sequencial.

Modelo recomendado: a síntese do dossiê e a edição de doc se beneficiam de raciocínio cuidadoso e bom texto. Use o modelo mais forte disponível na sessão.

**Relação com o resto do fluxo:** o `/sdd-run-all` aponta para `/sdd-archive` quando todas as tasks ficam `done`. O `/sdd-archive` é o passo "In Docs" do workflow original, agora autocontido — sem board, ele deriva tudo do estado dos arquivos e do Git.
