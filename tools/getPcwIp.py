import socket

host = "pcw.uabc.mx"

def run():
    try:
        ip_address = socket.gethostbyname(host)
        print(f"host: {host}")
        print(f"ip: {ip_address}")
        return ip_address
    except socket.gaierror as e:
        print(f"Error resolving host {host}: {e}")
        return ""