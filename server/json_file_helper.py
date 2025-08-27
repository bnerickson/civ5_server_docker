import argparse
import json
import logging
import os
import sys


def parse_args():
    """
    parse_args(): Parse CLI arguments

    Inputs:
        args: Script Arguments
    Outputs:
        parser.parse_args() output
    """

    script_description = """Civ5 Turn and Player Status Helper"""
    parser = argparse.ArgumentParser(description=script_description, add_help=True)

    parser.add_argument(
        "-l",
        "--log",
        help="Set log level [Default: 'WARNING'].",
        dest="loglevel",
        choices=['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'],
        default='WARNING',
        type=str,
    )
    parser.add_argument(
        "-c",
        "--config",
        help="JSON config file",
        dest="config",
        required=True,
        type=str,
    )

    subparsers = parser.add_subparsers(
        title="task",
        dest="task",
        help="Choose a subtask.",
    )
    subparsers.required = True

    parser_print = subparsers.add_parser(
        "print",
        help="Print Turn number or Players as string",
    )
    parser_print.add_argument(
        "-p",
        "--parameter",
        help="JSON field to extract from config file",
        dest="parameter",
        choices=["turn", "players"],
        required=True,
        type=str,
    )

    parser_update = subparsers.add_parser(
        "update",
        help="Update config file with new parameters",
    )
    parser_update.add_argument(
        "-t",
        "--turn",
        help="Turn number",
        dest="turn",
        required=True,
        type=str,
    )
    parser_update.add_argument(
        "-p",
        "--players",
        help="Players",
        dest="players",
        required=True,
        type=str,
    )

    return parser.parse_args()


def main():
    """
    main(): main function parses args and executes the get functions.

    Inputs:
        args: Arguments given by the user.
    Outputs:
        None
    """
    args = parse_args()

    logger = logging.getLogger(__name__)
    logging.basicConfig(
        level=getattr(logging, args.loglevel),
        format="%(asctime)s [%(levelname)s] %(message)s",
        handlers=[logging.StreamHandler(sys.stdout)],
    )

    try:
        with open(args.config, "r", encoding="utf-8") as json_file:
            civ_status = json.load(json_file)
    except (KeyError, PermissionError, OSError, json.decoder.JSONDecodeError) as err:
        logger.error(f"Failed to open config file, error {err}")
        os.remove(args.config)
        sys.exit(0)

    if args.task == "print":
        if args.parameter in civ_status:
            print(civ_status[args.parameter])
        else:
            print("")
    elif args.task == "update":
        new_json = {
            "turn": args.turn,
            "players": args.players
        }
        try:
            with open(args.config, "w", encoding="utf-8") as json_file:
                json.dump(new_json, json_file)
        except (KeyError, PermissionError, OSError, json.decoder.JSONDecodeError) as err:
            logger.error(f"Failed to write to config file, error {err}")


if __name__ == "__main__":
    main()
