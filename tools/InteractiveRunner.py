from colorama import Fore, Style, init

import tools.getPcwCert as getPcwCert
import tools.getPcwIp as getPcwIp

def run():
    init(autoreset=True)
    print(f"{Fore.RED}━━━━━━━━{Fore.GREEN}  乃丫 ㄚㄖ丫ㄖⲌ  {Fore.RED}━━━━━━━━{Style.RESET_ALL}")
    print(f"{Fore.LIGHTGREEN_EX}\n\t山 🝗 ㇄ ⼕ ㄖ 爪 🝗   七 ㄖ{Style.RESET_ALL}")
    print(f"{Fore.LIGHTGREEN_EX}\n\t⼕ 讠 爪 闩   ㄒ ㄖ ㄖ ㇄{Style.RESET_ALL}")
    print(f"{Fore.RED}\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{Style.RESET_ALL}")


    while True:
        options_menu()

        opc = input(f"{Fore.CYAN}CIMA-TOOL> {Style.RESET_ALL}").strip().lower()

        if opc == "1":
            getPcwCert.run()
        elif opc == "2":
            getPcwIp.run()

        elif opc in ["exit", "quit"]:
            print(f"{Fore.GREEN}Exiting CIMA-TOOL. Goodbye!{Style.RESET_ALL}")
            break

def options_menu():
    print(f"{Fore.GREEN}\nAvailable Commands:{Style.RESET_ALL}")
    print("""
    1. Get Pcw Certificate
    2. Get Pcw IP
    """)

    print(f" exit or quit - Exit the tool")

