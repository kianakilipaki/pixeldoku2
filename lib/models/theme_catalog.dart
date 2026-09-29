class PixelDokuTheme {
  const PixelDokuTheme({
    required this.id,
    required this.name,
    required this.unlockLevel,
    required this.backgroundAsset,
    required this.musicAsset,
    required this.iconAssets,
    required this.profileAssets,
  });

  final String id;
  final String name;
  final int unlockLevel;
  final String backgroundAsset;
  final String musicAsset;
  final List<String> iconAssets;
  final List<String> profileAssets;

  String iconForValue(int value) => iconAssets[value - 1];
}

class ThemeCatalog {
  static const List<PixelDokuTheme> themes = [
    PixelDokuTheme(
      id: 'birds',
      name: 'Birds',
      unlockLevel: 1,
      backgroundAsset: 'lib/assets/themes/birds/MntForest-bg.png',
      musicAsset: 'lib/assets/themes/birds/forest-guitar-lofi-161108.mp3',
      iconAssets: [
        'lib/assets/themes/birds/bird_1.png',
        'lib/assets/themes/birds/bird_2.png',
        'lib/assets/themes/birds/bird_3.png',
        'lib/assets/themes/birds/bird_4.png',
        'lib/assets/themes/birds/bird_5.png',
        'lib/assets/themes/birds/bird_6.png',
        'lib/assets/themes/birds/bird_7.png',
        'lib/assets/themes/birds/bird_8.png',
        'lib/assets/themes/birds/bird_9.png',
      ],
      profileAssets: [
        'lib/assets/themes/birds/bird_1.png',
        'lib/assets/themes/birds/bird_2.png',
        'lib/assets/themes/birds/bird_3.png',
        'lib/assets/themes/birds/bird_4.png',
        'lib/assets/themes/birds/bird_5.png',
        'lib/assets/themes/birds/bird_6.png',
        'lib/assets/themes/birds/bird_7.png',
        'lib/assets/themes/birds/bird_8.png',
        'lib/assets/themes/birds/bird_9.png',
      ],
    ),
    PixelDokuTheme(
      id: 'bugs',
      name: 'Bugs',
      unlockLevel: 11,
      backgroundAsset: 'lib/assets/themes/bugs/leaf-bg.png',
      musicAsset:
          'lib/assets/themes/bugs/whispering-vinyl-loops-lofi-beats-281193.mp3',
      iconAssets: [
        'lib/assets/themes/bugs/bug_1.png',
        'lib/assets/themes/bugs/bug_2.png',
        'lib/assets/themes/bugs/bug_3.png',
        'lib/assets/themes/bugs/bug_4.png',
        'lib/assets/themes/bugs/bug_5.png',
        'lib/assets/themes/bugs/bug_6.png',
        'lib/assets/themes/bugs/bug_7.png',
        'lib/assets/themes/bugs/bug_8.png',
        'lib/assets/themes/bugs/bug_9.png',
      ],
      profileAssets: [
        'lib/assets/themes/bugs/bug_1.png',
        'lib/assets/themes/bugs/bug_2.png',
        'lib/assets/themes/bugs/bug_3.png',
        'lib/assets/themes/bugs/bug_4.png',
        'lib/assets/themes/bugs/bug_5.png',
        'lib/assets/themes/bugs/bug_6.png',
        'lib/assets/themes/bugs/bug_7.png',
        'lib/assets/themes/bugs/bug_8.png',
        'lib/assets/themes/bugs/bug_9.png',
      ],
    ),
    PixelDokuTheme(
      id: 'cats',
      name: 'Cats',
      unlockLevel: 21,
      backgroundAsset: 'lib/assets/themes/cats/cat-city.png',
      musicAsset:
          'lib/assets/themes/cats/lofi-song-memories-sunbeam-by-lofium-242711.mp3',
      iconAssets: [
        'lib/assets/themes/cats/cat_1.png',
        'lib/assets/themes/cats/cat_2.png',
        'lib/assets/themes/cats/cat_3.png',
        'lib/assets/themes/cats/cat_4.png',
        'lib/assets/themes/cats/cat_5.png',
        'lib/assets/themes/cats/cat_6.png',
        'lib/assets/themes/cats/cat_7.png',
        'lib/assets/themes/cats/cat_8.png',
        'lib/assets/themes/cats/cat_9.png',
      ],
      profileAssets: [
        'lib/assets/themes/cats/cat_1.png',
        'lib/assets/themes/cats/cat_2.png',
        'lib/assets/themes/cats/cat_3.png',
        'lib/assets/themes/cats/cat_4.png',
        'lib/assets/themes/cats/cat_5.png',
        'lib/assets/themes/cats/cat_6.png',
        'lib/assets/themes/cats/cat_7.png',
        'lib/assets/themes/cats/cat_8.png',
        'lib/assets/themes/cats/cat_9.png',
      ],
    ),
    PixelDokuTheme(
      id: 'dogs',
      name: 'Dogs',
      unlockLevel: 31,
      backgroundAsset: 'lib/assets/themes/dogs/dog-park.png',
      musicAsset:
          'lib/assets/themes/dogs/good-morning-upbeat-happy-ukulele-244395.mp3',
      iconAssets: [
        'lib/assets/themes/dogs/dog_1.png',
        'lib/assets/themes/dogs/dog_2.png',
        'lib/assets/themes/dogs/dog_3.png',
        'lib/assets/themes/dogs/dog_4.png',
        'lib/assets/themes/dogs/dog_5.png',
        'lib/assets/themes/dogs/dog_6.png',
        'lib/assets/themes/dogs/dog_7.png',
        'lib/assets/themes/dogs/dog_8.png',
        'lib/assets/themes/dogs/dog_9.png',
      ],
      profileAssets: [
        'lib/assets/themes/dogs/dog_1.png',
        'lib/assets/themes/dogs/dog_2.png',
        'lib/assets/themes/dogs/dog_3.png',
        'lib/assets/themes/dogs/dog_4.png',
        'lib/assets/themes/dogs/dog_5.png',
        'lib/assets/themes/dogs/dog_6.png',
        'lib/assets/themes/dogs/dog_7.png',
        'lib/assets/themes/dogs/dog_8.png',
        'lib/assets/themes/dogs/dog_9.png',
      ],
    ),
    PixelDokuTheme(
      id: 'fish',
      name: 'Fish',
      unlockLevel: 41,
      backgroundAsset: 'lib/assets/themes/fish/ocean-bg.png',
      musicAsset:
          'lib/assets/themes/fish/waves-of-solitude-lofi-beats-281203.mp3',
      iconAssets: [
        'lib/assets/themes/fish/fish_1.png',
        'lib/assets/themes/fish/fish_2.png',
        'lib/assets/themes/fish/fish_3.png',
        'lib/assets/themes/fish/fish_4.png',
        'lib/assets/themes/fish/fish_5.png',
        'lib/assets/themes/fish/fish_6.png',
        'lib/assets/themes/fish/fish_7.png',
        'lib/assets/themes/fish/fish_8.png',
        'lib/assets/themes/fish/fish_9.png',
      ],
      profileAssets: [
        'lib/assets/themes/fish/fish_1.png',
        'lib/assets/themes/fish/fish_2.png',
        'lib/assets/themes/fish/fish_3.png',
        'lib/assets/themes/fish/fish_4.png',
        'lib/assets/themes/fish/fish_5.png',
        'lib/assets/themes/fish/fish_6.png',
        'lib/assets/themes/fish/fish_7.png',
        'lib/assets/themes/fish/fish_8.png',
        'lib/assets/themes/fish/fish_9.png',
      ],
    ),
    PixelDokuTheme(
      id: 'swamp',
      name: 'Swamp',
      unlockLevel: 51,
      backgroundAsset: 'lib/assets/themes/swamp/swamp-bg.png',
      musicAsset:
          'lib/assets/themes/swamp/hip-hoprock-bayou-cheifin-blues-191536.mp3',
      iconAssets: [
        'lib/assets/themes/swamp/amphibian_1.png',
        'lib/assets/themes/swamp/amphibian_2.png',
        'lib/assets/themes/swamp/amphibian_3.png',
        'lib/assets/themes/swamp/amphibian_4.png',
        'lib/assets/themes/swamp/amphibian_5.png',
        'lib/assets/themes/swamp/amphibian_6.png',
        'lib/assets/themes/swamp/amphibian_7.png',
        'lib/assets/themes/swamp/amphibian_8.png',
        'lib/assets/themes/swamp/amphibian_9.png',
      ],
      profileAssets: [
        'lib/assets/themes/swamp/amphibian_1.png',
        'lib/assets/themes/swamp/amphibian_2.png',
        'lib/assets/themes/swamp/amphibian_3.png',
        'lib/assets/themes/swamp/amphibian_4.png',
        'lib/assets/themes/swamp/amphibian_5.png',
        'lib/assets/themes/swamp/amphibian_6.png',
        'lib/assets/themes/swamp/amphibian_7.png',
        'lib/assets/themes/swamp/amphibian_8.png',
        'lib/assets/themes/swamp/amphibian_9.png',
      ],
    ),
    PixelDokuTheme(
      id: 'forest',
      name: 'Forest',
      unlockLevel: 61,
      backgroundAsset: 'lib/assets/themes/forest/forest-bg.png',
      musicAsset: 'lib/assets/themes/birds/forest-guitar-lofi-161108.mp3',
      iconAssets: [
        'lib/assets/themes/forest/woods_1.png',
        'lib/assets/themes/forest/woods_2.png',
        'lib/assets/themes/forest/woods_3.png',
        'lib/assets/themes/forest/woods_4.png',
        'lib/assets/themes/forest/woods_5.png',
        'lib/assets/themes/forest/woods_6.png',
        'lib/assets/themes/forest/woods_7.png',
        'lib/assets/themes/forest/woods_8.png',
        'lib/assets/themes/forest/woods_9.png',
      ],
      profileAssets: [
        'lib/assets/themes/forest/woods_1.png',
        'lib/assets/themes/forest/woods_2.png',
        'lib/assets/themes/forest/woods_3.png',
        'lib/assets/themes/forest/woods_4.png',
        'lib/assets/themes/forest/woods_5.png',
        'lib/assets/themes/forest/woods_6.png',
        'lib/assets/themes/forest/woods_7.png',
        'lib/assets/themes/forest/woods_8.png',
        'lib/assets/themes/forest/woods_9.png',
      ],
    ),
  ];

  static List<String> get allProfileAssets {
    return themes
        .expand((theme) => theme.profileAssets)
        .toList(growable: false);
  }

  static PixelDokuTheme byId(String id) {
    return themes.firstWhere(
      (theme) => theme.id == id,
      orElse: () => themes.first,
    );
  }

  /// Theme assigned to a standard level based on its unlock tier.
  static PixelDokuTheme forLevel(int level) {
    var result = themes.first;
    for (final theme in themes) {
      if (level < theme.unlockLevel) break;
      result = theme;
    }
    return result;
  }

  static List<String> unlockedThemeIdsForLevel(int level) {
    return themes
        .where((theme) => level >= theme.unlockLevel)
        .map((theme) => theme.id)
        .toList();
  }
}
