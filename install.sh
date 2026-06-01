#!/usr/bin/env bash
#
# install.sh — instalador do SDD Workflow (Spec-Driven Development)
#
# Clona o kit de https://github.com/lipebz/fluxo-sdd e copia os comandos
# e skills para o .claude/ do projeto atual, de forma segura (sem
# sobrescrever customizações sem avisar; faz backup do que colidir).
#
# Uso:
#   bash install.sh                 # instala no diretório atual
#   bash install.sh /caminho/projeto  # instala no diretório informado
#   bash install.sh --help
#
# Ou direto da web (sempre pega a versão mais recente):
#   curl -fsSL https://raw.githubusercontent.com/lipebz/fluxo-sdd/main/install.sh | bash
#
set -euo pipefail

# ----- configuração -----
REPO_URL="https://github.com/lipebz/fluxo-sdd.git"
REPO_BRANCH="main"

# ----- cores (degradam para vazio se não houver TTY) -----
if [ -t 1 ]; then
  BOLD=$(printf '\033[1m'); DIM=$(printf '\033[2m'); RESET=$(printf '\033[0m')
  GREEN=$(printf '\033[32m'); YELLOW=$(printf '\033[33m'); RED=$(printf '\033[31m'); BLUE=$(printf '\033[34m')
else
  BOLD=""; DIM=""; RESET=""; GREEN=""; YELLOW=""; RED=""; BLUE=""
fi

info()  { printf '%s\n' "${BLUE}›${RESET} $*"; }
ok()    { printf '%s\n' "${GREEN}✓${RESET} $*"; }
warn()  { printf '%s\n' "${YELLOW}⚠${RESET} $*"; }
err()   { printf '%s\n' "${RED}✗${RESET} $*" >&2; }

usage() {
  cat <<EOF
${BOLD}SDD Workflow — instalador${RESET}

Clona o kit do GitHub e copia comandos + skills para o .claude/ do projeto.

${BOLD}Uso:${RESET}
  bash install.sh [DIRETORIO_DO_PROJETO]

  DIRETORIO_DO_PROJETO   Onde instalar (padrão: diretório atual)

${BOLD}Opções:${RESET}
  -h, --help    Mostra esta ajuda

O instalador é seguro:
  - nunca apaga skills próprias do seu projeto;
  - faz backup (.bak-TIMESTAMP) de qualquer arquivo do SDD que já exista e difira;
  - preserva/mescla o seu .claude/.gitignore.
EOF
}

# ----- parse de argumentos -----
TARGET_DIR="."
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    -*) err "Opção desconhecida: $arg"; usage; exit 1 ;;
    *) TARGET_DIR="$arg" ;;
  esac
done

# ----- pré-checagens -----
command -v git >/dev/null 2>&1 || { err "git não encontrado. Instale o git e tente de novo."; exit 1; }

if [ ! -d "$TARGET_DIR" ]; then
  err "Diretório não existe: $TARGET_DIR"
  exit 1
fi
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"  # normaliza para caminho absoluto

info "Instalando o SDD Workflow em: ${BOLD}${TARGET_DIR}${RESET}"
if [ ! -d "$TARGET_DIR/.git" ]; then
  warn "Este diretório não parece ser um repositório git. O SDD usa branches por change — recomendo rodar 'git init' antes de usar o fluxo."
fi

# ----- clona o kit em um tmp -----
TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

info "Clonando o kit de ${REPO_URL} (branch ${REPO_BRANCH})…"
if ! git clone --quiet --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" "$TMP_DIR/kit" 2>/dev/null; then
  err "Falha ao clonar o repositório. Verifique sua conexão e o acesso a ${REPO_URL}."
  exit 1
fi
SRC=".claude"
if [ ! -d "$TMP_DIR/kit/$SRC/commands" ]; then
  err "Kit clonado não contém .claude/commands — estrutura inesperada. Abortando."
  exit 1
fi
ok "Kit clonado."

# ----- helper: copia um arquivo com backup seguro -----
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
COPIED=0; SKIPPED=0; BACKED_UP=0

