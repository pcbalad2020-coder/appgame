import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:webview_flutter/webview_flutter.dart';

// =========================================================================
// نقطة انطلاق التطبيق
// =========================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // التسويق لا يجب أن يمنع التطبيق من العمل: مهلة 5 ثوانٍ ثم نكمل.
  try {
    await AdService.instance.initialize().timeout(const Duration(seconds: 5));
  } catch (e, s) {
    debugPrint('AdMob initialization failed, continuing without ads: $e\n$s');
  }

  // تحميل الإعدادات قبل أول إطار حتى لا تومض الشاشة الرئيسية فارغة.
  await SettingsService.instance.load();

  // إعادة جدولة التذكير اليومي عند كل إقلاع، ليطابق نصّه لعبة الغد.
  // لا ننتظره: الإشعارات ميزة كمالية ولا يجوز أن تؤخّر أول إطار.
  if (SettingsService.instance.notificationsEnabled) {
    unawaited(NotificationService.instance.scheduleDailyReminder());
  }

  runApp(const MiniGamesHubApp());
}

class MiniGamesHubApp extends StatefulWidget {
  const MiniGamesHubApp({super.key});

  @override
  State<MiniGamesHubApp> createState() => _MiniGamesHubAppState();
}

class _MiniGamesHubAppState extends State<MiniGamesHubApp>
    with WidgetsBindingObserver {
  bool _isAppReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _showStartupAppOpenAd();
  }

  void _showStartupAppOpenAd() {
    Future.delayed(const Duration(milliseconds: 700), () {
      AdService.instance.showAppOpenAdIfAvailable(
        onComplete: () {
          if (mounted) setState(() => _isAppReady = true);
        },
      );
    });

    // شبكة أمان: لا نحبس المستخدم أكثر من 2.5 ثانية مهما حصل.
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted && !_isAppReady) setState(() => _isAppReady = true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isAppReady) {
      AdService.instance.showAppOpenAdIfAvailable(onComplete: () {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AdService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SettingsService.instance,
      builder: (context, _) => MaterialApp(
        title: 'ألعاب أونلاين مجانية',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(Brightness.light),
        darkTheme: buildAppTheme(Brightness.dark),
        themeMode: SettingsService.instance.themeMode,
        builder: (context, child) {
          final palette = context.palette;
          final iconBrightness =
              palette.isDark ? Brightness.light : Brightness.dark;
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: iconBrightness,
            systemNavigationBarColor: palette.background,
            systemNavigationBarIconBrightness: iconBrightness,
          ));
          // اتجاه الواجهة يتبع اللغة المختارة (RTL للعربية).
          return Directionality(
            textDirection: L.isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _isAppReady
              ? const HomeScreen(key: ValueKey('home'))
              : const _SplashView(key: ValueKey('splash')),
        ),
      ),
    );
  }
}

class _SplashView extends StatefulWidget {
  const _SplashView({super.key});

