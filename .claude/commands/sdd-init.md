---
description: Inicializa a estrutura SDD no projeto — gera docs/constitution.md, docs/AGENTS.md e os atalhos na raiz (CLAUDE.md, CODEX.md, GEMINI.md, AGENTS.md) para os agentes IA escolhidos
argument-hint: (sem argumentos — comando interativo)
allowed-tools: Bash(mkdir:*), Bash(ln:*), Bash(cp:*), Bash(test:*), Bash(ls:*), Bash(rm:*), Bash(date:*), Bash(pwd:*), Write, Read
---

# Comando /sdd-init

Você é o assistente de bootstrap do fluxo Spec-Driven Development. Sua função é inicializar a estrutura mínima do SDD em um projeto novo (ou retroativamente em um projeto existente), de forma interativa, sem sobrescrever conteúdo do usuário sem permissão.

Diretório do projeto: !`pwd`

Estado atual:
- `docs/constitution.md` existe? !`test -f docs/constitution.md && echo "SIM" || echo "NÃO"`
- `docs/AGENTS.md` existe? !`test -f docs/AGENTS.md && echo "SIM" || echo "NÃO"`
- Atalhos na raiz: !`ls -1 CLAUDE.md CODEX.md GEMINI.md AGENTS.md 2>/dev/null || echo "(nenhum)"`

---

## Regras gerais de conduta

1. **Uma pergunta por vez.** Faça UMA pergunta, encerre o turno e espere a resposta. Nunca dispare várias perguntas num bloco só.
2. **Não sobrescreva sem permissão.** Se um arquivo já existe, pergunte antes de regerar.
3. **Tom direto.** Sem floreio. Você está fazendo um setup, não um questionário.
4. **Não implemente código de produto.** Este comando só cria estrutura de documentação e atalhos.

---

## Fase 1 — Detecção e plano

Com base no estado atual mostrado acima:

- Se **nada existe**: siga o caminho feliz (Fases 2 → 5).
- Se **algo já existe**: liste o que está presente e pergunte se o usuário quer:
  - manter intacto (pular esses arquivos);
  - sobrescrever com novo template (perde conteúdo existente);
  - cancelar o comando.

Encerre o turno após essa pergunta.

---

## Fase 2 — Quais agentes IA?

Pergunte ao usuário quais ferramentas de IA ele usa neste projeto. Multi-seleção. Opções:

- **Claude Code** → cria `CLAUDE.md` na raiz
- **Codex** → cria `CODEX.md` na raiz
- **Gemini CLI** → cria `GEMINI.md` na raiz
- **AGENTS.md genérico** (padrão aberto, lido por Cursor, Jules e outras) → cria `AGENTS.md` na raiz

Recomendação default: Claude Code + AGENTS.md genérico (cobre quase tudo).

Encerre o turno após a pergunta.

---

## Fase 3 — Estratégia de atalho

Pergunte qual estratégia usar para os atalhos na raiz:

- **Symlink** (recomendado em Linux/Mac) — `CLAUDE.md` é um link simbólico para `docs/AGENTS.md`. Fonte única, sem duplicação. Pode não funcionar bem em Windows sem permissão admin ou `core.symlinks=true`.
- **Cópia** (portátil) — `CLAUDE.md` é um arquivo independente com o mesmo conteúdo. Funciona em qualquer SO, mas precisa sincronizar manualmente se mudar o conteúdo. (Sugira ao usuário criar um `/sync-agents` no futuro se escolher essa opção.)

Encerre o turno após a pergunta.

---

## Fase 4 — Identidade do projeto

Faça as perguntas abaixo, **uma por turno**, para preencher os templates. Pule as que já foram respondidas em turnos anteriores.

1. **Nome do projeto:** (texto curto — vai no título do constitution e do AGENTS.md)
2. **Resumo do projeto em uma frase:** (o que ele é, qual o escopo)
3. **Stack principal:** (uma a três frases — ex: "Vanilla JS + localStorage, sem build" / "Laravel 11 + Vue 3 + PostgreSQL")
4. **Entrypoint:** (arquivo ou comando para abrir o projeto — ex: `src/index.html`, `php artisan serve`, `npm run dev`)
5. **Como rodar localmente:** (uma a três linhas de instrução prática — vai no AGENTS.md)

Encerre o turno após cada pergunta. Se a resposta vier rica e cobrir várias perguntas, pule as cobertas.

---

## Fase 5 — Geração dos arquivos

Crie as pastas-base se não existirem:

```bash
mkdir -p docs/changes docs/patterns docs/adr
```

### 5.1 — `docs/constitution.md`

Use o template abaixo, substituindo os placeholders `{{...}}` com as respostas coletadas. Mantenha apenas as seções 1, 2 e 7 preenchidas com o que foi coletado; as demais ficam como esqueleto comentado para o usuário preencher depois.

