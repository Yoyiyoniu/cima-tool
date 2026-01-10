import ssl
import socket
import hashlib
import subprocess
from datetime import datetime
from cryptography import x509
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import serialization
import os
from colorama import Fore, Style, init
from pathlib import Path

init(autoreset=True)

def get_certificate(hostname: str, port: int = 443) -> bytes:
    context = ssl.create_default_context()
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE

    with socket.create_connection((hostname, port), timeout=10) as sock:
        with context.wrap_socket(sock, server_hostname=hostname) as ssock:
            cert_der = ssock.getpeercert(binary_form=True)
            return cert_der


def validate_current_wifi() -> bool:
    """Comprueba la red WiFi mediante iwgetid; si iwgetid no existe (p. ej. en Termux), omite la comprobación y continúa."""
    try:
        result = subprocess.run(
            ['iwgetid', '-r'],
            capture_output=True,
            text=True,
            check=True
        )

        current_ssid = result.stdout.strip()
        validSsid = ["UABC-5G", "UABC-2.4G"]
        if not current_ssid:
            print(f"{Fore.RED}❌ No WiFi connection detected. Please connect to a WiFi network.{Style.RESET_ALL}")
            return False

        if current_ssid not in validSsid:
            print(f"{Fore.RED}❌ Connected to '{current_ssid}'. Please connect to {validSsid} WiFi network.{Style.RESET_ALL}")
            return False

        print(f"{Fore.GREEN}✓ Connected to '{current_ssid}'{Style.RESET_ALL}")
        return True

    except FileNotFoundError:
        # En entornos como Termux no está disponible iwgetid; no abortamos la ejecución
        print(f"{Fore.YELLOW}ℹ️  'iwgetid' no encontrado. Omitiendo la comprobación de WiFi (usando Termux o entorno sin wireless-tools).{Style.RESET_ALL}")
        return True
    except subprocess.CalledProcessError:
        print(f"{Fore.RED}❌ Error checking WiFi connection.{Style.RESET_ALL}")
        return False
    except Exception as e:
        print(f"{Fore.RED}❌ Unexpected error checking WiFi: {e}{Style.RESET_ALL}")
        return False


def get_certificate_info(cert_der: bytes) -> dict:
    """Extrae información del certificado."""
    cert = x509.load_der_x509_certificate(cert_der, default_backend())

    # Calcular fingerprints
    sha256_fingerprint = hashlib.sha256(cert_der).hexdigest().upper()
    sha1_fingerprint = hashlib.sha1(cert_der).hexdigest().upper()

    # Formatear fingerprint con ":"
    sha256_formatted = ":".join(
        sha256_fingerprint[i:i + 2] for i in range(0, len(sha256_fingerprint), 2)
    )

    return {
        "subject": cert.subject.rfc4514_string(),
        "issuer": cert.issuer.rfc4514_string(),
        "serial_number": cert.serial_number,
        "not_valid_before": cert.not_valid_before_utc,
        "not_valid_after": cert.not_valid_after_utc,
        "sha256_fingerprint": sha256_fingerprint,
        "sha256_formatted": sha256_formatted,
        "sha1_fingerprint": sha1_fingerprint,
        "cert_der": cert_der,
        "cert_pem": cert.public_bytes(serialization.Encoding.PEM).decode(),
    }


def save_certificate(cert_info: dict, base_filename: str = "pcw_cert"):
    """Guarda el certificado en varios formatos en el directorio `cert/` relativo a la raíz del proyecto."""
    base_dir = Path(__file__).resolve().parents[1]
    cert_dir = base_dir / "cert"
    os.makedirs(cert_dir, exist_ok=True)
    base_path = cert_dir / base_filename

    # Guardar PEM
    with open(base_path.with_suffix('.pem'), "w") as f:
        f.write(cert_info["cert_pem"])
    print(f"{Fore.CYAN}✓ Guardado: {base_path.with_suffix('.pem')}{Style.RESET_ALL}")

    # Guardar DER
    with open(base_path.with_suffix('.der'), "wb") as f:
        f.write(cert_info["cert_der"])
    print(f"{Fore.CYAN}✓ Guardado: {base_path.with_suffix('.der')}{Style.RESET_ALL}")

    # Guardar info como texto
    with open(base_path.with_name(base_path.name + "_info.txt"), "w") as f:
        f.write(f"Subject: {cert_info['subject']}\n")
        f.write(f"Issuer: {cert_info['issuer']}\n")
        f.write(f"Serial: {cert_info['serial_number']}\n")
        f.write(f"Valid From: {cert_info['not_valid_before']}\n")
        f.write(f"Valid Until: {cert_info['not_valid_after']}\n")
        f.write(f"SHA-256: {cert_info['sha256_formatted']}\n")
        f.write(f"SHA-1: {cert_info['sha1_fingerprint']}\n")
    print(f"{Fore.CYAN}✓ Guardado: {base_path.with_name(base_path.name + '_info.txt')}{Style.RESET_ALL}")


def run():
    hostname = "pcw.uabc.mx"
    print(f"{Fore.CYAN}\nExtracting cert from: {hostname}...{Style.RESET_ALL}")

    try:
        if not validate_current_wifi():
            return
        cert_der = get_certificate(hostname)
        cert_info = get_certificate_info(cert_der)

        print(f"{Fore.CYAN}\nInformación del Certificado:{Style.RESET_ALL}")
        print(f"   Subject: {cert_info['subject']}")
        print(f"   Issuer:  {cert_info['issuer']}")
        print(f"   Válido:  {cert_info['not_valid_before']} → {cert_info['not_valid_after']}")
        print(f"{Fore.CYAN}\n  SHA-256 Fingerprint:{Style.RESET_ALL}")
        print(f"   {cert_info['sha256_formatted']}")

        now = datetime.now(cert_info['not_valid_after'].tzinfo)
        if cert_info['not_valid_after'] < now:
            print(f"{Fore.RED}\n [WARNING]: CERT EXPIRED{Style.RESET_ALL}")
        else:
            days_left = (cert_info['not_valid_after'] - now).days
            print(f"{Fore.GREEN}\n✓ Cert expire in {days_left} days{Style.RESET_ALL}")

        print(f"{Fore.CYAN}\n saving...{Style.RESET_ALL}")
        save_certificate(cert_info)

        print(f"{Fore.GREEN}\n ¡Complete!{Style.RESET_ALL}")

    except socket.timeout:
        print(f"{Fore.RED}\n❌ Error: Timeout{Style.RESET_ALL}")
    except socket.gaierror:
        print(f"{Fore.RED}\n❌ Error: Cant resolve {hostname}{Style.RESET_ALL}")
    except Exception as e:
        print(f"{Fore.RED}\n❌ Error: {e}{Style.RESET_ALL}")