  @override
  State<_SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<_SplashView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => Transform.scale(
                scale: 0.96 + (_controller.value * 0.06),
                child: child,
              ),
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  gradient: palette.primaryGradient,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: palette.violet.withValues(alpha: 0.45),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: const Icon(Icons.sports_esports_rounded,
                    color: Colors.white, size: 42),
              ),
            ),
            const SizedBox(height: 20),
            ShaderMask(
              shaderCallback: (bounds) =>
                  palette.brandGradient.createShader(bounds),
              child: Text(
                L.appTitle,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// النصوص (عربي / إنجليزي)
// =========================================================================

/// طبقة نصوص خفيفة بدل حزمة ترجمة كاملة، تقرأ اللغة من [SettingsService].
class L {
  const L._();

  static bool get isArabic => SettingsService.instance.isArabic;
  static String _t(String ar, String en) => isArabic ? ar : en;

  static String get appTitle => _t('ألعاب أونلاين مجانية', 'Free Online Games');
  static String gamesReady(int n) =>
      _t('$n لعبة جاهزة للّعب', '$n games ready to play');
  static String get searchHint => _t('ابحث عن لعبة...', 'Search games...');
  static String get all => _t('الكل', 'All');
  static String get play => _t('العب', 'Play');
  static String get continuePlaying => _t('تابع اللعب', 'Continue playing');
  static String get jumpBackIn => _t('ارجع لما توقفت عنده', 'Jump back in');
  static String get featured => _t('المميزة', 'Featured');
  static String get handPicked => _t('مختارة بعناية', 'Hand-picked');
  static String get noGamesFound => _t('لا توجد نتائج', 'No games found');
  static String get noGamesHint => _t(
      'جرّب كلمة أخرى أو أزل الفلتر.', 'Try another word or clear the filter.');
  static String get offline => _t('بدون إنترنت', 'Offline');
  static String gameCount(int n) => isArabic
      ? (n == 1 ? 'لعبة واحدة' : '$n ألعاب')
      : '$n game${n == 1 ? '' : 's'}';

  // الفئات
  static String get puzzle => _t('ألغاز', 'Puzzle');
  static String get action => _t('أكشن', 'Action');
  static String get sports => _t('رياضة', 'Sports');
  static String get arcade => _t('أركيد', 'Arcade');

  // شاشة اللعبة
  static String get loadingGame =>
      _t('جارٍ تحميل اللعبة...', 'Loading game...');
  static String get warmingUp => _t('جارٍ التجهيز...', 'Warming up...');
  static String get loadFailed =>
      _t('تعذّر تحميل اللعبة.', 'This game couldn\'t be loaded.');
  static String get loadFailedHint => _t(
      'حاولنا مرة أخرى تلقائياً ولم تنجح. تحقق من الاتصال ثم أعد المحاولة.',
      'We retried once automatically. Check your connection and try again.');
  static String get retryingAuto =>
      _t('تعذّر التحميل، جارٍ إعادة المحاولة...', 'Load failed — retrying...');
  static String get retry => _t('أعد المحاولة', 'Retry');
  static String get extraLife => _t('حياة إضافية', 'Extra life');
  static String get extraLifeGranted =>
      _t('حصلت على حياة إضافية! 🎉', 'Extra life granted! 🎉');
  static String get adNotReady => _t('الإعلان غير جاهز، حاول بعد قليل.',
      'Reward ad not ready — try again shortly.');

  // الإعدادات
  static String get settings => _t('الإعدادات', 'Settings');
  static String get appearance => _t('المظهر', 'Appearance');
  static String get theme => _t('الثيم', 'Theme');
  static String get light => _t('نهاري', 'Light');
  static String get dark => _t('ليلي', 'Dark');
  static String get system => _t('النظام', 'System');
  static String get language => _t('اللغة', 'Language');
  static String get gameplay => _t('اللعب', 'Gameplay');
  static String get sound => _t('الصوت', 'Sound');
  static String get soundSub => _t('أصوات داخل الألعاب', 'Audio inside games');
  static String get haptics => _t('الاهتزاز', 'Haptics');
  static String get hapticsSub =>
      _t('اهتزاز عند أحداث اللعبة', 'Vibration on game events');
  static String get library => _t('المكتبة', 'Library');
  static String get gamesInstalled => _t('عدد الألعاب', 'Games installed');
  static String get playableOffline =>
      _t('تعمل بدون إنترنت', 'Playable offline');
  static String get clearRecent =>
      _t('مسح آخر ما لعبت', 'Clear recently played');
  static String get nothingToClear => _t('لا يوجد شيء', 'Nothing to clear');
  static String rememberedGames(int n) =>
      isArabic ? 'محفوظ: ${gameCount(n)}' : '$n game${n == 1 ? '' : 's'} saved';
  static String get recentCleared =>
      _t('تم مسح آخر ما لعبت', 'Recently played cleared');
  static String get about => _t('حول التطبيق', 'About');
  static String get version => _t('الإصدار', 'Version');
  static String get privacyPolicy => _t('سياسة الخصوصية', 'Privacy Policy');

  // المفضّلة والأقسام الجديدة
  static String get favorites => _t('مفضّلتي', 'My favorites');
  static String get favoritesSub =>
      _t('الألعاب التي حفظتها', 'Games you saved');
  static String get addedToFavorites =>
      _t('أُضيفت إلى المفضّلة ⭐', 'Added to favorites ⭐');
  static String get removedFromFavorites =>
      _t('أُزيلت من المفضّلة', 'Removed from favorites');
  static String get gameOfTheDay => _t('لعبة اليوم', 'Game of the day');
  static String get gameOfTheDaySub =>
      _t('اختيار جديد كل 24 ساعة', 'A new pick every 24 hours');

  // الترتيب
  static String get sortBy => _t('ترتيب', 'Sort');
  static String get sortDefault => _t('الافتراضي', 'Default');
  static String get sortTopRated => _t('الأعلى تقييماً', 'Top rated');
  static String get sortAlphabetical => _t('أبجدياً', 'A–Z');
  static String get sortMostPlayed => _t('الأكثر لعباً', 'Most played');

  // المهام والعملات
  static String get dailyMissions => _t('المهام اليومية', 'Daily missions');
  static String missionsDone(int done, int total) =>
      _t('أنجزت $done من $total', '$done of $total completed');
  static String get claim => _t('استلم', 'Claim');
  static String get claimed => _t('مُستلمة', 'Claimed');
  static String coinsEarned(int n) =>
      _t('حصلت على $n عملة! 🪙', 'You earned $n coins! 🪙');
  static String get coins => _t('عملات', 'Coins');
  static String get wallet => _t('محفظتي', 'Wallet');
  static String get notEnoughCoins => _t('رصيدك غير كافٍ', 'Not enough coins');
  static String get watchAd => _t('شاهد إعلاناً', 'Watch an ad');
  static String useCoins(int n) => _t('استخدم $n عملة', 'Use $n coins');
  static String get howToEarn => _t(
      'اكسب العملات بإنجاز المهام اليومية ومشاهدة الإعلانات.',
      'Earn coins by completing daily missions and watching ads.');

  // الإحصاءات
  static String get stats => _t('إحصاءاتي', 'My stats');
  static String get statsSub =>
      _t('تقدّمك وسلسلة أيامك', 'Your progress and streak');
  static String get totalPlays => _t('مرات اللعب', 'Total plays');
  static String get playTime => _t('وقت اللعب', 'Play time');
  static String get gamesTried => _t('ألعاب جرّبتها', 'Games tried');
  static String get streak => _t('سلسلة الأيام', 'Day streak');
  static String get bestStreak => _t('أطول سلسلة', 'Best streak');
  static String get mostPlayed => _t('الأكثر لعباً', 'Most played');
  static String get noStatsYet =>
      _t('العب أول لعبة لتبدأ إحصاءاتك.', 'Play a game to start your stats.');
  static String days(int n) => isArabic
      ? (n == 1 ? 'يوم واحد' : (n == 2 ? 'يومان' : '$n أيام'))
      : '$n day${n == 1 ? '' : 's'}';
  static String duration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (isArabic) {
      if (h > 0) return '$h س $m د';
      return '$m دقيقة';
    }
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  static String get resetProgress => _t('مسح كل التقدّم', 'Reset all progress');
  static String get resetProgressSub =>
      _t('المفضّلة والإحصاءات والعملات', 'Favorites, stats and coins');
  static String get resetConfirm => _t(
      'سيُمسح كل شيء ولا يمكن التراجع. هل أنت متأكد؟',
      'Everything will be erased permanently. Are you sure?');
  static String get cancel => _t('إلغاء', 'Cancel');
  static String get confirm => _t('تأكيد', 'Confirm');
  static String get progressReset => _t('تم مسح التقدّم', 'Progress reset');

  // المشاركة والتقييم
  static String get share => _t('مشاركة', 'Share');
  static String shareText(String game) => _t(
      'جرّب لعبة «$game» على تطبيق ${L.appTitle}!',
      'Try "$game" on ${L.appTitle}!');
  static String get rateApp => _t('قيّم التطبيق', 'Rate the app');
  static String get rateAppSub =>
      _t('تقييمك يساعدنا كثيراً', 'Your rating helps a lot');
  static String get ratePrompt => _t(
      'استمتعت باللعب؟ تقييمك في المتجر يساعدنا على الاستمرار.',
      'Enjoying the games? A quick rating really helps us.');
  static String get rateNow => _t('قيّم الآن', 'Rate now');
  static String get later => _t('لاحقاً', 'Later');

  // الإشعارات
  static String get notifications => _t('الإشعارات', 'Notifications');
  static String get notificationsSub => _t(
      'تذكير يومي بلعبة اليوم', 'A daily reminder about the game of the day');
  static String get notificationTitle =>
      _t('لعبة اليوم بانتظارك 🎮', 'Your game of the day is ready 🎮');
  static String notificationBody(String game) =>
      _t('جرّب «$game» الآن!', 'Try "$game" now!');

  // شاشة اللعبة
  static String get rotate => _t('تدوير', 'Rotate');
  static String get noConnection =>
      _t('لا يوجد اتصال بالإنترنت', 'No internet connection');
}

// =========================================================================
// مزوّدو الألعاب عن بُعد
// =========================================================================

enum GameHost { gameDistribution, famobi }

/// روابط GameDistribution — مزوّد يسمح صراحةً بتضمين ألعابه داخل التطبيقات.
class GameDistribution {
  const GameDistribution._();

  static const String host = 'https://html5.gamedistribution.com';

  /// يُرسل كـ `gd_sdk_referrer_url` لنسب المشاهدات إلى حسابك.
  static const String referrerUrl = 'https://minigameshub.app';

  static final RegExp _idPattern = RegExp(r'^[0-9a-f]{32}$');

  static bool isValidId(String gameId) => _idPattern.hasMatch(gameId.trim());

  static String embedUrl(String gameId) {
    final id = gameId.trim();
    if (!isValidId(id)) {
      throw ArgumentError.value(
        gameId,
        'gameId',
        'Expected a 32-character hex GameDistribution id',
      );
    }
    return '$host/$id/?gd_sdk_referrer_url=$referrerUrl';
  }

  static String? idFromUrl(String url) {
    final match =
        RegExp(r'gamedistribution\.com/([0-9a-f]{32})').firstMatch(url);
    return match?.group(1);
  }
}

/// Famobi (Softgames) — يقدّم مشغّلاً مجرداً بلا واجهة بوابة ويسمح بالتضمين.
class Famobi {
  const Famobi._();

  static const String host = 'https://play.famobi.com';

  /// معرّف الشريك — اتركه null حتى تحصل على حساب ناشر.
  static const String? partnerId = null;

  static final RegExp _slugPattern = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

  static bool isValidSlug(String slug) => _slugPattern.hasMatch(slug.trim());

  static String embedUrl(String slug) {
    final cleaned = slug.trim();
    if (!isValidSlug(cleaned)) {
      throw ArgumentError.value(
        slug,
        'slug',
        'Expected a lowercase hyphenated Famobi slug, e.g. garden-bloom',
      );
    }
    const partner = partnerId;
    return partner == null ? '$host/$cleaned' : '$host/$cleaned/$partner';
  }

  static String? slugFromUrl(String url) {
    final match =
        RegExp(r'play\.famobi\.com/([a-z0-9]+(?:-[a-z0-9]+)*)').firstMatch(url);
    return match?.group(1);
  }

  static const String _imageHost = 'https://img.cdn.famobi.com';
  static const String _imagePath = '/portal/html5games/images/tmp';

  /// ألعاب اسم صورتها لا يتبع نمط الـ slug.
  static const Map<String, String> _teaserOverrides = {
    'table-tennis-world-tour': 'TableTennis_WorldTour_Teaser',
  };

  /// الرابط الأساسي (الأرجح) لصورة اللعبة.
  ///
  /// `garden-bloom` → `GardenBloomTeaser.jpg`. الواجهة تستخدم
  /// [artworkCandidates] التي تبدأ بهذا الرابط ثم تجرّب بدائل، لكن هذه
  /// الدالة تبقى للاستخدام المباشر وفي الاختبارات.
  static String teaserUrl(String slug) => artworkCandidates(slug).first;

  /// قائمة روابط مرشّحة لصورة اللعبة، تُجرَّب بالترتيب.
  ///
  /// Famobi ينشر صورة لكل لعبة على مسار مشتق من الـ slug، لكن التسمية
  /// ليست موحّدة 100%. تجربة عدة أنماط ترفع نسبة الألعاب التي تظهر
  /// بصورتها الرسمية، وإن فشلت كلها يظهر غلاف مصمَّم بدل صورة مكسورة.
  static List<String> artworkCandidates(String slug) {
    final cleaned = slug.trim();
    final pascal = _pascalCase(cleaned);
    final names = <String>{
      if (_teaserOverrides[cleaned] != null) _teaserOverrides[cleaned]!,
      '${pascal}Teaser',
      '${pascal}_Teaser',
      pascal,
    };
    return [
      for (final name in names) '$_imageHost$_imagePath/$name.jpg',
      for (final name in names) '$_imageHost$_imagePath/$name.png',
    ];
  }

  /// `moto-x3m-pool-party` → `MotoX3mPoolParty`.
  static String _pascalCase(String slug) => slug
      .split('-')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join();
}

// =========================================================================
// نموذج اللعبة + الكتالوج
// =========================================================================

enum GameCategory { puzzle, action, sports, arcade }

extension GameCategoryLabel on GameCategory {
  String get label {
    switch (this) {
      case GameCategory.puzzle:
        return L.puzzle;
      case GameCategory.action:
        return L.action;
      case GameCategory.sports:
        return L.sports;
      case GameCategory.arcade:
        return L.arcade;
    }
  }

  IconData get icon {
    switch (this) {
      case GameCategory.puzzle:
        return Icons.extension_rounded;
      case GameCategory.action:
        return Icons.bolt_rounded;
      case GameCategory.sports:
        return Icons.sports_soccer_rounded;
      case GameCategory.arcade:
        return Icons.videogame_asset_rounded;
    }
  }

  String get emoji {
    switch (this) {
      case GameCategory.puzzle:
        return '🧩';
      case GameCategory.action:
        return '⚔️';
      case GameCategory.sports:
        return '⚽';
      case GameCategory.arcade:
        return '🕹️';
    }
  }
}

/// لعبة واحدة قابلة للتشغيل.
///
/// تُعتبر «محلية» إذا كان [localAssetPath] موجوداً فتُحمَّل من داخل التطبيق
/// فوراً، وإلا يُستخدم [remoteUrl].
class Game {
  final String id;
  final String title;
  final String description;

  /// صورة مرفقة داخل التطبيق: `assets/thumbnails/<id>.png`.
  final String thumbnailAsset;

  /// روابط صور مرشّحة من مزوّد اللعبة، تُجرَّب بالترتيب قبل الصورة المرفقة.
  final List<String> thumbnailUrls;

  final String? localAssetPath;
  final String? remoteUrl;
  final GameCategory category;
  final double rating;
  final bool isFeatured;

  const Game({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailAsset,
    this.thumbnailUrls = const [],
    this.localAssetPath,
    this.remoteUrl,
    required this.category,
    required this.rating,
    this.isFeatured = false,
  }) : assert(
          localAssetPath != null || remoteUrl != null,
          'A Game must define either localAssetPath or remoteUrl.',
        );

  bool get isLocal => localAssetPath != null && localAssetPath!.isNotEmpty;

  String get playableSource => localAssetPath ?? remoteUrl!;

  /// سلسلة مصادر الصورة: صور المزوّد ثم الصورة المرفقة ثم الغلاف المصمَّم.
  List<String> get artworkSources => [...thumbnailUrls, thumbnailAsset];

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      thumbnailAsset: json['thumbnailAsset'] as String,
      thumbnailUrls:
          (json['thumbnailUrls'] as List?)?.cast<String>() ?? const [],
      localAssetPath: json['localAssetPath'] as String?,
      remoteUrl: json['remoteUrl'] as String?,
      category: GameCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => GameCategory.arcade,
      ),
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      isFeatured: json['isFeatured'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'thumbnailAsset': thumbnailAsset,
        'thumbnailUrls': thumbnailUrls,
        'localAssetPath': localAssetPath,
        'remoteUrl': remoteUrl,
        'category': category.name,
        'rating': rating,
        'isFeatured': isFeatured,
      };
}

/// مدخل لعبة من مزوّد خارجي قبل تحويله إلى [Game].
class RemoteGameEntry {
  final String id;
  final GameHost host;
  final String gameId;
  final String title;
  final String description;
  final GameCategory category;
  final double rating;
  final bool isFeatured;

  /// رابط صورة مخصّص يتجاوز الاشتقاق التلقائي (مفيد لألعاب
  /// GameDistribution التي لا يمكن اشتقاق صورتها).
  final String? artworkUrlOverride;

  const RemoteGameEntry({
    required this.id,
    required this.host,
    required this.gameId,
    required this.title,
    required this.description,
    required this.category,
    required this.rating,
    this.isFeatured = false,
    this.artworkUrlOverride,
  });

  bool get isConfigured {
    switch (host) {
      case GameHost.gameDistribution:
        return GameDistribution.isValidId(gameId);
      case GameHost.famobi:
        return Famobi.isValidSlug(gameId);
    }
  }

  String get embedUrl {
    switch (host) {
      case GameHost.gameDistribution:
        return GameDistribution.embedUrl(gameId);
      case GameHost.famobi:
        return Famobi.embedUrl(gameId);
    }
  }

  List<String> get artworkUrls {
    if (artworkUrlOverride != null) return [artworkUrlOverride!];
    switch (host) {
      case GameHost.famobi:
        return Famobi.artworkCandidates(gameId);
      case GameHost.gameDistribution:
        // GameDistribution لا ينشر الصور على مسار قابل للاشتقاق، لذا
        // انسخ رابط الصورة من لوحة التحكم إلى artworkUrlOverride.
        return const [];
    }
  }

  Game toGame() => Game(
        id: id,
        title: title,
        description: description,
        thumbnailAsset: 'assets/thumbnails/$id.png',
        thumbnailUrls: artworkUrls,
        remoteUrl: embedUrl,
        category: category,
        rating: rating,
        isFeatured: isFeatured,
      );

  static List<Game> resolve(List<RemoteGameEntry> entries) => entries
      .where((entry) => entry.isConfigured)
      .map((entry) => entry.toGame())
      .toList(growable: false);
}

class GameCatalog {
  // =====================================================================
  // أضف الألعاب هنا
  //
  // Famobi           → host: GameHost.famobi
  //   الرابط: https://play.famobi.com/<slug>   |  gameId = الـ slug
  //
  // GameDistribution → host: GameHost.gameDistribution
  //   الرابط: https://html5.gamedistribution.com/<32-hex>/
  //   gameId = المعرّف السداسي، و artworkUrlOverride = رابط الصورة.
  //
  // المدخل الذي لم يُملأ معرّفه يتجاهله resolve، فالتطبيق يبقى يعمل.
  //
  // لا تضع روابط CrazyGames/Poki: تمنع التضمين، واستخدامها يعرّضك
  // لرفض في Google Play ومخالفة في AdMob.
  // =====================================================================
  static const List<RemoteGameEntry> remoteEntries = [
    // --- ألغاز ---
    RemoteGameEntry(
      id: 'garden_bloom',
      host: GameHost.famobi,
      gameId: 'garden-bloom',
      title: 'Garden Bloom',
      description: 'طابق ثلاث زهرات وأعد الحياة إلى الحديقة.',
      category: GameCategory.puzzle,
      rating: 4.5,
      isFeatured: true,
    ),
    RemoteGameEntry(
      id: 'bubble_woods',
      host: GameHost.famobi,
      gameId: 'bubble-woods',
      title: 'Bubble Woods',
      description: 'صوّب وفجّر تجمعات الفقاعات قبل انتهاء الوقت.',
      category: GameCategory.puzzle,
      rating: 4.4,
      isFeatured: true,
    ),
    RemoteGameEntry(
      id: 'onet_connect_classic',
      host: GameHost.famobi,
      gameId: 'onet-connect-classic',
      title: 'Onet Connect Classic',
      description: 'اربط البلاطات المتشابهة قبل نفاد الوقت.',
      category: GameCategory.puzzle,
      rating: 4.3,
    ),
    RemoteGameEntry(
      id: 'zoo_boom',
      host: GameHost.famobi,
      gameId: 'zoo-boom',
      title: 'Zoo Boom',
      description: 'اضغط مجموعات الحيوانات لتفريغ اللوح.',
      category: GameCategory.puzzle,
      rating: 4.2,
    ),
    RemoteGameEntry(
      id: 'solitaire_klondike',
      host: GameHost.famobi,
      gameId: 'solitaire-klondike',
      title: 'Solitaire Klondike',
      description: 'لعبة الورق الكلاسيكية بنسختها الأشهر.',
      category: GameCategory.puzzle,
      rating: 4.5,
    ),
    RemoteGameEntry(
      id: 'bubble_tower_3d',
      host: GameHost.famobi,
      gameId: 'bubble-tower-3d',
      title: 'Bubble Tower 3D',
      description: 'فجّر طريقك نزولاً في برج فقاعات دوّار.',
      category: GameCategory.puzzle,
      rating: 4.3,
    ),
    RemoteGameEntry(
      id: 'element_blocks',
      host: GameHost.famobi,
      gameId: 'element-blocks',
      title: 'Element Blocks',
      description: 'رتّب القوالب المتساقطة لإكمال صفوف كاملة.',
      category: GameCategory.puzzle,
      rating: 4.2,
    ),
    RemoteGameEntry(
      id: 'word_solitaire',
      host: GameHost.famobi,
      gameId: 'word-solitaire',
      title: 'Word Solitaire',
      description: 'كوّن كلمات من الأوراق المعروضة.',
      category: GameCategory.puzzle,
      rating: 4.1,
    ),
    RemoteGameEntry(
      id: 'temple_blocks',
      host: GameHost.famobi,
      gameId: 'temple-blocks',
      title: 'Temple Blocks',
      description: 'حرّك القوالب الحجرية لتفتح طريق المعبد.',
      category: GameCategory.puzzle,
      rating: 4.2,
    ),

    // --- رياضة ---
    RemoteGameEntry(
      id: 'billiards_classic',
      host: GameHost.famobi,
      gameId: '8-ball-billiards-classic',
      title: '8 Ball Billiards Classic',
      description: 'صوّب بدقة وأنزل الكرة رقم 8.',
      category: GameCategory.sports,
      rating: 4.4,
      isFeatured: true,
    ),
    RemoteGameEntry(
      id: 'basketball_superstars',
      host: GameHost.famobi,
      gameId: 'basketball-superstars',
      title: 'Basketball Superstars',
      description: 'مواجهات كرة سلة سريعة بأسلوب أركيد.',
      category: GameCategory.sports,
      rating: 4.3,
    ),
    RemoteGameEntry(
      id: 'archery_world_tour',
      host: GameHost.famobi,
      gameId: 'archery-world-tour',
      title: 'Archery World Tour',
      description: 'احسب الرياح وأصب المنتصف.',
      category: GameCategory.sports,
      rating: 4.2,
    ),
    RemoteGameEntry(
      id: 'table_tennis_world_tour',
      host: GameHost.famobi,
      gameId: 'table-tennis-world-tour',
      title: 'Table Tennis World Tour',
      description: 'جولة عالمية في كرة الطاولة.',
      category: GameCategory.sports,
      rating: 4.3,
    ),
    RemoteGameEntry(
      id: 'free_kick_3d',
      host: GameHost.famobi,
      gameId: '3d-free-kick',
      title: '3D Free Kick',
      description: 'لفّ الكرة فوق الحائط وسجّل.',
      category: GameCategory.sports,
      rating: 4.1,
    ),

    // --- أركيد وأكشن ---
    RemoteGameEntry(
      id: 'fun_race_3d',
      host: GameHost.famobi,
      gameId: 'fun-race-3d',
      title: 'Fun Race 3D',
      description: 'اجتز الحواجز واسبق منافسك.',
      category: GameCategory.arcade,
      rating: 4.5,
    ),
    RemoteGameEntry(
      id: 'tower_crash_3d',
      host: GameHost.famobi,
      gameId: 'tower-crash-3d',
      title: 'Tower Crash 3D',
      description: 'أسقط الأبراج بتصويب محسوب.',
      category: GameCategory.arcade,
      rating: 4.1,
    ),
    RemoteGameEntry(
      id: 'bouncemasters',
      host: GameHost.famobi,
      gameId: 'bouncemasters',
      title: 'Bouncemasters',
      description: 'اقذف واقفز لأبعد مسافة ممكنة.',
      category: GameCategory.arcade,
      rating: 4.4,
    ),
    RemoteGameEntry(
      id: 'jelly_run_2048',
      host: GameHost.famobi,
      gameId: 'jelly-run-2048',
      title: 'Jelly Run 2048',
      description: 'ادمج الأرقام وأنت تركض بين العقبات.',
      category: GameCategory.arcade,
      rating: 4.3,
      isFeatured: true,
    ),
    RemoteGameEntry(
      id: 'moto_x3m_pool_party',
      host: GameHost.famobi,
      gameId: 'moto-x3m-pool-party',
      title: 'Moto X3M Pool Party',
      description: 'سباق دراجات وحركات بهلوانية حول المسبح.',
      category: GameCategory.action,
      rating: 4.6,
      isFeatured: true,
    ),
    RemoteGameEntry(
      id: 'om_nom_run',
      host: GameHost.famobi,
      gameId: 'om-nom-run',
      title: 'Om Nom Run',
      description: 'اركض، تفادَ، واجمع في جري لا ينتهي.',
      category: GameCategory.action,
      rating: 4.5,
    ),
    RemoteGameEntry(
      id: 'cannon_balls_3d',
      host: GameHost.famobi,
      gameId: 'cannon-balls-3d',
      title: 'Cannon Balls 3D',
      description: 'دمّر المباني بقذائف المدفعية.',
      category: GameCategory.action,
      rating: 4.2,
    ),

    // --- دفعة إضافية من html5games.com (بوابة Famobi الرسمية) ---
    RemoteGameEntry(
      id: 'totemia_cursed_marbles',
      host: GameHost.famobi,
      gameId: 'totemia-cursed-marbles',
      title: 'Totemia: Cursed Marbles',
      description: 'صوّب على الكرات الملوّنة وأوقف اللعنة قبل أن تصل النهاية.',
      category: GameCategory.puzzle,
      rating: 4.5,
      isFeatured: true,
    ),
    RemoteGameEntry(
      id: 'cut_the_rope_2',
      host: GameHost.famobi,
      gameId: 'cut-the-rope-2',
      title: 'Cut The Rope 2',
      description: 'اقطع الحبال وأوصل الحلوى إلى أوم نوم.',
      category: GameCategory.puzzle,
      rating: 4.7,
    ),
    RemoteGameEntry(
      id: 'parking_jam',
      host: GameHost.famobi,
      gameId: 'parking-jam',
      title: 'Parking Jam',
      description: 'أخرج السيارات من الموقف بالترتيب الصحيح.',
      category: GameCategory.puzzle,
      rating: 4.4,
    ),
    RemoteGameEntry(
      id: 'mahjong_classic',
      host: GameHost.famobi,
      gameId: 'mahjong-classic',
      title: 'Mahjong Classic',
      description: 'أزل البلاطات المتطابقة حتى يخلو اللوح.',
      category: GameCategory.puzzle,
      rating: 4.3,
    ),
    RemoteGameEntry(
      id: 'penalty_shooters_2',
      host: GameHost.famobi,
      gameId: 'penalty-shooters-2',
      title: 'Penalty Shooters 2',
      description: 'سدّد وتصدَّ في مواجهات ركلات الترجيح.',
      category: GameCategory.sports,
      rating: 4.5,
    ),
    RemoteGameEntry(
      id: 'curve_ball_3d',
      host: GameHost.famobi,
      gameId: 'curve-ball-3d',
      title: 'Curve Ball 3D',
      description: 'تنس ثلاثي الأبعاد بسرعة تتصاعد مع كل ضربة.',
      category: GameCategory.sports,
      rating: 4.2,
    ),
    RemoteGameEntry(
      id: 'hoop_royale',
      host: GameHost.famobi,
      gameId: 'hoop-royale',
      title: 'Hoop Royale',
      description: 'حرّك السلة بدل الكرة وسجّل بأصعب الزوايا.',
      category: GameCategory.sports,
      rating: 4.1,
    ),
    RemoteGameEntry(
      id: 'cars_arena',
      host: GameHost.famobi,
      gameId: 'cars-arena',
      title: 'Cars Arena',
      description: 'اصطدم بخصومك وكن آخر سيارة صامدة.',
      category: GameCategory.arcade,
      rating: 4.3,
    ),
    RemoteGameEntry(
      id: 'stack_smash',
      host: GameHost.famobi,
      gameId: 'stack-smash',
      title: 'Stack Smash',
      description: 'حطّم الطبقات في طريقك نزولاً إلى القاع.',
      category: GameCategory.arcade,
      rating: 4.2,
    ),
    RemoteGameEntry(
      id: 'gun_spin',
      host: GameHost.famobi,
      gameId: 'gun-spin',
      title: 'Gun Spin',
      description: 'استخدم الارتداد لتطير أبعد ما يمكن.',
      category: GameCategory.action,
      rating: 4.4,
    ),

    // --- دفعة ثالثة من html5games.com ---
    RemoteGameEntry(
      id: 'smarty_bubbles',
      host: GameHost.famobi,
      gameId: 'smarty-bubbles',
      title: 'Smarty Bubbles',
      description: 'قنّاص الفقاعات الكلاسيكي بأسلوبه الأصلي.',
      category: GameCategory.puzzle,
      rating: 4.4,
    ),
    RemoteGameEntry(
      id: 'game_2048',
      host: GameHost.famobi,
      gameId: '2048',
      title: '2048',
      description: 'ادمج الأرقام حتى تصل إلى البلاطة 2048.',
      category: GameCategory.puzzle,
      rating: 4.5,
    ),
    RemoteGameEntry(
      id: 'sudoku_classic',
      host: GameHost.famobi,
      gameId: 'sudoku-classic',
      title: 'Sudoku Classic',
      description: 'سودوكو بأربع مستويات صعوبة.',
      category: GameCategory.puzzle,
      rating: 4.2,
    ),
    RemoteGameEntry(
      id: 'chess_classic',
      host: GameHost.famobi,
      gameId: 'chess-classic',
      title: 'Chess Classic',
      description: 'شطرنج ضد الحاسوب بمستويات متدرّجة.',
      category: GameCategory.puzzle,
      rating: 4.3,
    ),
    RemoteGameEntry(
      id: 'bowling_3d',
      host: GameHost.famobi,
      gameId: '3d-bowling',
      title: '3D Bowling',
      description: 'اضبط الزاوية والقوة وأسقط كل القوارير.',
      category: GameCategory.sports,
      rating: 4.2,
    ),
    RemoteGameEntry(
      id: 'slam_dunk_basketball',
      host: GameHost.famobi,
      gameId: 'slam-dunk-basketball',
      title: 'Slam Dunk Basketball',
      description: 'ارمِ الكرة في السلة قبل انتهاء الوقت.',
      category: GameCategory.sports,
      rating: 4.1,
    ),
    RemoteGameEntry(
      id: 'goalkeeper_champ',
      host: GameHost.famobi,
      gameId: 'goalkeeper-champ',
      title: 'Goalkeeper Champ',
      description: 'تصدَّ للتسديدات وكن حارس المرمى البطل.',
      category: GameCategory.sports,
      rating: 4.3,
    ),
    RemoteGameEntry(
      id: 'moto_x3m',
      host: GameHost.famobi,
      gameId: 'moto-x3m',
      title: 'Moto X3M',
      description: 'النسخة الأصلية من سباق الدراجات البهلواني.',
      category: GameCategory.action,
      rating: 4.7,
      isFeatured: true,
    ),
    RemoteGameEntry(
      id: 'slope',
      host: GameHost.famobi,
      gameId: 'slope',
      title: 'Slope',
      description: 'وجّه الكرة في منحدر لا نهائي متسارع.',
      category: GameCategory.arcade,
      rating: 4.5,
    ),
    RemoteGameEntry(
      id: 'color_tunnel',
      host: GameHost.famobi,
      gameId: 'color-tunnel',
      title: 'Color Tunnel',
      description: 'اندفع في نفق ملوّن وتفادَ العوائق.',
      category: GameCategory.arcade,
      rating: 4.3,
    ),

    // --- دفعة رابعة من html5games.com ---
    RemoteGameEntry(
      id: 'om_nom_bubbles',
      host: GameHost.famobi,
      gameId: 'om-nom-bubbles',
      title: 'Om Nom Bubbles',
      description: 'ساعد أوم نوم على تفجير الحلوى الملوّنة.',
      category: GameCategory.puzzle,
      rating: 4.4,
    ),
    RemoteGameEntry(
      id: 'thief_puzzle',
      host: GameHost.famobi,
      gameId: 'thief-puzzle',
      title: 'Thief Puzzle',
      description: 'اسحب الدبابيس بالترتيب الصحيح واسرق الكنز.',
      category: GameCategory.puzzle,
      rating: 4.2,
    ),
    RemoteGameEntry(
      id: 'euro_penalty_cup_2021',
      host: GameHost.famobi,
      gameId: 'euro-penalty-cup-2021',
      title: 'Euro Penalty Cup 2021',
      description: 'خض بطولة ركلات الجزاء الأوروبية.',
      category: GameCategory.sports,
      rating: 4.3,
    ),
    RemoteGameEntry(
      id: 'street_hoops_3d',
      host: GameHost.famobi,
      gameId: 'street-hoops-3d',
      title: 'Street Hoops 3D',
      description: 'كرة سلة الشوارع بثلاثة أبعاد.',
      category: GameCategory.sports,
      rating: 4.2,
    ),
    RemoteGameEntry(
      id: 'train_miner',
      host: GameHost.famobi,
      gameId: 'train-miner',
      title: 'Train Miner',
      description: 'وسّع قطارك واحفر طريقك نحو المناجم.',
      category: GameCategory.arcade,
      rating: 4.5,
      isFeatured: true,
    ),
    RemoteGameEntry(
      id: 'color_fill_3d',
      host: GameHost.famobi,
      gameId: 'color-fill-3d',
      title: 'Color Fill 3D',
      description: 'لوّن كامل المساحة دون أن يمسّك الخصم.',
      category: GameCategory.arcade,
      rating: 4.3,
    ),
    RemoteGameEntry(
      id: 'drift_cup_racing',
      host: GameHost.famobi,
      gameId: 'drift-cup-racing',
      title: 'Drift Cup Racing',
      description: 'انحرف في المنعطفات واحصد كأس البطولة.',
      category: GameCategory.arcade,
      rating: 4.2,
    ),
    RemoteGameEntry(
      id: 'giant_rush',
      host: GameHost.famobi,
      gameId: 'giant-rush',
      title: 'Giant Rush',
      description: 'اجمع الكتل، كبِّر حجمك، واهزم العملاق.',
      category: GameCategory.action,
      rating: 4.5,
    ),
    RemoteGameEntry(
      id: 'knife_rain',
      host: GameHost.famobi,
      gameId: 'knife-rain',
      title: 'Knife Rain',
      description: 'اغرس السكاكين في الهدف الدوّار دون أن تصطدم.',
      category: GameCategory.action,
      rating: 4.1,
    ),

    // قالب GameDistribution — الصق المعرّف ورابط الصورة ليظهر في القائمة.
    // RemoteGameEntry(
    //   id: 'gd_slot_1',
    //   host: GameHost.gameDistribution,
    //   gameId: 'ضع-المعرّف-السداسي-هنا',
    //   artworkUrlOverride: 'https://.../cover.jpg',
    //   title: 'Game Slot 1',
    //   description: '...',
    //   category: GameCategory.arcade,
    //   rating: 4.5,
    // ),
  ];

  /// الألعاب المدمجة داخل التطبيق (تعمل بلا إنترنت).
  ///
  /// فارغة حالياً: الألعاب الثلاث السابقة (Puzzle Blocks / Space Shooter /
  /// Arcade Runner) حُذفت لأنها بلا صور وبلا ملفات لعب في assets، فكانت
  /// تظهر بغلاف بديل ثم تفشل عند التشغيل. أضف لعبة هنا فقط بعد وضع
  /// ملفاتها في assets/games/<id>/ وصورتها في assets/thumbnails/<id>.png.
  static const List<Game> bundledGames = [];

  /// ما تعرضه الشاشة الرئيسية: المدمجة أولاً ثم ألعاب المزوّدين.
  static final List<Game> games = [
    ...bundledGames,
    ...RemoteGameEntry.resolve(remoteEntries),
  ];

  static List<Game> get featured =>
      games.where((g) => g.isFeatured).toList(growable: false);

  static List<Game> byCategory(GameCategory category) =>
      games.where((g) => g.category == category).toList(growable: false);

  static Game? byId(String id) {
    for (final game in games) {
      if (game.id == id) return game;
    }
    return null;
  }

  /// لعبة اليوم — اختيار ثابت طوال اليوم ومختلف كل يوم.
  ///
  /// مشتق من التاريخ لا من عشوائية حقيقية، حتى يرى المستخدم نفس اللعبة
  /// كلما فتح التطبيق في اليوم ذاته، وحتى يتطابق ما يظهر في الشاشة مع ما
  /// يذكره الإشعار اليومي دون الحاجة لتخزين الاختيار.
  static Game gameOfTheDay([DateTime? at]) {
    final d = at ?? DateTime.now();
    final seed = d.year * 10000 + d.month * 100 + d.day;
    return games[seed % games.length];
  }

  /// يرتّب نسخة من [list] حسب [sort] دون المساس بالأصل.
  static List<Game> sorted(List<Game> list, GameSort sort) {
    final out = [...list];
    switch (sort) {
      case GameSort.defaultOrder:
        break;
      case GameSort.topRated:
        out.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case GameSort.alphabetical:
        out.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case GameSort.mostPlayed:
        final s = SettingsService.instance;
        out.sort((a, b) {
          final diff = s.playCountOf(b.id).compareTo(s.playCountOf(a.id));
          return diff != 0 ? diff : b.rating.compareTo(a.rating);
        });
        break;
    }
    return out;
  }
}

// =========================================================================
// إدارة إعلانات AdMob
// =========================================================================

/// مدير إعلانات مركزي: كل صيغة إعلان تُحمَّل مسبقاً في الخلفية حتى تظهر
/// فوراً عند الحاجة، ثم يُعاد تحميلها مباشرة بعد العرض.
class AdService {
  AdService._internal();
  static final AdService instance = AdService._internal();

  // ---------------------------------------------------------------------
  // معرّفات اختبار رسمية من Google. استبدلها بمعرّفاتك قبل النشر.
  // ---------------------------------------------------------------------
  static const String appOpenAdUnitId =
      'ca-app-pub-3940256099942544/9257390401';
  static const String bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String interstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String rewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  AppOpenAd? _appOpenAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  bool _isShowingAppOpenAd = false;
  bool _isLoadingAppOpenAd = false;
  bool _isLoadingInterstitial = false;
  bool _isLoadingRewarded = false;

  DateTime? _appOpenLoadTime;
  static const Duration _appOpenAdMaxCacheDuration = Duration(hours: 4);

  DateTime? _lastInterstitialShownAt;
  int _gamesPlayedSinceLastInterstitial = 0;
  static const int _interstitialMinGamesBetweenAds = 1;
  static const Duration _interstitialMinInterval = Duration(seconds: 45);

  int _appOpenRetryAttempt = 0;
  int _interstitialRetryAttempt = 0;
  int _rewardedRetryAttempt = 0;
  static const int _maxRetryAttempts = 4;

  Timer? _appOpenRetryTimer;
  Timer? _interstitialRetryTimer;
  Timer? _rewardedRetryTimer;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    preloadAppOpenAd();
    preloadInterstitialAd();
    preloadRewardedAd();
  }

  // ------------------------- App Open -------------------------
  void preloadAppOpenAd() {
    if (_isLoadingAppOpenAd || isAppOpenAdReady) return;
    _isLoadingAppOpenAd = true;
    AppOpenAd.load(
      adUnitId: appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _appOpenLoadTime = DateTime.now();
          _isLoadingAppOpenAd = false;
          _appOpenRetryAttempt = 0;
        },
        onAdFailedToLoad: (error) {
          _isLoadingAppOpenAd = false;
          _scheduleRetry(
            attempt: _appOpenRetryAttempt++,
            timerSetter: (t) => _appOpenRetryTimer = t,
            loadFn: preloadAppOpenAd,
          );
        },
      ),
    );
  }

  bool get isAppOpenAdReady {
    if (_appOpenAd == null || _appOpenLoadTime == null) return false;
    final expired = DateTime.now().difference(_appOpenLoadTime!) >
        _appOpenAdMaxCacheDuration;
    if (expired) {
      _appOpenAd?.dispose();
      _appOpenAd = null;
      return false;
    }
    return true;
  }

  void showAppOpenAdIfAvailable({required VoidCallback onComplete}) {
    if (_isShowingAppOpenAd || !isAppOpenAdReady) {
      onComplete();
      preloadAppOpenAd();
      return;
    }

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => _isShowingAppOpenAd = true,
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isShowingAppOpenAd = false;
        ad.dispose();
        _appOpenAd = null;
        preloadAppOpenAd();
        onComplete();
      },
      onAdDismissedFullScreenContent: (ad) {
        _isShowingAppOpenAd = false;
        ad.dispose();
        _appOpenAd = null;
        preloadAppOpenAd();
        onComplete();
      },
    );
    _appOpenAd!.show();
  }

  // ------------------------- Interstitial -------------------------
  void preloadInterstitialAd() {
    if (_isLoadingInterstitial || _interstitialAd != null) return;
    _isLoadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isLoadingInterstitial = false;
          _interstitialRetryAttempt = 0;
        },
        onAdFailedToLoad: (error) {
          _isLoadingInterstitial = false;
          _scheduleRetry(
            attempt: _interstitialRetryAttempt++,
            timerSetter: (t) => _interstitialRetryTimer = t,
            loadFn: preloadInterstitialAd,
          );
        },
      ),
    );
  }

  void notifyGameSessionEnded() => _gamesPlayedSinceLastInterstitial++;

  bool get _passesFrequencyCap {
    if (_gamesPlayedSinceLastInterstitial < _interstitialMinGamesBetweenAds) {
      return false;
    }
    if (_lastInterstitialShownAt != null &&
        DateTime.now().difference(_lastInterstitialShownAt!) <
            _interstitialMinInterval) {
      return false;
    }
    return true;
  }

  void showInterstitialOnGameExit({required VoidCallback onComplete}) {
    notifyGameSessionEnded();

    if (_interstitialAd == null || !_passesFrequencyCap) {
      onComplete();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        preloadInterstitialAd();
        onComplete();
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _lastInterstitialShownAt = DateTime.now();
        _gamesPlayedSinceLastInterstitial = 0;
        preloadInterstitialAd();
        onComplete();
      },
    );
    _interstitialAd!.show();
  }

  // ------------------------- Rewarded -------------------------
  void preloadRewardedAd() {
    if (_isLoadingRewarded || _rewardedAd != null) return;
    _isLoadingRewarded = true;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoadingRewarded = false;
          _rewardedRetryAttempt = 0;
        },
        onAdFailedToLoad: (error) {
          _isLoadingRewarded = false;
          _scheduleRetry(
            attempt: _rewardedRetryAttempt++,
            timerSetter: (t) => _rewardedRetryTimer = t,
            loadFn: preloadRewardedAd,
          );
        },
      ),
    );
  }

  bool get isRewardedAdReady => _rewardedAd != null;

  void showRewardedAd({
    required void Function(RewardItem reward) onUserEarnedReward,
    VoidCallback? onAdUnavailable,
    VoidCallback? onDismissed,
  }) {
    if (_rewardedAd == null) {
      onAdUnavailable?.call();
      preloadRewardedAd();
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        preloadRewardedAd();
        onDismissed?.call();
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        preloadRewardedAd();
        onDismissed?.call();
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) => onUserEarnedReward(reward),
    );
  }

  // ------------------------- Banner -------------------------
  BannerAd createBannerAd({
    required VoidCallback onLoaded,
    required void Function(LoadAdError error) onFailed,
    AdSize size = AdSize.banner,
  }) {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded(),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          onFailed(error);
        },
      ),
    )..load();
  }

  // ------------------------- إعادة المحاولة -------------------------
  void _scheduleRetry({
    required int attempt,
    required void Function(Timer) timerSetter,
    required VoidCallback loadFn,
  }) {
    if (attempt >= _maxRetryAttempts) return;
    final backoffSeconds = 2 << attempt; // 2s, 4s, 8s, 16s
    timerSetter(Timer(Duration(seconds: backoffSeconds), loadFn));
  }

  void dispose() {
    _appOpenRetryTimer?.cancel();
    _interstitialRetryTimer?.cancel();
    _rewardedRetryTimer?.cancel();

    _appOpenAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();

    _appOpenAd = null;
    _interstitialAd = null;
    _rewardedAd = null;
  }
}

