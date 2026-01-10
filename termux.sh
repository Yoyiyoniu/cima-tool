#!/bin/sh

set -e

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

ensure_bash() {
  if ! has_cmd bash; then
    echo "Instalando bash... (pkg install -y bash)"
    pkg install -y bash
  fi
}

download() {
  url="$1"
  out="$2"
  if has_cmd curl; then
    curl -L -o "$out" "$url"
  elif has_cmd wget; then
    wget -O "$out" "$url"
  else
    echo "Necesitas curl o wget para descargar archivos. Instalando curl..."
    pkg install -y curl
    curl -L -o "$out" "$url"
  fi
}

# Detectar si estamos en Termux (Android)
ON_TERMUX=0
if [ -n "$PREFIX" ] && echo "$PREFIX" | grep -q "com.termux" 2>/dev/null; then
  ON_TERMUX=1
elif [ -d "/data/data/com.termux" ]; then
  ON_TERMUX=1
fi

# Parsear argumento --use-conda para forzar intento de instalar/usar conda
USE_CONDA=0
# Parse only leading args for this script; keep others to pass to the python script
while [ "$#" -gt 0 ]; do
  case "$1" in
    --use-conda)
      USE_CONDA=1
      shift
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

# Si estamos en Termux, por defecto no forzamos conda a menos que USE_CONDA=1
if [ "$ON_TERMUX" -eq 1 ] && [ "$USE_CONDA" -ne 1 ]; then
  echo "Detectado Termux en teléfono: por defecto usaré pip en lugar de conda. Si quieres forzar conda, vuelve a ejecutar con --use-conda o establece USE_CONDA=1."
fi

# Instala Miniforge o Miniconda según la arquitectura
install_conda() {
  echo "Intentando instalar conda (Miniforge/Miniconda)..."
  ensure_bash

  ARCH="$(uname -m)"
  TMP_INSTALLER="/tmp/conda_installer.sh"

  if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    # Miniforge aarch64 puede funcionar en Termux en algunos casos, pero no está garantizado
    URL="https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-aarch64.sh"
  else
    URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
  fi

  echo "Descargando instalador desde: $URL"
  download "$URL" "$TMP_INSTALLER"
  chmod +x "$TMP_INSTALLER"

  echo "Ejecutando instalador (esto instalará en \$HOME/miniconda)..."
  bash "$TMP_INSTALLER" -b -p "$HOME/miniconda"

  # Inicializar conda para la shell actual
  . "$HOME/miniconda/etc/profile.d/conda.sh" || true
  export PATH="$HOME/miniconda/bin:$PATH"

  if has_cmd conda; then
    echo "Conda instalado en $HOME/miniconda"
    return 0
  else
    echo "Error: la instalación de conda falló"
    return 1
  fi
}

# Obtener nombre del entorno desde environment.yml
get_env_name_from_yml() {
  if [ -f environment.yml ]; then
    name_line=$(grep -E '^name:' environment.yml | head -n1 || true)
    if [ -n "$name_line" ]; then
      echo "$name_line" | awk '{print $2}'
      return
    fi
  fi
  # valor por defecto
  echo "cima_env"
}

# Comprueba si un entorno conda existe
conda_env_exists() {
  env_name="$1"
  if ! has_cmd conda; then
    return 1
  fi
  conda env list | awk '{print $1}' | grep -xq "$env_name" && return 0 || return 1
}

# Crear entorno conda desde environment.yml
create_conda_env() {
  env_name="$1"
  if [ ! -f environment.yml ]; then
    echo "No se encontró environment.yml"
    return 1
  fi

  echo "Creando entorno conda desde environment.yml..."
  conda env create -f environment.yml || {
    echo "conda env create falló, intentando conda env update..."
    conda env update -f environment.yml --prune || return 1
  }
  return 0
}

# Comprobar si paquetes Python requeridos están instalados (prueba import de paquetes clave)
python_deps_ok() {
  python - <<'PY' >/dev/null 2>&1 || exit 1
try:
    import cryptography, colorama
except Exception:
    raise SystemExit(1)
PY
}

