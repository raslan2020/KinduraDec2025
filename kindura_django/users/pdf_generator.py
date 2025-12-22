"""
PDF Generator for Kindura Patient Reports
Uses reportlab to generate professional medical reports
"""

from reportlab.lib import colors
from reportlab.lib.pagesizes import letter, A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT
from io import BytesIO
from django.core.files.base import ContentFile
import os


def generate_patient_report_pdf(report):
    """
    Generate a PDF for a patient report.
    Returns a ContentFile that can be saved to FileField.
    """
    buffer = BytesIO()

    # Create the PDF document
    doc = SimpleDocTemplate(
        buffer,
        pagesize=letter,
        rightMargin=0.75*inch,
        leftMargin=0.75*inch,
        topMargin=0.75*inch,
        bottomMargin=0.75*inch
    )

    # Container for PDF elements
    elements = []

    # Styles
    styles = getSampleStyleSheet()

    # Custom styles
    title_style = ParagraphStyle(
        'CustomTitle',
        parent=styles['Heading1'],
        fontSize=24,
        spaceAfter=12,
        textColor=colors.HexColor('#2563EB'),
        alignment=TA_CENTER
    )

    subtitle_style = ParagraphStyle(
        'CustomSubtitle',
        parent=styles['Normal'],
        fontSize=12,
        textColor=colors.grey,
        alignment=TA_CENTER,
        spaceAfter=24
    )

    section_title_style = ParagraphStyle(
        'SectionTitle',
        parent=styles['Heading2'],
        fontSize=14,
        textColor=colors.HexColor('#1F2937'),
        spaceBefore=16,
        spaceAfter=8
    )

    body_style = ParagraphStyle(
        'BodyText',
        parent=styles['Normal'],
        fontSize=10,
        leading=14,
        textColor=colors.HexColor('#4B5563')
    )

    highlight_style = ParagraphStyle(
        'Highlight',
        parent=styles['Normal'],
        fontSize=10,
        leading=14,
        textColor=colors.HexColor('#DC2626'),
        backColor=colors.HexColor('#FEE2E2'),
        borderPadding=8
    )

    # Header
    elements.append(Paragraph("Kindura AI", title_style))
    elements.append(Paragraph(
        f"{report.report_type.capitalize()} Patient Report",
        subtitle_style
    ))

    # Patient and Date Info
    patient_name = f"{report.user.first_name} {report.user.last_name}".strip() or report.user.email
    date_range = f"{report.period_start.strftime('%B %d, %Y')}"
    if report.period_start != report.period_end:
        date_range += f" - {report.period_end.strftime('%B %d, %Y')}"

    info_data = [
        ['Patient:', patient_name, 'Report Date:', report.report_date.strftime('%B %d, %Y')],
        ['Email:', report.user.email, 'Period:', date_range],
    ]

    info_table = Table(info_data, colWidths=[1*inch, 2.5*inch, 1*inch, 2.5*inch])
    info_table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('TEXTCOLOR', (0, 0), (0, -1), colors.grey),
        ('TEXTCOLOR', (2, 0), (2, -1), colors.grey),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
    ]))
    elements.append(info_table)
    elements.append(Spacer(1, 20))

    # Adherence Summary Box
    elements.append(Paragraph("Medication Adherence", section_title_style))

    adherence_color = colors.HexColor('#10B981')  # Green
    if report.adherence_percentage < 85:
        adherence_color = colors.HexColor('#F59E0B')  # Orange
    if report.adherence_percentage < 70:
        adherence_color = colors.HexColor('#EF4444')  # Red

    adherence_data = [
        ['Adherence Rate', 'Doses Taken', 'Doses Missed', 'Grade'],
        [
            f"{report.adherence_percentage:.0f}%",
            f"{report.doses_taken}/{report.total_doses_scheduled}",
            str(report.doses_missed),
            report.adherence_grade
        ]
    ]

    adherence_table = Table(adherence_data, colWidths=[1.75*inch]*4)
    adherence_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#F3F4F6')),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.HexColor('#6B7280')),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, 0), 9),
        ('FONTNAME', (0, 1), (-1, 1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 1), (-1, 1), 14),
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 10),
        ('TOPPADDING', (0, 0), (-1, -1), 10),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#E5E7EB')),
    ]))
    elements.append(adherence_table)
    elements.append(Spacer(1, 16))

    # AI Summary
    if report.ai_summary:
        elements.append(Paragraph("Summary", section_title_style))
        elements.append(Paragraph(report.ai_summary.replace('\n', '<br/>'), body_style))
        elements.append(Spacer(1, 8))

    # Key Observations
    if report.ai_observations:
        elements.append(Paragraph("Key Observations", section_title_style))
        elements.append(Paragraph(report.ai_observations.replace('\n', '<br/>'), body_style))
        elements.append(Spacer(1, 8))

    # Concerns (highlighted)
    if report.ai_concerns and report.ai_concerns.strip():
        elements.append(Paragraph("Concerns Requiring Attention", section_title_style))
        elements.append(Paragraph(report.ai_concerns.replace('\n', '<br/>'), highlight_style))
        elements.append(Spacer(1, 8))

    # Recommendations
    if report.ai_recommendations:
        elements.append(Paragraph("Recommendations", section_title_style))
        elements.append(Paragraph(report.ai_recommendations.replace('\n', '<br/>'), body_style))
        elements.append(Spacer(1, 8))

    # Side Effects
    if report.side_effects_count > 0:
        elements.append(Paragraph(f"Side Effects Reported ({report.side_effects_count})", section_title_style))
        for effect in report.side_effects_reported:
            effect_text = f"• [{effect.get('severity', 'N/A').upper()}] {effect.get('description', 'No description')}"
            elements.append(Paragraph(effect_text, body_style))
        elements.append(Spacer(1, 8))

    # Footer
    elements.append(Spacer(1, 30))
    footer_style = ParagraphStyle(
        'Footer',
        parent=styles['Normal'],
        fontSize=8,
        textColor=colors.grey,
        alignment=TA_CENTER
    )
    elements.append(Paragraph(
        f"Generated by Kindura AI on {report.created_at.strftime('%B %d, %Y at %I:%M %p')}",
        footer_style
    ))
    elements.append(Paragraph(
        "This report is for informational purposes only and should be reviewed by a healthcare professional.",
        footer_style
    ))

    # Build PDF
    doc.build(elements)

    # Get PDF content
    pdf_content = buffer.getvalue()
    buffer.close()

    # Create filename
    filename = f"kindura_report_{report.user.id}_{report.report_type}_{report.report_date.strftime('%Y%m%d')}.pdf"

    return ContentFile(pdf_content, name=filename)


def generate_and_save_pdf(report):
    """
    Generate PDF and save it to the report's pdf_file field.
    """
    pdf_file = generate_patient_report_pdf(report)
    report.pdf_file.save(pdf_file.name, pdf_file, save=True)
    report.pdf_generated = True
    report.save()
    return report.pdf_file.url
