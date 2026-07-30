import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class FastRevenueInvoicePdf {
  static Uint8List? _logoBytes;

  static Future<Uint8List> build(Map<String, dynamic> invoice) async {
    _logoBytes ??= (await rootBundle.load(
      'assets/images/Makk-Finsol-logo.png',
    )).buffer.asUint8List();

    final document = PdfDocument();
    document.pageSettings.margins.all = 34;
    final page = document.pages.add();
    final g = page.graphics;
    final size = page.getClientSize();

    final title = PdfStandardFont(
      PdfFontFamily.timesRoman,
      16,
      style: PdfFontStyle.bold,
    );
    final bold = PdfStandardFont(
      PdfFontFamily.timesRoman,
      10,
      style: PdfFontStyle.bold,
    );
    final normal = PdfStandardFont(PdfFontFamily.timesRoman, 10);
    final small = PdfStandardFont(PdfFontFamily.timesRoman, 8);
    final italic = PdfStandardFont(
      PdfFontFamily.timesRoman,
      10,
      style: PdfFontStyle.italic,
    );
    final pen = PdfPen(PdfColor(80, 80, 80), width: 0.7);
    final blue = PdfBrushes.cornflowerBlue;
    final red = PdfBrushes.indianRed;

    g.drawImage(
      PdfBitmap(_logoBytes!),
      Rect.fromLTWH(size.width - 160, 10, 140, 58),
    );

    var y = 112.0;
    _box(g, pen, 0, y, size.width, 30);
    _text(g, 'No. ${invoice['invoiceNo'] ?? '-'}', bold, 10, y + 9, w: 160);
    _text(g, 'INVOICE', title, size.width / 2 - 42, y + 7, w: 90);
    _text(
      g,
      'Date: ${_date(invoice['invoiceDate'])}',
      bold,
      size.width - 145,
      y + 9,
      w: 135,
      align: PdfTextAlignment.right,
    );
    y += 30;

    _box(g, pen, 0, y, size.width, 92);
    g.drawLine(pen, Offset(size.width / 2, y), Offset(size.width / 2, y + 92));
    _text(g, 'Billed From :', normal, 10, y + 10, w: 160);
    _text(g, 'MAKK Finsol IMF Private Limited,', bold, 10, y + 25, w: 230);
    _text(g, '1-65/43/55, Kakatiya Hills', normal, 10, y + 40, w: 230);
    _text(g, 'Madhapur, Shaikpet,', normal, 10, y + 55, w: 230);
    _text(g, 'Hyderabad - 500081', normal, 10, y + 70, w: 230);
    _text(g, 'GSTIN : 36AASCM7711R1ZI', bold, 10, y + 84, w: 230);

    final billedTo = (invoice['billedTo'] ?? invoice['companyName'] ?? '-')
        .toString();
    final billedToAddress = (invoice['billedToAddress'] ?? '')
        .toString()
        .trim();
    final billedToGstin = (invoice['billedToGstin'] ?? '').toString().trim();
    _text(
      g,
      'Billed To:',
      normal,
      size.width - 110,
      y + 8,
      w: 100,
      align: PdfTextAlignment.right,
    );
    _text(
      g,
      billedTo,
      bold,
      size.width / 2 + 8,
      y + 34,
      w: size.width / 2 - 18,
      align: PdfTextAlignment.right,
    );
    if (billedToAddress.isNotEmpty) {
      _text(
        g,
        billedToAddress,
        normal,
        size.width / 2 + 8,
        y + 50,
        w: size.width / 2 - 18,
        align: PdfTextAlignment.right,
      );
    }
    if (billedToGstin.isNotEmpty) {
      _text(
        g,
        'GSTIN : $billedToGstin',
        bold,
        size.width / 2 + 8,
        y + 74,
        w: size.width / 2 - 18,
        align: PdfTextAlignment.right,
      );
    }
    y += 92;

    final taxable = _num(invoice['taxableValue']);
    final includeGst = invoice['includeGst'] == true;
    final cgst = includeGst ? _round2(taxable * 0.09) : 0.0;
    final sgst = includeGst ? _round2(taxable * 0.09) : 0.0;
    final totalGst = cgst + sgst;
    final total = taxable + totalGst;

    final col = <double>[0, 52, 220, 265, 310, 445, size.width];
    final headerH = 34.0;
    final bodyH = includeGst ? 166.0 : 125.0;
    _box(g, pen, 0, y, size.width, headerH + bodyH);
    for (final x in col.skip(1).take(col.length - 2)) {
      g.drawLine(pen, Offset(x, y), Offset(x, y + headerH + bodyH));
    }
    g.drawLine(pen, Offset(0, y + headerH), Offset(size.width, y + headerH));
    _text(
      g,
      'Sl. No.',
      bold,
      col[0] + 6,
      y + 11,
      w: col[1] - col[0] - 12,
      align: PdfTextAlignment.center,
    );
    _text(
      g,
      'Description',
      bold,
      col[1] + 6,
      y + 11,
      w: col[2] - col[1] - 12,
      align: PdfTextAlignment.center,
    );
    _text(
      g,
      'Code',
      bold,
      col[2] + 6,
      y + 11,
      w: col[3] - col[2] - 12,
      align: PdfTextAlignment.center,
    );
    _text(
      g,
      'Rate\n(Rs)',
      bold,
      col[3] + 6,
      y + 7,
      w: col[4] - col[3] - 12,
      align: PdfTextAlignment.center,
    );
    _text(
      g,
      'GST',
      bold,
      col[4] + 6,
      y + 11,
      w: col[5] - col[4] - 12,
      align: PdfTextAlignment.center,
    );
    _text(
      g,
      'Amount (Rs)',
      bold,
      col[5] + 6,
      y + 11,
      w: col[6] - col[5] - 12,
      align: PdfTextAlignment.center,
    );

    final by = y + headerH;
    _text(
      g,
      '1.',
      normal,
      col[0] + 6,
      by + 17,
      w: col[1] - col[0] - 12,
      align: PdfTextAlignment.center,
    );
    _text(
      g,
      'Insurance referral\ncommission',
      normal,
      col[1] + 12,
      by + 16,
      w: col[2] - col[1] - 24,
      align: PdfTextAlignment.center,
    );
    _text(
      g,
      '9971',
      normal,
      col[2] + 6,
      by + 13,
      w: col[3] - col[2] - 12,
      align: PdfTextAlignment.center,
    );
    _text(
      g,
      includeGst ? '18%' : '-',
      normal,
      col[3] + 6,
      by + 13,
      w: col[4] - col[3] - 12,
      align: PdfTextAlignment.center,
    );
    _text(
      g,
      'Taxable Value',
      normal,
      col[4] + 14,
      by + 16,
      w: col[5] - col[4] - 20,
    );
    _text(
      g,
      _money(taxable),
      normal,
      col[5] + 8,
      by + 16,
      w: col[6] - col[5] - 16,
      align: PdfTextAlignment.right,
    );
    var sy = by + 76;
    if (includeGst) {
      _text(g, 'CGST@9%', normal, col[4] + 14, sy, w: 100);
      _text(
        g,
        _money(cgst),
        normal,
        col[5] + 8,
        sy,
        w: col[6] - col[5] - 16,
        align: PdfTextAlignment.right,
      );
      sy += 18;
      _text(g, 'SGST@9%', normal, col[4] + 14, sy, w: 100);
      _text(
        g,
        _money(sgst),
        normal,
        col[5] + 8,
        sy,
        w: col[6] - col[5] - 16,
        align: PdfTextAlignment.right,
      );
      sy += 18;
      _text(g, 'Total GST', normal, col[4] + 14, sy, w: 100);
      _text(
        g,
        _money(totalGst),
        normal,
        col[5] + 8,
        sy,
        w: col[6] - col[5] - 16,
        align: PdfTextAlignment.right,
      );
      sy += 30;
    } else {
      sy += 28;
    }
    _text(g, 'Total Invoice Value', bold, col[4] + 14, sy, w: 120);
    _text(
      g,
      _money(total),
      bold,
      col[5] + 8,
      sy,
      w: col[6] - col[5] - 16,
      align: PdfTextAlignment.right,
    );
    y += headerH + bodyH;

    _box(g, pen, 0, y, size.width, 34);
    _text(
      g,
      'Total in words : (${_amountInWords(total)})',
      italic,
      10,
      y + 10,
      w: size.width - 20,
    );
    y += 34;

    _box(g, pen, 0, y, size.width, 118);
    g.drawLine(
      pen,
      Offset(size.width * .58, y),
      Offset(size.width * .58, y + 118),
    );
    _text(
      g,
      'BANK DETAILS',
      bold,
      92,
      y + 18,
      w: 140,
      align: PdfTextAlignment.center,
    );
    _text(
      g,
      'Account Name        : MAKK FINSOL IMF PVT. LTD.',
      normal,
      12,
      y + 48,
      w: 300,
    );
    _text(g, 'Bank Name           : AXIS Bank', normal, 12, y + 65, w: 300);
    _text(
      g,
      'Account Number      : 925020002633301',
      normal,
      12,
      y + 82,
      w: 300,
    );
    _text(g, 'IFSC Code           : UTIB0000193', normal, 12, y + 99, w: 300);
    _text(
      g,
      'For MAKK Finsol IMF Pvt. Ltd.',
      bold,
      size.width * .58 + 28,
      y + 42,
      w: 180,
      align: PdfTextAlignment.center,
    );
    _text(
      g,
      'Authorized Signatory',
      bold,
      size.width * .58 + 28,
      y + 92,
      w: 180,
      align: PdfTextAlignment.center,
    );

    g.drawRectangle(
      brush: blue,
      bounds: Rect.fromLTWH(42, size.height - 70, size.width - 130, 7),
    );
    g.drawRectangle(
      brush: red,
      bounds: Rect.fromLTWH(size.width - 88, size.height - 70, 48, 7),
    );
    _text(
      g,
      '# 1-65/43/55, Kakatiya Hills, Madhapur, Shaikpet, Hyderabad - 500081, Telangana. India',
      small,
      50,
      size.height - 54,
      w: size.width - 100,
      align: PdfTextAlignment.center,
    );
    _text(
      g,
      'info@makkfinsol.com, www.makkfinsol.com, Ph: 040-23099999, Cell: +91 9646898989',
      small,
      50,
      size.height - 40,
      w: size.width - 100,
      align: PdfTextAlignment.center,
    );

    final bytes = Uint8List.fromList(await document.save());
    document.dispose();
    return bytes;
  }

  static void _box(
    PdfGraphics g,
    PdfPen pen,
    double x,
    double y,
    double w,
    double h,
  ) {
    g.drawRectangle(pen: pen, bounds: Rect.fromLTWH(x, y, w, h));
  }

  static void _text(
    PdfGraphics g,
    String text,
    PdfFont font,
    double x,
    double y, {
    required double w,
    PdfTextAlignment align = PdfTextAlignment.left,
  }) {
    g.drawString(
      text,
      font,
      bounds: Rect.fromLTWH(x, y, w, 42),
      format: PdfStringFormat(alignment: align),
    );
  }

  static double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(
          (value ?? '').toString().replaceAll(',', '').trim(),
        ) ??
        0;
  }

  static double _round2(double value) => double.parse(value.toStringAsFixed(2));

  static String _money(double value) => value.toStringAsFixed(2);

  static String _date(dynamic value) {
    DateTime? date;
    if (value is Timestamp) date = value.toDate();
    if (value is DateTime) date = value;
    date ??= DateTime.tryParse((value ?? '').toString());
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  static String _amountInWords(double amount) {
    final rupees = amount.floor();
    final paise = ((amount - rupees) * 100).round();
    final rupeeWords = _numberWords(rupees).toUpperCase();
    if (paise == 0) return '$rupeeWords ONLY';
    return '$rupeeWords AND ${_numberWords(paise).toUpperCase()} PAISE ONLY';
  }

  static String _numberWords(int value) {
    if (value == 0) return 'zero';
    final parts = <String>[];
    final crore = value ~/ 10000000;
    value %= 10000000;
    final lakh = value ~/ 100000;
    value %= 100000;
    final thousand = value ~/ 1000;
    value %= 1000;
    final hundred = value ~/ 100;
    value %= 100;
    if (crore > 0) parts.add('${_underHundred(crore)} crore');
    if (lakh > 0) parts.add('${_underHundred(lakh)} lakh');
    if (thousand > 0) parts.add('${_underHundred(thousand)} thousand');
    if (hundred > 0) parts.add('${_ones[hundred]} hundred');
    if (value > 0) parts.add(_underHundred(value));
    return parts.join(' ');
  }

  static String _underHundred(int value) {
    if (value < 20) return _ones[value];
    final ten = value ~/ 10;
    final one = value % 10;
    return one == 0 ? _tens[ten] : '${_tens[ten]} ${_ones[one]}';
  }

  static const _ones = [
    'zero',
    'one',
    'two',
    'three',
    'four',
    'five',
    'six',
    'seven',
    'eight',
    'nine',
    'ten',
    'eleven',
    'twelve',
    'thirteen',
    'fourteen',
    'fifteen',
    'sixteen',
    'seventeen',
    'eighteen',
    'nineteen',
  ];
  static const _tens = [
    '',
    '',
    'twenty',
    'thirty',
    'forty',
    'fifty',
    'sixty',
    'seventy',
    'eighty',
    'ninety',
  ];
}
