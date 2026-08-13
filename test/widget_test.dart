// Tests for the pure model/catalog layer.
//
// Widget-level tests of HomeScreen/MiniGamesHubApp are intentionally not
// here: both touch AdMob platform channels on init (banner load, App Open
// ad), which need plugin mocks to run under flutter_test.

import 'package:flutter_test/flutter_test.dart';

import 'package:minigames_hub/main.dart';

void main() {
  group('Game', () {
    test('reports isLocal and playableSource for a bundled game', () {
      const game = Game(
        id: 'local',
        title: 'Local',
        description: '',
        thumbnailAsset: 'assets/thumbnails/local.png',
        localAssetPath: 'assets/games/local/index.html',
        category: GameCategory.puzzle,
        rating: 4.0,
      );

      expect(game.isLocal, isTrue);
      expect(game.playableSource, 'assets/games/local/index.html');
    });

    test('falls back to remoteUrl when there is no local asset', () {
      const game = Game(
        id: 'remote',
        title: 'Remote',
        description: '',
        thumbnailAsset: 'assets/thumbnails/remote.png',
        remoteUrl: 'https://example.com/game/index.html',
        category: GameCategory.arcade,
        rating: 3.5,
      );

      expect(game.isLocal, isFalse);
      expect(game.playableSource, 'https://example.com/game/index.html');
    });

    test('asserts when neither a local asset nor a remote URL is given', () {
      expect(
        () => Game(
          id: 'broken',
          title: 'Broken',
          description: '',
          thumbnailAsset: 'assets/thumbnails/broken.png',
          category: GameCategory.action,
          rating: 1.0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('survives a fromJson/toJson round trip', () {
      const original = Game(
        id: 'puzzle_blocks',
        title: 'Puzzle Blocks',
        description: 'Slide and match colorful blocks.',
        thumbnailAsset: 'assets/thumbnails/puzzle_blocks.png',
        localAssetPath: 'assets/games/puzzle_blocks/index.html',
        category: GameCategory.puzzle,
        rating: 4.6,
        isFeatured: true,
      );

      final restored = Game.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.description, original.description);
      expect(restored.thumbnailAsset, original.thumbnailAsset);
      expect(restored.localAssetPath, original.localAssetPath);
      expect(restored.remoteUrl, original.remoteUrl);
      expect(restored.category, original.category);
      expect(restored.rating, original.rating);
      expect(restored.isFeatured, original.isFeatured);
    });

    test('fromJson applies defaults and an unknown category falls back', () {
      final game = Game.fromJson({
        'id': 'x',
        'title': 'X',
        'thumbnailAsset': 'assets/thumbnails/x.png',
        'remoteUrl': 'https://example.com/x/index.html',
        'category': 'not_a_real_category',
      });

      expect(game.description, '');
      expect(game.rating, 0.0);
      expect(game.isFeatured, isFalse);
      expect(game.category, GameCategory.arcade);
    });
  });

  group('GameCatalog', () {
    test('every game has a unique id', () {
      final ids = GameCatalog.games.map((g) => g.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every game has a usable source and a sane rating', () {
      for (final game in GameCatalog.games) {
        expect(game.playableSource, isNotEmpty, reason: game.id);
        expect(game.title, isNotEmpty, reason: game.id);
        expect(game.rating, inInclusiveRange(0.0, 5.0), reason: game.id);
      }
    });

    test('does not list soccer_kicks, whose assets are not bundled yet', () {
      expect(GameCatalog.games.any((g) => g.id == 'soccer_kicks'), isFalse);
    });
  });

  group('GameDistribution', () {
    // A syntactically valid id (32 hex chars) used purely to exercise the
    // URL builder — not a real published game.
    const validId = '0123456789abcdef0123456789abcdef';

    test('accepts a 32-char hex id and rejects anything else', () {
      expect(GameDistribution.isValidId(validId), isTrue);
      expect(GameDistribution.isValidId('  $validId  '), isTrue);
      expect(GameDistribution.isValidId('PASTE_GAMEDISTRIBUTION_ID_HERE'),
          isFalse);
      expect(GameDistribution.isValidId(''), isFalse);
      expect(GameDistribution.isValidId('abc123'), isFalse);
      expect(GameDistribution.isValidId(validId.toUpperCase()), isFalse);
    });

    test('builds an https embed URL carrying the referrer', () {
      final url = GameDistribution.embedUrl(validId);

      expect(url, startsWith('https://html5.gamedistribution.com/$validId/'));
      expect(url, contains('gd_sdk_referrer_url='));
      expect(Uri.parse(url).scheme, 'https');
    });

    test('throws on a malformed id instead of building a dead URL', () {
      expect(() => GameDistribution.embedUrl('not-an-id'),
          throwsA(isA<ArgumentError>()));
    });

    test('recovers an id from a dashboard embed URL', () {
      expect(
        GameDistribution.idFromUrl(
            'https://html5.gamedistribution.com/$validId/'),
        validId,
      );
      expect(GameDistribution.idFromUrl('https://example.com/nope'), isNull);
    });
  });

  group('Famobi', () {
    test('accepts hyphenated lowercase slugs and rejects the rest', () {
      expect(Famobi.isValidSlug('garden-bloom'), isTrue);
      expect(Famobi.isValidSlug('  garden-bloom  '), isTrue);
      expect(Famobi.isValidSlug('bubble3'), isTrue);
      expect(Famobi.isValidSlug('Garden-Bloom'), isFalse);
      expect(Famobi.isValidSlug('garden--bloom'), isFalse);
      expect(Famobi.isValidSlug('-garden'), isFalse);
      expect(Famobi.isValidSlug(''), isFalse);
    });

    test('builds the play.famobi.com embed URL', () {
      expect(Famobi.embedUrl('garden-bloom'),
          'https://play.famobi.com/garden-bloom');
      expect(Uri.parse(Famobi.embedUrl('garden-bloom')).scheme, 'https');
    });

    test('throws on a malformed slug', () {
      expect(() => Famobi.embedUrl('Garden Bloom'),
          throwsA(isA<ArgumentError>()));
    });

    test('derives the teaser URLs Famobi actually serves', () {
      // Expected values were read from each game's og:image tag, so this
      // pins the slug -> PascalCase derivation against the real CDN.
      const expected = <String, String>{
        'garden-bloom': 'GardenBloomTeaser',
        'bubble-woods': 'BubbleWoodsTeaser',
        'onet-connect-classic': 'OnetConnectClassicTeaser',
        'zoo-boom': 'ZooBoomTeaser',
        'solitaire-klondike': 'SolitaireKlondikeTeaser',
        '8-ball-billiards-classic': '8BallBilliardsClassicTeaser',
        'basketball-superstars': 'BasketballSuperstarsTeaser',
        'archery-world-tour': 'ArcheryWorldTourTeaser',
        'fun-race-3d': 'FunRace3dTeaser',
        'tower-crash-3d': 'TowerCrash3dTeaser',
        'moto-x3m-pool-party': 'MotoX3mPoolPartyTeaser',
      };

      expected.forEach((slug, file) {
        expect(
          Famobi.teaserUrl(slug),
          'https://img.cdn.famobi.com/portal/html5games/images/tmp/$file.jpg',
          reason: slug,
        );
      });
    });

    test('recovers a slug from a play URL, with or without partner id', () {
      expect(Famobi.slugFromUrl('https://play.famobi.com/garden-bloom'),
          'garden-bloom');
      expect(Famobi.slugFromUrl('https://play.famobi.com/garden-bloom/A-1000'),
          'garden-bloom');
      expect(Famobi.slugFromUrl('https://example.com/nope'), isNull);
    });
  });

  group('RemoteGameEntry', () {
    const unconfigured = RemoteGameEntry(
      id: 'slot',
      host: GameHost.gameDistribution,
      gameId: 'PASTE_GAMEDISTRIBUTION_ID_HERE',
      title: 'Slot',
      description: '',
      category: GameCategory.arcade,
      rating: 4.0,
    );
    const configured = RemoteGameEntry(
      id: 'real',
      host: GameHost.gameDistribution,
      gameId: '0123456789abcdef0123456789abcdef',
      title: 'Real',
      description: '',
      category: GameCategory.puzzle,
      rating: 4.0,
    );
    const famobiEntry = RemoteGameEntry(
      id: 'garden_bloom',
      host: GameHost.famobi,
      gameId: 'garden-bloom',
      title: 'Garden Bloom',
      description: '',
      category: GameCategory.puzzle,
      rating: 4.5,
    );

    test('validates each provider by its own id format', () {
      expect(famobiEntry.isConfigured, isTrue);
      expect(famobiEntry.embedUrl, contains('play.famobi.com/garden-bloom'));

      // A Famobi slug is not a valid GameDistribution id and vice versa.
      const mismatched = RemoteGameEntry(
        id: 'x',
        host: GameHost.gameDistribution,
        gameId: 'garden-bloom',
        title: 'X',
        description: '',
        category: GameCategory.puzzle,
        rating: 4.0,
      );
      expect(mismatched.isConfigured, isFalse);
    });

    test('every configured Famobi entry builds a valid play URL', () {
      final famobiEntries = GameCatalog.remoteEntries
          .where((e) => e.host == GameHost.famobi)
          .toList();

      // 21 = Garden Bloom + two batches of 10 from html5games.com.
      // Pinned deliberately so an accidental deletion shows up here.
      expect(famobiEntries.length, 21);

      for (final entry in famobiEntries) {
        expect(entry.isConfigured, isTrue, reason: entry.id);
        expect(entry.embedUrl, 'https://play.famobi.com/${entry.gameId}',
            reason: entry.id);
      }
    });

    test('catalog ids and titles are unique across all providers', () {
      final ids = GameCatalog.games.map((g) => g.id).toList();
      final titles = GameCatalog.games.map((g) => g.title).toList();

      expect(ids.toSet().length, ids.length);
      expect(titles.toSet().length, titles.length);
    });

    test('the Sports filter is no longer empty', () {
      expect(
        GameCatalog.games.where((g) => g.category == GameCategory.sports),
        isNotEmpty,
      );
    });

    test('Garden Bloom is present and playable in the shipped catalog', () {
      final game =
          GameCatalog.games.firstWhere((g) => g.id == 'garden_bloom');

      expect(game.title, 'Garden Bloom');
      expect(game.isLocal, isFalse);
      expect(game.playableSource, 'https://play.famobi.com/garden-bloom');
    });

    test('reports whether its provider id has been filled in', () {
      expect(unconfigured.isConfigured, isFalse);
      expect(configured.isConfigured, isTrue);
    });

    test('resolve drops placeholder entries so no broken tile is shown', () {
      final resolved = RemoteGameEntry.resolve([unconfigured, configured]);

      expect(resolved.length, 1);
      expect(resolved.single.id, 'real');
      expect(resolved.single.isLocal, isFalse);
      expect(resolved.single.playableSource, contains('gamedistribution.com'));
    });

    test('the shipped catalog contains no half-configured remote games', () {
      for (final game in GameCatalog.games) {
        expect(game.playableSource, isNot(contains('PASTE_')), reason: game.id);
        expect(game.playableSource, isNot(contains('example.com')),
            reason: game.id);
      }
    });
  });

  group('GameCategory', () {
    test('every category has a non-empty label and emoji', () {
      for (final category in GameCategory.values) {
        expect(category.label, isNotEmpty);
        expect(category.emoji, isNotEmpty);
      }
    });
  });
}