copy_file_safe() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -f "$dst" ]; then
    if cmp -s "$src" "$dst"; then
      SKIPPED=$((SKIPPED+1)); return  # idêntico, nada a fazer
    fi
    cp "$dst" "${dst}.bak-${TIMESTAMP}"
    BACKED_UP=$((BACKED_UP+1))
    warn "Diferente — backup criado: ${DIM}${dst}.bak-${TIMESTAMP}${RESET}"
  fi
  cp "$src" "$dst"
  COPIED=$((COPIED+1))
}

# ----- copia uma árvore inteira, arquivo por arquivo (preserva o resto) -----
# Retorna 1 (sem abortar) se a árvore-fonte não existir, para o chamador avisar.
copy_tree_safe() {
  local src_root="$1" dst_root="$2"
  local f rel
  if [ ! -d "$src_root" ]; then
    return 1
  fi
  while IFS= read -r -d '' f; do
    rel="${f#"$src_root"/}"
    copy_file_safe "$f" "$dst_root/$rel"
  done < <(find "$src_root" -type f -print0)
  return 0
}

# ----- 1) comandos -----
info "Copiando comandos…"
if ! copy_tree_safe "$TMP_DIR/kit/$SRC/commands" "$TARGET_DIR/.claude/commands"; then
  err "O kit clonado não tem .claude/commands — instalação não pode continuar."
  exit 1
fi

# ----- 2) skills de stack (NÃO toca em outras skills do projeto) -----
info "Copiando skills de stack…"
if ! copy_tree_safe "$TMP_DIR/kit/$SRC/skills/stacks" "$TARGET_DIR/.claude/skills/stacks"; then
  warn "O kit clonado não tem .claude/skills/stacks (versão do repo sem as skills curadas)."
  warn "Comandos foram instalados; o /sdd-analyze ainda funciona usando fallback web para skills."
fi

# ----- 3) .claude/.gitignore (mescla, não sobrescreve cego) -----
GI_SRC="$TMP_DIR/kit/$SRC/.gitignore"
GI_DST="$TARGET_DIR/.claude/.gitignore"
if [ -f "$GI_SRC" ]; then
  if [ ! -f "$GI_DST" ]; then
    cp "$GI_SRC" "$GI_DST"
    ok "Criado .claude/.gitignore"
  else
    # garante que as regras essenciais (!commands/ !skills/) existam, sem mexer no resto
    ADDED=0
    for rule in "!commands/" "!commands/**" "!skills/" "!skills/**"; do
      if ! grep -qxF "$rule" "$GI_DST"; then
        printf '%s\n' "$rule" >> "$GI_DST"; ADDED=$((ADDED+1))
      fi
    done
    if [ "$ADDED" -gt 0 ]; then
      ok "Mescladas ${ADDED} regra(s) no .claude/.gitignore existente"
    else
      SKIPPED=$((SKIPPED+1))
    fi
  fi
fi

# ----- relatório -----
echo
ok "${BOLD}Instalação concluída.${RESET}"
printf '   %s arquivos copiados · %s já idênticos · %s backups criados\n' "$COPIED" "$SKIPPED" "$BACKED_UP"
if [ "$BACKED_UP" -gt 0 ]; then
  warn "Arquivos que diferiam foram salvos como *.bak-${TIMESTAMP} — revise se eram customizações suas."
fi
echo
cat <<EOF
${BOLD}Próximos passos:${RESET}
  1. Abra o Claude Code na raiz do projeto e digite ${BLUE}/${RESET} — os comandos ${BLUE}sdd-*${RESET} devem aparecer.
  2. Rode ${BLUE}/sdd-init${RESET}     — estrutura docs/ + identidade do projeto.
  3. Rode ${BLUE}/sdd-analyze${RESET}  — descobre a stack, extrai patterns reais e ativa as skills.
  4. Comece a trabalhar:
       ${BLUE}/sdd-new "sua feature"${RESET}     (fluxo completo)   ou
       ${BLUE}/sdd-direct "mudança rápida"${RESET} (fast path)

  Commit sugerido:
       git add .claude/ docs/ && git commit -m "chore: instala SDD workflow"
EOF
