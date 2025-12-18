#!/bin/bash
if [[ $EUID -ne 0 ]]; then
    echo "Этот скрипт нужно запускать с sudo или от root"
    exit 1
fi

ROLES=("proxy" "backend" "postgres" "redis")
PROXY_IP="192.168.100.23"
BACKEND_IP="192.168.100.21"

if [[ $# -ne 1 ]]; then
    echo "Использование: $0 <server-role>"
    echo "Доступные роли: ${ROLES[*]}"
    exit 1
fi

ROLE=""

for r in "${ROLES[@]}"; do
    if [[ "$1" == "$r" ]]; then
        ROLE=$1
        break
    fi
done

if [[ -z "$ROLE" ]]; then
  echo "Некорректная роль"
  echo "Доступные роли: ${ROLES[*]}"
  exit 1
fi

# Определяем дистрибутив
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  DIST_ID="${ID,,}"
  DIST_LIKE="${ID_LIKE:-}"
else
  echo "Не удалось определить дистрибутив"
  exit 1
fi

if ! command -v iptables &>/dev/null; then
    echo "iptables не найден, устанавливаем..."
    if [[ "$DIST_LIKE" == *"debian"* ]]; then
        PM="apt"
        UPDATE_CMD="apt update -y"
        INSTALL_CMD="apt install -y"
        PACKAGE_NAMES="iptables iptables-persistent"

        export DEBIAN_FRONTEND=noninteractive

    elif [[ "$DIST_LIKE" == *"rhel"* || "$DIST_LIKE" == *"fedora"* ]]; then
        OS="redhat"
        PACKAGE_NAMES="iptables iptables-services"
        if command -v dnf >/dev/null 2>&1; then
            PM="dnf"
            UPDATE_CMD="dnf -y update"
            INSTALL_CMD="dnf install -y"
        else
            PM="yum"
            UPDATE_CMD="yum -y update"
            INSTALL_CMD="yum install -y"
        fi
    else
        echo "Неизвестный дистрибутив ($DIST_ID). Пожалуйста, установите iptables вручную."
        exit 1
    fi
    echo "Updating system..."
    $UPDATE_CMD
    $INSTALL_CMD $PACKAGE_NAMES
fi

# настраиваем iptables

iptables -F
iptables -X
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

case "$ROLE" in
    proxy)
       iptables -A INPUT -p tcp --dport 5000 -j ACCEPT
       ;;
    backend)
        iptables -A INPUT -p tcp -s $PROXY_IP --dport 8080 -j ACCEPT
        ;;
    postgres)
        iptables -A INPUT -p tcp -s $BACKEND_IP --dport 5432 -j ACCEPT
        ;;
    redis)
        iptables -A INPUT -p tcp -s $PROXY_IP --dport 6379 -j ACCEPT
        ;;
esac

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT


if [[ "$DIST_LIKE" == *"debian"* ]]; then
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4
    ip6tables-save > /etc/iptables/rules.v6

elif [[ "$DIST_LIKE" == *"rhel"* || "$DIST_LIKE" == *"fedora"* ]]; then
    iptables-save > /etc/sysconfig/iptables

    if command -v systemctl >/dev/null 2>&1; then
        echo "Включаем сервис iptables..."
        systemctl enable iptables 2>/dev/null || true
        systemctl restart iptables 2>/dev/null || true
    fi
fi