// =========================================================================
// الإعدادات المحفوظة
// =========================================================================

/// طريقة ترتيب شبكة النتائج.
enum GameSort { defaultOrder, topRated, alphabetical, mostPlayed }

/// مهمة يومية واحدة.
class Mission {
  final String id;
  final int target;
  final int reward;
  const Mission({required this.id, required this.target, required this.reward});

  String get title {
    switch (id) {
      case 'play_3':
        return L.isArabic ? 'العب 3 ألعاب اليوم' : 'Play 3 games today';
      case 'try_new':
        return L.isArabic
            ? 'جرّب لعبة لم تلعبها'
            : 'Try a game you haven\'t played';
      case 'play_5min':
        return L.isArabic ? 'العب 5 دقائق' : 'Play for 5 minutes';
      default:
        return id;
    }
  }

  IconData get icon {
    switch (id) {
      case 'play_3':
        return Icons.sports_esports_rounded;
      case 'try_new':
        return Icons.explore_rounded;
      case 'play_5min':
        return Icons.timer_rounded;
      default:
        return Icons.task_alt_rounded;
    }
  }
}

/// تفضيلات المستخدم + تقدّمه، محفوظة على الجهاز.
///
/// [ChangeNotifier] واحد يملك كل الحالة المستمرة: الإعدادات، المفضّلة،
/// الإحصاءات، العملات، والمهام اليومية. جعلها خدمة واحدة يبقي الشاشات
/// متزامنة بلا أن تملك أي منها الحالة.
class SettingsService extends ChangeNotifier {
  SettingsService._internal();
  static final SettingsService instance = SettingsService._internal();

