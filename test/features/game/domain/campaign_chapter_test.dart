import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/campaign_chapter.dart';
import 'package:nine_fuse/features/game/domain/level_generator.dart';

void main() {
  group('total de estrelas do capítulo', () {
    // O denominador da barra do cabeçalho é o capítulo, não a campanha — e ele
    // é sempre `fases do capítulo * 3`. Um denominador que divergisse disso
    // faria a barra encher antes (ou nunca encher) do fim do trecho.
    test('é a contagem de fases vezes as estrelas por fase', () {
      for (final chapter in kChapters) {
        expect(chapter.starTotal, chapter.levelCount * kStarsPerLevel);
      }
    });

    test('o capítulo 4 vai da fase 21 à 30 e vale 30 estrelas', () {
      final chapter = chapterOf(21);

      expect(chapter.number, 4);
      expect(chapter.firstLevel, 21);
      expect(chapter.lastLevel, 30);
      expect(chapter.levelCount, 10);
      expect(chapter.starTotal, 30);
    });

    test('toda fase do capítulo gerado devolve o mesmo capítulo', () {
      final chapter = chapterOf(21);

      for (int n = chapter.firstLevel; n <= chapter.lastLevel; n++) {
        expect(chapterOf(n).number, chapter.number, reason: 'fase $n');
      }
      // O degrau seguinte é outro capítulo, com a mesma largura de bloco.
      expect(chapterOf(chapter.lastLevel + 1).number, chapter.number + 1);
      expect(chapterOf(chapter.lastLevel + 1).starTotal, kBlockSize * 3);
    });
  });
}
