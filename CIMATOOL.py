import argparse
import tools.getPcwCert as getPcwCert
import tools.InteractiveRunner as InteractiveRunner

def main():
    parser = argparse.ArgumentParser(
        description="Private CIMA Tool for testing purposes.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    parser.add_argument("--cert", "-c", action="store_true", help="Get PCW certificate")

    #TODO: Add

    args = parser.parse_args()

    if args.cert:
        getPcwCert.run()
    else:
        InteractiveRunner.run()
        print("")

if __name__ == "__main__":
    main()
