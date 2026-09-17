#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
CONFIG_FILE="./.git_myconfig"

usage() {
    cat <<EOF
Використання:
  $SCRIPT_NAME                            - довідка
  $SCRIPT_NAME <dir_name>                 - створити та ініціалізувати репозиторій <dir_name>
  $SCRIPT_NAME <dir_name> <remote_url>    - те саме + підключити remote-репозиторій

Налаштування (USER_NAME, USER_EMAIL, USER_BRANCH) зчитуються з файлу
"$CONFIG_FILE" у поточній директорії. Якщо файл відсутній - буде
запропоновано створити його в діалоговому режимі.
EOF
}

# --- Безпека: кількість параметрів ---
if [ "$#" -gt 2 ]; then
    echo "Помилка: занадто багато параметрів (максимум 2)." >&2
    exit 1
fi

# --- Безпека: скрипт запускається з директорії проєктів, а не зсередини репозиторію ---
if [ -d "./.git" ]; then
    echo "Помилка: поточна директорія вже є Git-репозиторієм." >&2
    echo "Запускайте скрипт з директорії проєктів (напр. ~/projects/), а не зсередини репозиторію." >&2
    exit 1
fi

# --- Конфігурація: завантажити або запропонувати створити ---
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
else
    echo "Файл конфігурації '$CONFIG_FILE' не знайдено."
    read -rp "Створити його зараз? [y/N]: " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        read -rp "Ваше ім'я (USER_NAME): " USER_NAME
        read -rp "Ваш email (USER_EMAIL): " USER_EMAIL
        read -rp "Гілка за замовчуванням (USER_BRANCH) [main]: " USER_BRANCH
        USER_BRANCH="${USER_BRANCH:-main}"

        cat > "$CONFIG_FILE" <<EOF
USER_NAME="$USER_NAME"
USER_EMAIL="$USER_EMAIL"
USER_BRANCH="$USER_BRANCH"
EOF
        echo "Конфігурацію збережено у $CONFIG_FILE"
    else
        echo "Без конфігурації продовжити неможливо. Завершення роботи."
        exit 0
    fi
fi

if [ -z "${USER_NAME:-}" ] || [ -z "${USER_EMAIL:-}" ] || [ -z "${USER_BRANCH:-}" ]; then
    echo "Помилка: конфігурація неповна (USER_NAME/USER_EMAIL/USER_BRANCH)." >&2
    exit 1
fi

if [ "$#" -eq 0 ]; then
    usage
    exit 0
fi

DIR_NAME="$1"
REMOTE_URL="${2:-}"

init_repo_in_dir() {
    local dir="$1"
    (
        cd "$dir"
        git init
        git config --local user.name "$USER_NAME"
        git config --local user.email "$USER_EMAIL"
        git config --local init.defaultBranch "$USER_BRANCH"
        git branch -M "$USER_BRANCH" 2>/dev/null || true
        if [ ! -f README.md ]; then
            echo "# $(basename "$dir")" > README.md
            git add README.md
            git commit -m "Initial commit: add README.md"
        fi
    )
}

add_remote() {
    local dir="$1"
    local url="$2"
    (
        cd "$dir"
        if git remote get-url origin >/dev/null 2>&1; then
            echo "Remote 'origin' вже існує у '$dir', пропускаю."
        else
            git remote add origin "$url"
            echo "Remote 'origin' додано: $url"
        fi
    )
}

# --- 1 параметр: створити/ініціалізувати директорію-репозиторій ---
if [ "$#" -eq 1 ]; then
    if [ -d "$DIR_NAME" ]; then
        if [ -d "$DIR_NAME/.git" ]; then
            echo "Директорія '$DIR_NAME' вже є Git-репозиторієм."
            exit 0
        elif [ -n "$(ls -A "$DIR_NAME" 2>/dev/null)" ]; then
            echo "Директорія '$DIR_NAME' існує та не є порожньою (і не є репозиторієм)."
            exit 0
        else
            init_repo_in_dir "$DIR_NAME"
        fi
    else
        mkdir -p "$DIR_NAME"
        init_repo_in_dir "$DIR_NAME"
    fi
    exit 0
fi

# --- 2 параметри: директорія + remote_url ---
if [ "$#" -eq 2 ]; then
    if [ ! -d "$DIR_NAME" ]; then
        mkdir -p "$DIR_NAME"
        init_repo_in_dir "$DIR_NAME"
        add_remote "$DIR_NAME" "$REMOTE_URL"
    elif [ -d "$DIR_NAME/.git" ]; then
        add_remote "$DIR_NAME" "$REMOTE_URL"
    elif [ -z "$(ls -A "$DIR_NAME" 2>/dev/null)" ]; then
        init_repo_in_dir "$DIR_NAME"
        add_remote "$DIR_NAME" "$REMOTE_URL"
    else
        echo "Директорія '$DIR_NAME' існує, містить файли, але не є Git-репозиторієм. Завершення роботи." >&2
        exit 1
    fi
fi
