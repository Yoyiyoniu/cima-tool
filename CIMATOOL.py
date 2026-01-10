import argparse
from pathlib import Path
import sys

BASE_DIR = Path(__file__).resolve().parent
if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

import tools.getPcwCert as getPcwCert
import tools.InteractiveRunner as InteractiveRunner

def main():
    parser = argparse.ArgumentParser(
        description="Private CIMA Tool for testing purposes.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    parser.add_argument("--cert", "-c", action="store_true", help="Get PCW certificate")

    args = parser.parse_args()

    if args.cert:
        getPcwCert.run()
    else:
        InteractiveRunner.run()
        print("")

if __name__ == "__main__":
    main()