  static const _kSound = 'settings.sound';
  static const _kHaptics = 'settings.haptics';
  static const _kRecent = 'settings.recentGameIds';
  static const _kThemeMode = 'settings.themeMode';
  static const _kLanguage = 'settings.language';
  static const _kFavorites = 'settings.favoriteIds';
  static const _kSort = 'settings.sortMode';
  static const _kPlayCounts = 'stats.playCounts';
  static const _kPlaySeconds = 'stats.totalSeconds';
  static const _kStreakDays = 'stats.streakDays';
  static const _kStreakBest = 'stats.streakBest';
  static const _kLastPlayDay = 'stats.lastPlayDay';
  static const _kCoins = 'wallet.coins';
  static const _kMissionDay = 'missions.day';
  static const _kMissionProgress = 'missions.progress';
  static const _kMissionClaimed = 'missions.claimed';
  static const _kMissionNewGames = 'missions.newGameIds';
  static const _kLaunchCount = 'app.launchCount';
  static const _kRateDone = 'app.rateDone';
  static const _kNotifications = 'app.notifications';

  static const int maxRecent = 8;

  /// المهام اليومية الثابتة. تُصفَّر تلقائياً مع كل يوم جديد.
  static const List<Mission> missions = [
    Mission(id: 'play_3', target: 3, reward: 25),
    Mission(id: 'try_new', target: 1, reward: 30),
    Mission(id: 'play_5min', target: 300, reward: 35),
  ];

  SharedPreferences? _prefs;

  bool _soundEnabled = true;
  bool _hapticsEnabled = true;
  List<String> _recentGameIds = const [];
  ThemeMode _themeMode = ThemeMode.system;
  String _languageCode = 'ar';
  List<String> _favoriteIds = const [];
  GameSort _sort = GameSort.defaultOrder;

  Map<String, int> _playCounts = {};
  int _totalPlaySeconds = 0;
  int _streakDays = 0;
  int _bestStreak = 0;
  String _lastPlayDay = '';

  int _coins = 0;

  String _missionDay = '';
  Map<String, int> _missionProgress = {};
  List<String> _missionClaimed = const [];
  List<String> _missionNewGameIds = const [];

  int _launchCount = 0;
  bool _rateDone = false;
  bool _notificationsEnabled = false;

  // ---------------------------- getters ----------------------------
  bool get soundEnabled => _soundEnabled;
  bool get hapticsEnabled => _hapticsEnabled;
  List<String> get recentGameIds => List.unmodifiable(_recentGameIds);
  ThemeMode get themeMode => _themeMode;
  String get languageCode => _languageCode;
  bool get isArabic => _languageCode == 'ar';
  List<String> get favoriteIds => List.unmodifiable(_favoriteIds);
  GameSort get sort => _sort;
  int get coins => _coins;
  int get streakDays => _streakDays;
  int get bestStreak => _bestStreak;
  int get totalPlaySeconds => _totalPlaySeconds;
  int get totalPlays => _playCounts.values.fold(0, (a, b) => a + b);
  int get distinctGamesPlayed => _playCounts.length;
  bool get notificationsEnabled => _notificationsEnabled;
  int get launchCount => _launchCount;
  bool get rateDone => _rateDone;

  bool isFavorite(String gameId) => _favoriteIds.contains(gameId);
  int playCountOf(String gameId) => _playCounts[gameId] ?? 0;

  /// اللعبة الأكثر لعباً، أو null إن لم يُلعب شيء بعد.
  String? get mostPlayedId {
    if (_playCounts.isEmpty) return null;
    return _playCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  // ---------------------------- التحميل ----------------------------
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      _soundEnabled = prefs.getBool(_kSound) ?? true;
      _hapticsEnabled = prefs.getBool(_kHaptics) ?? true;
      _recentGameIds = prefs.getStringList(_kRecent) ?? const [];
      _themeMode = _decodeThemeMode(prefs.getString(_kThemeMode));
      _languageCode = prefs.getString(_kLanguage) ?? 'ar';
      _favoriteIds = prefs.getStringList(_kFavorites) ?? const [];
      _sort = GameSort.values.firstWhere(
        (s) => s.name == prefs.getString(_kSort),
        orElse: () => GameSort.defaultOrder,
      );
      _playCounts = _decodeCounts(prefs.getStringList(_kPlayCounts));
      _totalPlaySeconds = prefs.getInt(_kPlaySeconds) ?? 0;
      _streakDays = prefs.getInt(_kStreakDays) ?? 0;
      _bestStreak = prefs.getInt(_kStreakBest) ?? 0;
      _lastPlayDay = prefs.getString(_kLastPlayDay) ?? '';
      _coins = prefs.getInt(_kCoins) ?? 0;
      _missionDay = prefs.getString(_kMissionDay) ?? '';
      _missionProgress = _decodeCounts(prefs.getStringList(_kMissionProgress));
      _missionClaimed = prefs.getStringList(_kMissionClaimed) ?? const [];
      _missionNewGameIds = prefs.getStringList(_kMissionNewGames) ?? const [];
      _notificationsEnabled = prefs.getBool(_kNotifications) ?? false;
      _rateDone = prefs.getBool(_kRateDone) ?? false;
      _launchCount = (prefs.getInt(_kLaunchCount) ?? 0) + 1;
      await prefs.setInt(_kLaunchCount, _launchCount);

      _rolloverMissionsIfNeeded();
      _breakStreakIfStale();
      notifyListeners();
    } catch (e) {
      debugPrint('SettingsService.load failed, using defaults: $e');
    }
  }

  /// الخريطة تُخزَّن كقائمة نصوص "key=value" لأن SharedPreferences لا
  /// يدعم الخرائط مباشرة.
  static Map<String, int> _decodeCounts(List<String>? raw) {
    final map = <String, int>{};
    for (final entry in raw ?? const <String>[]) {
      final i = entry.lastIndexOf('=');
      if (i <= 0) continue;
      final value = int.tryParse(entry.substring(i + 1));
      if (value != null) map[entry.substring(0, i)] = value;
    }
    return map;
  }

  static List<String> _encodeCounts(Map<String, int> map) =>
      map.entries.map((e) => '${e.key}=${e.value}').toList();

  static String _dayKey([DateTime? at]) {
    final d = at ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  // ---------------------------- الإعدادات ----------------------------
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _prefs?.setString(_kThemeMode, mode.name);
  }

  /// تبديل سريع بين النهاري والليلي من الشريط العلوي.
  Future<void> toggleBrightness(Brightness current) async {
    await setThemeMode(
      current == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }

  Future<void> setLanguage(String code) async {
    if (_languageCode == code) return;
    _languageCode = code;
    notifyListeners();
    await _prefs?.setString(_kLanguage, code);
  }

  static ThemeMode _decodeThemeMode(String? stored) {
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setSoundEnabled(bool value) async {
    if (_soundEnabled == value) return;
    _soundEnabled = value;
    notifyListeners();
    await _prefs?.setBool(_kSound, value);
  }

  Future<void> setHapticsEnabled(bool value) async {
    if (_hapticsEnabled == value) return;
    _hapticsEnabled = value;
    notifyListeners();
    await _prefs?.setBool(_kHaptics, value);
  }

  Future<void> setSort(GameSort value) async {
    if (_sort == value) return;
    _sort = value;
    notifyListeners();
    await _prefs?.setString(_kSort, value.name);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    if (_notificationsEnabled == value) return;
    _notificationsEnabled = value;
    notifyListeners();
    await _prefs?.setBool(_kNotifications, value);
  }

  Future<void> markRateDone() async {
    _rateDone = true;
    await _prefs?.setBool(_kRateDone, true);
  }

  // ---------------------------- المفضّلة ----------------------------
  Future<bool> toggleFavorite(String gameId) async {
    final adding = !_favoriteIds.contains(gameId);
    _favoriteIds = adding
        ? [gameId, ..._favoriteIds]
        : _favoriteIds.where((id) => id != gameId).toList();
    notifyListeners();
    await _prefs?.setStringList(_kFavorites, _favoriteIds);
    return adding;
  }

  // ---------------------------- آخر ما لُعب ----------------------------
  Future<void> markPlayed(String gameId) async {
    final updated = <String>[
      gameId,
      ..._recentGameIds.where((id) => id != gameId),
    ];
    if (updated.length > maxRecent) {
      updated.removeRange(maxRecent, updated.length);
    }
    _recentGameIds = updated;

    // مهمة "جرّب لعبة جديدة": تحتسب فقط لعبة لم تُفتح من قبل إطلاقاً.
    final isNewGame = !_playCounts.containsKey(gameId);
    _playCounts[gameId] = (_playCounts[gameId] ?? 0) + 1;

    _rolloverMissionsIfNeeded();
    _bumpMission('play_3', 1);
    if (isNewGame && !_missionNewGameIds.contains(gameId)) {
      _missionNewGameIds = [..._missionNewGameIds, gameId];
      _bumpMission('try_new', 1);
    }

    _touchStreak();

    notifyListeners();
    await _prefs?.setStringList(_kRecent, updated);
    await _prefs?.setStringList(_kPlayCounts, _encodeCounts(_playCounts));
    await _prefs?.setStringList(_kMissionNewGames, _missionNewGameIds);
    await _persistMissions();
  }

  Future<void> clearRecent() async {
    if (_recentGameIds.isEmpty) return;
    _recentGameIds = const [];
    notifyListeners();
    await _prefs?.setStringList(_kRecent, const []);
  }

  // ---------------------------- الوقت والسلسلة ----------------------------
  /// تُستدعى عند الخروج من لعبة بمدة الجلسة.
  Future<void> addPlayTime(Duration duration) async {
    final seconds = duration.inSeconds;
    if (seconds <= 0) return;
    _totalPlaySeconds += seconds;
    _rolloverMissionsIfNeeded();
    _bumpMission('play_5min', seconds);
    notifyListeners();
    await _prefs?.setInt(_kPlaySeconds, _totalPlaySeconds);
    await _persistMissions();
  }

  /// يزيد السلسلة يوماً واحداً فقط عند أول لعب في يوم جديد.
  void _touchStreak() {
    final today = _dayKey();
    if (_lastPlayDay == today) return;

    final yesterday = _dayKey(DateTime.now().subtract(const Duration(days: 1)));
    _streakDays = (_lastPlayDay == yesterday) ? _streakDays + 1 : 1;
    if (_streakDays > _bestStreak) _bestStreak = _streakDays;
    _lastPlayDay = today;

    _prefs?.setInt(_kStreakDays, _streakDays);
    _prefs?.setInt(_kStreakBest, _bestStreak);
    _prefs?.setString(_kLastPlayDay, today);
  }

  /// تنقطع السلسلة إن مرّ يوم كامل دون لعب — يُفحص عند كل إقلاع.
  void _breakStreakIfStale() {
    if (_lastPlayDay.isEmpty) return;
    final today = _dayKey();
    final yesterday = _dayKey(DateTime.now().subtract(const Duration(days: 1)));
    if (_lastPlayDay != today &&
        _lastPlayDay != yesterday &&
        _streakDays != 0) {
      _streakDays = 0;
      _prefs?.setInt(_kStreakDays, 0);
    }
  }

  // ---------------------------- المهام ----------------------------
  int missionProgress(String id) => _missionProgress[id] ?? 0;
  bool isMissionClaimed(String id) => _missionClaimed.contains(id);

  bool isMissionComplete(String id) {
    final mission = missions.firstWhere((m) => m.id == id);
    return missionProgress(id) >= mission.target;
  }

  int get missionsCompleted =>
      missions.where((m) => isMissionComplete(m.id)).length;

  bool get hasClaimableMission =>
      missions.any((m) => isMissionComplete(m.id) && !isMissionClaimed(m.id));

  void _rolloverMissionsIfNeeded() {
    final today = _dayKey();
    if (_missionDay == today) return;
    _missionDay = today;
    _missionProgress = {};
    _missionClaimed = const [];
    _missionNewGameIds = const [];
    _prefs?.setString(_kMissionDay, today);
    _prefs?.setStringList(_kMissionNewGames, const []);
  }

  void _bumpMission(String id, int amount) {
    final mission = missions.firstWhere((m) => m.id == id);
    final current = _missionProgress[id] ?? 0;
    if (current >= mission.target) return;
    _missionProgress[id] = (current + amount).clamp(0, mission.target);
  }

  Future<void> _persistMissions() async {
    await _prefs?.setStringList(
        _kMissionProgress, _encodeCounts(_missionProgress));
    await _prefs?.setStringList(_kMissionClaimed, _missionClaimed);
  }

  /// يصرف مكافأة مهمة مكتملة. يُرجع المبلغ، أو 0 إن لم تكن قابلة للصرف.
  Future<int> claimMission(String id) async {
    if (!isMissionComplete(id) || isMissionClaimed(id)) return 0;
    final mission = missions.firstWhere((m) => m.id == id);
    _missionClaimed = [..._missionClaimed, id];
    await addCoins(mission.reward);
    await _persistMissions();
    return mission.reward;
  }

  // ---------------------------- العملات ----------------------------
  Future<void> addCoins(int amount) async {
    if (amount <= 0) return;
    _coins += amount;
    notifyListeners();
    await _prefs?.setInt(_kCoins, _coins);
  }

  /// يخصم [amount] إن توفّر الرصيد. يُرجع false إن كان الرصيد غير كافٍ.
  Future<bool> spendCoins(int amount) async {
    if (_coins < amount) return false;
    _coins -= amount;
    notifyListeners();
    await _prefs?.setInt(_kCoins, _coins);
    return true;
  }

  /// يمسح كل التقدّم (المفضّلة والإحصاءات والعملات والمهام).
  Future<void> resetProgress() async {
    _favoriteIds = const [];
    _recentGameIds = const [];
    _playCounts = {};
    _totalPlaySeconds = 0;
    _streakDays = 0;
    _bestStreak = 0;
    _lastPlayDay = '';
    _coins = 0;
    _missionProgress = {};
    _missionClaimed = const [];
    _missionNewGameIds = const [];
    notifyListeners();
    final p = _prefs;
    if (p == null) return;
    await p.setStringList(_kFavorites, const []);
    await p.setStringList(_kRecent, const []);
    await p.setStringList(_kPlayCounts, const []);
    await p.setInt(_kPlaySeconds, 0);
    await p.setInt(_kStreakDays, 0);
    await p.setInt(_kStreakBest, 0);
    await p.setString(_kLastPlayDay, '');
    await p.setInt(_kCoins, 0);
    await _persistMissions();
  }
}

// =========================================================================
// الإشعارات اليومية
// =========================================================================

/// تذكير يومي واحد بلعبة اليوم.
///
/// كل استدعاء مغلّف بـ try/catch: الإشعارات ميزة كمالية، وفشل الأذونات
/// أو المنصة يجب ألا يمنع التطبيق من العمل.
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  /// ساعة التذكير اليومي (السابعة مساءً).
  static const int reminderHour = 19;

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'daily_game',
    'التذكير اليومي',
    channelDescription: 'تذكير يومي بلعبة اليوم',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  Future<void> initialize() async {
    if (_ready) return;
    try {
      tz.initializeTimeZones();
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(settings);
      _ready = true;
    } catch (e) {
      debugPrint('NotificationService.initialize failed: $e');
    }
  }

  /// يطلب الإذن. يُرجع false إن رُفض أو تعذّر.
  Future<bool> requestPermission() async {
    try {
      await initialize();
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(
                alert: true, badge: true, sound: true) ??
            false;
      }
      return false;
    } catch (e) {
      debugPrint('requestPermission failed: $e');
      return false;
    }
  }

  /// يجدول تذكير الغد. يُعاد جدولته عند كل إقلاع، فيبقى نص الإشعار
  /// مطابقاً للعبة اليوم الفعلية بدل نص محفوظ قديم.
  Future<void> scheduleDailyReminder() async {
    try {
      await initialize();
      await cancelAll();

      final now = tz.TZDateTime.now(tz.local);
      var when =
          tz.TZDateTime(tz.local, now.year, now.month, now.day, reminderHour);
      if (!when.isAfter(now)) when = when.add(const Duration(days: 1));

      final game =
          GameCatalog.gameOfTheDay(DateTime(when.year, when.month, when.day));

      await _plugin.zonedSchedule(
        1,
        L.notificationTitle,
        L.notificationBody(game.title),
        when,
        const NotificationDetails(
          android: _androidDetails,
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        // مطلوب في flutter_local_notifications 17.x وأقدم، ومهمَل (بلا
        // ضرر) في 18.x — تركه هنا يجعل الملف يبني على الإصدارين.
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('scheduleDailyReminder failed: $e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('cancelAll failed: $e');
    }
  }
}

// =========================================================================
// تقييم التطبيق
// =========================================================================

/// نافذة تقييم المتجر.
///
/// تُعرض مرة واحدة فقط، وبعد أن يكون المستخدم قد لعب فعلاً — الطلب
/// المبكّر أو المتكرر يستفزّ الناس ويجلب تقييمات سيئة.
class RateService {
  const RateService._();

  static const int minLaunches = 3;
  static const int minPlays = 5;

  static bool shouldAsk() {
    final s = SettingsService.instance;
    return !s.rateDone &&
        s.launchCount >= minLaunches &&
        s.totalPlays >= minPlays;
  }

  /// يفتح نافذة التقييم داخل التطبيق، أو صفحة المتجر كخطة بديلة.
  static Future<void> openReview() async {
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
      } else {
        await review.openStoreListing();
      }
    } catch (e) {
      debugPrint('openReview failed: $e');
    }
    await SettingsService.instance.markRateDone();
  }

  /// يعرض نافذة لطيفة تسأل قبل فتح تقييم المتجر.
  static Future<void> maybeAsk(BuildContext context) async {
    if (!shouldAsk()) return;
    final palette = context.palette;

    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.star_rounded, color: palette.amber),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                L.rateApp,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          L.ratePrompt,
          style: TextStyle(color: palette.textSecondary, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(L.later, style: TextStyle(color: palette.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.violet,
              foregroundColor: palette.onAccent,
            ),
            child: Text(L.rateNow),
          ),
        ],
      ),
    );

    if (answer == true) {
      await openReview();
    } else {
      // "لاحقاً" لا يُسكت النافذة للأبد، لكنه يؤجّلها عبر تصفير العدّاد
      // الفعّال — نعلّمها كمنجزة فقط عند التقييم الحقيقي.
      await SettingsService.instance.markRateDone();
    }
  }
}

