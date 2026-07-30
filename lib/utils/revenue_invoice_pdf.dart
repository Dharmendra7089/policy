import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class RevenueInvoicePdf {
  static pw.MemoryImage? _cachedLogo;

  static Future<Uint8List> build(Map<String, dynamic> invoice) async {
    final logo = _cachedLogo ??= await _loadLogo();
    final rows = _rows(invoice['rows']);
    final includeGst = invoice['includeGst'] == true;
    final taxable = _num(invoice['taxableValue']);
    final cgst = includeGst ? _round2(taxable * 0.09) : 0.0;
    final sgst = includeGst ? _round2(taxable * 0.09) : 0.0;
    final totalGst = cgst + sgst;
    final total = taxable + totalGst;

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(44, 34, 44, 30),
        build: (context) => [
          _header(logo),
          pw.SizedBox(height: 58),
          _invoiceTitle(invoice),
          _billingBlock(invoice),
          _amountTable(
            taxable: taxable,
            cgst: cgst,
            sgst: sgst,
            totalGst: totalGst,
            total: total,
            includeGst: includeGst,
          ),
          _words(total),
          _settledRows(rows),
          pw.SizedBox(height: 8),
          _bankAndSignature(),
          pw.SizedBox(height: 28),
          _footer(),
        ],
      ),
    );
    return pdf.save();
  }

  static Future<pw.MemoryImage> _loadLogo() async {
    final logoBytes = await rootBundle.load(
      'assets/images/Makk-Finsol-logo.png',
    );
    return pw.MemoryImage(logoBytes.buffer.asUint8List());
  }

  static pw.Widget _header(pw.ImageProvider logo) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [pw.Image(logo, width: 150)],
    );
  }

  static pw.Widget _invoiceTitle(Map<String, dynamic> invoice) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey700),
      ),
      child: pw.Row(
        children: [
          _titleCell(
            'No. ${invoice['invoiceNo'] ?? '-'}',
            align: pw.TextAlign.left,
          ),
          _titleCell('INVOICE', bold: true, size: 16),
          _titleCell(
            'Date: ${_date(invoice['invoiceDate'])}',
            align: pw.TextAlign.right,
          ),
        ],
      ),
    );
  }

  static pw.Widget _titleCell(
    String text, {
    bool bold = true,
    double size = 12,
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Expanded(
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: pw.Text(
          text,
          textAlign: align,
          style: pw.TextStyle(
            fontSize: size,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ),
    );
  }

  static pw.Widget _billingBlock(Map<String, dynamic> invoice) {
    final billedTo = (invoice['billedTo'] ?? invoice['companyName'] ?? '-')
        .toString();
    final billedToAddress = (invoice['billedToAddress'] ?? '')
        .toString()
        .trim();
    final billedToGstin = (invoice['billedToGstin'] ?? '').toString().trim();
    return pw.Container(
      height: 90,
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(color: PdfColors.grey700),
          right: pw.BorderSide(color: PdfColors.grey700),
          bottom: pw.BorderSide(color: PdfColors.grey700),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Billed From :', style: _mutedBold()),
                  pw.Text('MAKK Finsol IMF Private Limited,', style: _bold()),
                  pw.Text('1-65/43/55, Kakatiya Hills'),
                  pw.Text('Madhapur, Shaikpet,'),
                  pw.Text('Hyderabad - 500081'),
                  pw.Text('GSTIN : 36AASCM7711R1ZI', style: _bold()),
                ],
              ),
            ),
          ),
          pw.Container(width: 1, color: PdfColors.grey700),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Billed To:', style: _mutedBold()),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    billedTo,
                    textAlign: pw.TextAlign.right,
                    style: _bold(),
                  ),
                  if (billedToAddress.isNotEmpty)
                    pw.Text(billedToAddress, textAlign: pw.TextAlign.right),
                  if (billedToGstin.isNotEmpty)
                    pw.Text(
                      'GSTIN : $billedToGstin',
                      textAlign: pw.TextAlign.right,
                      style: _bold(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _amountTable({
    required double taxable,
    required double cgst,
    required double sgst,
    required double totalGst,
    required double total,
    required bool includeGst,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey700),
      columnWidths: const {
        0: pw.FixedColumnWidth(48),
        1: pw.FlexColumnWidth(2.7),
        2: pw.FixedColumnWidth(58),
        3: pw.FixedColumnWidth(58),
        4: pw.FlexColumnWidth(2.2),
        5: pw.FixedColumnWidth(104),
      },
      children: [
        pw.TableRow(
          children: [
            _th('Sl. No.'),
            _th('Description'),
            _th('Code'),
            _th('Rate\n(Rs)'),
            _th('GST'),
            _th('Amount (Rs)'),
          ],
        ),
        pw.TableRow(
          children: [
            _td(
              '1.',
              height: includeGst ? 155 : 118,
              align: pw.Alignment.topCenter,
            ),
            _td(
              'Insurance referral\ncommission',
              height: includeGst ? 155 : 118,
              align: pw.Alignment.topCenter,
            ),
            _td(
              '9971',
              height: includeGst ? 155 : 118,
              align: pw.Alignment.topCenter,
            ),
            _td(
              includeGst ? '18%' : '-',
              height: includeGst ? 155 : 118,
              align: pw.Alignment.topCenter,
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(12, 14, 8, 8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Taxable Value'),
                  if (includeGst) ...[
                    pw.SizedBox(height: 52),
                    pw.Text('CGST@9%'),
                    pw.SizedBox(height: 8),
                    pw.Text('SGST@9%'),
                    pw.SizedBox(height: 8),
                    pw.Text('Total GST'),
                  ],
                  pw.SizedBox(height: includeGst ? 18 : 44),
                  pw.Text('Total Invoice Value', style: _bold()),
                ],
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(8, 14, 8, 8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(_money(taxable)),
                  if (includeGst) ...[
                    pw.SizedBox(height: 52),
                    pw.Text(_money(cgst)),
                    pw.SizedBox(height: 8),
                    pw.Text(_money(sgst)),
                    pw.SizedBox(height: 8),
                    pw.Text(_money(totalGst)),
                  ],
                  pw.SizedBox(height: includeGst ? 18 : 44),
                  pw.Text(
                    _money(total),
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _words(double amount) => pw.Container(
    width: double.infinity,
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        left: pw.BorderSide(color: PdfColors.grey700),
        right: pw.BorderSide(color: PdfColors.grey700),
        bottom: pw.BorderSide(color: PdfColors.grey700),
      ),
    ),
    padding: const pw.EdgeInsets.all(10),
    child: pw.Text(
      'Total in words : (${_amountInWords(amount)})',
      style: pw.TextStyle(
        fontStyle: pw.FontStyle.italic,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  );

  static pw.Widget _settledRows(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return pw.SizedBox();
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.TableHelper.fromTextArray(
        headers: const [
          'Customer',
          'Policy No.',
          'Policy',
          'Premium',
          'Commission',
        ],
        data: rows.take(18).map((row) {
          return [
            (row['customerName'] ?? '-').toString(),
            (row['policyNumber'] ?? '-').toString(),
            (row['policyName'] ?? row['productName'] ?? '-').toString(),
            _money(_num(row['premiumAmount'])),
            _money(_num(row['commissionAmount'])),
          ];
        }).toList(),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        headerStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
        cellStyle: const pw.TextStyle(fontSize: 7),
        cellAlignment: pw.Alignment.centerLeft,
      ),
    );
  }

  static pw.Widget _bankAndSignature() => pw.Container(
    height: 122,
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey700),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'BANK DETAILS',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                pw.SizedBox(height: 12),
                _bankRow('Account Name', 'MAKK FINSOL IMF PVT. LTD.'),
                _bankRow('Bank Name', 'AXIS Bank'),
                _bankRow('Account Number', '925020002633301'),
                _bankRow('IFSC Code', 'UTIB0000193'),
              ],
            ),
          ),
        ),
        pw.Container(width: 1, color: PdfColors.grey700),
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(18, 22, 18, 12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('For MAKK Finsol IMF Pvt. Ltd.', style: _bold()),
                pw.Spacer(),
                pw.Text('Authorized Signatory', style: _bold()),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  static pw.Widget _footer() => pw.Column(
    children: [
      pw.Container(
        height: 8,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40),
        child: pw.Row(
          children: [
            pw.Expanded(flex: 5, child: pw.Container(color: PdfColors.cyan600)),
            pw.Expanded(child: pw.Container(color: PdfColors.red500)),
          ],
        ),
      ),
      pw.SizedBox(height: 8),
      pw.Text(
        '# 1-65/43/55, Kakatiya Hills, Madhapur, Shaikpet, Hyderabad - 500081, Telangana. India',
        style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 9),
      ),
      pw.Text(
        'info@makkfinsol.com, www.makkfinsol.com, Ph: 040-23099999, Cell: +91 9646898989',
        style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 9),
      ),
    ],
  );

  static pw.Widget _bankRow(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      children: [
        pw.SizedBox(width: 92, child: pw.Text(label)),
        pw.Text(': '),
        pw.Expanded(child: pw.Text(value, style: _bold())),
      ],
    ),
  );

  static pw.Widget _th(String text) => pw.Padding(
    padding: const pw.EdgeInsets.all(8),
    child: pw.Text(
      text,
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
    ),
  );

  static pw.Widget _td(
    String text, {
    required double height,
    required pw.Alignment align,
  }) => pw.Container(
    height: height,
    alignment: align,
    padding: const pw.EdgeInsets.all(8),
    child: pw.Text(text, textAlign: pw.TextAlign.center),
  );

  static pw.TextStyle _bold() => pw.TextStyle(fontWeight: pw.FontWeight.bold);
  static pw.TextStyle _mutedBold() =>
      pw.TextStyle(color: PdfColors.grey700, fontWeight: pw.FontWeight.bold);

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

  static String _date(dynamic value) {
    DateTime? date;
    if (value is Timestamp) date = value.toDate();
    if (value is DateTime) date = value;
    date ??= DateTime.tryParse((value ?? '').toString());
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  static String _money(double value) => value.toStringAsFixed(2);

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