# Instala dependencias con pip desde requirements.txt
install_pip_requirements() {
  if [ -f requirements.txt ]; then
    echo "Instalando dependencias Python con pip (requirements.txt)..."
    python -m pip install --upgrade pip setuptools wheel
    python -m pip install --user -r requirements.txt
  else
    echo "No se encontró requirements.txt, omitiendo pip install"
  fi
}

# --- inicio del script principal ---

if ! has_cmd python; then
  echo "Please install python in Termux: pkg install python"
  exit 1
fi

if ! has_cmd openssl; then
  echo "Please install openssl in Termux: pkg install openssl-tool"
  exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CERT_DIR="$SCRIPT_DIR/cert"
DER="$CERT_DIR/pcw_cert.der"
PEM="$CERT_DIR/pcw_cert.pem"

mkdir -p "$CERT_DIR"

# If environment.yml exists, decide whether to use conda or pip
if [ -f "$SCRIPT_DIR/environment.yml" ]; then
  cd "$SCRIPT_DIR"
  ENV_NAME=$(get_env_name_from_yml)
  echo "Detected environment.yml, desired conda env name: $ENV_NAME"

  # If on Termux and user didn't request conda, skip conda installation
  if [ "$ON_TERMUX" -eq 1 ] && [ "$USE_CONDA" -ne 1 ]; then
    echo "Running on Termux: skipping conda. Using pip instead unless you set --use-conda or USE_CONDA=1."
    if ! python_deps_ok; then
      install_pip_requirements
    else
      echo "Las dependencias pip parecen ya estar presentes."
    fi
  else
    # Ensure conda exists (try to use installed conda or install Miniconda/Miniforge)
    if ! has_cmd conda; then
      echo "conda no encontrado en PATH. Intentando instalar Miniconda/Miniforge..."
      if ! install_conda; then
        echo "No se pudo instalar conda, se usará pip como alternativa."
        if ! python_deps_ok; then
          install_pip_requirements
        fi
      fi
    fi

    # Si conda está disponible, crea/asegura el entorno
    if has_cmd conda; then
      . "${HOME}/miniconda/etc/profile.d/conda.sh" 2>/dev/null || true
      export PATH="$HOME/miniconda/bin:$PATH"

      if conda_env_exists "$ENV_NAME"; then
        echo "Entorno conda '$ENV_NAME' ya existe."
      else
        echo "Entorno conda '$ENV_NAME' no existe. Creándolo..."
        create_conda_env "$ENV_NAME" || {
          echo "Error creando entorno conda. Se intentará instalar dependencias por pip en su lugar."
          if ! python_deps_ok; then
            install_pip_requirements
          fi
        }
      fi
    fi
  fi
else
  # No environment.yml -> ensure pip deps exist
  if ! python_deps_ok; then
    install_pip_requirements
  else
    echo "Las dependencias Python parecen ya estar presentes."
  fi
fi

# Convertir DER a PEM si pem missing pero der existe
if [ ! -f "$PEM" ] && [ -f "$DER" ]; then
  echo "Convirtiendo $DER -> $PEM"
  openssl x509 -inform der -in "$DER" -out "$PEM"
fi

# Ejecutar la herramienta: si conda y entorno disponible y el usuario lo solicitó, usar conda run; si no, usar python
if has_cmd conda && [ -f "$SCRIPT_DIR/environment.yml" ] && [ "$USE_CONDA" -eq 1 ]; then
  ENV_NAME=$(get_env_name_from_yml)
  echo "Ejecutando dentro del entorno conda: $ENV_NAME"
  conda run -n "$ENV_NAME" --no-capture-output python "$SCRIPT_DIR/CIMATOOL.py" "$@"
else
  echo "Ejecutando con python del sistema"
  python "$SCRIPT_DIR/CIMATOOL.py" "$@"
fi