// =========================================================================
// الثيم: لوحتان كاملتان (ليلي ونهاري)
// =========================================================================

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Brightness brightness;

  final Color background;
  final Color backgroundAlt;
  final Color surface;
  final Color surfaceHigh;
  final Color surfaceGlass;
  final Color border;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  final Color violet;
  final Color indigo;
  final Color rose;
  final Color mint;
  final Color amber;
  final Color emerald;

  final Color onAccent;
  final Color shadow;

  const AppPalette({
    required this.brightness,
    required this.background,
    required this.backgroundAlt,
    required this.surface,
    required this.surfaceHigh,
    required this.surfaceGlass,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.violet,
    required this.indigo,
    required this.rose,
    required this.mint,
    required this.amber,
    required this.emerald,
    required this.onAccent,
    required this.shadow,
  });

  bool get isDark => brightness == Brightness.dark;

  /// أسود مائل للبنفسجي: الصور تبرز فوقه دون أن تنافسه الخلفية.
  static const dark = AppPalette(
    brightness: Brightness.dark,
    background: Color(0xFF07060F),
    backgroundAlt: Color(0xFF0D0B1C),
    surface: Color(0xFF15122A),
    surfaceHigh: Color(0xFF1F1B3A),
    surfaceGlass: Color(0x662A2450),
    border: Color(0xFF2E2857),
    textPrimary: Color(0xFFF4F2FF),
    textSecondary: Color(0xFFA79FC4),
    textMuted: Color(0xFF6F678F),
    violet: Color(0xFF8B5CF6),
    indigo: Color(0xFF6366F1),
    rose: Color(0xFFF43F5E),
    mint: Color(0xFF2DD4BF),
    amber: Color(0xFFFBBF24),
    emerald: Color(0xFF10B981),
    onAccent: Colors.white,
    shadow: Color(0x66000000),
  );

  /// أبيض دافئ مع درجات أغمق للألوان حتى تبقى مقروءة على خلفية فاتحة.
  static const light = AppPalette(
    brightness: Brightness.light,
    background: Color(0xFFF7F5FF),
    backgroundAlt: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFF0ECFF),
    surfaceGlass: Color(0xCCFFFFFF),
    border: Color(0xFFE4DEF7),
    textPrimary: Color(0xFF14102B),
    textSecondary: Color(0xFF544C77),
    textMuted: Color(0xFF8B84A8),
    violet: Color(0xFF7C3AED),
    indigo: Color(0xFF4F46E5),
    rose: Color(0xFFE11D48),
    mint: Color(0xFF0D9488),
    amber: Color(0xFFD97706),
    emerald: Color(0xFF059669),
    onAccent: Colors.white,
    shadow: Color(0x1A1B1046),
  );

  LinearGradient get brandGradient => LinearGradient(
        colors: [mint, violet, rose],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );

  LinearGradient get primaryGradient => LinearGradient(
        colors: [indigo, violet],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get pageGradient => LinearGradient(
        colors: [background, backgroundAlt, background],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0, 0.45, 1],
      );

  Color accentFor(GameCategory category) {
    switch (category) {
      case GameCategory.puzzle:
        return violet;
      case GameCategory.action:
        return rose;
      case GameCategory.sports:
        return emerald;
      case GameCategory.arcade:
        return amber;
    }
  }

  /// خلفية الغلاف المصمَّم عندما لا تتوفر صورة.
  LinearGradient fallbackGradientFor(GameCategory category) {
    final accent = accentFor(category);
    return LinearGradient(
      colors: [
        Color.lerp(accent, background, isDark ? 0.35 : 0.55)!,
        Color.lerp(accent, background, isDark ? 0.78 : 0.84)!,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  List<BoxShadow> cardShadow(Color accent) => [
        BoxShadow(
          color: accent.withValues(alpha: isDark ? 0.18 : 0.14),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: shadow,
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  @override
  AppPalette copyWith({Brightness? brightness}) => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return t < 0.5 ? this : other;
  }
}

extension PaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}

ThemeData buildAppTheme(Brightness brightness) {
  final palette =
      brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: palette.violet,
    onPrimary: palette.onAccent,
    secondary: palette.mint,
    onSecondary: palette.onAccent,
    tertiary: palette.rose,
    error: palette.rose,
    onError: palette.onAccent,
    surface: palette.surface,
    onSurface: palette.textPrimary,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: palette.background,
    colorScheme: scheme,
    fontFamily: 'Roboto',
    splashFactory: InkRipple.splashFactory,
    dividerColor: palette.border,
    extensions: [palette],
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.surfaceHigh,
      contentTextStyle: TextStyle(color: palette.textPrimary),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    textTheme: TextTheme(
      titleLarge: TextStyle(
        color: palette.textPrimary,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
      titleMedium: TextStyle(
        color: palette.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      bodyMedium: TextStyle(color: palette.textSecondary),
    ),
    iconTheme: IconThemeData(color: palette.textSecondary),
  );
}

// =========================================================================
// صور الألعاب والأغلفة
// =========================================================================

/// غلاف اللعبة.
///
/// يجرّب روابط المزوّد واحداً تلو الآخر، ثم الصورة المرفقة داخل التطبيق،
/// وأخيراً غلافاً مصمَّماً بلون الفئة — فلا يظهر مربع صورة مكسورة أبداً.
class GameArtwork extends StatefulWidget {
  final Game game;
  final double iconSize;

  const GameArtwork({super.key, required this.game, this.iconSize = 34});

  @override
  State<GameArtwork> createState() => _GameArtworkState();
}

class _GameArtworkState extends State<GameArtwork> {
  int _sourceIndex = 0;

  @override
  void didUpdateWidget(covariant GameArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game.id != widget.game.id) _sourceIndex = 0;
  }

  void _tryNextSource() {
    // التبديل بعد اكتمال الإطار: لا يجوز استدعاء setState أثناء البناء.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _sourceIndex++);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final sources =
        widget.game.artworkSources.where((s) => s.isNotEmpty).toList();

    if (_sourceIndex >= sources.length) {
      return _DesignedCover(game: widget.game, iconSize: widget.iconSize);
    }

    final source = sources[_sourceIndex];

    if (source.startsWith('http')) {
      return Image.network(
        source,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _LoadingCover(palette: palette, game: widget.game);
        },
        errorBuilder: (_, __, ___) {
          _tryNextSource();
          return _LoadingCover(palette: palette, game: widget.game);
        },
        frameBuilder: (context, child, frame, wasSync) {
          if (wasSync || frame != null) {
            return AnimatedOpacity(
              opacity: 1,
              duration: const Duration(milliseconds: 250),
              child: child,
            );
          }
          return _LoadingCover(palette: palette, game: widget.game);
        },
      );
    }

    return Image.asset(
      source,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        _tryNextSource();
        return _DesignedCover(game: widget.game, iconSize: widget.iconSize);
      },
    );
  }
}

class _LoadingCover extends StatelessWidget {
  final AppPalette palette;
  final Game game;
  const _LoadingCover({required this.palette, required this.game});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Color.lerp(
          palette.accentFor(game.category), palette.background, 0.75)!,
      highlightColor: Color.lerp(
          palette.accentFor(game.category), palette.background, 0.55)!,
      period: const Duration(milliseconds: 1100),
      child: const ColoredBox(color: Colors.black, child: SizedBox.expand()),
    );
  }
}

/// غلاف بديل مصمَّم: تدرّج بلون الفئة + نقشة دوائر + أيقونة الفئة.
/// يبدو مقصوداً لا ناقصاً، ويمنع أي بطاقة من الظهور بلا صورة.
class _DesignedCover extends StatelessWidget {
  final Game game;
  final double iconSize;

