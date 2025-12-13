import pymupdf
import re
from rest_framework import status
from rest_framework.response import Response

def error_response(message, status_code):
    return Response({"error": message}, status=status_code)

def pdf_to_markdown(pdf_file):
    try:
        doc = pymupdf.open(pdf_file)
        markdown = ""

        for page in doc:
            text = page.get_text("text")
            lines = text.splitlines()

            for line in lines:
                stripped_line = line.strip()

                # Simple heading conversion
                if stripped_line.isupper() and len(stripped_line.split()) < 10:
                    markdown += f"\n\n## {stripped_line}\n"
                elif re.match(r"^\d+[\).]", stripped_line):  # Numbered list
                    markdown += f"\n1. {stripped_line}\n"
                else:
                    markdown += f"{stripped_line}\n"

        doc.close()
        return markdown

    except Exception as e:
        print(f"PDF processing error: {e}")
        # Return a simple error string instead of Response object
        return f"Error processing PDF: {str(e)}"