```markdown
---
title: "Constitution — {{NOME_PROJETO}}"
---

# Constitution — {{NOME_PROJETO}}

> Regras fundamentais de identidade, arquitetura e segurança do projeto. Todo agente de IA deve ler antes de qualquer implementação. Para instruções operacionais (como rodar, fluxo SDD, checklist), ver [`AGENTS.md`](./AGENTS.md).

---

## 1. Identidade do projeto

{{RESUMO_PROJETO}}

**Entrypoint:** `{{ENTRYPOINT}}`

---

## 2. Stack canônica

{{STACK}}

**Regra:** Não introduzir nenhuma dependência externa sem uma ADR aprovada que justifique o trade-off.

---

## 3. Modelo de dados

_(Preencher: schemas principais, entidades, relacionamentos. Pode usar TypeScript-like interfaces ou tabelas.)_

---

## 4. Padrões de código

_(Preencher: convenções específicas — como nomear, como estruturar arquivos, anti-padrões a evitar.)_

---

## 5. Convenções de nomeação

_(Preencher: tabela contexto → convenção → exemplo.)_

| Contexto | Convenção | Exemplo |
|---|---|---|
| Funções | _camelCase_ | _exemplo_ |
| Variáveis | _camelCase_ | _exemplo_ |
| Constantes | _UPPER_SNAKE_CASE_ | _exemplo_ |

---

## 6. Segurança e privacidade

_(Preencher: regras específicas — onde dados ficam, o que nunca pode ser logado, dependências auditadas, etc.)_

---

## 7. Fronteiras do agente (anti-alucinação)

Estas regras evitam que o agente invente estruturas que não existem no projeto:

1. _(Preencher: o que o projeto NÃO tem — ex: "Não há backend", "Não há testes automatizados ainda".)_
2. _(Preencher: limites do escopo.)_
3. **Pare em ambiguidade.** Se o escopo de uma task não estiver claro, pergunte. Não infira nem invente comportamento não documentado.

---

## 8. Decisões arquiteturais registradas

| ADR | Título | Status |
|---|---|---|
| _(nenhuma ainda)_ | | |

Consulte os ADRs em [`adr/`](./adr/) antes de propor mudanças estruturais.
```

### 5.2 — `docs/AGENTS.md`

```markdown
---
title: "AGENTS.md — {{NOME_PROJETO}}"
---

# AGENTS.md — {{NOME_PROJETO}}

> Instruções operacionais para agentes de IA (Claude Code, Codex, Gemini, etc.) trabalhando neste projeto.
> Para regras de identidade, arquitetura e anti-alucinação, ver [`constitution.md`](./constitution.md).

---

## Antes de qualquer task

1. Leia [`constitution.md`](./constitution.md) — regras fundamentais (stack, modelo de dados, fronteiras).
2. Consulte [`patterns/`](./patterns/) — exemplares canônicos do código real.
3. Verifique [`adr/`](./adr/) se for tocar em decisões arquiteturais.
4. Leia a task ativa em [`changes/<slug>/tasks/`](./changes/) e respeite o `files_touched` declarado.

---

## Como rodar o projeto

{{COMO_RODAR}}

---

## Fluxo SDD — referência rápida

Toda alteração nasce de uma `/sdd-new` e termina em `/sdd-archive`. Os comandos vivem em `.claude/commands/`. Consulte o [README](../README.md) para os fluxos completos.

| Comando | Quando usar |
|---|---|
| `/sdd-new <texto>` | Captura inicial de qualquer pedido — classifica em feature/fix/chore |
| `/sdd-prd <slug>` | Gera o PRD (somente feature) |
| `/sdd-approve <slug>` | Aprova documentos da change (PRD, SPEC, PLAN-EXEC) e carimba tasks |
| `/sdd-spec <slug>` | Gera a SPEC + ADRs |
| `/sdd-tasks <slug>` | Decompõe a SPEC em tasks com dependências + plano de execução |
| `/sdd-run-all <slug>` | Executa todas as tasks autonomamente (1 commit por task, retomável) |
| `/sdd-status [slug]` | Mostra estado atual das changes (read-only) |
| `/sdd-archive <slug>` | Fecha a change, sincroniza docs e atualiza CHANGELOG |

> Fluxos rápidos de fix e chore ainda não existem nesta versão — todas as changes passam pelo fluxo de feature por enquanto.

---

## Regras operacionais

1. **`files_touched` é fronteira dura.** Trabalhe somente dentro dos arquivos declarados na task ativa. Se precisar tocar algo fora, pare e pergunte.
2. **Nunca feche uma change sem `/sdd-archive`.** O comando sincroniza CHANGELOG e docs.
3. **Nunca delete, comente ou skipe um teste/comportamento para fazer outro funcionar.** Resolva o conflito na raiz.
4. **Recursos compartilhados → sequencial.** Schemas, configs globais, migrations e arquivos de roteamento nunca rodam em paralelo com outras tasks.
5. **Toda decisão arquitetural não trivial gera um ADR.** Em `docs/adr/`, antes da implementação.
6. **Um commit por task.** Mensagem no formato `<tipo>(<slug>): <descrição>`.

---

## Pare em ambiguidade

Se o escopo de uma task não estiver claro, **pergunte**. Não infira nem invente comportamento não documentado.

---

## Checklist pré-entrega

_(Preencher conforme o projeto evolui. Sugestão de itens para começar:)_

- [ ] O projeto sobe sem erros no console / log.
- [ ] As operações principais funcionam com dados reais.
- [ ] Nenhum dado é corrompido após reload / reinicialização.
- [ ] O código não introduz estado global não intencional.
```

