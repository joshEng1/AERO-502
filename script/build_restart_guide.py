"""Build the offline, fillable restart handout. Requires Python and reportlab."""
import argparse
from pathlib import Path
import reportlab
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

from reportlab.lib import colors
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfgen import canvas
from reportlab.platypus import Paragraph


def build(app="", url="", support="", output=None):
    destination = Path(output or Path(__file__).resolve().parents[1] / "docs/RESTART_GUIDE.pdf")
    destination.parent.mkdir(parents=True, exist_ok=True)
    pdf = canvas.Canvas(str(destination), pagesize=(612, 792))
    pdf.setTitle("AERO Task Hub - Offline restart guide")
    pdf.setAuthor("AERO-502 project team")
    font_root = Path(reportlab.__file__).parent / "fonts"
    pdfmetrics.registerFont(TTFont("Guide", str(font_root / "Vera.ttf")))
    pdfmetrics.registerFont(TTFont("Guide-Bold", str(font_root / "VeraBd.ttf")))
    pdfmetrics.registerFontFamily("Guide", normal="Guide", bold="Guide-Bold", italic="Guide", boldItalic="Guide-Bold")
    maroon = colors.HexColor("#500000")
    body = ParagraphStyle("body", fontName="Guide", fontSize=10.5, leading=15, textColor=colors.HexColor("#202a34"))

    def paragraph(text, y, size=10.5):
        style = ParagraphStyle("paragraph", parent=body, fontSize=size)
        block = Paragraph(text, style)
        _, height = block.wrap(512, 720)
        block.drawOn(pdf, 50, y - height)
        return y - height - 9

    def heading(text, y):
        pdf.setFillColor(maroon)
        pdf.setFont("Guide-Bold", 13)
        pdf.drawString(50, y, text)
        return y - 17

    def field(name, label, y, value="", height=22):
        pdf.setFont("Guide-Bold", 9)
        pdf.setFillColor(colors.HexColor("#202a34"))
        pdf.drawString(50, y, label)
        pdf.acroForm.textfield(name=name, tooltip=label, x=50, y=y-height-6, width=512,
                              height=height, value=value, fontName="Helvetica", fontSize=10,
                              borderWidth=0.7, borderColor=colors.HexColor("#9babb9"),
                              fillColor=colors.HexColor("#f6f8fa"), textColor=colors.black,
                              maxlen=220, forceBorder=True)
        return y-height-24

    def footer(page):
        pdf.setStrokeColor(colors.HexColor("#c9d2da"))
        pdf.line(50, 43, 562, 43)
        pdf.setFont("Guide", 8)
        pdf.setFillColor(colors.HexColor("#596775"))
        pdf.drawString(50, 29, "Keep a saved copy outside the application. No passwords or keys belong in this file.")
        pdf.drawRightString(562, 16, f"{page} / 2")

    pdf.setFillColor(maroon)
    pdf.setFont("Guide-Bold", 23)
    pdf.drawString(50, 747, "AERO Task Hub")
    pdf.setFont("Guide", 15)
    pdf.drawString(50, 723, "Offline restart guide")
    y = paragraph("Complete these application details with the owner and verify the procedure on the separate practice app before handover. Blank details mean the handout is not finalized.", 704)
    y = field("app_name", "Exact Heroku application name (APP_NAME in commands)", y, app)
    y = field("website_url", "Website address", y, url)
    y = field("support_contact", "Designated support person and contact method", y, support)
    y = heading("1. Sign in and identify the application", y - 3)
    y = paragraph('Open <b>https://dashboard.heroku.com</b> and sign in using your authorized Heroku account. You need access to this application and permission to restart its dynos. Confirm the owner under Access and the exact app name above. Use the separate practice app for the exercise.', y)
    y = heading("2. Record the release and restart", y - 3)
    y = paragraph("In the app dashboard, record the current release from Activity. Open More and choose Restart all dynos. Alternatively, with the Heroku CLI signed in, replace APP_NAME with the exact name above and run:", y)
    y = paragraph('<font face="Guide">heroku ps:restart -a APP_NAME</font>', y)
    y = heading("3. Verify that service has returned", y - 3)
    y = paragraph("Open the website's /login page, then /up. Confirm that the sign-in page loads and the health check succeeds. Have an approved user complete Google sign-in and open an existing permitted task. Record the release, result and time on page 2. Restarting does not repair lost database records.", y)
    footer(1)
    pdf.showPage()
    pdf.setFillColor(maroon)
    pdf.setFont("Guide-Bold", 21)
    pdf.drawString(50, 747, "If restarting does not resolve it")
    y = paragraph("Confirm the application name and website address from page 1. Read the app's recent errors in its dashboard logs, or use the CLI command below. Note the time, error category and release; keep credentials and member data out of shared notes.", 722)
    y = paragraph('<font face="Guide">heroku logs --tail -a APP_NAME</font>', y)
    y = paragraph("If Google sign-in fails, have an authorized administrator check the OAuth client configuration and callback address, and verify that the chosen email is approved under People. Do not paste client secrets or database URLs into support messages.", y)
    y = paragraph("Contact the designated support person on page 1 with the symptoms and verification result. A code rollback and a database restore are different operations. Restoring a database replaces its records and can lose changes made after the backup. Recovery practice must target a separate test database, using the embedded administrator guide or its saved copy.", y)
    y = heading("Controlled verification and delivery record", y - 4)
    y = field("practice_app", "Practice app name and distinct test database identifier", y)
    y = field("operator_date", "Operator / trainer and verification date", y)
    y = field("release_result", "Release ID, sign-in result, existing-task check and elapsed time", y)
    y = field("follow_up", "Unresolved issue or follow-up action (write None only after verification)", y)
    y = field("receipt", "JD receipt confirmation and location of the copy saved outside the app", y)
    y = paragraph("Transfer the actual verification result, PDF location and delivery confirmation into Project Notebook Section 4.2. A generated document does not demonstrate that a restart, training session or delivery occurred.", y, 9.5)
    paragraph('Command reference: https://devcenter.heroku.com/articles/heroku-cli-commands<br/>Source code: https://github.com/joshEng1/AERO-502', y, 8.5)
    footer(2)
    pdf.save()
    return destination


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", default="")
    parser.add_argument("--url", default="")
    parser.add_argument("--support", default="")
    parser.add_argument("--output")
    args = parser.parse_args()
    build(args.app, args.url, args.support, args.output)
