import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../agreement_pdf.dart';
import '../api.dart';
import '../ui.dart';
import 'agreement.dart';
import 'docs.dart';
import 'home.dart';

/// Admin: open one KYC document (PDF in the phone's viewer, photo full screen). Works before and after approval.
Future<void> openAdminDoc(BuildContext context, Map<String, dynamic> d) async {
  try {
    final (bytes, mime) = await api.bytes('/v1/admin/docs/${d['id']}');
    if (!context.mounted) return;
    if (mime.contains('pdf')) {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/${d['type']}_${d['id']}.pdf');
      await f.writeAsBytes(bytes, flush: true);
      await OpenFilex.open(f.path);
    } else {
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => Scaffold(
                    appBar: bar(docLabels['${d['type']}']?.$1 ?? tr('Document')),
                    backgroundColor: Colors.black,
                    body: InteractiveViewer(maxScale: 6, child: Center(child: Image.memory(bytes))),
                  )));
    }
  } on ApiError catch (e) {
    if (context.mounted) toast(context, e.message);
  }
}

/// One row per document with a View button.
class AdminDocList extends StatefulWidget {
  final List<Map<String, dynamic>> docs;
  final List<String> missing;
  const AdminDocList({super.key, required this.docs, this.missing = const []});
  @override
  State<AdminDocList> createState() => _AdminDocListState();
}

class _AdminDocListState extends State<AdminDocList> {
  String? opening;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.docs.isEmpty && widget.missing.isEmpty) Text(tr('No documents.'), style: tx(13, color: kMute)),
      for (final d in widget.docs)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Box(
            child: Row(children: [
              Icon(d['mime'] == 'application/pdf' ? Icons.picture_as_pdf_outlined : Icons.image_outlined, color: kAct),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${docLabels['${d['type']}']?.$1 ?? d['type']} · ${sizeText((d['size'] as num).toInt())}', style: tx(13.5, weight: FontWeight.w700)),
                  Text(dateText(((d['createdAt'] ?? 0) as num).toInt()), style: tx(11.5, color: kMute)),
                ]),
              ),
              TextButton(
                onPressed: opening != null
                    ? null
                    : () async {
                        setState(() => opening = '${d['id']}');
                        await openAdminDoc(context, d);
                        if (mounted) setState(() => opening = null);
                      },
                child: Text(opening == d['id'] ? tr('Opening…') : tr('View')),
              ),
            ]),
          ),
        ),
      for (final m in widget.missing)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Box(
            color: kRedBg,
            child: Row(children: [
              Icon(Icons.error_outline, color: kRed),
              const SizedBox(width: 10),
              Expanded(child: Text(tr('{0} not uploaded yet', [docLabels[m]?.$1 ?? m]), style: tx(13.5, color: kRed, weight: FontWeight.w700))),
            ]),
          ),
        ),
    ]);
  }
}

/// Admin: the signed agreement as the same PDF the partner has (any version, old or current).
Future<void> openAgreementVersionPdf(BuildContext context, Map<String, dynamic> a) async {
  try {
    final data = await AgreementData.fromSigned(a);
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/NukadKart_Agreement_${a['id']}.pdf');
    await f.writeAsBytes(await agreementPdf(data), flush: true);
    await OpenFilex.open(f.path);
  } catch (e) {
    if (context.mounted) toast(context, tr('Could not open the agreement ({0}).', ['$e']));
  }
}
