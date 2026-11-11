import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../widgets/ui.dart';
import 'subcategory_screen.dart';

const _tileBg = [Color(0xFFFFF0E8), Color(0xFFFFF8E1), Color(0xFFFDEBF2), Color(0xFFF0EBFA)];

class CategoriesTab extends StatelessWidget {
  const CategoriesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: Colors.white,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [Text('All categories', style: head(21))]),
          ),
        ),
      ),
      const Divider(height: 1, color: kLine),
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 24), children: [
          for (var i = 0; i < kCategories.length; i++) ...[
            Row(children: [
              Text(kCategories[i].emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(kCategories[i].name, style: head(16.5)),
            ]),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 8,
              childAspectRatio: 0.72,
              children: [
                for (final sub in kCategories[i].subs)
                  GestureDetector(
                    onTap: () =>
                        Navigator.push(context, MaterialPageRoute(builder: (_) => SubcategoryScreen(sub: sub))),
                    child: Column(children: [
                      AspectRatio(aspectRatio: 1, child: EmojiTileFill(sub.emoji, bg: _tileBg[i])),
                      const SizedBox(height: 5),
                      Text(sub.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: body(11, weight: FontWeight.w600).copyWith(height: 1.2)),
                    ]),
                  ),
              ],
            ),
            const SizedBox(height: 18),
          ],
        ]),
      ),
    ]);
  }
}

class EmojiTileFill extends StatelessWidget {
  final String emoji;
  final Color bg;
  const EmojiTileFill(this.emoji, {super.key, required this.bg});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      return Container(
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.center,
        child: Text(emoji, style: TextStyle(fontSize: c.maxWidth * 0.48)),
      );
    });
  }
}
