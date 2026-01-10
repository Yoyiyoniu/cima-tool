#!/bin/bash

DOMAIN="pcw.uabc.mx"

if command -v nslookup &> /dev/null; then
    IP=$(nslookup $DOMAIN 2>/dev/null | grep -A 1 "Name:" | grep "Address" | tail -n 1 | awk '{print $2}')
    if [ ! -z "$IP" ] && [[ $IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "IP encontrada: $IP"
        exit 0
    fi
fi

if command -v ping &> /dev/null; then
    IP=$(ping -c 1 $DOMAIN 2>/dev/null | grep -oP '\([0-9.]+\)' | head -n 1 | tr -d '()')
    if [ ! -z "$IP" ] && [[ $IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "IP encontrada: $IP"
        exit 0
    fi
fi

if command -v getent &> /dev/null; then
    IP=$(getent hosts $DOMAIN 2>/dev/null | awk '{print $1}' | head -n 1)
    if [ ! -z "$IP" ] && [[ $IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "IP encontrada: $IP"
        exit 0
    fi
fi

if command -v host &> /dev/null; then
    IP=$(host $DOMAIN 2>/dev/null | grep -oP 'has address \K[0-9.]+' | head -n 1)
    if [ ! -z "$IP" ] && [[ $IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "IP encontrada: $IP"
        exit 0
    fi
fi

if command -v dig &> /dev/null; then
    IP=$(dig +short $DOMAIN 2>/dev/null | grep -oP '^[0-9.]+$' | head -n 1)
    if [ ! -z "$IP" ] && [[ $IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "IP encontrada: $IP"
        exit 0
    fi
fi

echo "Error: No se pudo obtener la IP de $DOMAIN"
echo ""
echo "Sugerencias:"
echo "   - Verifica tu conexión a internet"
echo "   - Si usas VPN, desactívala temporalmente"
echo "   - Instala herramientas DNS: pkg install bind-utils"
exit 1