### 5.3 — Atalhos na raiz

Para cada agente selecionado na Fase 2, crie o atalho conforme a estratégia da Fase 3.

**Mapeamento agente → arquivo:**

| Agente | Arquivo na raiz |
|---|---|
| Claude Code | `CLAUDE.md` |
| Codex | `CODEX.md` |
| Gemini CLI | `GEMINI.md` |
| Genérico | `AGENTS.md` |

**Symlink:**

```bash
ln -s docs/AGENTS.md CLAUDE.md
ln -s docs/AGENTS.md CODEX.md
ln -s docs/AGENTS.md GEMINI.md
ln -s docs/AGENTS.md AGENTS.md
```

Crie apenas os escolhidos.

**Cópia:**

```bash
cp docs/AGENTS.md CLAUDE.md
cp docs/AGENTS.md CODEX.md
cp docs/AGENTS.md GEMINI.md
cp docs/AGENTS.md AGENTS.md
```

Se o arquivo de destino já existir e o usuário escolheu "sobrescrever" na Fase 1, remova antes (`rm <arquivo>`). Se escolheu "manter intacto", pule esse atalho específico e avise no relatório final.

---

## Fase 6 — Relatório e próximos passos

Liste de forma compacta:

1. **Arquivos criados** (com caminho).
2. **Atalhos criados** na raiz (e a estratégia usada — symlink/cópia).
3. **Pastas-base criadas** (`docs/changes/`, `docs/patterns/`, `docs/adr/`).
4. **Próximos passos sugeridos:**
   - Preencher seções 3-6 do `docs/constitution.md` com a realidade do projeto.
   - Criar 3-4 exemplares em `docs/patterns/` apontando para arquivos reais do código.
   - Rodar `/sdd-new <descrição>` para começar a primeira change.

Seja conciso. Não repita o conteúdo dos arquivos — o usuário pode abri-los.

---

## Exemplo de execução (referência interna)

```
> /sdd-init

[Detecta: nada existe ainda. Caminho feliz.]

Claude: Quais agentes IA você usa neste projeto? (multi)
        a) Claude Code   b) Codex   c) Gemini CLI   d) AGENTS.md genérico
> a, d

Claude: Estratégia de atalho? Symlink (Linux/Mac, fonte única) ou Cópia (portátil)?
> symlink

Claude: Nome do projeto?
> Agenda de Pessoas

Claude: Resumo em uma frase?
> SPA client-side para gerenciar cadastros de pessoas, sem backend.

Claude: Stack principal?
> Vanilla JS + HTML/CSS + localStorage, sem build step.

Claude: Entrypoint?
> src/index.html

Claude: Como rodar localmente?
> Abrir src/index.html no navegador. Janela anônima para sessão isolada.

[Gera docs/constitution.md, docs/AGENTS.md, symlinks CLAUDE.md e AGENTS.md na raiz, pastas vazias.]

Claude: ✅ Estrutura SDD criada.
        Arquivos: docs/constitution.md, docs/AGENTS.md
        Atalhos: CLAUDE.md → docs/AGENTS.md, AGENTS.md → docs/AGENTS.md (symlinks)
        Pastas: docs/changes/, docs/patterns/, docs/adr/

        Próximos passos:
        1. Preencher seções 3-6 do constitution com a realidade do projeto.
        2. Criar exemplares em docs/patterns/.
        3. /sdd-new <descrição> para começar a primeira change.
```

---

## Notas de instalação

Este comando assume que o diretório de trabalho é a raiz do projeto. Se rodar em subdiretório, os caminhos relativos vão errar — peça ao usuário para confirmar `pwd` antes de prosseguir se houver dúvida.

Para projetos que **já têm** documentação SDD parcial (ex: vindos do template antigo `docs/explanation/constitution.md`), este comando não migra automaticamente. Avise o usuário e sugira mover manualmente o conteúdo antigo antes de sobrescrever.
