import 'dart:math';

import 'package:flutter/material.dart' hide Badge;

import '../../localization/app_localizations.dart';
import '../../ui/widgets.dart';

class BookSheet extends StatefulWidget {
  const BookSheet({super.key, required this.pages, this.initial});

  final Set<int> pages;
  final int? initial;

  @override
  State<BookSheet> createState() => _BookSheetState();
}

class _BookSheetState extends State<BookSheet> {
  late int page;

  List<String> get titles => [
    tr('book.1.title'),
    tr('book.2.title'),
    tr('book.3.title'),
    tr('book.4.title'),
    tr('book.5.title'),
  ];

  List<String> get texts => [
    tr('book.1.text'),
    tr('book.2.text'),
    tr('book.3.text'),
    tr('book.4.text'),
    tr('book.5.text'),
  ];

  @override
  void initState() {
    super.initState();
    page = widget.initial ?? (widget.pages.toList()..sort()).last;
    if (!widget.pages.contains(page)) page = 0;
  }

  // Kitap butonları: kitaba özel tıklama sesi, gecikmesiz dokunuş ve küçülme.
  // Tooltip dışarıda, çünkü içteki buton işaretçi almıyor.
  Widget _bookButton({
    required String tooltip,
    required VoidCallback? onTap,
    required Widget Function(VoidCallback? pressed) builder,
  }) => Tooltip(
    message: tooltip,
    triggerMode: TooltipTriggerMode.manual,
    child: TapDownButton(
      onTap: onTap,
      sound: TapDownButton.bookSound,
      builder: builder,
    ),
  );

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 430,
          maxHeight: min(MediaQuery.sizeOf(context).height * .72, 540),
        ),
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(9, 7, 6, 7),
          decoration: BoxDecoration(
            color: const Color(0xff315e51),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: const Color(0xffc7a56a), width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x35000000),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 4,
                offset: Offset(4, 2),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xffd8c295), width: 1.5),
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xffdfc99e),
                  Color(0xfffffbef),
                  Color(0xfffffbef),
                  Color(0xfff1e2c2),
                ],
                stops: [0.0, 0.055, 0.82, 1.0],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 5,
                  offset: Offset(-3, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 10, 6),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xffffe3a3),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: const Color(0xffd5b66f),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.menu_book_rounded,
                          color: ink,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tr('book.title'),
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.bold,
                            color: ink,
                          ),
                        ),
                      ),
                      _bookButton(
                        tooltip: tr('book.close'),
                        onTap: () => Navigator.pop(context),
                        builder: (pressed) => IconButton(
                          onPressed: pressed,
                          icon: const Icon(Icons.close, color: ink),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xffddcba8)),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(26, 10, 26, 20),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      child: Column(
                        key: ValueKey(page),
                        children: [
                          ClipRect(
                            child: SizedBox(
                              height: page == 2 ? 125 : 90,
                              child: Center(
                                child: page == 2
                                    ? Transform.scale(
                                        scale: 0.70,
                                        child: const FishPicture(scan: true),
                                      )
                                    : page == 4
                                    ? const Badge()
                                    : Container(
                                        width: 76,
                                        height: 76,
                                        decoration: BoxDecoration(
                                          color: page == 0
                                              ? const Color(0xffd9eef0)
                                              : const Color(0xffe2efd2),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xffc8a86a),
                                            width: 2,
                                          ),
                                        ),
                                        child: Icon(
                                          page == 0
                                              ? Icons.waves_rounded
                                              : Icons.eco_outlined,
                                          size: 45,
                                          color: ink,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            titles[page],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'StorySerif',
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: ink,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            texts[page],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: ink,
                              fontSize: 13,
                              height: 1.7,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            tr('book.quote'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xffffe7ad),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xffd8bd7e),
                              ),
                            ),
                            child: Text(
                              tr('common.page', {'page': page + 1}),
                              style: const TextStyle(
                                color: ink,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 5; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: _bookButton(
                            tooltip: widget.pages.contains(i)
                                ? titles[i]
                                : tr('common.notDiscovered'),
                            onTap: widget.pages.contains(i)
                                ? () => setState(() => page = i)
                                : null,
                            builder: (pressed) => IconButton.filledTonal(
                              onPressed: pressed,
                              style: IconButton.styleFrom(
                                minimumSize: const Size(38, 38),
                                backgroundColor: page == i
                                    ? ink
                                    : const Color(0xffeadbbd),
                                foregroundColor: page == i ? cream : ink,
                              ),
                              icon: widget.pages.contains(i)
                                  ? Text(
                                      '${i + 1}',
                                      style: TextStyle(
                                        color: page == i ? cream : ink,
                                      ),
                                    )
                                  : const Icon(Icons.lock_outline, size: 17),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
