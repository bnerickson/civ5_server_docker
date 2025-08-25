import asyncio
import json
import mailparser
import re
import os


from aiosmtpd.controller import Controller


DEBUG = True

url_regex = r"<a\s*href=\"(.*)\">"
bcc_regex = r"Bcc: (.*)"


class PrintEmailsServer:
    async def handle_DATA(self, server, session, envelope):
        peer = session.peer
        mail_from = envelope.mail_from
        rcpttos = envelope.rcpt_tos
        data = envelope.content

        if DEBUG:
            print("-------------------------------------")
            print(peer)
            print("-------")
            print(mailfrom)
            print("-------")
            print(rcpttos)
            print("-------")
            print(data)

        bcc = re.search(bcc_regex, data).groups()[0]
        bccs = [email + ">" if email[-1] != '>' else email for email in bcc.split(">,")]
        quoted_bccs = []
        for bcc_email in bccs:
            quoted_bccs.append('"' + bcc_email[::-1].replace("<", '<"', 1)[::-1])
        quoted_bcc_str = ', '.join(quoted_bccs)

        fixed_data = re.sub(bcc_regex, "Bcc: " + quoted_bcc_str, data)

        mail = mailparser.parse_from_string(fixed_data)

        if DEBUG:
            print("-------")
            print(mail.bcc)


def main():
    print("Starting SMTP listener on 127.0.0.1:1025...")
    handler = PrintEmailsServer()
    controller = Controller(handler, hostname='127.0.0.1', port=1025)
    # Run the event loop in a separate thread.
    controller.start()
    # Wait for the user to press Return.
    input('SMTP server running. Press Return to stop server and exit.')
    controller.stop()


if __name__ == "__main__":
    main()