  const _DesignedCover({required this.game, required this.iconSize});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accent = palette.accentFor(game.category);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: palette.fallbackGradientFor(game.category),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _CoverPatternPainter(
              color: palette.onAccent.withValues(alpha: 0.10),
              seed: game.id.hashCode,
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(iconSize * 0.34),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.28),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: palette.onAccent.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Icon(
                    game.category.icon,
                    size: iconSize,
                    color: palette.onAccent.withValues(alpha: 0.92),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverPatternPainter extends CustomPainter {
  final Color color;
  final int seed;

  const _CoverPatternPainter({required this.color, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    for (var i = 0; i < 5; i++) {
      final center = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      canvas.drawCircle(
        center,
        (size.shortestSide * 0.18) +
            random.nextDouble() * size.shortestSide * 0.3,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CoverPatternPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.seed != seed;
}

// =========================================================================
// عناصر واجهة مشتركة
// =========================================================================

/// انكماش خفيف عند الضغط — يعطي إحساس زر حقيقي.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scale;

  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.97,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// زر «العب» الموحّد أسفل كل بطاقة.
class PlayButton extends StatelessWidget {
  final Color accent;
  final VoidCallback onTap;
  final double height;
  final bool dense;

  const PlayButton({
    super.key,
    required this.accent,
    required this.onTap,
    this.height = 34,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent, Color.lerp(accent, palette.violet, 0.45)!],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.32),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(11),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_arrow_rounded,
                    size: dense ? 15 : 17, color: palette.onAccent),
                const SizedBox(width: 5),
                Text(
                  L.play,
                  style: TextStyle(
                    color: palette.onAccent,
                    fontSize: dense ? 12 : 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// زر القلب لإضافة/إزالة لعبة من المفضّلة.
class FavoriteButton extends StatelessWidget {
  final Game game;
  final bool onArtwork;
  final double size;

  const FavoriteButton({
    super.key,
    required this.game,
    this.onArtwork = true,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AnimatedBuilder(
      animation: SettingsService.instance,
      builder: (context, _) {
        final isFav = SettingsService.instance.isFavorite(game.id);
        return GestureDetector(
          onTap: () async {
            final added =
                await SettingsService.instance.toggleFavorite(game.id);
            if (SettingsService.instance.hapticsEnabled) {
              HapticFeedback.selectionClick();
            }
            if (!context.mounted) return;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content:
                    Text(added ? L.addedToFavorites : L.removedFromFavorites),
                duration: const Duration(milliseconds: 1400),
              ));
          },
          child: Container(
            padding: EdgeInsets.all(size * 0.33),
            decoration: BoxDecoration(
              // فوق الصورة نحتاج خلفية داكنة ثابتة مهما كان الثيم.
              color: onArtwork
                  ? Colors.black.withValues(alpha: 0.5)
                  : palette.surfaceHigh,
              shape: BoxShape.circle,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                key: ValueKey(isFav),
                size: size,
                color: isFav
                    ? palette.rose
                    : (onArtwork ? Colors.white : palette.textMuted),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// شارة رصيد العملات في الشريط العلوي.
class CoinBadge extends StatelessWidget {
  final VoidCallback? onTap;
  const CoinBadge({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AnimatedBuilder(
      animation: SettingsService.instance,
      builder: (context, _) => Pressable(
        onTap: onTap ?? () {},
        scale: 0.93,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: palette.amber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.amber.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.monetization_on_rounded,
                  size: 17, color: palette.amber),
              const SizedBox(width: 5),
              Text(
                '${SettingsService.instance.coins}',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// يشارك لعبة عبر تطبيقات الجهاز.
Future<void> shareGame(BuildContext context, Game game) async {
  try {
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      L.shareText(game.title),
      subject: game.title,
      // مطلوب على iPad وإلا انهار التطبيق: نافذة المشاركة تحتاج
      // مرجعاً لموضع انبثاقها على الشاشة.
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
  } catch (e) {
    debugPrint('shareGame failed: $e');
  }
}

/// شارة التقييم فوق الغلاف.
class RatingBadge extends StatelessWidget {
  final double rating;
  const RatingBadge({super.key, required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        // دائماً داكنة: تجلس فوق الصورة لا فوق خلفية الصفحة.
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 12, color: Color(0xFFFBBF24)),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HotBadge extends StatelessWidget {
  const _HotBadge();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: palette.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded,
              size: 11, color: palette.onAccent),
          const SizedBox(width: 2),
          Text(
            'HOT',
            style: TextStyle(
              color: palette.onAccent,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// بطاقات الألعاب
// =========================================================================

/// البطاقة القياسية: صورة + عنوان + فئة + زر «العب».
class GameCard extends StatelessWidget {
  final Game game;
  final VoidCallback onTap;
  final double? width;

  const GameCard({
    super.key,
    required this.game,
    required this.onTap,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accent = palette.accentFor(game.category);

    return SizedBox(
      width: width,
      child: Pressable(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.border),
            boxShadow: palette.cardShadow(accent),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    GameArtwork(game: game),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x59000000), Colors.transparent],
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      top: 8,
                      start: 8,
                      child: RatingBadge(rating: game.rating),
                    ),
                    PositionedDirectional(
                      top: 6,
                      end: 6,
                      child: FavoriteButton(game: game, size: 16),
                    ),
                    if (game.isFeatured)
                      const PositionedDirectional(
                        bottom: 8,
                        end: 8,
                        child: _HotBadge(),
                      ),
                    if (game.isLocal)
                      PositionedDirectional(
                        bottom: 8,
                        start: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.offline_bolt_rounded,
                                  size: 11, color: palette.mint),
                              const SizedBox(width: 3),
                              Text(
                                L.offline,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      game.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            game.category.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    PlayButton(accent: accent, onTap: onTap, dense: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// البطاقة العريضة لقسم «المميزة».
class FeaturedGameCard extends StatelessWidget {
  final Game game;
  final VoidCallback onTap;

  const FeaturedGameCard({
    super.key,
    required this.game,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accent = palette.accentFor(game.category);

    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: palette.border),
          boxShadow: palette.cardShadow(accent),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GameArtwork(game: game, iconSize: 52),
            // حجاب داكن ثابت في الثيمين: النص يجلس فوق الصورة.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x22000000), Color(0xF20A0714)],
                  stops: [0.25, 1],
                ),
              ),
            ),
            PositionedDirectional(
              top: 12,
              start: 12,
              child: RatingBadge(rating: game.rating),
            ),
            PositionedDirectional(
              top: 10,
              end: 10,
              child: FavoriteButton(game: game, size: 18),
            ),
            PositionedDirectional(
              start: 14,
              end: 14,
              bottom: 12,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          game.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          game.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFCFC8E8),
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 96,
                    child: PlayButton(accent: accent, onTap: onTap, height: 38),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// صف أفقي مضغوط لقسم «تابع اللعب».
class RecentGameTile extends StatelessWidget {
  final Game game;
  final VoidCallback onTap;

  const RecentGameTile({super.key, required this.game, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accent = palette.accentFor(game.category);

    return Pressable(
      onTap: onTap,
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.border),
          boxShadow: palette.cardShadow(accent),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 62,
                height: 62,
                child: GameArtwork(game: game, iconSize: 22),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    game.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    game.category.label,
                    style: TextStyle(color: palette.textMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  PlayButton(
                      accent: accent, onTap: onTap, height: 28, dense: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// شاشة اللعبة
// =========================================================================

class GameScreen extends StatefulWidget {
  final Game game;
  const GameScreen({super.key, required this.game});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final WebViewController _controller;

  bool _isLoading = true;
  bool _hasError = false;
  bool _isExiting = false;

  /// عند أول فشل نعيد التحميل تلقائياً مرة واحدة فقط، ثم نعرض شاشة الخطأ.
  /// مرة واحدة تكفي لعلاج انقطاع لحظي في الشبكة، وتكرارها بلا حد يحبس
  /// المستخدم في دوامة تحميل بلا مخرج.
  static const Duration _autoRetryDelay = Duration(milliseconds: 1200);
  bool _autoRetryUsed = false;
  bool _isRetrying = false;
  Timer? _autoRetryTimer;

  /// بداية الجلسة — الفرق عند الخروج يُضاف إلى وقت اللعب الكلي.
  final DateTime _sessionStart = DateTime.now();

  /// تكلفة الحياة الإضافية بالعملات، كبديل عن مشاهدة إعلان.
  static const int _extraLifeCost = 100;

  /// الوضع الأفقي القسري داخل اللعبة (زر التدوير).
  bool _forcedLandscape = false;

  bool _isMuted = !SettingsService.instance.soundEnabled;

  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // كثير من ألعاب HTML5 أفقية فقط، لذا نفك قفل الاتجاه داخل اللعبة
    // ونعيده عند الخروج.
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'HapticBridge',
        onMessageReceived: _handleHapticMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _isRetrying = false;
            });
            if (_isMuted) _applyMuteState();
          },
          onWebResourceError: _handleLoadError,
        ),
      );

    _loadGame();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.setBackgroundColor(context.palette.background);
  }

  /// يستقبل `window.HapticBridge.postMessage(type)` من داخل اللعبة.
  void _handleHapticMessage(JavaScriptMessage message) {
    if (!SettingsService.instance.hapticsEnabled) return;

    switch (message.message) {
      case 'light':
        HapticFeedback.lightImpact();
        break;
      case 'medium':
        HapticFeedback.mediumImpact();
        break;
      case 'heavy':
        HapticFeedback.heavyImpact();
        break;
      case 'success':
        HapticFeedback.selectionClick();
        break;
      default:
        HapticFeedback.lightImpact();
    }
  }

  /// يعالج فشل التحميل: محاولة تلقائية واحدة ثم شاشة الخطأ.
  void _handleLoadError(WebResourceError error) {
    if (!mounted) return;

    // نتجاهل أخطاء الموارد الفرعية (صورة أو ملف صوت لم يُحمَّل): اللعبة
    // غالباً تعمل رغمها، ولا معنى لإعادة تحميل الصفحة كلها بسببها.
    if (error.isForMainFrame == false) return;

    if (!_autoRetryUsed) {
      _autoRetryUsed = true;
      setState(() {
        _hasError = false;
        _isLoading = true;
        _isRetrying = true;
      });
      _autoRetryTimer?.cancel();
      _autoRetryTimer = Timer(_autoRetryDelay, () {
        if (!mounted || _isExiting) return;
        _loadGame();
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _isRetrying = false;
      _hasError = true;
    });
  }

  /// إعادة المحاولة اليدوية من زر الخطأ — تمنح المستخدم محاولة تلقائية
  /// جديدة أيضاً، لأن الظروف قد تكون تغيّرت (عاد الاتصال مثلاً).
  void _retryManually() {
    _autoRetryUsed = false;
    setState(() {
      _isLoading = true;
      _isRetrying = false;
      _hasError = false;
    });
    _loadGame();
  }

  void _loadGame() {
    if (widget.game.isLocal) {
      _controller.loadFlutterAsset(widget.game.localAssetPath!);
    } else {
      _controller.loadRequest(Uri.parse(widget.game.remoteUrl!));
    }
  }

  @override
  void dispose() {
    _autoRetryTimer?.cancel();
    _glowController.dispose();
    // _forcedLandscape لا يُعاد ضبطه هنا: السطر التالي يعيد القفل
    // الرأسي للتطبيق كله على أي حال.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    // WebViewController بلا dispose في webview_flutter 4.x؛ إيقاف الصوت
    // هنا يمنع استمرار اللعبة في الخلفية.
    _controller.runJavaScript(
      'try { document.querySelectorAll("audio,video").forEach(function(m){ m.pause(); }); } catch(e) {}',
    );
    super.dispose();
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _applyMuteState();
  }

  /// مساران للكتم: عناصر الوسائط مباشرة، ثم `window.setGameMuted` للألعاب
  /// التي تولّد صوتها عبر Web Audio API.
  void _applyMuteState() {
    _controller.runJavaScript(
      'try { document.querySelectorAll("audio,video").forEach(function(m){ m.muted = $_isMuted; }); } catch(e) {} '
      'try { if (window.setGameMuted) { window.setGameMuted($_isMuted); } } catch(e) {}',
    );
  }

  /// يبدّل بين ترك الاتجاه للّعبة وبين فرض الوضع الأفقي.
  ///
  /// بعض الألعاب تكتشف الاتجاه بنفسها وبعضها لا، فالزر يمنح المستخدم
  /// مخرجاً بدل انتظار اللعبة أن تتصرّف.
  void _toggleOrientation() {
    setState(() => _forcedLandscape = !_forcedLandscape);
    SystemChrome.setPreferredOrientations(
      _forcedLandscape
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : DeviceOrientation.values,
    );
  }

  /// يمنح حياة إضافية مقابل عملات — بديل فوري عن مشاهدة إعلان.
  Future<void> _spendCoinsForExtraLife() async {
    final ok = await SettingsService.instance.spendCoins(_extraLifeCost);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(L.notEnoughCoins)));
      return;
    }
    _grantExtraLife();
  }

  void _grantExtraLife() {
    _controller.runJavaScript(
      'try { if (window.onExtraLifeGranted) { window.onExtraLifeGranted(); } } catch(e) {}',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(L.extraLifeGranted)));
  }

  /// نافذة تخيّر بين مشاهدة إعلان أو دفع عملات.
  Future<void> _openExtraLifeSheet() async {
    final palette = context.palette;
    final coins = SettingsService.instance.coins;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.favorite_rounded, color: palette.rose),
                  const SizedBox(width: 8),
                  Text(
                    L.extraLife,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SheetOption(
                icon: Icons.play_circle_fill_rounded,
                accent: palette.violet,
                title: L.watchAd,
                subtitle: L.isArabic ? 'مجاناً' : 'Free',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showRewardedExtraLife();
                },
              ),
              const SizedBox(height: 10),
              _SheetOption(
                icon: Icons.monetization_on_rounded,
                accent: palette.amber,
                title: L.useCoins(_extraLifeCost),
                subtitle: '${L.coins}: $coins',
                enabled: coins >= _extraLifeCost,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _spendCoinsForExtraLife();
                },
              ),
              const SizedBox(height: 12),
              Text(
                L.howToEarn,
                style: TextStyle(color: palette.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRewardedExtraLife() {
    AdService.instance.showRewardedAd(
      onUserEarnedReward: (reward) {
        _grantExtraLife();
        // مكافأة إضافية بالعملات: تجعل مشاهدة الإعلان مجدية حتى حين لا
        // يحتاج اللاعب الحياة فعلاً.
        SettingsService.instance.addCoins(20);
      },
      onAdUnavailable: () {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(L.adNotReady)));
      },
    );
  }

  Future<void> _handleExit() async {
    if (_isExiting) return;
    _isExiting = true;

    // تُسجَّل قبل الإعلان البيني حتى لا تُفقد إن أُغلق التطبيق أثناءه.
    await SettingsService.instance
        .addPlayTime(DateTime.now().difference(_sessionStart));

    await _controller.runJavaScript(
      'try { document.querySelectorAll("audio,video").forEach(function(m){ m.pause(); }); } catch(e) {}',
    );

    if (!mounted) return;

    AdService.instance.showInterstitialOnGameExit(
      onComplete: () {
        if (mounted) Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleExit();
      },
      child: Scaffold(
        backgroundColor: palette.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(palette),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                        child: WebViewWidget(controller: _controller)),
                    if (_isLoading) _buildLoadingOverlay(palette),
                    if (_hasError) _buildErrorOverlay(palette),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(AppPalette palette) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(6, 8, 12, 8),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _handleExit,
            icon: Icon(
              L.isArabic
                  ? Icons.arrow_forward_ios_rounded
                  : Icons.arrow_back_ios_new_rounded,
              color: palette.textPrimary,
              size: 18,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.game.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                  ),
                ),
                Text(
                  widget.game.category.label,
                  style: TextStyle(color: palette.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _toggleMute,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            icon: Icon(
              _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: palette.textSecondary,
              size: 20,
            ),
          ),
          IconButton(
            onPressed: _toggleOrientation,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            tooltip: L.rotate,
            icon: Icon(
              _forcedLandscape
                  ? Icons.stay_current_portrait_rounded
                  : Icons.screen_rotation_rounded,
              color: palette.textSecondary,
              size: 20,
            ),
          ),
          IconButton(
            onPressed: () => shareGame(context, widget.game),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            tooltip: L.share,
            icon: Icon(Icons.ios_share_rounded,
                color: palette.textSecondary, size: 19),
          ),
          FavoriteButton(game: widget.game, onArtwork: false, size: 18),
          const SizedBox(width: 6),
          _buildExtraLifeButton(palette),
        ],
      ),
    );
  }

  Widget _buildExtraLifeButton(AppPalette palette) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glow = 6 + (_glowController.value * 10);
        return Container(
          margin: const EdgeInsetsDirectional.only(start: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: palette.rose.withValues(alpha: 0.55),
                blurRadius: glow,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _openExtraLifeSheet,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [palette.rose, palette.violet]),
              shape: BoxShape.circle,
            ),
            child:
                Icon(Icons.favorite_rounded, color: palette.onAccent, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay(AppPalette palette) {
    return Container(
      color: palette.background,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(palette.mint),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _isRetrying
                ? L.retryingAuto
                : (widget.game.isLocal ? L.warmingUp : L.loadingGame),
            style: TextStyle(color: palette.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorOverlay(AppPalette palette) {
    return Container(
      color: palette.background,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, color: palette.textSecondary, size: 40),
          const SizedBox(height: 14),
          Text(
            L.loadFailed,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            L.loadFailedHint,
            style: TextStyle(color: palette.textMuted, fontSize: 12.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _retryManually,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(L.retry),
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.violet,
              foregroundColor: palette.onAccent,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

/// صف خيار داخل نافذة سفلية.
class _SheetOption extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  const _SheetOption({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.surfaceHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(color: palette.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(
                L.isArabic
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: palette.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// المهام اليومية والإحصاءات
// =========================================================================

/// بطاقة المهام اليومية في الشاشة الرئيسية.
class DailyMissionsCard extends StatelessWidget {
  const DailyMissionsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AnimatedBuilder(
      animation: SettingsService.instance,
      builder: (context, _) {
        final s = SettingsService.instance;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Container(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette.border),
              boxShadow: palette.cardShadow(palette.indigo),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.task_alt_rounded,
                        color: palette.indigo, size: 19),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            L.dailyMissions,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            L.missionsDone(s.missionsCompleted,
                                SettingsService.missions.length),
                            style: TextStyle(
                                color: palette.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (s.streakDays > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: palette.amber.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_fire_department_rounded,
                                size: 14, color: palette.amber),
                            const SizedBox(width: 3),
                            Text(
                              '${s.streakDays}',
                              style: TextStyle(
                                color: palette.amber,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final mission in SettingsService.missions)
                  _MissionRow(mission: mission),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MissionRow extends StatelessWidget {
  final Mission mission;
  const _MissionRow({required this.mission});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final s = SettingsService.instance;
    final progress = s.missionProgress(mission.id);
    final done = s.isMissionComplete(mission.id);
    final claimed = s.isMissionClaimed(mission.id);
    final ratio = (progress / mission.target).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(mission.icon,
              size: 17, color: done ? palette.emerald : palette.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mission.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 5,
                    backgroundColor: palette.surfaceHigh,
                    valueColor: AlwaysStoppedAnimation(
                        done ? palette.emerald : palette.violet),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 74,
            child: claimed
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 15, color: palette.emerald),
                      const SizedBox(width: 4),
                      Text(
                        L.claimed,
                        style:
                            TextStyle(color: palette.textMuted, fontSize: 11),
                      ),
                    ],
                  )
                : done
                    ? SizedBox(
                        height: 28,
                        child: ElevatedButton(
                          onPressed: () async {
                            final reward = await SettingsService.instance
                                .claimMission(mission.id);
                            if (reward <= 0 || !context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(L.coinsEarned(reward))),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: palette.amber,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9)),
                          ),
                          child: Text(
                            '+${mission.reward}',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                        ),
                      )
                    : Text(
                        '$progress/${mission.target}',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: palette.textMuted, fontSize: 11.5),
                      ),
          ),
        ],
      ),
    );
  }
}

/// شاشة الإحصاءات الشخصية.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: SettingsService.instance,
          builder: (context, _) {
            final s = SettingsService.instance;
            final topGame = s.mostPlayedId == null
                ? null
                : GameCatalog.byId(s.mostPlayedId!);

            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 20, 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          L.isArabic
                              ? Icons.arrow_forward_ios_rounded
                              : Icons.arrow_back_ios_new_rounded,
                          color: palette.textPrimary,
                          size: 19,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Text(
                        L.stats,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (s.totalPlays == 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Column(
                      children: [
                        Icon(Icons.insights_rounded,
                            size: 46, color: palette.textMuted),
                        const SizedBox(height: 12),
                        Text(L.noStatsYet,
                            style: TextStyle(color: palette.textMuted)),
                      ],
                    ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            icon: Icons.local_fire_department_rounded,
                            accent: palette.amber,
                            value: '${s.streakDays}',
                            label: L.streak,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatTile(
                            icon: Icons.emoji_events_rounded,
                            accent: palette.emerald,
                            value: '${s.bestStreak}',
                            label: L.bestStreak,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            icon: Icons.sports_esports_rounded,
                            accent: palette.violet,
                            value: '${s.totalPlays}',
                            label: L.totalPlays,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatTile(
                            icon: Icons.timer_rounded,
                            accent: palette.indigo,
                            value: L.duration(s.totalPlaySeconds),
                            label: L.playTime,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            icon: Icons.explore_rounded,
                            accent: palette.mint,
                            value: '${s.distinctGamesPlayed}',
                            label: L.gamesTried,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatTile(
                            icon: Icons.monetization_on_rounded,
                            accent: palette.amber,
                            value: '${s.coins}',
                            label: L.coins,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (topGame != null) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 26, 20, 10),
                      child: Text(
                        L.mostPlayed,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: RecentGameTile(
                        game: topGame,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => GameScreen(game: topGame)),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String value;
  final String label;

  const _StatTile({
    required this.icon,
    required this.accent,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: palette.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// شاشة سياسة الخصوصية
// =========================================================================

/// نص سياسة الخصوصية مضمَّن داخل التطبيق.
///
/// مكتوب هنا كنص لا كصفحة ويب لسببين: يعمل بلا إنترنت (متطلب مراجعة في
/// Google Play — يجب أن تكون السياسة متاحة دائماً)، ويتبع ثيم التطبيق
/// وخطه واتجاهه تلقائياً.
///
/// ⚠️ املأ الحقول الثلاثة أدناه قبل النشر: بدونها تُرفض المراجعة.
class PrivacyPolicy {
  const PrivacyPolicy._();

  /// اسمك أو اسم شركتك كما سيظهر في المتجر.
  static const String developerName = '[اسم المطوّر]';

  /// بريد التواصل — يجب أن يكون عاملاً ويطابق بريد حساب Play Console.
  static const String contactEmail = '[بريدك الإلكتروني]';

  /// تاريخ آخر تحديث للسياسة.
  static const String lastUpdated = '[التاريخ]';

  /// رابط النسخة المنشورة على الويب. Google Play تطلب رابطاً خارجياً
  /// إضافةً إلى النسخة داخل التطبيق، فضعه هنا ليظهر زر فتحه.
  static const String webUrl = '';

  static List<({String title, String body})> sections() =>
      L.isArabic ? _arabic() : _english();

  static String get intro => L.isArabic
      ? 'تشرح هذه السياسة أي معلومات يجمعها تطبيق «${L.appTitle}»، وكيف '
          'تُستخدم، ومع من تُشارَك. التطبيق لا يطلب إنشاء حساب ولا تسجيل دخول.'
      : 'This policy explains what information the "${L.appTitle}" app '
          'collects, how it is used, and who it is shared with. The app '
          'requires no account and no sign-in.';

  static List<({String title, String body})> _arabic() => [
        (
          title: 'المعلومات التي نجمعها',
          body: 'لا نجمع أي معلومات تعرّفك شخصياً. لا نطلب اسمك ولا بريدك '
              'ولا رقم هاتفك ولا موقعك الجغرافي.\n\n'
              'يُحفظ على جهازك فقط: إعداداتك (الثيم، اللغة، الصوت، الاهتزاز) '
              'وقائمة آخر الألعاب التي فتحتها. تبقى داخل الجهاز ولا تُرسل إلى '
              'أي خادم، وتُحذف بالكامل عند حذف التطبيق.\n\n'
              'تجمع خدمة الإعلانات تلقائياً: معرّف الإعلان الخاص بجهازك، نوع '
              'الجهاز ونظامه ولغته، عنوان IP والبلد التقريبي، وبيانات التفاعل '
              'مع الإعلانات.',
        ),
        (
          title: 'لماذا نستخدم هذه المعلومات',
          body: '• عرض إعلانات تمويلية تبقي التطبيق مجانياً بالكامل\n'
              '• حفظ تفضيلاتك حتى لا تعيد ضبطها في كل مرة\n'
              '• قياس أداء الإعلانات ومنع الاحتيال',
        ),
        (
          title: 'خدمات الطرف الثالث',
          body: 'يعتمد التطبيق على خدمتين خارجيتين لكل منهما سياسة خصوصية '
              'مستقلة:\n\n'
              '• Google AdMob — لعرض الإعلانات.\n'
              '• Famobi / HTML5Games — مزوّد الألعاب. تُعرض الألعاب داخل نافذة '
              'ويب مدمجة من خوادم Famobi، وقد يجمع المزوّد بياناته الخاصة '
              'أثناء اللعب.\n\n'
              'نحن لا نتحكم في ممارسات هذه الجهات ولا نتحمّل مسؤوليتها.',
        ),
        (
          title: 'خصوصية الأطفال',
          body: 'التطبيق غير موجَّه للأطفال دون سن 13 عاماً، ولا نجمع عن قصد '
              'أي بيانات منهم. إن كنت وليّ أمر وتعتقد أن طفلك زوّدنا '
              'بمعلومات، راسلنا وسنحذفها فوراً.',
        ),
        (
          title: 'حقوقك في التحكم',
          body: '• تصفير أو حجب معرّف الإعلان: أندرويد ‹ الإعدادات ‹ Google ‹ '
              'الإعلانات. آيفون ‹ الإعدادات ‹ الخصوصية ‹ التتبّع.\n'
              '• حذف بياناتك المحلية: امسح «آخر ما لعبت» من إعدادات التطبيق، '
              'أو احذف التطبيق لإزالة كل شيء.\n'
              '• سكان الاتحاد الأوروبي والمملكة المتحدة: لك حق الوصول إلى '
              'بياناتك وتصحيحها وحذفها والاعتراض على معالجتها وفق GDPR.\n'
              '• سكان كاليفورنيا: لك الحق بموجب CCPA في معرفة ما يُجمع ورفض '
              'بيعه. نحن لا نبيع بياناتك.',
        ),
        (
          title: 'أمن البيانات',
          body: 'كل الاتصالات تمرّ عبر HTTPS مشفّر. ولأننا لا نحتفظ ببيانات '
              'على خوادمنا، تبقى معلوماتك على جهازك أو لدى مزوّدي الخدمة '
              'المذكورين أعلاه.',
        ),
        (
          title: 'تعديلات على هذه السياسة',
          body: 'قد نحدّث هذه السياسة عند تغيّر التطبيق أو المتطلبات '
              'القانونية. سيتغيّر تاريخ آخر تحديث أعلاه، ويُعدّ استمرارك في '
              'استخدام التطبيق موافقة على النسخة الجديدة.',
        ),
      ];

  static List<({String title, String body})> _english() => [
        (
          title: 'Information We Collect',
          body: 'We collect no personally identifiable information. We never '
              'ask for your name, email, phone number, or location.\n\n'
              'Stored on your device only: your settings (theme, language, '
              'sound, haptics) and your recently played list. These stay on '
              'the device, are never sent to any server, and are erased when '
              'you uninstall.\n\n'
              'Collected automatically by the ad service: your device\'s '
              'Advertising ID, device model, OS and language, IP address and '
              'approximate country, and ad interaction data.',
        ),
        (
          title: 'How We Use It',
          body: '• Serving ads, which is what keeps the app free\n'
              '• Remembering your preferences between sessions\n'
              '• Measuring ad performance and preventing fraud',
        ),
        (
          title: 'Third-Party Services',
          body: 'The app relies on two external services, each with its own '
              'privacy policy:\n\n'
              '• Google AdMob — advertising.\n'
              '• Famobi / HTML5Games — game provider. Games load in an '
              'embedded web view from Famobi\'s servers and the provider may '
              'collect its own data during play.\n\n'
              'We do not control these parties\' practices and are not '
              'responsible for them.',
        ),
        (
          title: 'Children\'s Privacy',
          body: 'The app is not directed at children under 13, and we do not '
              'knowingly collect data from them. If you are a parent and '
              'believe your child provided information, contact us and we '
              'will delete it promptly.',
        ),
        (
          title: 'Your Choices',
          body: '• Reset or limit your Advertising ID: Android › Settings › '
              'Google › Ads. iOS › Settings › Privacy › Tracking.\n'
              '• Delete local data: clear "Recently played" in the app\'s '
              'settings, or uninstall the app to remove everything.\n'
              '• EU/UK residents: under GDPR you may access, correct, delete, '
              'or object to processing of your data.\n'
              '• California residents: under CCPA you may know what is '
              'collected and opt out of its sale. We do not sell your data.',
        ),
        (
          title: 'Data Security',
          body: 'All traffic uses encrypted HTTPS. Because we operate no '
              'servers of our own, your information remains on your device or '
              'with the providers listed above.',
        ),
        (
          title: 'Changes to This Policy',
          body: 'We may update this policy as the app or legal requirements '
              'change. The date above will change, and continued use of the '
              'app constitutes acceptance of the revised version.',
        ),
      ];
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final sections = PrivacyPolicy.sections();

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 20, 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        L.isArabic
                            ? Icons.arrow_forward_ios_rounded
                            : Icons.arrow_back_ios_new_rounded,
                        color: palette.textPrimary,
                        size: 19,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        L.privacyPolicy,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // بطاقة التعريف: اسم التطبيق والمطوّر وتاريخ التحديث.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: palette.primaryGradient,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        L.appTitle,
                        style: TextStyle(
                          color: palette.onAccent,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _metaLine(palette, L.isArabic ? 'المطوّر' : 'Developer',
                          PrivacyPolicy.developerName),
                      _metaLine(
                          palette,
                          L.isArabic ? 'آخر تحديث' : 'Last updated',
                          PrivacyPolicy.lastUpdated),
                      _metaLine(palette, L.isArabic ? 'التواصل' : 'Contact',
                          PrivacyPolicy.contactEmail),
                    ],
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Text(
                  PrivacyPolicy.intro,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 14,
                    height: 1.7,
                  ),
                ),
              ),
            ),

            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final section = sections[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 4,
                              height: 18,
                              margin: const EdgeInsetsDirectional.only(
                                  end: 9, top: 2),
                              decoration: BoxDecoration(
                                color: palette.violet,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${index + 1}. ${section.title}',
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          section.body,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 14,
                            height: 1.75,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                childCount: sections.length,
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: palette.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.mail_outline_rounded,
                          color: palette.mint, size: 19),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          L.isArabic
                              ? 'لأي سؤال بخصوص الخصوصية: ${PrivacyPolicy.contactEmail}'
                              : 'For any privacy question: ${PrivacyPolicy.contactEmail}',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaLine(AppPalette palette, String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          '$label: $value',
          style: TextStyle(
            color: palette.onAccent.withValues(alpha: 0.85),
            fontSize: 12.5,
          ),
        ),
      );
}

// =========================================================================
// شاشة الإعدادات
// =========================================================================

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SettingsService get _settings => SettingsService.instance;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _settings,
          builder: (context, _) => CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _header(context, palette)),
              SliverToBoxAdapter(
                child: _Section(
                  title: L.appearance,
                  children: [
                    _themeSelector(palette),
                    _languageSelector(palette)
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: _Section(
                  title: L.gameplay,
                  children: [
                    _SwitchTile(
                      icon: Icons.volume_up_rounded,
                      accent: palette.mint,
                      title: L.sound,
                      subtitle: L.soundSub,
                      value: _settings.soundEnabled,
                      onChanged: _settings.setSoundEnabled,
                    ),
                    _SwitchTile(
                      icon: Icons.vibration_rounded,
                      accent: palette.violet,
                      title: L.haptics,
                      subtitle: L.hapticsSub,
                      value: _settings.hapticsEnabled,
                      onChanged: _settings.setHapticsEnabled,
                    ),
                    _SwitchTile(
                      icon: Icons.notifications_active_rounded,
                      accent: palette.amber,
                      title: L.notifications,
                      subtitle: L.notificationsSub,
                      value: _settings.notificationsEnabled,
                      onChanged: _onNotificationsToggled,
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: _Section(
                  title: L.stats,
                  children: [
                    _ActionTile(
                      icon: Icons.insights_rounded,
                      accent: palette.emerald,
                      title: L.stats,
                      subtitle: L.statsSub,
                      enabled: true,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const StatsScreen()),
                      ),
                    ),
                    _InfoTile(
                      icon: Icons.monetization_on_rounded,
                      accent: palette.amber,
                      title: L.wallet,
                      trailing: '${_settings.coins}',
                    ),
                    _ActionTile(
                      icon: Icons.delete_sweep_rounded,
                      accent: palette.rose,
                      title: L.resetProgress,
                      subtitle: L.resetProgressSub,
                      enabled: true,
                      onTap: _confirmReset,
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: _Section(
                  title: L.library,
                  children: [
                    _InfoTile(
                      icon: Icons.sports_esports_rounded,
                      accent: palette.rose,
                      title: L.gamesInstalled,
                      trailing: '${GameCatalog.games.length}',
                    ),
                    _ActionTile(
                      icon: Icons.history_rounded,
                      accent: palette.indigo,
                      title: L.clearRecent,
                      subtitle: _settings.recentGameIds.isEmpty
                          ? L.nothingToClear
                          : L.rememberedGames(_settings.recentGameIds.length),
                      enabled: _settings.recentGameIds.isNotEmpty,
                      onTap: () async {
                        await _settings.clearRecent();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(L.recentCleared)),
                        );
                      },
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: _Section(
                  title: L.about,
                  children: [
                    _InfoTile(
                      icon: Icons.info_outline_rounded,
                      accent: palette.mint,
                      title: L.version,
                      trailing: '1.2.0',
                    ),
                    _ActionTile(
                      icon: Icons.star_rounded,
                      accent: palette.amber,
                      title: L.rateApp,
                      subtitle: L.rateAppSub,
                      enabled: true,
                      onTap: RateService.openReview,
                    ),
                    _ActionTile(
                      icon: Icons.privacy_tip_outlined,
                      accent: palette.indigo,
                      title: L.privacyPolicy,
                      subtitle: L.isArabic
                          ? 'ما نجمعه وكيف نستخدمه'
                          : 'What we collect and how it\'s used',
                      enabled: true,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const PrivacyPolicyScreen()),
                      ),
                    ),
                  ],
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  /// تشغيل الإشعارات يطلب الإذن أولاً؛ الرفض يعيد المفتاح لوضعه.
  Future<void> _onNotificationsToggled(bool value) async {
    if (!value) {
      await _settings.setNotificationsEnabled(false);
      await NotificationService.instance.cancelAll();
      return;
    }

    final granted = await NotificationService.instance.requestPermission();
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L.isArabic
              ? 'لم يُمنح إذن الإشعارات'
              : 'Notification permission denied'),
        ),
      );
      return;
    }

    await _settings.setNotificationsEnabled(true);
    await NotificationService.instance.scheduleDailyReminder();
  }

  Future<void> _confirmReset() async {
    final palette = context.palette;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          L.resetProgress,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          L.resetConfirm,
          style: TextStyle(color: palette.textSecondary, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(L.cancel, style: TextStyle(color: palette.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.rose,
              foregroundColor: Colors.white,
            ),
            child: Text(L.confirm),
          ),
        ],
      ),
    );

    if (ok != true) return;
    await _settings.resetProgress();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(L.progressReset)));
  }

  Widget _themeSelector(AppPalette palette) {
    final options = <ThemeMode, ({String label, IconData icon})>{
      ThemeMode.light: (label: L.light, icon: Icons.light_mode_rounded),
      ThemeMode.dark: (label: L.dark, icon: Icons.dark_mode_rounded),
      ThemeMode.system: (label: L.system, icon: Icons.smartphone_rounded),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _selectorLabel(palette, L.theme),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final entry in options.entries) ...[
                Expanded(
                  child: _SegmentOption(
                    label: entry.value.label,
                    icon: entry.value.icon,
                    selected: _settings.themeMode == entry.key,
                    onTap: () => _settings.setThemeMode(entry.key),
                  ),
                ),
                if (entry.key != options.keys.last) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _languageSelector(AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _selectorLabel(palette, L.language),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SegmentOption(
                  label: 'العربية',
                  icon: Icons.translate_rounded,
                  selected: _settings.isArabic,
                  onTap: () => _settings.setLanguage('ar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SegmentOption(
                  label: 'English',
                  icon: Icons.language_rounded,
                  selected: !_settings.isArabic,
                  onTap: () => _settings.setLanguage('en'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _selectorLabel(AppPalette palette, String text) => Text(
        text,
        style: TextStyle(
          color: palette.textPrimary,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
      );

  Widget _header(BuildContext context, AppPalette palette) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              L.isArabic
                  ? Icons.arrow_forward_ios_rounded
                  : Icons.arrow_back_ios_new_rounded,
              color: palette.textPrimary,
              size: 19,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Text(
            L.settings,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? palette.violet : palette.surfaceHigh,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: selected ? palette.violet : palette.border),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: palette.violet.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 19,
                color: selected ? palette.onAccent : palette.textMuted),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: selected ? palette.onAccent : palette.textSecondary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, bottom: 10),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.border),
              boxShadow: [
                BoxShadow(
                  color: palette.shadow,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _TileFrame extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String? subtitle;
  final Widget trailing;
  final VoidCallback? onTap;
  final bool enabled;

  const _TileFrame({
    required this.icon,
    required this.accent,
    required this.title,
    required this.trailing,
    this.subtitle,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: accent, size: 19),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style:
                            TextStyle(color: palette.textMuted, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return _TileFrame(
      icon: icon,
      accent: accent,
      title: title,
      subtitle: subtitle,
      onTap: () => onChanged(!value),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: palette.onAccent,
        activeTrackColor: accent,
        inactiveTrackColor: palette.surfaceHigh,
        inactiveThumbColor: palette.textMuted,
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String trailing;

  const _InfoTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return _TileFrame(
      icon: icon,
      accent: accent,
      title: title,
      trailing: Text(
        trailing,
        style: TextStyle(
          color: palette.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  const _ActionTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return _TileFrame(
      icon: icon,
      accent: accent,
      title: title,
      subtitle: subtitle,
      enabled: enabled,
      onTap: onTap,
      trailing: Icon(
        L.isArabic ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
        color: palette.textMuted,
        size: 20,
      ),
    );
  }
}

// =========================================================================
// الشاشة الرئيسية
// =========================================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  GameCategory? _selectedCategory;
  String _query = '';

  bool _isLoadingCatalog = true;

  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  SettingsService get _settings => SettingsService.instance;

  /// عند البحث أو الفلترة نستبدل الأقسام بشبكة نتائج واحدة.
  bool get _isFiltering => _query.isNotEmpty || _selectedCategory != null;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
    _loadCatalog();
    _loadBannerAd();
  }

  Future<void> _loadCatalog() async {
    await Future.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    setState(() => _isLoadingCatalog = false);
  }

  void _loadBannerAd() {
    _bannerAd = AdService.instance.createBannerAd(
      onLoaded: () {
        if (!mounted) return;
        setState(() => _isBannerLoaded = true);
      },
      onFailed: (error) {
        if (!mounted) return;
        setState(() => _isBannerLoaded = false);
        _bannerAd = null;
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  List<Game> get _filteredGames {
    final matches = GameCatalog.games.where((game) {
      final matchesCategory =
          _selectedCategory == null || game.category == _selectedCategory;
      final matchesQuery =
          _query.isEmpty || game.title.toLowerCase().contains(_query);
      return matchesCategory && matchesQuery;
    }).toList();
    return GameCatalog.sorted(matches, _settings.sort);
  }

  List<Game> get _favoriteGames {
    final byId = {for (final game in GameCatalog.games) game.id: game};
    return _settings.favoriteIds
        .map((id) => byId[id])
        .whereType<Game>()
        .toList();
  }

  List<Game> get _recentGames {
    final byId = {for (final game in GameCatalog.games) game.id: game};
    return _settings.recentGameIds
        .map((id) => byId[id])
        .whereType<Game>()
        .toList();
  }

  Future<void> _openGame(Game game) async {
    _settings.markPlayed(game.id);
    await Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: GameScreen(game: game),
          ),
        ),
      ),
    );

    // بعد اللعب مباشرة أفضل لحظة لطلب التقييم — الشرط داخل RateService
    // يضمن أن هذا يحدث مرة واحدة وبعد عدة جلسات.
    if (!mounted) return;
    await RateService.maybeAsk(context);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: palette.pageGradient),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _settings,
            builder: (context, _) => Column(
              children: [
                Expanded(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeader(palette)),
                      SliverToBoxAdapter(child: _buildSearchBar(palette)),
                      SliverToBoxAdapter(child: _buildCategoryChips(palette)),
                      if (_isLoadingCatalog)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          sliver: _buildShimmerGrid(palette),
                        )
                      else if (_isFiltering) ...[
                        SliverToBoxAdapter(child: _buildSortBar(palette)),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          sliver: _buildResultsGrid(palette),
                        ),
                      ] else
                        ..._buildSections(palette),
                    ],
                  ),
                ),
                _buildStickyBanner(palette),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------- الرأس والبحث -------------------------

  Widget _buildHeader(AppPalette palette) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 14, 4),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: palette.primaryGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: palette.violet.withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.sports_esports_rounded,
                color: Colors.white, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) =>
                      palette.brandGradient.createShader(bounds),
                  child: Text(
                    L.appTitle,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color:
                          Colors.white, // يستبدله التدرّج، يجب أن يبقى معتماً
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  L.gamesReady(GameCatalog.games.length),
                  style: TextStyle(color: palette.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          CoinBadge(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StatsScreen()),
            ),
          ),
          const SizedBox(width: 8),
          _IconButtonSquare(
            icon: palette.isDark
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
            onTap: () => _settings.toggleBrightness(palette.brightness),
          ),
          const SizedBox(width: 8),
          _IconButtonSquare(
            icon: Icons.settings_rounded,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border),
          boxShadow: [
            BoxShadow(
              color: palette.shadow,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          style: TextStyle(color: palette.textPrimary),
          cursorColor: palette.mint,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: L.searchHint,
            hintStyle: TextStyle(color: palette.textMuted),
            prefixIcon: Icon(Icons.search_rounded, color: palette.textMuted),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: Icon(Icons.close_rounded, color: palette.textMuted),
                    onPressed: () => _searchController.clear(),
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips(AppPalette palette) {
    return SizedBox(
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        children: [
          _CategoryChip(
            label: L.all,
            icon: Icons.auto_awesome_rounded,
            accent: palette.violet,
            selected: _selectedCategory == null,
            onTap: () => setState(() => _selectedCategory = null),
          ),
          ...GameCategory.values.map(
            (category) => _CategoryChip(
              label: category.label,
              icon: category.icon,
              accent: palette.accentFor(category),
              selected: _selectedCategory == category,
              onTap: () => setState(() => _selectedCategory = category),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------- الأقسام -------------------------

  List<Widget> _buildSections(AppPalette palette) {
    final recent = _recentGames;
    final featured = GameCatalog.featured;
    final favorites = _favoriteGames;
    final daily = GameCatalog.gameOfTheDay();

    return [
      // لعبة اليوم أولاً: بطاقة واحدة بارزة تدفع لاكتشاف ألعاب جديدة.
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: L.gameOfTheDay,
              subtitle: L.gameOfTheDaySub,
              icon: Icons.today_rounded,
              accent: palette.mint,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 176,
                child: FeaturedGameCard(
                  game: daily,
                  onTap: () => _openGame(daily),
                ),
              ),
            ),
          ],
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: 22)),
      const SliverToBoxAdapter(child: DailyMissionsCard()),

      if (favorites.isNotEmpty)
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                title: L.favorites,
                subtitle: L.favoritesSub,
                icon: Icons.favorite_rounded,
                accent: palette.rose,
              ),
              SizedBox(
                height: 244,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: favorites.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => GameCard(
                    game: favorites[index],
                    width: 158,
                    onTap: () => _openGame(favorites[index]),
                  ),
                ),
              ),
            ],
          ),
        ),

      if (recent.isNotEmpty)
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                title: L.continuePlaying,
                subtitle: L.jumpBackIn,
                icon: Icons.history_rounded,
              ),
              SizedBox(
                height: 98,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: recent.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => RecentGameTile(
                    game: recent[index],
                    onTap: () => _openGame(recent[index]),
                  ),
                ),
              ),
            ],
          ),
        ),
      if (featured.isNotEmpty)
        SliverToBoxAdapter(
          child: _FeaturedSection(games: featured, onTapGame: _openGame),
        ),
      for (final category in GameCategory.values)
        ..._categorySection(palette, category),
      const SliverToBoxAdapter(child: SizedBox(height: 20)),
    ];
  }

  List<Widget> _categorySection(AppPalette palette, GameCategory category) {
    final games = GameCatalog.byCategory(category);
    if (games.isEmpty) return const [];

    return [
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: category.label,
              subtitle: L.gameCount(games.length),
              accent: palette.accentFor(category),
              icon: category.icon,
              onSeeAll: () => setState(() => _selectedCategory = category),
            ),
            SizedBox(
              height: 244,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: games.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) => GameCard(
                  game: games[index],
                  width: 158,
                  onTap: () => _openGame(games[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  // ------------------------- النتائج -------------------------

  /// شريط الترتيب — يظهر فقط مع النتائج المفلترة، حيث يكون مفيداً.
  Widget _buildSortBar(AppPalette palette) {
    String labelOf(GameSort sort) {
      switch (sort) {
        case GameSort.defaultOrder:
          return L.sortDefault;
        case GameSort.topRated:
          return L.sortTopRated;
        case GameSort.alphabetical:
          return L.sortAlphabetical;
        case GameSort.mostPlayed:
          return L.sortMostPlayed;
      }
    }

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8, top: 5),
            child: Row(
              children: [
                Icon(Icons.sort_rounded, size: 15, color: palette.textMuted),
                const SizedBox(width: 4),
                Text(
                  '${L.sortBy}:',
                  style: TextStyle(color: palette.textMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          for (final sort in GameSort.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: GestureDetector(
                onTap: () => _settings.setSort(sort),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _settings.sort == sort
                        ? palette.violet
                        : palette.surface,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: _settings.sort == sort
                          ? palette.violet
                          : palette.border,
                    ),
                  ),
                  child: Text(
                    labelOf(sort),
                    style: TextStyle(
                      color: _settings.sort == sort
                          ? palette.onAccent
                          : palette.textSecondary,
                      fontSize: 12.5,
                      fontWeight: _settings.sort == sort
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultsGrid(AppPalette palette) {
    final games = _filteredGames;

    if (games.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 64),
          child: Column(
            children: [
              Icon(Icons.sports_esports_outlined,
                  size: 48, color: palette.textMuted),
              const SizedBox(height: 12),
              Text(
                L.noGamesFound,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                L.noGamesHint,
                style: TextStyle(color: palette.textMuted, fontSize: 12.5),
              ),
            ],
          ),
        ),
      );
    }

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.63,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => GameCard(
          game: games[index],
          onTap: () => _openGame(games[index]),
        ),
        childCount: games.length,
      ),
    );
  }

  Widget _buildShimmerGrid(AppPalette palette) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.63,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => Shimmer.fromColors(
          baseColor: palette.surface,
          highlightColor: palette.surfaceHigh,
          period: const Duration(milliseconds: 1200),
          child: Container(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        childCount: 6,
      ),
    );
  }

  Widget _buildStickyBanner(AppPalette palette) {
    if (!_isBannerLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      alignment: Alignment.center,
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}

// =========================================================================
// عناصر الأقسام
// =========================================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color? accent;
  final IconData? icon;
  final VoidCallback? onSeeAll;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.accent,
    this.icon,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = accent ?? palette.violet;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 16, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 28,
            margin: const EdgeInsetsDirectional.only(end: 10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16, color: color),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(color: palette.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (onSeeAll != null)
            IconButton(
              onPressed: onSeeAll,
              icon: Icon(
                L.isArabic
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: palette.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}

/// كاروسيل «المميزة» مع مؤشر صفحات.
class _FeaturedSection extends StatefulWidget {
  final List<Game> games;
  final void Function(Game) onTapGame;

  const _FeaturedSection({required this.games, required this.onTapGame});

  @override
  State<_FeaturedSection> createState() => _FeaturedSectionState();
}

class _FeaturedSectionState extends State<_FeaturedSection> {
  late final PageController _controller =
      PageController(viewportFraction: 0.88);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: L.featured,
          subtitle: L.handPicked,
          icon: Icons.local_fire_department_rounded,
          accent: palette.rose,
        ),
        SizedBox(
          height: 186,
          child: PageView.builder(
            controller: _controller,
            padEnds: false,
            onPageChanged: (index) => setState(() => _page = index),
            itemCount: widget.games.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 4, 0),
              child: FeaturedGameCard(
                game: widget.games[index],
                onTap: () => widget.onTapGame(widget.games[index]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < widget.games.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page ? palette.violet : palette.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IconButtonSquare extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconButtonSquare({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Pressable(
      onTap: onTap,
      scale: 0.92,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: palette.surfaceGlass,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.border),
        ),
        child: Icon(icon, color: palette.textSecondary, size: 20),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? accent : palette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? accent : palette.border),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 15,
                  color: selected ? palette.onAccent : palette.textMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? palette.onAccent : palette.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
