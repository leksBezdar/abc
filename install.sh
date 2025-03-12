#!/bin/bash

# Скрипт для фикса пакетов mysql
# Ошибки возникают, т.к. mysql  не содержит нужные заголовки
# Ставится костыльное решение libmysqlclient-dev, которое эти заголовки за них добавит

set -euo pipefail

# Проверка активации виртуального окружения пока выключена, т.к. на сервере все зависимости ставят глобально (зачем-то)
# if [ -z "$VIRTUAL_ENV" ]; then
#     echo "Ошибка: Скрипт должен выполняться в виртуальном окружении"
#     exit 1
# fi


# Вывод списка доступных флагов и их описания
echo "=== Доступные флаги ==="
echo "--no-log: Отключает логирование выполнения скрипта. По умолчанию логи включены."
echo "--with-backup: Создает бэкап системных пакетов перед установкой зависимостей. По умолчанию бэкап не создается."
echo ""
echo "Пример использования: bash ./install.sh --no-log --with-backup"
echo ""


# Обработка флагов
BACKUP_ENABLED=false
LOG_ENABLED=true

if [[ $# -gt 0 ]]; then
    while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do case $1 in
        --no-log)
            echo "Логирование отключено"
            LOG_ENABLED=false
            shift
            ;;
        --with-backup)
            echo "Бэкап будет создан"
            BACKUP_ENABLED=true
            shift
            ;;
        *)
            echo "Неизвестный флаг: $1"
            exit 1
            ;;
        esac done
else
    echo "Аргументы командной строки отсутствуют. Продолжаем без изменений."
fi

# Настройка логирования
if [ "$LOG_ENABLED" = true ]; then
    LOG_DIR="./logs"
    mkdir -p "$LOG_DIR"
    LOG_FILE="$LOG_DIR/install.log"
    exec > >(tee -a "$LOG_FILE") 2>&1
else
    exec > >(cat) 2>&1
fi

# Создание бэкапа (если включен флаг)
if [ "$BACKUP_ENABLED" = true ]; then
    echo "=== Создание бэкапа системных пакетов ==="
    dpkg --get-selections >system_packages.bak
    if [ $? -ne 0 ]; then
        echo "Ошибка при создании бэкапа"
        exit 1
    else
        echo "Бэкап создан: system_packages.bak"
    fi
else
    echo "Бэкап не создан (используйте --with-backup для его создания)"
fi

# Функция очистки при ошибке
cleanup() {
    echo "Операция прервана. Проверьте логи: $LOG_FILE"
    exit 1
}
trap cleanup ERR

# Установка системных зависимостей
echo "=== Установка системных зависимостей ==="
sudo apt install -y libmysqlclient-dev pkg-config python3-dev build-essential

# Проверка mysql_config
if [ ! -f /usr/bin/mysql_config ]; then
    echo "Ошибка: Файл mysql_config не найден"
    exit 1
fi

# Проверка версии pip
PIP_VERSION=$(pip --version | awk '{print $2}' | cut -d '.' -f1-2)
IFS='.' read -ra PIP_VERSION <<<"$PIP_VERSION"
if [ ${PIP_VERSION[0]} -ge 23 ] || ([ ${PIP_VERSION[0]} -eq 22 ] && [ ${PIP_VERSION[1]} -ge 1 ]); then
    PIP_OPTION="--global-option"
else
    PIP_OPTION="--install-option"
fi

# Установка mysqlclient
echo "=== Установка mysqlclient ==="
pip install --no-cache-dir mysqlclient \
    $PIP_OPTION="--with-mysql-config=/usr/bin/mysql_config"
pip list

echo "=== Готово ==="
