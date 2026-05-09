import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import your models and splash screen
import 'class.dart';
import 'splash.dart';

// ----------------------------------------------------
// DESIGN SYSTEM (CENTRALIZED CONSTANTS)
// ----------------------------------------------------
class AppTheme {
  static const Color leather = Color(0xFF4A3728); // Main dark brown
  static const Color parchment = Color(0xFFFDF5E6); // Main background
  static const Color ink = Color(0xFF2E211B); // Main text color
  static const Color fadedInk = Color(0xFF8D7B68); // Subtitles / faded text
  static const Color crimson = Color(0xFF8B0000); // Highlights / Favorites
  static const Color gold = Color(0xFFD3C4A9); // Dividers / Header text

  static const String font = 'serif'; // Universal app font
}

// ----------------------------------------------------
// ENUMS FOR CATEGORIES
// ----------------------------------------------------
enum SongCategory { all, favorites, hymns, choruses, carols }

// ----------------------------------------------------
// FAVORITES SERVICE (LOCAL STORAGE)
// ----------------------------------------------------
class FavoritesService {
  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;
  FavoritesService._internal();

  late SharedPreferences _prefs;
  Set<int> favoriteNumbers = {};

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final List<String>? savedFavs = _prefs.getStringList('favorites');
    if (savedFavs != null) {
      favoriteNumbers = savedFavs.map(int.parse).toSet();
    }
  }

  Future<void> toggleFavorite(int number) async {
    if (favoriteNumbers.contains(number)) {
      favoriteNumbers.remove(number);
    } else {
      favoriteNumbers.add(number);
    }
    await _prefs.setStringList(
      'favorites',
      favoriteNumbers.map((e) => e.toString()).toList(),
    );
  }

  bool isFavorite(int number) => favoriteNumbers.contains(number);
}

// ----------------------------------------------------
// INSTANT LOADING CACHE (PRELOADER)
// ----------------------------------------------------
class HymnDataLoader {
  static List<Song>? preloadedSongs;
  static bool isLoaded = false;

  static final RegExp _refrainMatch = RegExp(
    r'^\[?refrain\]?:?',
    caseSensitive: false,
  );
  static final RegExp _refrainReplace = RegExp(
    r'^\[?refrain\]?:?\s*',
    caseSensitive: false,
  );

  static String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text
        .toLowerCase()
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }

  static Future<void> load(ContentStorage storage) async {
    if (isLoaded) return;

    final library = await storage.readFile();
    if (library == null) return;

    List<Song> tempBook = [];
    final chapters = library['chapter'] as List<dynamic>? ?? [];

    for (int i = 0; i < chapters.length; i++) {
      final stanzas = chapters[i]['stanza'] as List<dynamic>? ?? [];
      List<LyricBlock> parsedLyrics = [];

      for (var stanza in stanzas) {
        String text = stanza.toString().trim();

        if (_refrainMatch.hasMatch(text)) {
          text = text.replaceFirst(_refrainReplace, '').trim();
          parsedLyrics.add(LyricBlock(type: LyricType.refrain, text: text));
        } else {
          parsedLyrics.add(LyricBlock(type: LyricType.verse, text: text));
        }
      }

      tempBook.add(
        Song(
          i + 1,
          _toTitleCase(chapters[i]['title'].toString()),
          parsedLyrics,
        ),
      );
    }

    preloadedSongs = tempBook;
    isLoaded = true;
  }
}

// ----------------------------------------------------
// MAIN
// ----------------------------------------------------

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Future.wait([
    FavoritesService().init(),
    HymnDataLoader.load(ContentStorage()),
  ]);

  runApp(const MyApp());
}

