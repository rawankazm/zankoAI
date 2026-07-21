import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/database_service.dart';
import '../../services/language_provider.dart';
import '../../models/flashcard_model.dart';
import 'package:uuid/uuid.dart';

class QrShareSheet extends StatelessWidget {
  final List<FlashcardModel> deck;
  const QrShareSheet({super.key, required this.deck});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final langProvider = Provider.of<LanguageProvider>(context);

    // Serialize deck
    final cardsData = deck.map((c) => {'f': c.front, 'b': c.back}).toList();
    final String serializedData = json.encode({
      'type': 'zanko_deck',
      'cards': cardsData,
    });

    final String title = langProvider.currentLanguage == AppLanguage.english
        ? 'Share Deck'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'مشاركة مجموعة الكروت'
            : 'هاوبەشکردنی فلاشکاردەکان';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Text(
                        langProvider.currentLanguage == AppLanguage.english
                            ? 'Let your friend scan this QR code to import this deck instantly!'
                            : langProvider.currentLanguage == AppLanguage.arabic
                                ? 'دع صديقك يمسح هذا الكود لاستيراد الكروت فوراً!'
                                : 'با هاوڕێکەت ئەم کۆدی QRە سکان بکات بۆ ئەوەی فلاشکاردەکانت وەربگرێت!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'Noto Sans Arabic',
                          fontWeight: FontWeight.bold,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      QrImageView(
                        data: serializedData,
                        version: QrVersions.auto,
                        size: 260.0,
                        backgroundColor: Colors.white,
                        errorStateBuilder: (cxt, err) {
                          return const Center(child: Text("Data too large for QR Code. Try sharing a smaller deck."));
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${deck.length} Flashcards',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.maxFinite,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('دابخە (Close)', style: TextStyle(fontFamily: 'Noto Sans Arabic')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QrScannerView extends StatefulWidget {
  const QrScannerView({super.key});

  @override
  State<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<QrScannerView> {
  final MobileScannerController _controller = MobileScannerController();
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_hasScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.isNotEmpty) {
        setState(() {
          _hasScanned = true;
        });

        try {
          final Map<String, dynamic> data = json.decode(rawValue);
          if (data['type'] == 'zanko_deck' && data['cards'] != null) {
            final List<dynamic> cardsList = data['cards'];
            final dbService = Provider.of<DatabaseService>(context, listen: false);
            
            // Re-import deck
            await dbService.clearFlashcards();
            final uuid = const Uuid();
            for (var cardData in cardsList) {
              final card = FlashcardModel(
                id: 'card_${uuid.v4()}',
                front: cardData['f'] ?? '',
                back: cardData['b'] ?? '',
              );
              await dbService.addFlashcard(card);
            }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Deck imported successfully! / فلاشکاردەکان بە سەرکەوتوویی هاوردە کران!', 
                    style: TextStyle(fontFamily: 'Noto Sans Arabic')),
                ),
              );
              Navigator.pop(context, true); // Return success
            }
          } else {
            throw Exception('Invalid QR code format for ZankoAI.');
          }
        } catch (e) {
          setState(() {
            _hasScanned = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Scan Error: $e')),
            );
          }
        }
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);

    final String scanTitle = langProvider.currentLanguage == AppLanguage.english
        ? 'Scan Deck QR'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'مسح كود البطاقات'
            : 'سکانکردنی کۆدی فلاشکارد';

    return Scaffold(
      appBar: AppBar(
        title: Text(scanTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android_rounded),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Scanner Overlay Frame
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent, width: 4),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Align QR code inside the box to scan\nکۆدی QR لە ناو چوارگۆشەکە دابنێ',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Noto Sans Arabic'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
