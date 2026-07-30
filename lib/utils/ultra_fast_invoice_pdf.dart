import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

class UltraFastInvoicePdf {
  static Uint8List build(Map<String, dynamic> invoice) {
    final content = StringBuffer();

    void line(double x1, double y1, double x2, double y2) {
      content.writeln(
        '${_n(x1)} ${_n(_py(y1))} m ${_n(x2)} ${_n(_py(y2))} l S',
      );
    }

    void rect(double x, double y, double w, double h) {
      content.writeln('${_n(x)} ${_n(_py(y + h))} ${_n(w)} ${_n(h)} re S');
    }

    void text(
      String value,
      double x,
      double y, {
      double size = 10,
      bool bold = false,
    }) {
      final font = bold ? 'F2' : 'F1';
      content.writeln(
        'BT /$font ${_n(size)} Tf ${_n(x)} ${_n(_py(y))} Td (${_esc(value)}) Tj ET',
      );
    }

    void right(
      String value,
      double x,
      double y, {
      double size = 10,
      bool bold = false,
    }) {
      final approxWidth = value.length * size * 0.48;
      text(value, x - approxWidth, y, size: size, bold: bold);
    }

    final includeGst = invoice['includeGst'] == true;
    final taxable = _num(invoice['taxableValue']);
    final cgst = includeGst ? _round2(taxable * 0.09) : 0.0;
    final sgst = includeGst ? _round2(taxable * 0.09) : 0.0;
    final totalGst = cgst + sgst;
    final total = taxable + totalGst;
    final rows = _rows(invoice['rows']);
    final company = (invoice['companyName'] ?? invoice['billedTo'] ?? '-')
        .toString();

    text('MAKK', 390, 58, size: 34, bold: true);
    text('FINSOL IMF PVT. LTD.', 392, 82, size: 12, bold: true);
    text('CIN: U66220TS2024PTC192069', 392, 99, size: 9);

    rect(50, 150, 495, 28);
    text('No. ${invoice['invoiceNo'] ?? '-'}', 60, 168, size: 12, bold: true);
    text('INVOICE', 268, 168, size: 15, bold: true);
    right(
      'Date: ${_date(invoice['invoiceDate'])}',
      535,
      168,
      size: 12,
      bold: true,
    );

    rect(50, 178, 495, 92);
    line(300, 178, 300, 270);
    text('Billed From :', 60, 198);
    text('MAKK Finsol IMF Private Limited,', 60, 214, bold: true);
    text('1-65/43/55, Kakatiya Hills', 60, 230);
    text('Madhapur, Shaikpet, Hyderabad - 500081', 60, 246);
    text('GSTIN : 36AASCM7711R1ZI', 60, 262, bold: true);

    right('Billed To:', 535, 196);
    right(company, 535, 224, bold: true);
    final billedToAddress = (invoice['billedToAddress'] ?? '')
        .toString()
        .trim();
    final billedToGstin = (invoice['billedToGstin'] ?? '').toString().trim();
    if (billedToAddress.isNotEmpty) right(billedToAddress, 535, 241);
    if (billedToGstin.isNotEmpty) {
      right('GSTIN : $billedToGstin', 535, 260, bold: true);
    }

    final tableY = 270.0;
    final tableH = includeGst ? 198.0 : 155.0;
    rect(50, tableY, 495, tableH);
    line(50, tableY + 34, 545, tableY + 34);
    for (final x in [102.0, 255.0, 300.0, 345.0, 460.0]) {
      line(x, tableY, x, tableY + tableH);
    }
    text('Sl. No.', 61, tableY + 22, bold: true);
    text('Description', 137, tableY + 22, bold: true);
    text('Code', 266, tableY + 22, bold: true);
    text('Rate', 310, tableY + 22, bold: true);
    text('GST', 385, tableY + 22, bold: true);
    text('Amount (Rs)', 476, tableY + 22, bold: true);

    text('1.', 72, tableY + 62);
    text('Insurance referral commission', 120, tableY + 62);
    text('9971', 265, tableY + 62);
    text(includeGst ? '18%' : '-', 310, tableY + 62);
    text('Taxable Value', 360, tableY + 62);
    right(_money(taxable), 535, tableY + 62);

    var ay = tableY + 116;
    if (includeGst) {
      text('CGST@9%', 360, ay);
      right(_money(cgst), 535, ay);
      ay += 18;
      text('SGST@9%', 360, ay);
      right(_money(sgst), 535, ay);
      ay += 18;
      text('Total GST', 360, ay);
      right(_money(totalGst), 535, ay);
      ay += 30;
    } else {
      ay += 20;
    }
    text('Total Invoice Value', 360, ay, bold: true);
    right(_money(total), 535, ay, bold: true);

    final wordsY = tableY + tableH;
    rect(50, wordsY, 495, 34);
    text(
      'Total in words : (${_amountInWords(total)})',
      60,
      wordsY + 21,
      bold: true,
    );

    final detailY = wordsY + 44;
    text('Invoice Policies', 50, detailY, size: 11, bold: true);
    text('Customer', 50, detailY + 18, size: 9, bold: true);
    text('Policy No.', 190, detailY + 18, size: 9, bold: true);
    text('Premium', 335, detailY + 18, size: 9, bold: true);
    text('Commission', 425, detailY + 18, size: 9, bold: true);
    var ry = detailY + 34;
    for (final row in rows.take(8)) {
      text((row['customerName'] ?? '-').toString(), 50, ry, size: 8);
      text((row['policyNumber'] ?? '-').toString(), 190, ry, size: 8);
      right(_money(_num(row['premiumAmount'])), 385, ry, size: 8);
      right(_money(_num(row['commissionAmount'])), 495, ry, size: 8);
      ry += 14;
    }

    final bankY = 650.0;
    rect(50, bankY, 495, 118);
    line(315, bankY, 315, bankY + 118);
    text('BANK DETAILS', 142, bankY + 24, size: 12, bold: true);
    text('Account Name      : MAKK FINSOL IMF PVT. LTD.', 60, bankY + 50);
    text('Bank Name         : AXIS Bank', 60, bankY + 67);
    text('Account Number    : 925020002633301', 60, bankY + 84);
    text('IFSC Code         : UTIB0000193', 60, bankY + 101);
    text('For MAKK Finsol IMF Pvt. Ltd.', 355, bankY + 52, bold: true);
    text('Authorized Signatory', 380, bankY + 102, bold: true);

    content.writeln('0.2 w');
    content.writeln('0 0.55 0.75 RG 90 ${_n(_py(798))} 360 7 re S');
    content.writeln('0.85 0.2 0.18 RG 450 ${_n(_py(798))} 55 7 re S');
    text(
      '# 1-65/43/55, Kakatiya Hills, Madhapur, Shaikpet, Hyderabad - 500081, Telangana. India',
      82,
      816,
      size: 8,
    );
    text(
      'info@makkfinsol.com, www.makkfinsol.com, Ph: 040-23099999, Cell: +91 9646898989',
      92,
      830,
      size: 8,
    );

    return _pdf(content.toString());
  }