// ----------------------------------------------------
// MAIN APP
// ----------------------------------------------------

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hymns of Praise',
      theme: ThemeData(
        fontFamily: AppTheme.font,
        primaryColor: AppTheme.leather,
        scaffoldBackgroundColor: AppTheme.parchment,
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: AppTheme.leather,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// ----------------------------------------------------
// HOME SCREEN (LIST & CATEGORIES)
// ----------------------------------------------------

class Contents extends StatefulWidget {
  final ContentStorage storage;

  const Contents({super.key, required this.storage});

  @override
  State<Contents> createState() => ContentsState();
}

class ContentsState extends State<Contents> {
  List<Song> _hymnBook = [];
  bool _isLoading = true;
  String _searchQuery = '';
  SongCategory _currentCategory = SongCategory.all;

  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    if (HymnDataLoader.isLoaded && HymnDataLoader.preloadedSongs != null) {
      setState(() {
        _hymnBook = HymnDataLoader.preloadedSongs!;
        _isLoading = false;
      });
    } else {
      await HymnDataLoader.load(widget.storage);
      if (mounted) {
        setState(() {
          _hymnBook = HymnDataLoader.preloadedSongs ?? [];
          _isLoading = false;
        });
      }
    }
  }

  List<Song> get _filteredSongs {
    Iterable<Song> filtered = _hymnBook;

    switch (_currentCategory) {
      case SongCategory.favorites:
        filtered = filtered.where(
          (s) => FavoritesService().isFavorite(s.number),
        );
        break;
      case SongCategory.hymns:
        filtered = filtered.where((s) => s.number >= 1 && s.number <= 95);
        break;
      case SongCategory.choruses:
        filtered = filtered.where((s) => s.number >= 96 && s.number <= 202);
        break;
      case SongCategory.carols:
        filtered = filtered.where((s) => s.number >= 203 && s.number <= 215);
        break;
      case SongCategory.all:
        break;
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((song) {
        if (song.number.toString().contains(query)) return true;
        return song.title.toLowerCase().contains(query);
      });
    }

    return filtered.toList();
  }

  void _selectCategoryFromDrawer(SongCategory category) {
    setState(() => _currentCategory = category);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // --- REUSABLE DRAWER TILE WIDGET ---
  Widget _buildDrawerTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required SongCategory category,
    Color iconColor = AppTheme.leather,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        tileColor: AppTheme.crimson.withOpacity(0.06),
        leading: Icon(icon, color: iconColor),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.ink,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: AppTheme.fadedInk,
            fontSize: 13,
            fontStyle: FontStyle.italic,
          ),
        ),
        onTap: () => _selectCategoryFromDrawer(category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.parchment,
      drawer: Drawer(
        backgroundColor: AppTheme.parchment,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(
                top: 60.0,
                bottom: 24.0,
                left: 20.0,
                right: 20.0,
              ),
              decoration: const BoxDecoration(
                color: AppTheme.leather,
                image: DecorationImage(
                  image: AssetImage(
                    'assets/images/church.webp',
                  ), // Ensure extension matches your file
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Color(0xDA2E211B),
                    BlendMode.darken,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Hymnary',
                    style: TextStyle(
                      color: AppTheme.parchment,
                      fontSize: 28,
                      fontFamily: AppTheme.font,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '“Praise the Lord! Praise God in his sanctuary; Praise him in His mighty firmament.”',
                    style: TextStyle(
                      color: AppTheme.gold,
                      fontSize: 12.0,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '— Psalm 150',
                    style: TextStyle(
                      color: AppTheme.gold,
                      fontSize: 12.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Much cleaner Drawer integration using the extracted widget!
            _buildDrawerTile(
              icon: Icons.library_music,
              title: 'All Songs',
              subtitle: 'Complete Collection',
              category: SongCategory.all,
            ),
            _buildDrawerTile(
              icon: Icons.book,
              title: 'Hymns',
              subtitle: '1 - 95',
              category: SongCategory.hymns,
            ),
            _buildDrawerTile(
              icon: Icons.queue_music,
              title: 'Choruses',
              subtitle: '96 - 202',
              category: SongCategory.choruses,
            ),
            _buildDrawerTile(
              icon: Icons.star,
              title: 'Christmas Carols',
              subtitle: '203 - 215',
              category: SongCategory.carols,
            ),
            _buildDrawerTile(
              icon: Icons.favorite,
              title: 'My Favorites',
              subtitle: 'Saved Hymns',
              category: SongCategory.favorites,
              iconColor: AppTheme.crimson,
            ),

            const SizedBox(height: 16),
            Divider(
              color: AppTheme.gold.withOpacity(0.8),
              thickness: 1.5,
              indent: 16,
              endIndent: 16,
            ),

            ListTile(
              leading: const Icon(Icons.wine_bar, color: AppTheme.crimson),
              title: const Text(
                'The Holy Eucharist',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.crimson,
                  fontSize: 18,
                  fontFamily: AppTheme.font,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EucharistScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: AppTheme.leather,
        elevation: 4,
        iconTheme: const IconThemeData(color: AppTheme.parchment),
        title: TextField(
          controller: _controller,
          keyboardType: TextInputType.text,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.ink,
            fontFamily: AppTheme.font,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(
              0xFFF4EAD5,
            ), // Slightly darker parchment for search bar
            prefixIcon: const Icon(Icons.search, color: AppTheme.leather),
            hintText: 'Search number or title...',
            hintStyle: const TextStyle(
              color: AppTheme.fadedInk,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30.0),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 0,
              horizontal: 16,
            ),
          ),
          autocorrect: false,
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
        actions: [
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: AppTheme.parchment),
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _controller.clear();
                });
                FocusScope.of(context).unfocus();
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.leather),
            )
          : _buildSongList(),
    );
  }

  Widget _buildSongList() {
    final songs = _filteredSongs;

    if (songs.isEmpty) {
      return Center(
        child: Text(
          _currentCategory == SongCategory.favorites
              ? 'No favorite hymns yet.\nTap the heart icon on a hymn to save it!'
              : 'No hymns found.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.ink,
            fontSize: 18,
            fontStyle: FontStyle.italic,
            height: 1.5,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        final isFav = FavoritesService().isFavorite(song.number);

        return InkWell(
          onTap: () {
            FocusScope.of(context).unfocus();
            final globalIndex = _hymnBook.indexWhere(
              (s) => s.number == song.number,
            );

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    LyricScreen(songs: _hymnBook, initialIndex: globalIndex),
              ),
            ).then((_) => setState(() {}));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 18.0,
            ),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE8DCC4), width: 1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 45,
                  child: Text(
                    '${song.number}.',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.leather,
                      fontFamily: AppTheme.font,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    song.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.ink,
                      fontFamily: AppTheme.font,
                    ),
                  ),
                ),
                if (isFav)
                  const Icon(Icons.favorite, color: AppTheme.crimson, size: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ----------------------------------------------------
// READING SCREEN (LYRICS)
// ----------------------------------------------------

class LyricScreen extends StatefulWidget {
  final List<Song> songs;
  final int initialIndex;

  const LyricScreen({
    super.key,
    required this.songs,
    required this.initialIndex,
  });

  @override
  State<LyricScreen> createState() => _LyricScreenState();
}

class _LyricScreenState extends State<LyricScreen> {
  double _fontScale = 1.0;
  late int _currentIndex;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _decreaseFontScale() => setState(() => _fontScale *= 0.9);
  void _increaseFontScale() => setState(() => _fontScale *= 1.1);

  void _toggleFavorite() async {
    final currentSong = widget.songs[_currentIndex];
    await FavoritesService().toggleFavorite(currentSong.number);
    setState(() {});
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _scrollToTop();
    }
  }

  void _goToNext() {
    if (_currentIndex < widget.songs.length - 1) {
      setState(() => _currentIndex++);
      _scrollToTop();
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = _fontScale * 18.0;
    final currentSong = widget.songs[_currentIndex];
    final isFavorite = FavoritesService().isFavorite(currentSong.number);
    final hasPrevious = _currentIndex > 0;
    final hasNext = _currentIndex < widget.songs.length - 1;

    return Scaffold(
      backgroundColor: AppTheme.parchment,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: AppTheme.parchment),
        backgroundColor: AppTheme.leather,
        elevation: 4,
        title: Text(
          'Hymn ${currentSong.number}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.parchment,
            fontFamily: AppTheme.font,
          ),
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 5.0),
            child: IconButton(
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? AppTheme.crimson : AppTheme.leather,
                size: 22,
              ),
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.parchment,
                shape: const CircleBorder(),
              ),
              onPressed: _toggleFavorite,
              tooltip: isFavorite
                  ? 'Remove from Favorites'
                  : 'Add to Favorites',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove, color: AppTheme.parchment),
            onPressed: _decreaseFontScale,
            tooltip: 'Decrease Font',
          ),
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.parchment),
            onPressed: _increaseFontScale,
            tooltip: 'Increase Font',
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Text(
                currentSong.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: fontSize * 1.1,
                  fontWeight: FontWeight.w900,
                  fontFamily: AppTheme.font,
                  color: AppTheme.leather,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 40.0),
            ...currentSong.lyrics.map((block) {
              final isRefrain = block.type == LyricType.refrain;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: 28.0,
                  left: isRefrain ? 32.0 : 0.0,
                ),
                child: Text(
                  block.text,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontFamily: AppTheme.font,
                    fontSize: fontSize,
                    height: 1.6,
                    color: AppTheme.ink,
                    fontStyle: isRefrain ? FontStyle.italic : FontStyle.normal,
                    fontWeight: isRefrain ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 60,
          decoration: const BoxDecoration(
            color: AppTheme.parchment,
            border: Border(top: BorderSide(color: AppTheme.gold, width: 1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: hasPrevious ? _goToPrevious : null,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_back_ios,
                      size: 16,
                      color: hasPrevious ? AppTheme.leather : AppTheme.gold,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "Previous",
                      style: TextStyle(
                        fontFamily: AppTheme.font,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: hasPrevious ? AppTheme.leather : AppTheme.gold,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${currentSong.number} of ${widget.songs.length}',
                style: const TextStyle(
                  fontFamily: AppTheme.font,
                  fontSize: 14,
                  color: AppTheme.fadedInk,
                  fontStyle: FontStyle.italic,
                ),
              ),
              TextButton(
                onPressed: hasNext ? _goToNext : null,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: Row(
                  children: [
                    Text(
                      "Next",
                      style: TextStyle(
                        fontFamily: AppTheme.font,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: hasNext ? AppTheme.leather : AppTheme.gold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: hasNext ? AppTheme.leather : AppTheme.gold,
                    ),
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

// ----------------------------------------------------
// THE HOLY EUCHARIST SCREEN
// ----------------------------------------------------
class EucharistScreen extends StatefulWidget {
  const EucharistScreen({super.key});

  @override
  State<EucharistScreen> createState() => _EucharistScreenState();
}

class _EucharistScreenState extends State<EucharistScreen> {
  double _fontScale = 1.0;

  void _decreaseFontScale() => setState(() => _fontScale *= 0.9);
  void _increaseFontScale() => setState(() => _fontScale *= 1.1);

  Widget _buildSectionTitle(String title, double fontSize) {
    return Padding(
      padding: const EdgeInsets.only(top: 32.0, bottom: 16.0),
      child: Center(
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fontSize * 1.2,
            fontWeight: FontWeight.w900,
            fontFamily: AppTheme.font,
            color: AppTheme.leather,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildLiturgyBlock({
    required String speaker,
    required String text,
    required double fontSize,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontFamily: AppTheme.font,
            fontSize: fontSize,
            height: 1.6,
            color: AppTheme.ink,
          ),
          children: [
            if (speaker.isNotEmpty)
              TextSpan(
                text: "$speaker ",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.crimson,
                ),
              ),
            TextSpan(text: text),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionBlock(String text, double fontSize) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0, left: 16.0, right: 16.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppTheme.font,
          fontSize: fontSize * 0.9,
          height: 1.5,
          fontStyle: FontStyle.italic,
          color: AppTheme.fadedInk,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = _fontScale * 18.0;

    return Scaffold(
      backgroundColor: AppTheme.parchment,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: AppTheme.parchment),
        backgroundColor: AppTheme.leather,
        elevation: 4,
        title: const Text(
          'The Holy Eucharist',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.parchment,
            fontFamily: AppTheme.font,
          ),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.remove, color: AppTheme.parchment),
            onPressed: _decreaseFontScale,
            tooltip: 'Decrease Font',
          ),
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.parchment),
            onPressed: _increaseFontScale,
            tooltip: 'Increase Font',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Text(
                "ORDER OF HOLY COMMUNION",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: fontSize * 1.1,
                  fontWeight: FontWeight.w900,
                  fontFamily: AppTheme.font,
                  color: AppTheme.crimson,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            Divider(color: AppTheme.gold.withOpacity(0.8), thickness: 1.5),

            const SizedBox(height: 24.0),
            _buildLiturgyBlock(
              speaker: "Presbyter:",
              text:
                  "Let a man/woman examine himself/herself, and so eat of the bread and drink of the cup. For anyone who eats and drinks without discerning the body eats and drinks judgement upon himself/herself.",
              fontSize: fontSize,
            ),
            _buildSectionTitle("Prayer of Confession", fontSize),
            _buildLiturgyBlock(
              speaker: "Congregation:",
              text:
                  "Almighty God, our Heavenly Father, we have sinned against you and against one another in thought and word and deed, in the evil we have done and in the good we have not done, through ignorance, through weakness, through our own deliberate fault. We are truly sorry and repent of all our sins. For the sake of your Son, Jesus Christ, who died for us, forgive us all that is past; and grant that we may serve you in newness of life to the glory of your name. Amen.",
              fontSize: fontSize,
            ),
            _buildSectionTitle("The Assurances", fontSize),
            _buildLiturgyBlock(
              speaker: "",
              text:
                  "For God so loved the world that He gave His only begotten Son that whosoever believes in Him should not perish but have eternal life.",
              fontSize: fontSize,
            ),
            _buildLiturgyBlock(
              speaker: "",
              text:
                  "While we were still weak, at the right time Christ died for ungodly. One will hardly die for a righteous man - though perhaps for a good man one will dare even to die, but God shows His love for us in that while we were yet sinners, Christ died for us.",
              fontSize: fontSize,
            ),
            _buildLiturgyBlock(
              speaker: "",
              text:
                  "Jesus said to them I am the bread of life. He who comes to Me shall not hunger, and he who believes in me shall never thirst. I am the living bread which came down from heaven, if any one eats this bread he will live forever and the bread which I shall give for the life of the world is my flesh.",
              fontSize: fontSize,
            ),
            _buildLiturgyBlock(
              speaker: "",
              text:
                  "Truly, truly I say to you unless you eat the flesh of the Son of Man and drink His blood, you have no life in you, he who eats My flesh and drinks My blood, has eternal life and I will raise him up in the last day. For my flesh is food indeed and my blood is drink indeed.",
              fontSize: fontSize,
            ),
            _buildLiturgyBlock(
              speaker: "",
              text:
                  "I received from the Lord what I also delivered to you that the Lord Jesus in the night when He was betrayed took bread and when He had given thanks. He broke it and said, \"This is My body which is for you. Do this in remembrance of Me.\" In the same way also the cup after supper saying this is the new covenant in My blood. Do this as often as you drink it, in remembrance of Me. For as often as you eat this bread and drink the cup, you proclaim the Lord's death until He comes.",
              fontSize: fontSize,
            ),
            _buildSectionTitle("Prayer for the Bread and Cup", fontSize),
            _buildLiturgyBlock(
              speaker: "",
              text:
                  "We do not presume to come to this your table, merciful Lord, trusting in our own righteousness, but in your manifold and great mercies. We are not worthy so much as to gather up the crumbs under your table. But you are the same Lord whose nature is always to have mercy. Grant us therefore, gracious Lord, so to eat the bread, that is the flesh of your dear Son Jesus Christ, and to drink the cup that is His blood, that our sinful bodies and souls may be made clean by His most precious body and blood, and that we may evermore dwell in Him, and He in us.",
              fontSize: fontSize,
            ),
            _buildLiturgyBlock(
              speaker: "",
              text:
                  "Accept through Him, our great high priest, this our sacrifice of thanks and praise; and as we eat and drink these holy gifts in the presence of Your divine majesty, renew us by Your Spirit, inspire us with Your love, and unite us in the body of Your Son, Jesus Christ our Lord. With Him, and in Him, and through Him, by the power of the Holy Spirit, with all who stand before You in earth and heaven, we worship You, Father Almighty, in songs of everlasting praise; Blessing and honour and glory and power be Yours for ever and ever. Amen.",
              fontSize: fontSize,
            ),
            _buildSectionTitle("Breaking of the Bread", fontSize),
            _buildLiturgyBlock(
              speaker: "Presbyter:",
              text:
                  "For in the same night that He was betrayed He took bread and after giving thanks, He broke it, gave it to the disciples and said take, eat, this is My body which is given for you.",
              fontSize: fontSize,
            ),
            _buildInstructionBlock(
              "(Taking the bread individually which indicates our individual relationship with our Lord)",
              fontSize,
            ),
            _buildSectionTitle("Giving the Cup", fontSize),
            _buildLiturgyBlock(
              speaker: "Presbyter:",
              text:
                  "In the same way after supper He took the cup and having given thanks He gave it to them and said drink this all of you, for this is My blood of the new covenant which is shed for you and for the many, for the forgiveness of sins. Do this as often as you drink it in remembrance of me.",
              fontSize: fontSize,
            ),
            _buildInstructionBlock(
              "(Taking the cup together as a sign of our fellowship as a church)",
              fontSize,
            ),
            _buildSectionTitle("Post-Communion Prayer", fontSize),
            _buildLiturgyBlock(
              speaker: "Congregation:",
              text:
                  "Almighty God, we thank you for feeding us with the body and blood of your Son Jesus Christ. Through Him we offer you ourselves to be a living sacrifice. Send us out in the power of your Spirit to live and work to your praise and glory. Amen.",
              fontSize: fontSize,
            ),
            _buildSectionTitle("The Apostle's Creed", fontSize),
            _buildLiturgyBlock(
              speaker: "",
              text:
                  "I believe in God, the Father Almighty, creator of heaven and earth.\n\nI believe in Jesus Christ, his holy Son, our Lord.\n\nHe was conceived by the power of the Holy Spirit and born of the Virgin Mary.\n\nHe suffered under Pontius Pilate was crucified, died and was buried.\n\nHe descended to the dead. On the third day He rose again.\n\nHe ascended into Heaven, and is seated at the right hand of the Father.\n\nHe will come again to judge the living and the dead.\n\nI believe in the Holy Spirit, the holy Catholic Church, the communion of saints, the forgiveness of sins, the resurrection of the body, and the life everlasting. Amen.",
              fontSize: fontSize,
            ),
            const SizedBox(height: 40.0),
          ],
        ),
      ),
    );
  }
}
