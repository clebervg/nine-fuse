import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/campaign_chapter.dart';
import 'package:nine_fuse/features/game/domain/level_catalog.dart';
import 'package:nine_fuse/features/game/domain/level_generator.dart';

void main() {
  group('levelAt', () {
    test('as fases artesanais saem intactas do catálogo', () {
      expect(kCampaign.length, kHandcraftedLevels);

      for (final level in kCampaign) {
        final fromCatalog = levelAt(level.number);
        expect(fromCatalog.objective, level.objective);
        expect(fromCatalog.moveLimit, level.moveLimit);
        expect(fromCatalog.spawnMin, level.spawnMin);
        expect(fromCatalog.teaches, level.teaches);
      }
    });

    test('a fase 11 em diante é gerada', () {
      expect(levelAt(11).moveLimit, generateLevel(11).moveLimit);
      expect(levelAt(11).objective, generateLevel(11).objective);
    });

    test('a numeração é contínua e sem buraco até bem longe', () {
      for (int n = 1; n <= 1000; n++) {
        expect(levelAt(n).number, n);
      }
    });

    test('recusa fase zero ou negativa', () {
      expect(() => levelAt(0), throwsA(isA<AssertionError>()));
    });
  });

  group('chapterOf', () {
    test('os capítulos artesanais não mudam', () {
      expect(chapterOf(1).number, 1);
      expect(chapterOf(6).number, 1);
      expect(chapterOf(7).number, 2);
      expect(chapterOf(10).number, 2);
    });

    test('gera capítulos além do segundo, de dez em dez', () {
      expect(chapterOf(11).number, 3);
      expect(chapterOf(20).number, 3);
      expect(chapterOf(21).number, 4);
      // 990 fases além do capítulo artesanal (fase 10), em blocos de
      // kBlockSize=10: 99 blocos completos, o último cobrindo exatamente
      // 991-1000 — capítulo 2 (último artesanal) + 99 blocos = 101.
      expect(chapterOf(1000).number, 101);
    });

    test('o capítulo gerado cobre exatamente a fase pedida', () {
      for (int n = 11; n <= 1000; n++) {
        final chapter = chapterOf(n);
        expect(chapter.contains(n), isTrue, reason: 'fase $n');
        expect(chapter.levelCount, kBlockSize, reason: 'fase $n');
        expect(chapter.starTotal, kBlockSize * kStarsPerLevel, reason: 'fase $n');
      }
    });

    test('a numeração dos capítulos não tem buraco', () {
      var previous = chapterOf(1).number;
      for (int n = 2; n <= 1000; n++) {
        final current = chapterOf(n).number;
        expect(current - previous, anyOf(0, 1), reason: 'fase $n');
        previous = current;
      }
    });
  });
}