  static Uint8List _pdf(String stream) {
    final objects = <String>[
      '<< /Type /Catalog /Pages 2 0 R >>',
      '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R /F2 5 0 R >> >> /Contents 6 0 R >>',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>',
      '<< /Length ${latin1.encode(stream).length} >>\nstream\n$stream\nendstream',
    ];
    final out = StringBuffer('%PDF-1.4\n');
    final offsets = <int>[0];
    for (var i = 0; i < objects.length; i++) {
      offsets.add(latin1.encode(out.toString()).length);
      out.writeln('${i + 1} 0 obj');
      out.writeln(objects[i]);
      out.writeln('endobj');
    }
    final xref = latin1.encode(out.toString()).length;
    out.writeln('xref');
    out.writeln('0 ${objects.length + 1}');
    out.writeln('0000000000 65535 f ');
    for (final offset in offsets.skip(1)) {
      out.writeln('${offset.toString().padLeft(10, '0')} 00000 n ');
    }
    out.writeln('trailer << /Size ${objects.length + 1} /Root 1 0 R >>');
    out.writeln('startxref');
    out.writeln(xref);
    out.writeln('%%EOF');
    return Uint8List.fromList(latin1.encode(out.toString()));
  }

  static double _py(double y) => 842 - y;
  static String _n(num value) =>
      value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2);
  static String _esc(String value) => value
      .replaceAll('\\', r'\\')
      .replaceAll('(', r'\(')
      .replaceAll(')', r'\)')
      .replaceAll(RegExp(r'[^\x20-\x7E]'), ' ');

  static List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
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
