import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// The `pdf` package's built-in base14 fonts (Helvetica etc.) have no
/// Arabic glyphs at all, so any Arabic text in a printed PDF needs an
/// explicit Arabic-capable font — this loads Noto Naskh Arabic via the
/// `printing` package's bundled Google Fonts helper (fetched once and
/// cached on disk by the plugin) and builds a [pw.ThemeData] with it set
/// as both the regular and bold face, with right-to-left text direction.
///
/// Note: the very first print on a device needs network access to fetch
/// the font; after that it's cached locally.
Future<pw.ThemeData> arabicPdfTheme() async {
  final regular = await PdfGoogleFonts.notoNaskhArabicRegular();
  final bold = await PdfGoogleFonts.notoNaskhArabicBold();
  return pw.ThemeData.withFont(base: regular, bold: bold);
}
