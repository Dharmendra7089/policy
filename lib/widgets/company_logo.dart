import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const _companyLogoAssetVersion = '20260620-2';

String _cleanCompanyName(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

String? companyLogoAssetForName(String companyName) {
  final name = _cleanCompanyName(companyName);
  if (name.isEmpty) return null;

  const mappings = <String, String>{
    'export credit guarantee corporation': 'ecgc.jpg',
    'ecgc': 'ecgc.jpg',
    'agriculture insurance company': 'agriculture-insurance-company.png',
    'bajaj allianz life': 'bajaj-allianz-life.png',
    'bajaj allianz': 'bajaj-allianz-general.png',
    'aditya birla sun life': 'aditya-birla-sun-life.webp',
    'aditya birla health': 'aditya-birla-health.png',
    'icici prudential': 'icici-prudential-life.png',
    'icici lombard': 'icici-lombard.png',
    'indusind nippon life': 'indusind-nippon-life.png',
    'reliance nippon life': 'indusind-nippon-life.png',
    'axis max life': 'axis-max-life.png',
    'max life': 'axis-max-life.png',
    'sbi general': 'sbi-general.webp',
    'sbi life': 'sbi-life.png',
    'iffco tokio': 'iffco-tokio.png',
    'hdfc ergo': 'hdfc-ergo.png',
    'united india': 'united-india.png',
    'new india assurance': 'new-india-assurance.png',
    'niva bupa': 'niva-bupa.png',
    'care health': 'care-health.png',
    'star health': 'star-health.png',
    'galaxy health': 'galaxy-health.png',
    'manipalcigna': 'manipalcigna.png',
    'manipal cigna': 'manipalcigna.png',
  };

  for (final entry in mappings.entries) {
    if (name.contains(entry.key)) {
      return 'assets/images/company_logos/${entry.value}';
    }
  }
  return null;
}

String? companyDomainForName(String companyName) {
  final name = _cleanCompanyName(companyName);
  if (name.isEmpty) return null;

  final mappings = <String, String>{
    'manipalcigna': 'manipalcigna.com',
    'manipal cigna': 'manipalcigna.com',
    'niva bupa': 'nivabupa.com',
    'sbi general': 'sbigeneral.in',
    'iffco tokio': 'iffcotokio.co.in',
    'hdfc ergo': 'hdfcergo.com',
    'icici lombard': 'icicilombard.com',
    'bajaj allianz': 'bajajallianz.com',
    'tata aig': 'tataaig.com',
    'reliance general': 'reliancegeneral.co.in',
    'chola ms': 'cholainsurance.com',
    'cholamandalam': 'cholainsurance.com',
    'digit': 'godigit.com',
    'go digit': 'godigit.com',
    'star health': 'starhealth.in',
    'care health': 'careinsurance.com',
    'religare': 'careinsurance.com',
    'aditya birla': 'adityabirlacapital.com',
    'kotak general': 'kotakgeneral.com',
    'royal sundaram': 'royalsundaram.in',
    'united india': 'uiic.co.in',
    'new india assurance': 'newindia.co.in',
    'national insurance': 'nationalinsurance.nic.co.in',
    'oriental insurance': 'orientalinsurance.org.in',
    'lic': 'licindia.in',
    'life insurance corporation': 'licindia.in',
    'sbi life': 'sbilife.co.in',
    'hdfc life': 'hdfclife.com',
    'icici prudential': 'iciciprulife.com',
    'max life': 'maxlifeinsurance.com',
    'tata aia': 'tataaia.com',
    'bajaj allianz life': 'bajajallianzlife.com',
    'pnb metlife': 'pnbmetlife.com',
    'canara hsbc': 'canarahsbclife.com',
    'kotak life': 'kotaklife.com',
    'bandhan life': 'bandhanlife.com',
    'aegon life': 'bandhanlife.com',
    'future generali': 'futuregenerali.in',
    'aviva': 'avivaindia.com',
    'ecgc': 'ecgc.in',
  };

  for (final entry in mappings.entries) {
    if (name.contains(entry.key)) return entry.value;
  }
  return null;
}

String? _domainFromWebsite(String website) {
  final raw = website.trim();
  if (raw.isEmpty) return null;
  final uri = Uri.tryParse(raw.startsWith('http') ? raw : 'https://$raw');
  final host = uri?.host.replaceFirst(RegExp(r'^www\.'), '');
  return host == null || host.isEmpty ? null : host;
}

String? companyLogoUrl({required String companyName, String? website}) {
  final domain =
      _domainFromWebsite(website ?? '') ?? companyDomainForName(companyName);
  if (domain == null || domain.isEmpty) return null;
  return 'https://www.google.com/s2/favicons?domain=$domain&sz=128';
}

class CompanyLogo extends StatelessWidget {
  static Stream<Map<String, String>> get _customLogoMapStream {
    // Do not wrap this in asBroadcastStream(). A late subscriber would not
    // receive the already-emitted Firestore snapshot until another company
    // document changed, leaving newly built logo widgets on their fallback.
    return FirebaseFirestore.instance
        .collection('insurance_companies')
        .snapshots()
        .map((snap) {
          final logos = <String, String>{};
          for (final doc in snap.docs) {
            final data = doc.data();
            final name = _cleanCompanyName(
              data['companyName']?.toString() ?? '',
            );
            final logoUrl = data['logoUrl']?.toString().trim() ?? '';
            if (name.isNotEmpty && logoUrl.isNotEmpty) {
              logos[name] = logoUrl;
            }
          }
          return logos;
        });
  }

  final String companyName;
  final String? website;
  final String? customLogoUrl;
  final double size;
  final double radius;
  final double? padding;

  const CompanyLogo({
    super.key,
    required this.companyName,
    this.website,
    this.customLogoUrl,
    this.size = 24,
    this.radius = 8,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final logoAsset = companyLogoAssetForName(companyName);
    final logoUrl = companyLogoUrl(companyName: companyName, website: website);
    final innerPadding = padding ?? (size * 0.14).clamp(2.0, 8.0).toDouble();
    final initial = companyName.trim().isEmpty
        ? '?'
        : companyName.trim().characters.first.toUpperCase();

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: _logoContent(
          logoAsset: logoAsset,
          logoUrl: logoUrl,
          initial: initial,
          innerPadding: innerPadding,
        ),
      ),
    );
  }

  Widget _logoContent({
    required String? logoAsset,
    required String? logoUrl,
    required String initial,
    required double innerPadding,
  }) {
    final providedLogoUrl = customLogoUrl?.trim() ?? '';
    final fallback = providedLogoUrl.isNotEmpty
        ? _networkLogo(providedLogoUrl, initial, innerPadding)
        : logoAsset != null
        ? _bundledLogo(logoAsset, initial, innerPadding)
        : logoUrl == null
        ? _CompanyLogoFallback(initial: initial, size: size)
        : _networkLogo(logoUrl, initial, innerPadding);

    final companyKey = _cleanCompanyName(companyName);
    if (companyKey.isEmpty || companyName.trim() == '-') return fallback;

    return StreamBuilder<Map<String, String>>(
      stream: _customLogoMapStream,
      builder: (context, snapshot) {
        // The company document is the source of truth. Policy records may
        // contain a copied companyLogoUrl from when the policy was created;
        // that stale value is now only a fallback while Firestore loads.
        final savedLogoUrl = _savedLogoForName(snapshot.data, companyName);
        if (savedLogoUrl.isEmpty) return fallback;
        return _networkLogo(savedLogoUrl, initial, innerPadding);
      },
    );
  }

  String _savedLogoForName(Map<String, String>? logos, String name) {
    if (logos == null || logos.isEmpty) return '';
    final key = _cleanCompanyName(name);
    if (key.isEmpty) return '';

    final exact = logos[key]?.trim() ?? '';
    if (exact.isNotEmpty) return exact;

    var bestKey = '';
    var bestLogo = '';
    for (final entry in logos.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) {
        if (entry.key.length > bestKey.length) {
          bestKey = entry.key;
          bestLogo = entry.value.trim();
        }
      }
    }
    return bestLogo;
  }

  Widget _networkLogo(String url, String initial, double innerPadding) {
    return Padding(
      padding: EdgeInsets.all(innerPadding),
      child: Image.network(
        url,
        key: ValueKey(url),
        // Firebase Storage currently does not return CORS headers for this
        // bucket. On Flutter Web, render through a native <img> element so
        // cross-origin company logos remain visible. Other platforms ignore
        // this setting and continue to fetch the image bytes normally.
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        width: size - (innerPadding * 2),
        height: size - (innerPadding * 2),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) =>
            _CompanyLogoFallback(initial: initial, size: size),
      ),
    );
  }

  Widget _bundledLogo(String assetPath, String initial, double innerPadding) {
    Widget fallback(BuildContext context, Object error, StackTrace? trace) =>
        _CompanyLogoFallback(initial: initial, size: size);

    if (kIsWeb) {
      return Padding(
        padding: EdgeInsets.all(innerPadding),
        child: Image.network(
          'assets/$assetPath?v=$_companyLogoAssetVersion',
          width: size - (innerPadding * 2),
          height: size - (innerPadding * 2),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: fallback,
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.all(innerPadding),
      child: Image.asset(
        assetPath,
        width: size - (innerPadding * 2),
        height: size - (innerPadding * 2),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: fallback,
      ),
    );
  }
}

class _CompanyLogoFallback extends StatelessWidget {
  final String initial;
  final double size;

  const _CompanyLogoFallback({required this.initial, required this.size});

  @override
  Widget build(BuildContext context) => Text(
    initial,
    style: TextStyle(
      color: const Color(0xFF0D2D4F),
      fontSize: size * 0.42,
      fontWeight: FontWeight.w900,
    ),
  );
}

class CompanyLogoLabel extends StatelessWidget {
  final String companyName;
  final String? website;
  final String? customLogoUrl;
  final double logoSize;
  final TextStyle? style;
  final int maxLines;

  const CompanyLogoLabel({
    super.key,
    required this.companyName,
    this.website,
    this.customLogoUrl,
    this.logoSize = 22,
    this.style,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final value = companyName.trim().isEmpty ? '-' : companyName.trim();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CompanyLogo(
          companyName: value,
          website: website,
          customLogoUrl: customLogoUrl,
          size: logoSize,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}
