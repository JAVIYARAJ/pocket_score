import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../theme/app_theme.dart';
import '../widgets/premium_header.dart';

/// Full-screen PDF preview with built-in share and print buttons.
class PdfPreviewScreen extends StatelessWidget {
  final Future<Uint8List> Function() buildPdf;
  final String filename;
  final String title;

  const PdfPreviewScreen({
    super.key,
    required this.buildPdf,
    this.filename = 'match_result.pdf',
    this.title = 'Match Result',
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Column(
          children: [
            PremiumHeader(
              category: 'PDF PREVIEW',
              title: title,
              showBackButton: true,
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Container(
                  color: AppColors.bg,
                  child: PdfPreview(
                    build: (_) => buildPdf(),
                    initialPageFormat: PdfPageFormat.a4,
                    allowPrinting: true,
                    allowSharing: true,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                    pdfFileName: filename,
                    scrollViewDecoration: const BoxDecoration(color: AppColors.bg),
                    pdfPreviewPageDecoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    loadingWidget: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
                          SizedBox(height: 16),
                          Text('Generating PDF…', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
