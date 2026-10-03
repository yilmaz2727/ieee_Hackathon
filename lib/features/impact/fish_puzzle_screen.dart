import 'package:flutter/material.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../../../../localization/app_localizations.dart';

enum PieceID { t1, t2, r1, r2, b1, b2, l1, l2 }

class PieceClipper extends CustomClipper<Path> {
  final PieceID piece;
  PieceClipper(this.piece);

  @override
  Path getClip(Size size) {
    Path path = Path();
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    switch (piece) {
      case PieceID.t1:
        path.moveTo(0, 0); path.lineTo(cx, 0); path.lineTo(cx, cy); path.close(); break;
      case PieceID.t2:
        path.moveTo(cx, 0); path.lineTo(w, 0); path.lineTo(cx, cy); path.close(); break;
      case PieceID.r1:
        path.moveTo(w, 0); path.lineTo(w, cy); path.lineTo(cx, cy); path.close(); break;
      case PieceID.r2:
        path.moveTo(w, cy); path.lineTo(w, h); path.lineTo(cx, cy); path.close(); break;
      case PieceID.b1:
        path.moveTo(w, h); path.lineTo(cx, h); path.lineTo(cx, cy); path.close(); break;
      case PieceID.b2:
        path.moveTo(cx, h); path.lineTo(0, h); path.lineTo(cx, cy); path.close(); break;
      case PieceID.l1:
        path.moveTo(0, h); path.lineTo(0, cy); path.lineTo(cx, cy); path.close(); break;
      case PieceID.l2:
        path.moveTo(0, cy); path.lineTo(0, 0); path.lineTo(cx, cy); path.close(); break;
    }
    return path;
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class FishPuzzleScreen extends StatefulWidget {
  final VoidCallback? onFinish;
  const FishPuzzleScreen({super.key, this.onFinish});

  @override
  State<FishPuzzleScreen> createState() => _FishPuzzleScreenState();
}

class _FishPuzzleScreenState extends State<FishPuzzleScreen> {
  static const double puzzleSize = 270.0;
  List<PieceID> piecesInTray = PieceID.values.toList()..shuffle();
  Set<PieceID> placedPieces = {};
  
  int _secondsPassed = 0;
  Timer? _timer;
  bool _isSuccess = false;

  bool get _isTr => AppLocalizations.instance.isTurkish;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !_isSuccess) {
        setState(() {
          _secondsPassed++;
        });
      }
    });
  }

  void _checkWin() async {
    if (placedPieces.length == piecesInTray.length) {
      _timer?.cancel();
      setState(() {
        _isSuccess = true;
      });

      int puzzleScore = max(10, 100 - _secondsPassed);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('puzzle_score', puzzleScore);

      Future.delayed(const Duration(milliseconds: 650), () {
        if (mounted) {
          _showKamuSpotuDialog(puzzleScore);
        }
      });
    }
  }

  void _showKamuSpotuDialog(int score) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF9F7EE),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blueAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isTr ? 'Balıkları Koruyalım!' : 'Protect the Fish!',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF2C5E43)),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/fish.png',
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 150,
                      color: Colors.blue.withValues(alpha: 0.2),
                      child: const Icon(Icons.sailing, size: 64, color: Colors.blueAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isTr 
                    ? 'Tebrikler! Bulmacayı tamamlayıp tatlı suda yaşayan balığımızı kurtardın.\n\nFakat ne yazık ki doğada işler bu kadar kolay değil. Nehir ve göllere atılan plastik atıklar zamanla parçalanarak "Mikroplastik" adını verdiğimiz küçük zehirli yapılara dönüşür.\n\nTemiz sulara duyarlı balıklar beslenirken yanlışlıkla bu mikroplastikleri yutar. Bu durum onların hastalanmasına, sistemlerinin tıkanmasına ve yaşam alanlarının tamamen yok olmasına sebep olur. Onları kurtarmak bizim elimizde! Bütün tatlı suları korumalı ve etrafı asla kirletmemeliyiz.'
                    : 'Congratulations! You completed the puzzle and saved our freshwater fish.\n\nBut unfortunately, things in nature aren\'t this easy. Plastic waste discarded into rivers and lakes slowly breaks down into toxic tiny pieces called "Microplastics".\n\nSensitive fish accidentally swallow these microplastics while feeding. This causes severe illness, blocks their digestive systems, and completely destroys their habitats. It\'s up to us to save them! We must protect our freshwaters and never throw plastics into nature.',
                  style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
                  textAlign: TextAlign.justify,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isTr ? 'Bulmaca Skoru: $score Puan ($_secondsPassed saniye)' : 'Puzzle Score: $score Points ($_secondsPassed seconds)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // close dialog
                if (widget.onFinish != null) {
                  widget.onFinish!(); // Go back to the game's flow natively!
                }
              },
              child: Text(
                _isTr ? 'Görevi Tamamla 🌊' : 'Complete Mission 🌊',
                style: const TextStyle(color: Color(0xFF2C5E43), fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget buildImageSlice(PieceID piece) {
    return Image.asset(
      'assets/images/fish.png',
      width: puzzleSize,
      height: puzzleSize,
      fit: BoxFit.cover,
      errorBuilder: (context, e, s) => Container(
        color: Colors.orangeAccent.withValues(alpha: 0.5),
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image, color: Colors.white, size: 40),
      ),
    );
  }

  Widget buildTarget(PieceID piece) {
    bool isPlaced = placedPieces.contains(piece);
    return DragTarget<PieceID>(
      onWillAcceptWithDetails: (details) => details.data == piece,
      onAcceptWithDetails: (details) {
        if (!context.mounted) return;
        setState(() {
          placedPieces.add(piece);
        });
        _checkWin();
      },
      builder: (context, candidateData, rejectedData) {
        return ClipPath(
          clipper: PieceClipper(piece),
          child: Container(
            width: puzzleSize,
            height: puzzleSize,
            color: isPlaced 
              ? Colors.transparent 
              : (candidateData.isNotEmpty ? Colors.green.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.05)),
            child: isPlaced ? buildImageSlice(piece) : null,
          ),
        );
      },
    );
  }

  Widget buildDraggable(PieceID piece) {
    bool isPlaced = placedPieces.contains(piece);
    final slice = ClipPath(
      clipper: PieceClipper(piece),
      child: SizedBox(
        width: puzzleSize,
        height: puzzleSize,
        child: buildImageSlice(piece),
      ),
    );
    
    return Visibility(
      visible: !isPlaced,
      maintainState: true,
      maintainAnimation: true,
      maintainSize: true,
      child: Draggable<PieceID>(
        data: piece,
        feedback: Transform.scale(
          scale: 1.05,
          child: Opacity(
            opacity: 0.8,
            child: slice,
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.0,
          child: const SizedBox(
            width: 70,
            height: 70,
          ),
        ),
        child: Container(
          width: 76,
          height: 76,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, spreadRadius: 0)],
          ),
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: puzzleSize + 20,
              height: puzzleSize + 20,
              child: Center(child: slice),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F0),
      appBar: AppBar(
        title: Text(
          _isTr ? 'Balığı Birleştir!' : 'Assemble the Fish!',
          style: const TextStyle(color: Color(0xFF2C5E43), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _isTr 
                        ? 'Geometrik parçaları sürükleyerek balığı tamamla. Ne kadar hızlı yaparsan o kadar çok puan kazanırsın!'
                        : 'Drag the scattered geometric pieces to assemble the fish. Faster times earn higher scores!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isTr ? 'Süre: $_secondsPassed saniye' : 'Time: $_secondsPassed seconds',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black54),
                ),
                const SizedBox(height: 10),
                
                // Puzzle Drop Zone (The Stack)
                Container(
                  width: puzzleSize,
                  height: puzzleSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300, width: 2, style: BorderStyle.solid),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 15, spreadRadius: 3),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Subtly show puzzle boundary
                      buildTarget(PieceID.t1),
                      buildTarget(PieceID.t2),
                      buildTarget(PieceID.r1),
                      buildTarget(PieceID.r2),
                      buildTarget(PieceID.b1),
                      buildTarget(PieceID.b2),
                      buildTarget(PieceID.l1),
                      buildTarget(PieceID.l2),
                      
                      // Show grid lines for clarity of the geometric cut
                      IgnorePointer(
                        child: CustomPaint(
                          size: const Size(puzzleSize, puzzleSize),
                          painter: GridDividerPainter(),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Trays full of pieces (Wrapped in Expanded & ScrollView to prevent overflow!)
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, spreadRadius: -2)],
                    ),
                    child: SingleChildScrollView(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: piecesInTray.map((p) => buildDraggable(p)).toList(),
                      ),
                    ),
                  ),
                ),

                if (_isSuccess)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: Text('✅', style: TextStyle(fontSize: 48)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GridDividerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0) return;
    Paint paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.3)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
      
    // Draw the X that slices the picture into 4 triangles
    canvas.drawLine(const Offset(0, 0), Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
    
    // Draw the + that slices the remaining triangles making it exactly 8 distinct slices
    canvas.drawLine(Offset(size.width/2, 0), Offset(size.width/2, size.height), paint);
    canvas.drawLine(Offset(0, size.height/2), Offset(size.width, size.height/2), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
