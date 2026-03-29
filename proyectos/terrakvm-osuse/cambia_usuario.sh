#!/bin/bash

# Verificar que se entregue un argumento
if [ -z "$1" ]; then
    echo "Uso: $0 <nuevo_usuario>"
    exit 1
fi

# Carpeta actual, recursivo, reemplazo en todos los archivos de texto
find . -type f -exec sed -i "s/nicolas-fuentes/$1/g" {} +

echo "Proyecto preparado para el usuario '$1'"
