// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $GameFoldersTable extends GameFolders
    with TableInfo<$GameFoldersTable, GameFolder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GameFoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 128,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _includeInTotalTimeMeta =
      const VerificationMeta('includeInTotalTime');
  @override
  late final GeneratedColumn<bool> includeInTotalTime = GeneratedColumn<bool>(
    'include_in_total_time',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("include_in_total_time" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _showOnHomeMeta = const VerificationMeta(
    'showOnHome',
  );
  @override
  late final GeneratedColumn<bool> showOnHome = GeneratedColumn<bool>(
    'show_on_home',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_on_home" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    sortOrder,
    includeInTotalTime,
    showOnHome,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'game_folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<GameFolder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('include_in_total_time')) {
      context.handle(
        _includeInTotalTimeMeta,
        includeInTotalTime.isAcceptableOrUnknown(
          data['include_in_total_time']!,
          _includeInTotalTimeMeta,
        ),
      );
    }
    if (data.containsKey('show_on_home')) {
      context.handle(
        _showOnHomeMeta,
        showOnHome.isAcceptableOrUnknown(
          data['show_on_home']!,
          _showOnHomeMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GameFolder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GameFolder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      includeInTotalTime: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}include_in_total_time'],
      )!,
      showOnHome: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_on_home'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $GameFoldersTable createAlias(String alias) {
    return $GameFoldersTable(attachedDatabase, alias);
  }
}

class GameFolder extends DataClass implements Insertable<GameFolder> {
  final int id;

  /// 文件夹名称（如在玩、已玩过、待玩或自定义名称）
  final String name;

  /// 排序序号
  final int sortOrder;

  /// 旧版兼容字段：不再参与 UI 或排序逻辑。
  final bool includeInTotalTime;

  /// 是否在“全部游戏”主页显示该文件夹卡片。
  final bool showOnHome;
  final DateTime createdAt;
  const GameFolder({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.includeInTotalTime,
    required this.showOnHome,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['sort_order'] = Variable<int>(sortOrder);
    map['include_in_total_time'] = Variable<bool>(includeInTotalTime);
    map['show_on_home'] = Variable<bool>(showOnHome);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  GameFoldersCompanion toCompanion(bool nullToAbsent) {
    return GameFoldersCompanion(
      id: Value(id),
      name: Value(name),
      sortOrder: Value(sortOrder),
      includeInTotalTime: Value(includeInTotalTime),
      showOnHome: Value(showOnHome),
      createdAt: Value(createdAt),
    );
  }

  factory GameFolder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GameFolder(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      includeInTotalTime: serializer.fromJson<bool>(json['includeInTotalTime']),
      showOnHome: serializer.fromJson<bool>(json['showOnHome']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'includeInTotalTime': serializer.toJson<bool>(includeInTotalTime),
      'showOnHome': serializer.toJson<bool>(showOnHome),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  GameFolder copyWith({
    int? id,
    String? name,
    int? sortOrder,
    bool? includeInTotalTime,
    bool? showOnHome,
    DateTime? createdAt,
  }) => GameFolder(
    id: id ?? this.id,
    name: name ?? this.name,
    sortOrder: sortOrder ?? this.sortOrder,
    includeInTotalTime: includeInTotalTime ?? this.includeInTotalTime,
    showOnHome: showOnHome ?? this.showOnHome,
    createdAt: createdAt ?? this.createdAt,
  );
  GameFolder copyWithCompanion(GameFoldersCompanion data) {
    return GameFolder(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      includeInTotalTime: data.includeInTotalTime.present
          ? data.includeInTotalTime.value
          : this.includeInTotalTime,
      showOnHome: data.showOnHome.present
          ? data.showOnHome.value
          : this.showOnHome,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GameFolder(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('includeInTotalTime: $includeInTotalTime, ')
          ..write('showOnHome: $showOnHome, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    sortOrder,
    includeInTotalTime,
    showOnHome,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GameFolder &&
          other.id == this.id &&
          other.name == this.name &&
          other.sortOrder == this.sortOrder &&
          other.includeInTotalTime == this.includeInTotalTime &&
          other.showOnHome == this.showOnHome &&
          other.createdAt == this.createdAt);
}

class GameFoldersCompanion extends UpdateCompanion<GameFolder> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> sortOrder;
  final Value<bool> includeInTotalTime;
  final Value<bool> showOnHome;
  final Value<DateTime> createdAt;
  const GameFoldersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.includeInTotalTime = const Value.absent(),
    this.showOnHome = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  GameFoldersCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.sortOrder = const Value.absent(),
    this.includeInTotalTime = const Value.absent(),
    this.showOnHome = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<GameFolder> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? sortOrder,
    Expression<bool>? includeInTotalTime,
    Expression<bool>? showOnHome,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (includeInTotalTime != null)
        'include_in_total_time': includeInTotalTime,
      if (showOnHome != null) 'show_on_home': showOnHome,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  GameFoldersCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? sortOrder,
    Value<bool>? includeInTotalTime,
    Value<bool>? showOnHome,
    Value<DateTime>? createdAt,
  }) {
    return GameFoldersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      includeInTotalTime: includeInTotalTime ?? this.includeInTotalTime,
      showOnHome: showOnHome ?? this.showOnHome,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (includeInTotalTime.present) {
      map['include_in_total_time'] = Variable<bool>(includeInTotalTime.value);
    }
    if (showOnHome.present) {
      map['show_on_home'] = Variable<bool>(showOnHome.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GameFoldersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('includeInTotalTime: $includeInTotalTime, ')
          ..write('showOnHome: $showOnHome, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $GamesTable extends Games with TableInfo<$GamesTable, Game> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GamesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 512,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exePathMeta = const VerificationMeta(
    'exePath',
  );
  @override
  late final GeneratedColumn<String> exePath = GeneratedColumn<String>(
    'exe_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _dirPathMeta = const VerificationMeta(
    'dirPath',
  );
  @override
  late final GeneratedColumn<String> dirPath = GeneratedColumn<String>(
    'dir_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconPngMeta = const VerificationMeta(
    'iconPng',
  );
  @override
  late final GeneratedColumn<Uint8List> iconPng = GeneratedColumn<Uint8List>(
    'icon_png',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backgroundPathMeta = const VerificationMeta(
    'backgroundPath',
  );
  @override
  late final GeneratedColumn<String> backgroundPath = GeneratedColumn<String>(
    'background_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detailBackgroundPathMeta =
      const VerificationMeta('detailBackgroundPath');
  @override
  late final GeneratedColumn<String> detailBackgroundPath =
      GeneratedColumn<String>(
        'detail_background_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _backgroundBlurAmountMeta =
      const VerificationMeta('backgroundBlurAmount');
  @override
  late final GeneratedColumn<double> backgroundBlurAmount =
      GeneratedColumn<double>(
        'background_blur_amount',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0.0),
      );
  static const VerificationMeta _launchArgsMeta = const VerificationMeta(
    'launchArgs',
  );
  @override
  late final GeneratedColumn<String> launchArgs = GeneratedColumn<String>(
    'launch_args',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _useLocaleEmulatorMeta = const VerificationMeta(
    'useLocaleEmulator',
  );
  @override
  late final GeneratedColumn<bool> useLocaleEmulator = GeneratedColumn<bool>(
    'use_locale_emulator',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("use_locale_emulator" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _leProfileMeta = const VerificationMeta(
    'leProfile',
  );
  @override
  late final GeneratedColumn<String> leProfile = GeneratedColumn<String>(
    'le_profile',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _lastPlayedAtMeta = const VerificationMeta(
    'lastPlayedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastPlayedAt = GeneratedColumn<DateTime>(
    'last_played_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalPlaySecondsMeta = const VerificationMeta(
    'totalPlaySeconds',
  );
  @override
  late final GeneratedColumn<int> totalPlaySeconds = GeneratedColumn<int>(
    'total_play_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _favoriteMeta = const VerificationMeta(
    'favorite',
  );
  @override
  late final GeneratedColumn<bool> favorite = GeneratedColumn<bool>(
    'favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<int> folderId = GeneratedColumn<int>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES game_folders (id)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    exePath,
    dirPath,
    iconPng,
    backgroundPath,
    detailBackgroundPath,
    backgroundBlurAmount,
    launchArgs,
    useLocaleEmulator,
    leProfile,
    createdAt,
    lastPlayedAt,
    totalPlaySeconds,
    favorite,
    folderId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'games';
  @override
  VerificationContext validateIntegrity(
    Insertable<Game> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('exe_path')) {
      context.handle(
        _exePathMeta,
        exePath.isAcceptableOrUnknown(data['exe_path']!, _exePathMeta),
      );
    } else if (isInserting) {
      context.missing(_exePathMeta);
    }
    if (data.containsKey('dir_path')) {
      context.handle(
        _dirPathMeta,
        dirPath.isAcceptableOrUnknown(data['dir_path']!, _dirPathMeta),
      );
    } else if (isInserting) {
      context.missing(_dirPathMeta);
    }
    if (data.containsKey('icon_png')) {
      context.handle(
        _iconPngMeta,
        iconPng.isAcceptableOrUnknown(data['icon_png']!, _iconPngMeta),
      );
    }
    if (data.containsKey('background_path')) {
      context.handle(
        _backgroundPathMeta,
        backgroundPath.isAcceptableOrUnknown(
          data['background_path']!,
          _backgroundPathMeta,
        ),
      );
    }
    if (data.containsKey('detail_background_path')) {
      context.handle(
        _detailBackgroundPathMeta,
        detailBackgroundPath.isAcceptableOrUnknown(
          data['detail_background_path']!,
          _detailBackgroundPathMeta,
        ),
      );
    }
    if (data.containsKey('background_blur_amount')) {
      context.handle(
        _backgroundBlurAmountMeta,
        backgroundBlurAmount.isAcceptableOrUnknown(
          data['background_blur_amount']!,
          _backgroundBlurAmountMeta,
        ),
      );
    }
    if (data.containsKey('launch_args')) {
      context.handle(
        _launchArgsMeta,
        launchArgs.isAcceptableOrUnknown(data['launch_args']!, _launchArgsMeta),
      );
    }
    if (data.containsKey('use_locale_emulator')) {
      context.handle(
        _useLocaleEmulatorMeta,
        useLocaleEmulator.isAcceptableOrUnknown(
          data['use_locale_emulator']!,
          _useLocaleEmulatorMeta,
        ),
      );
    }
    if (data.containsKey('le_profile')) {
      context.handle(
        _leProfileMeta,
        leProfile.isAcceptableOrUnknown(data['le_profile']!, _leProfileMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('last_played_at')) {
      context.handle(
        _lastPlayedAtMeta,
        lastPlayedAt.isAcceptableOrUnknown(
          data['last_played_at']!,
          _lastPlayedAtMeta,
        ),
      );
    }
    if (data.containsKey('total_play_seconds')) {
      context.handle(
        _totalPlaySecondsMeta,
        totalPlaySeconds.isAcceptableOrUnknown(
          data['total_play_seconds']!,
          _totalPlaySecondsMeta,
        ),
      );
    }
    if (data.containsKey('favorite')) {
      context.handle(
        _favoriteMeta,
        favorite.isAcceptableOrUnknown(data['favorite']!, _favoriteMeta),
      );
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Game map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Game(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      exePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exe_path'],
      )!,
      dirPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dir_path'],
      )!,
      iconPng: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}icon_png'],
      ),
      backgroundPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}background_path'],
      ),
      detailBackgroundPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail_background_path'],
      ),
      backgroundBlurAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}background_blur_amount'],
      )!,
      launchArgs: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}launch_args'],
      )!,
      useLocaleEmulator: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}use_locale_emulator'],
      )!,
      leProfile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}le_profile'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastPlayedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_played_at'],
      ),
      totalPlaySeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_play_seconds'],
      )!,
      favorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}favorite'],
      )!,
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}folder_id'],
      ),
    );
  }

  @override
  $GamesTable createAlias(String alias) {
    return $GamesTable(attachedDatabase, alias);
  }
}

class Game extends DataClass implements Insertable<Game> {
  final int id;

  /// 展示标题（默认取 PE FileDescription / ProductName / 目录名）。
  final String title;

  /// 标准化 exe 绝对路径（唯一）。
  final String exePath;

  /// exe 所在目录（启动工作目录 / LE 参数用）。
  final String dirPath;

  /// PE 提取的图标（PNG 字节，惰性生成，可为空）。
  final Uint8List? iconPng;

  /// 背景图的本地缓存路径；不把大图写入 SQLite。
  final String? backgroundPath;

  /// 详情弹窗专用的低分辨率模糊背景缓存路径。
  final String? detailBackgroundPath;

  /// 详情背景模糊派生图覆盖原图的强度（0 = 清晰）。
  final double backgroundBlurAmount;

  /// 附加启动参数。
  final String launchArgs;

  /// 是否经 Locale Emulator 代理启动。
  final bool useLocaleEmulator;

  /// LE Profile 名 / GUID（留空 = LEProc 默认行为）。
  final String leProfile;
  final DateTime createdAt;
  final DateTime? lastPlayedAt;

  /// 累计游玩秒数（会话提交时增量维护的冗余缓存，避免列表页聚合查询）。
  final int totalPlaySeconds;

  /// 收藏标记。
  final bool favorite;

  /// 所属自定义文件夹 ID（为空表示未归类/默认未放入文件夹）。
  final int? folderId;
  const Game({
    required this.id,
    required this.title,
    required this.exePath,
    required this.dirPath,
    this.iconPng,
    this.backgroundPath,
    this.detailBackgroundPath,
    required this.backgroundBlurAmount,
    required this.launchArgs,
    required this.useLocaleEmulator,
    required this.leProfile,
    required this.createdAt,
    this.lastPlayedAt,
    required this.totalPlaySeconds,
    required this.favorite,
    this.folderId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['exe_path'] = Variable<String>(exePath);
    map['dir_path'] = Variable<String>(dirPath);
    if (!nullToAbsent || iconPng != null) {
      map['icon_png'] = Variable<Uint8List>(iconPng);
    }
    if (!nullToAbsent || backgroundPath != null) {
      map['background_path'] = Variable<String>(backgroundPath);
    }
    if (!nullToAbsent || detailBackgroundPath != null) {
      map['detail_background_path'] = Variable<String>(detailBackgroundPath);
    }
    map['background_blur_amount'] = Variable<double>(backgroundBlurAmount);
    map['launch_args'] = Variable<String>(launchArgs);
    map['use_locale_emulator'] = Variable<bool>(useLocaleEmulator);
    map['le_profile'] = Variable<String>(leProfile);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastPlayedAt != null) {
      map['last_played_at'] = Variable<DateTime>(lastPlayedAt);
    }
    map['total_play_seconds'] = Variable<int>(totalPlaySeconds);
    map['favorite'] = Variable<bool>(favorite);
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<int>(folderId);
    }
    return map;
  }

  GamesCompanion toCompanion(bool nullToAbsent) {
    return GamesCompanion(
      id: Value(id),
      title: Value(title),
      exePath: Value(exePath),
      dirPath: Value(dirPath),
      iconPng: iconPng == null && nullToAbsent
          ? const Value.absent()
          : Value(iconPng),
      backgroundPath: backgroundPath == null && nullToAbsent
          ? const Value.absent()
          : Value(backgroundPath),
      detailBackgroundPath: detailBackgroundPath == null && nullToAbsent
          ? const Value.absent()
          : Value(detailBackgroundPath),
      backgroundBlurAmount: Value(backgroundBlurAmount),
      launchArgs: Value(launchArgs),
      useLocaleEmulator: Value(useLocaleEmulator),
      leProfile: Value(leProfile),
      createdAt: Value(createdAt),
      lastPlayedAt: lastPlayedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPlayedAt),
      totalPlaySeconds: Value(totalPlaySeconds),
      favorite: Value(favorite),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
    );
  }

  factory Game.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Game(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      exePath: serializer.fromJson<String>(json['exePath']),
      dirPath: serializer.fromJson<String>(json['dirPath']),
      iconPng: serializer.fromJson<Uint8List?>(json['iconPng']),
      backgroundPath: serializer.fromJson<String?>(json['backgroundPath']),
      detailBackgroundPath: serializer.fromJson<String?>(
        json['detailBackgroundPath'],
      ),
      backgroundBlurAmount: serializer.fromJson<double>(
        json['backgroundBlurAmount'],
      ),
      launchArgs: serializer.fromJson<String>(json['launchArgs']),
      useLocaleEmulator: serializer.fromJson<bool>(json['useLocaleEmulator']),
      leProfile: serializer.fromJson<String>(json['leProfile']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastPlayedAt: serializer.fromJson<DateTime?>(json['lastPlayedAt']),
      totalPlaySeconds: serializer.fromJson<int>(json['totalPlaySeconds']),
      favorite: serializer.fromJson<bool>(json['favorite']),
      folderId: serializer.fromJson<int?>(json['folderId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'exePath': serializer.toJson<String>(exePath),
      'dirPath': serializer.toJson<String>(dirPath),
      'iconPng': serializer.toJson<Uint8List?>(iconPng),
      'backgroundPath': serializer.toJson<String?>(backgroundPath),
      'detailBackgroundPath': serializer.toJson<String?>(detailBackgroundPath),
      'backgroundBlurAmount': serializer.toJson<double>(backgroundBlurAmount),
      'launchArgs': serializer.toJson<String>(launchArgs),
      'useLocaleEmulator': serializer.toJson<bool>(useLocaleEmulator),
      'leProfile': serializer.toJson<String>(leProfile),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastPlayedAt': serializer.toJson<DateTime?>(lastPlayedAt),
      'totalPlaySeconds': serializer.toJson<int>(totalPlaySeconds),
      'favorite': serializer.toJson<bool>(favorite),
      'folderId': serializer.toJson<int?>(folderId),
    };
  }

  Game copyWith({
    int? id,
    String? title,
    String? exePath,
    String? dirPath,
    Value<Uint8List?> iconPng = const Value.absent(),
    Value<String?> backgroundPath = const Value.absent(),
    Value<String?> detailBackgroundPath = const Value.absent(),
    double? backgroundBlurAmount,
    String? launchArgs,
    bool? useLocaleEmulator,
    String? leProfile,
    DateTime? createdAt,
    Value<DateTime?> lastPlayedAt = const Value.absent(),
    int? totalPlaySeconds,
    bool? favorite,
    Value<int?> folderId = const Value.absent(),
  }) => Game(
    id: id ?? this.id,
    title: title ?? this.title,
    exePath: exePath ?? this.exePath,
    dirPath: dirPath ?? this.dirPath,
    iconPng: iconPng.present ? iconPng.value : this.iconPng,
    backgroundPath: backgroundPath.present
        ? backgroundPath.value
        : this.backgroundPath,
    detailBackgroundPath: detailBackgroundPath.present
        ? detailBackgroundPath.value
        : this.detailBackgroundPath,
    backgroundBlurAmount: backgroundBlurAmount ?? this.backgroundBlurAmount,
    launchArgs: launchArgs ?? this.launchArgs,
    useLocaleEmulator: useLocaleEmulator ?? this.useLocaleEmulator,
    leProfile: leProfile ?? this.leProfile,
    createdAt: createdAt ?? this.createdAt,
    lastPlayedAt: lastPlayedAt.present ? lastPlayedAt.value : this.lastPlayedAt,
    totalPlaySeconds: totalPlaySeconds ?? this.totalPlaySeconds,
    favorite: favorite ?? this.favorite,
    folderId: folderId.present ? folderId.value : this.folderId,
  );
  Game copyWithCompanion(GamesCompanion data) {
    return Game(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      exePath: data.exePath.present ? data.exePath.value : this.exePath,
      dirPath: data.dirPath.present ? data.dirPath.value : this.dirPath,
      iconPng: data.iconPng.present ? data.iconPng.value : this.iconPng,
      backgroundPath: data.backgroundPath.present
          ? data.backgroundPath.value
          : this.backgroundPath,
      detailBackgroundPath: data.detailBackgroundPath.present
          ? data.detailBackgroundPath.value
          : this.detailBackgroundPath,
      backgroundBlurAmount: data.backgroundBlurAmount.present
          ? data.backgroundBlurAmount.value
          : this.backgroundBlurAmount,
      launchArgs: data.launchArgs.present
          ? data.launchArgs.value
          : this.launchArgs,
      useLocaleEmulator: data.useLocaleEmulator.present
          ? data.useLocaleEmulator.value
          : this.useLocaleEmulator,
      leProfile: data.leProfile.present ? data.leProfile.value : this.leProfile,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastPlayedAt: data.lastPlayedAt.present
          ? data.lastPlayedAt.value
          : this.lastPlayedAt,
      totalPlaySeconds: data.totalPlaySeconds.present
          ? data.totalPlaySeconds.value
          : this.totalPlaySeconds,
      favorite: data.favorite.present ? data.favorite.value : this.favorite,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Game(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('exePath: $exePath, ')
          ..write('dirPath: $dirPath, ')
          ..write('iconPng: $iconPng, ')
          ..write('backgroundPath: $backgroundPath, ')
          ..write('detailBackgroundPath: $detailBackgroundPath, ')
          ..write('backgroundBlurAmount: $backgroundBlurAmount, ')
          ..write('launchArgs: $launchArgs, ')
          ..write('useLocaleEmulator: $useLocaleEmulator, ')
          ..write('leProfile: $leProfile, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('totalPlaySeconds: $totalPlaySeconds, ')
          ..write('favorite: $favorite, ')
          ..write('folderId: $folderId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    exePath,
    dirPath,
    $driftBlobEquality.hash(iconPng),
    backgroundPath,
    detailBackgroundPath,
    backgroundBlurAmount,
    launchArgs,
    useLocaleEmulator,
    leProfile,
    createdAt,
    lastPlayedAt,
    totalPlaySeconds,
    favorite,
    folderId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Game &&
          other.id == this.id &&
          other.title == this.title &&
          other.exePath == this.exePath &&
          other.dirPath == this.dirPath &&
          $driftBlobEquality.equals(other.iconPng, this.iconPng) &&
          other.backgroundPath == this.backgroundPath &&
          other.detailBackgroundPath == this.detailBackgroundPath &&
          other.backgroundBlurAmount == this.backgroundBlurAmount &&
          other.launchArgs == this.launchArgs &&
          other.useLocaleEmulator == this.useLocaleEmulator &&
          other.leProfile == this.leProfile &&
          other.createdAt == this.createdAt &&
          other.lastPlayedAt == this.lastPlayedAt &&
          other.totalPlaySeconds == this.totalPlaySeconds &&
          other.favorite == this.favorite &&
          other.folderId == this.folderId);
}

class GamesCompanion extends UpdateCompanion<Game> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> exePath;
  final Value<String> dirPath;
  final Value<Uint8List?> iconPng;
  final Value<String?> backgroundPath;
  final Value<String?> detailBackgroundPath;
  final Value<double> backgroundBlurAmount;
  final Value<String> launchArgs;
  final Value<bool> useLocaleEmulator;
  final Value<String> leProfile;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastPlayedAt;
  final Value<int> totalPlaySeconds;
  final Value<bool> favorite;
  final Value<int?> folderId;
  const GamesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.exePath = const Value.absent(),
    this.dirPath = const Value.absent(),
    this.iconPng = const Value.absent(),
    this.backgroundPath = const Value.absent(),
    this.detailBackgroundPath = const Value.absent(),
    this.backgroundBlurAmount = const Value.absent(),
    this.launchArgs = const Value.absent(),
    this.useLocaleEmulator = const Value.absent(),
    this.leProfile = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.totalPlaySeconds = const Value.absent(),
    this.favorite = const Value.absent(),
    this.folderId = const Value.absent(),
  });
  GamesCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required String exePath,
    required String dirPath,
    this.iconPng = const Value.absent(),
    this.backgroundPath = const Value.absent(),
    this.detailBackgroundPath = const Value.absent(),
    this.backgroundBlurAmount = const Value.absent(),
    this.launchArgs = const Value.absent(),
    this.useLocaleEmulator = const Value.absent(),
    this.leProfile = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.totalPlaySeconds = const Value.absent(),
    this.favorite = const Value.absent(),
    this.folderId = const Value.absent(),
  }) : title = Value(title),
       exePath = Value(exePath),
       dirPath = Value(dirPath);
  static Insertable<Game> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? exePath,
    Expression<String>? dirPath,
    Expression<Uint8List>? iconPng,
    Expression<String>? backgroundPath,
    Expression<String>? detailBackgroundPath,
    Expression<double>? backgroundBlurAmount,
    Expression<String>? launchArgs,
    Expression<bool>? useLocaleEmulator,
    Expression<String>? leProfile,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastPlayedAt,
    Expression<int>? totalPlaySeconds,
    Expression<bool>? favorite,
    Expression<int>? folderId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (exePath != null) 'exe_path': exePath,
      if (dirPath != null) 'dir_path': dirPath,
      if (iconPng != null) 'icon_png': iconPng,
      if (backgroundPath != null) 'background_path': backgroundPath,
      if (detailBackgroundPath != null)
        'detail_background_path': detailBackgroundPath,
      if (backgroundBlurAmount != null)
        'background_blur_amount': backgroundBlurAmount,
      if (launchArgs != null) 'launch_args': launchArgs,
      if (useLocaleEmulator != null) 'use_locale_emulator': useLocaleEmulator,
      if (leProfile != null) 'le_profile': leProfile,
      if (createdAt != null) 'created_at': createdAt,
      if (lastPlayedAt != null) 'last_played_at': lastPlayedAt,
      if (totalPlaySeconds != null) 'total_play_seconds': totalPlaySeconds,
      if (favorite != null) 'favorite': favorite,
      if (folderId != null) 'folder_id': folderId,
    });
  }

  GamesCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String>? exePath,
    Value<String>? dirPath,
    Value<Uint8List?>? iconPng,
    Value<String?>? backgroundPath,
    Value<String?>? detailBackgroundPath,
    Value<double>? backgroundBlurAmount,
    Value<String>? launchArgs,
    Value<bool>? useLocaleEmulator,
    Value<String>? leProfile,
    Value<DateTime>? createdAt,
    Value<DateTime?>? lastPlayedAt,
    Value<int>? totalPlaySeconds,
    Value<bool>? favorite,
    Value<int?>? folderId,
  }) {
    return GamesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      exePath: exePath ?? this.exePath,
      dirPath: dirPath ?? this.dirPath,
      iconPng: iconPng ?? this.iconPng,
      backgroundPath: backgroundPath ?? this.backgroundPath,
      detailBackgroundPath: detailBackgroundPath ?? this.detailBackgroundPath,
      backgroundBlurAmount: backgroundBlurAmount ?? this.backgroundBlurAmount,
      launchArgs: launchArgs ?? this.launchArgs,
      useLocaleEmulator: useLocaleEmulator ?? this.useLocaleEmulator,
      leProfile: leProfile ?? this.leProfile,
      createdAt: createdAt ?? this.createdAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      totalPlaySeconds: totalPlaySeconds ?? this.totalPlaySeconds,
      favorite: favorite ?? this.favorite,
      folderId: folderId ?? this.folderId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (exePath.present) {
      map['exe_path'] = Variable<String>(exePath.value);
    }
    if (dirPath.present) {
      map['dir_path'] = Variable<String>(dirPath.value);
    }
    if (iconPng.present) {
      map['icon_png'] = Variable<Uint8List>(iconPng.value);
    }
    if (backgroundPath.present) {
      map['background_path'] = Variable<String>(backgroundPath.value);
    }
    if (detailBackgroundPath.present) {
      map['detail_background_path'] = Variable<String>(
        detailBackgroundPath.value,
      );
    }
    if (backgroundBlurAmount.present) {
      map['background_blur_amount'] = Variable<double>(
        backgroundBlurAmount.value,
      );
    }
    if (launchArgs.present) {
      map['launch_args'] = Variable<String>(launchArgs.value);
    }
    if (useLocaleEmulator.present) {
      map['use_locale_emulator'] = Variable<bool>(useLocaleEmulator.value);
    }
    if (leProfile.present) {
      map['le_profile'] = Variable<String>(leProfile.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastPlayedAt.present) {
      map['last_played_at'] = Variable<DateTime>(lastPlayedAt.value);
    }
    if (totalPlaySeconds.present) {
      map['total_play_seconds'] = Variable<int>(totalPlaySeconds.value);
    }
    if (favorite.present) {
      map['favorite'] = Variable<bool>(favorite.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<int>(folderId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GamesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('exePath: $exePath, ')
          ..write('dirPath: $dirPath, ')
          ..write('iconPng: $iconPng, ')
          ..write('backgroundPath: $backgroundPath, ')
          ..write('detailBackgroundPath: $detailBackgroundPath, ')
          ..write('backgroundBlurAmount: $backgroundBlurAmount, ')
          ..write('launchArgs: $launchArgs, ')
          ..write('useLocaleEmulator: $useLocaleEmulator, ')
          ..write('leProfile: $leProfile, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('totalPlaySeconds: $totalPlaySeconds, ')
          ..write('favorite: $favorite, ')
          ..write('folderId: $folderId')
          ..write(')'))
        .toString();
  }
}

class $PlaySessionsTable extends PlaySessions
    with TableInfo<$PlaySessionsTable, PlaySession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaySessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _gameIdMeta = const VerificationMeta('gameId');
  @override
  late final GeneratedColumn<int> gameId = GeneratedColumn<int>(
    'game_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES games (id)',
    ),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    gameId,
    startedAt,
    endedAt,
    durationSeconds,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'play_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaySession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('game_id')) {
      context.handle(
        _gameIdMeta,
        gameId.isAcceptableOrUnknown(data['game_id']!, _gameIdMeta),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaySession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaySession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      gameId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}game_id'],
      ),
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      )!,
    );
  }

  @override
  $PlaySessionsTable createAlias(String alias) {
    return $PlaySessionsTable(attachedDatabase, alias);
  }
}

class PlaySession extends DataClass implements Insertable<PlaySession> {
  final int id;

  /// 关联游戏（级联删除）。
  final int? gameId;
  final DateTime startedAt;
  final DateTime? endedAt;

  /// 已刷盘的持续秒数（内存累加，低频回写）。
  final int durationSeconds;
  const PlaySession({
    required this.id,
    this.gameId,
    required this.startedAt,
    this.endedAt,
    required this.durationSeconds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || gameId != null) {
      map['game_id'] = Variable<int>(gameId);
    }
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['duration_seconds'] = Variable<int>(durationSeconds);
    return map;
  }

  PlaySessionsCompanion toCompanion(bool nullToAbsent) {
    return PlaySessionsCompanion(
      id: Value(id),
      gameId: gameId == null && nullToAbsent
          ? const Value.absent()
          : Value(gameId),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      durationSeconds: Value(durationSeconds),
    );
  }

  factory PlaySession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaySession(
      id: serializer.fromJson<int>(json['id']),
      gameId: serializer.fromJson<int?>(json['gameId']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'gameId': serializer.toJson<int?>(gameId),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
    };
  }

  PlaySession copyWith({
    int? id,
    Value<int?> gameId = const Value.absent(),
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    int? durationSeconds,
  }) => PlaySession(
    id: id ?? this.id,
    gameId: gameId.present ? gameId.value : this.gameId,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    durationSeconds: durationSeconds ?? this.durationSeconds,
  );
  PlaySession copyWithCompanion(PlaySessionsCompanion data) {
    return PlaySession(
      id: data.id.present ? data.id.value : this.id,
      gameId: data.gameId.present ? data.gameId.value : this.gameId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaySession(')
          ..write('id: $id, ')
          ..write('gameId: $gameId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('durationSeconds: $durationSeconds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, gameId, startedAt, endedAt, durationSeconds);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaySession &&
          other.id == this.id &&
          other.gameId == this.gameId &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.durationSeconds == this.durationSeconds);
}

class PlaySessionsCompanion extends UpdateCompanion<PlaySession> {
  final Value<int> id;
  final Value<int?> gameId;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<int> durationSeconds;
  const PlaySessionsCompanion({
    this.id = const Value.absent(),
    this.gameId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.durationSeconds = const Value.absent(),
  });
  PlaySessionsCompanion.insert({
    this.id = const Value.absent(),
    this.gameId = const Value.absent(),
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    this.durationSeconds = const Value.absent(),
  }) : startedAt = Value(startedAt);
  static Insertable<PlaySession> custom({
    Expression<int>? id,
    Expression<int>? gameId,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<int>? durationSeconds,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (gameId != null) 'game_id': gameId,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
    });
  }

  PlaySessionsCompanion copyWith({
    Value<int>? id,
    Value<int?>? gameId,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<int>? durationSeconds,
  }) {
    return PlaySessionsCompanion(
      id: id ?? this.id,
      gameId: gameId ?? this.gameId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (gameId.present) {
      map['game_id'] = Variable<int>(gameId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaySessionsCompanion(')
          ..write('id: $id, ')
          ..write('gameId: $gameId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('durationSeconds: $durationSeconds')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  const AppSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSetting copyWith({String? key, String? value}) =>
      AppSetting(key: key ?? this.key, value: value ?? this.value);
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $GameFoldersTable gameFolders = $GameFoldersTable(this);
  late final $GamesTable games = $GamesTable(this);
  late final $PlaySessionsTable playSessions = $PlaySessionsTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    gameFolders,
    games,
    playSessions,
    appSettings,
  ];
}

typedef $$GameFoldersTableCreateCompanionBuilder =
    GameFoldersCompanion Function({
      Value<int> id,
      required String name,
      Value<int> sortOrder,
      Value<bool> includeInTotalTime,
      Value<bool> showOnHome,
      Value<DateTime> createdAt,
    });
typedef $$GameFoldersTableUpdateCompanionBuilder =
    GameFoldersCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> sortOrder,
      Value<bool> includeInTotalTime,
      Value<bool> showOnHome,
      Value<DateTime> createdAt,
    });

final class $$GameFoldersTableReferences
    extends BaseReferences<_$AppDatabase, $GameFoldersTable, GameFolder> {
  $$GameFoldersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$GamesTable, List<Game>> _gamesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.games,
    aliasName: 'game_folders__id__games__folder_id',
  );

  $$GamesTableProcessedTableManager get gamesRefs {
    final manager = $$GamesTableTableManager(
      $_db,
      $_db.games,
    ).filter((f) => f.folderId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_gamesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$GameFoldersTableFilterComposer
    extends Composer<_$AppDatabase, $GameFoldersTable> {
  $$GameFoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get includeInTotalTime => $composableBuilder(
    column: $table.includeInTotalTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showOnHome => $composableBuilder(
    column: $table.showOnHome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> gamesRefs(
    Expression<bool> Function($$GamesTableFilterComposer f) f,
  ) {
    final $$GamesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.games,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GamesTableFilterComposer(
            $db: $db,
            $table: $db.games,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GameFoldersTableOrderingComposer
    extends Composer<_$AppDatabase, $GameFoldersTable> {
  $$GameFoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get includeInTotalTime => $composableBuilder(
    column: $table.includeInTotalTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showOnHome => $composableBuilder(
    column: $table.showOnHome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GameFoldersTableAnnotationComposer
    extends Composer<_$AppDatabase, $GameFoldersTable> {
  $$GameFoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get includeInTotalTime => $composableBuilder(
    column: $table.includeInTotalTime,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get showOnHome => $composableBuilder(
    column: $table.showOnHome,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> gamesRefs<T extends Object>(
    Expression<T> Function($$GamesTableAnnotationComposer a) f,
  ) {
    final $$GamesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.games,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GamesTableAnnotationComposer(
            $db: $db,
            $table: $db.games,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GameFoldersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GameFoldersTable,
          GameFolder,
          $$GameFoldersTableFilterComposer,
          $$GameFoldersTableOrderingComposer,
          $$GameFoldersTableAnnotationComposer,
          $$GameFoldersTableCreateCompanionBuilder,
          $$GameFoldersTableUpdateCompanionBuilder,
          (GameFolder, $$GameFoldersTableReferences),
          GameFolder,
          PrefetchHooks Function({bool gamesRefs})
        > {
  $$GameFoldersTableTableManager(_$AppDatabase db, $GameFoldersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GameFoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GameFoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GameFoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> includeInTotalTime = const Value.absent(),
                Value<bool> showOnHome = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => GameFoldersCompanion(
                id: id,
                name: name,
                sortOrder: sortOrder,
                includeInTotalTime: includeInTotalTime,
                showOnHome: showOnHome,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int> sortOrder = const Value.absent(),
                Value<bool> includeInTotalTime = const Value.absent(),
                Value<bool> showOnHome = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => GameFoldersCompanion.insert(
                id: id,
                name: name,
                sortOrder: sortOrder,
                includeInTotalTime: includeInTotalTime,
                showOnHome: showOnHome,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$GameFoldersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({gamesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (gamesRefs) db.games],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (gamesRefs)
                    await $_getPrefetchedData<
                      GameFolder,
                      $GameFoldersTable,
                      Game
                    >(
                      currentTable: table,
                      referencedTable: $$GameFoldersTableReferences
                          ._gamesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$GameFoldersTableReferences(db, table, p0).gamesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.folderId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$GameFoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GameFoldersTable,
      GameFolder,
      $$GameFoldersTableFilterComposer,
      $$GameFoldersTableOrderingComposer,
      $$GameFoldersTableAnnotationComposer,
      $$GameFoldersTableCreateCompanionBuilder,
      $$GameFoldersTableUpdateCompanionBuilder,
      (GameFolder, $$GameFoldersTableReferences),
      GameFolder,
      PrefetchHooks Function({bool gamesRefs})
    >;
typedef $$GamesTableCreateCompanionBuilder =
    GamesCompanion Function({
      Value<int> id,
      required String title,
      required String exePath,
      required String dirPath,
      Value<Uint8List?> iconPng,
      Value<String?> backgroundPath,
      Value<String?> detailBackgroundPath,
      Value<double> backgroundBlurAmount,
      Value<String> launchArgs,
      Value<bool> useLocaleEmulator,
      Value<String> leProfile,
      Value<DateTime> createdAt,
      Value<DateTime?> lastPlayedAt,
      Value<int> totalPlaySeconds,
      Value<bool> favorite,
      Value<int?> folderId,
    });
typedef $$GamesTableUpdateCompanionBuilder =
    GamesCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String> exePath,
      Value<String> dirPath,
      Value<Uint8List?> iconPng,
      Value<String?> backgroundPath,
      Value<String?> detailBackgroundPath,
      Value<double> backgroundBlurAmount,
      Value<String> launchArgs,
      Value<bool> useLocaleEmulator,
      Value<String> leProfile,
      Value<DateTime> createdAt,
      Value<DateTime?> lastPlayedAt,
      Value<int> totalPlaySeconds,
      Value<bool> favorite,
      Value<int?> folderId,
    });

final class $$GamesTableReferences
    extends BaseReferences<_$AppDatabase, $GamesTable, Game> {
  $$GamesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $GameFoldersTable _folderIdTable(_$AppDatabase db) =>
      db.gameFolders.createAlias('games__folder_id__game_folders__id');

  $$GameFoldersTableProcessedTableManager? get folderId {
    final $_column = $_itemColumn<int>('folder_id');
    if ($_column == null) return null;
    final manager = $$GameFoldersTableTableManager(
      $_db,
      $_db.gameFolders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_folderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PlaySessionsTable, List<PlaySession>>
  _playSessionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.playSessions,
    aliasName: 'games__id__play_sessions__game_id',
  );

  $$PlaySessionsTableProcessedTableManager get playSessionsRefs {
    final manager = $$PlaySessionsTableTableManager(
      $_db,
      $_db.playSessions,
    ).filter((f) => f.gameId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_playSessionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$GamesTableFilterComposer extends Composer<_$AppDatabase, $GamesTable> {
  $$GamesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exePath => $composableBuilder(
    column: $table.exePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dirPath => $composableBuilder(
    column: $table.dirPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get iconPng => $composableBuilder(
    column: $table.iconPng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backgroundPath => $composableBuilder(
    column: $table.backgroundPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detailBackgroundPath => $composableBuilder(
    column: $table.detailBackgroundPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get backgroundBlurAmount => $composableBuilder(
    column: $table.backgroundBlurAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get launchArgs => $composableBuilder(
    column: $table.launchArgs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get useLocaleEmulator => $composableBuilder(
    column: $table.useLocaleEmulator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get leProfile => $composableBuilder(
    column: $table.leProfile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalPlaySeconds => $composableBuilder(
    column: $table.totalPlaySeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get favorite => $composableBuilder(
    column: $table.favorite,
    builder: (column) => ColumnFilters(column),
  );

  $$GameFoldersTableFilterComposer get folderId {
    final $$GameFoldersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.gameFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GameFoldersTableFilterComposer(
            $db: $db,
            $table: $db.gameFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> playSessionsRefs(
    Expression<bool> Function($$PlaySessionsTableFilterComposer f) f,
  ) {
    final $$PlaySessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playSessions,
      getReferencedColumn: (t) => t.gameId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaySessionsTableFilterComposer(
            $db: $db,
            $table: $db.playSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GamesTableOrderingComposer
    extends Composer<_$AppDatabase, $GamesTable> {
  $$GamesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exePath => $composableBuilder(
    column: $table.exePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dirPath => $composableBuilder(
    column: $table.dirPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get iconPng => $composableBuilder(
    column: $table.iconPng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backgroundPath => $composableBuilder(
    column: $table.backgroundPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detailBackgroundPath => $composableBuilder(
    column: $table.detailBackgroundPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get backgroundBlurAmount => $composableBuilder(
    column: $table.backgroundBlurAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get launchArgs => $composableBuilder(
    column: $table.launchArgs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get useLocaleEmulator => $composableBuilder(
    column: $table.useLocaleEmulator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get leProfile => $composableBuilder(
    column: $table.leProfile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalPlaySeconds => $composableBuilder(
    column: $table.totalPlaySeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get favorite => $composableBuilder(
    column: $table.favorite,
    builder: (column) => ColumnOrderings(column),
  );

  $$GameFoldersTableOrderingComposer get folderId {
    final $$GameFoldersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.gameFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GameFoldersTableOrderingComposer(
            $db: $db,
            $table: $db.gameFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GamesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GamesTable> {
  $$GamesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get exePath =>
      $composableBuilder(column: $table.exePath, builder: (column) => column);

  GeneratedColumn<String> get dirPath =>
      $composableBuilder(column: $table.dirPath, builder: (column) => column);

  GeneratedColumn<Uint8List> get iconPng =>
      $composableBuilder(column: $table.iconPng, builder: (column) => column);

  GeneratedColumn<String> get backgroundPath => $composableBuilder(
    column: $table.backgroundPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get detailBackgroundPath => $composableBuilder(
    column: $table.detailBackgroundPath,
    builder: (column) => column,
  );

  GeneratedColumn<double> get backgroundBlurAmount => $composableBuilder(
    column: $table.backgroundBlurAmount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get launchArgs => $composableBuilder(
    column: $table.launchArgs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get useLocaleEmulator => $composableBuilder(
    column: $table.useLocaleEmulator,
    builder: (column) => column,
  );

  GeneratedColumn<String> get leProfile =>
      $composableBuilder(column: $table.leProfile, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalPlaySeconds => $composableBuilder(
    column: $table.totalPlaySeconds,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get favorite =>
      $composableBuilder(column: $table.favorite, builder: (column) => column);

  $$GameFoldersTableAnnotationComposer get folderId {
    final $$GameFoldersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.gameFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GameFoldersTableAnnotationComposer(
            $db: $db,
            $table: $db.gameFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> playSessionsRefs<T extends Object>(
    Expression<T> Function($$PlaySessionsTableAnnotationComposer a) f,
  ) {
    final $$PlaySessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playSessions,
      getReferencedColumn: (t) => t.gameId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaySessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.playSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GamesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GamesTable,
          Game,
          $$GamesTableFilterComposer,
          $$GamesTableOrderingComposer,
          $$GamesTableAnnotationComposer,
          $$GamesTableCreateCompanionBuilder,
          $$GamesTableUpdateCompanionBuilder,
          (Game, $$GamesTableReferences),
          Game,
          PrefetchHooks Function({bool folderId, bool playSessionsRefs})
        > {
  $$GamesTableTableManager(_$AppDatabase db, $GamesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GamesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GamesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GamesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> exePath = const Value.absent(),
                Value<String> dirPath = const Value.absent(),
                Value<Uint8List?> iconPng = const Value.absent(),
                Value<String?> backgroundPath = const Value.absent(),
                Value<String?> detailBackgroundPath = const Value.absent(),
                Value<double> backgroundBlurAmount = const Value.absent(),
                Value<String> launchArgs = const Value.absent(),
                Value<bool> useLocaleEmulator = const Value.absent(),
                Value<String> leProfile = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastPlayedAt = const Value.absent(),
                Value<int> totalPlaySeconds = const Value.absent(),
                Value<bool> favorite = const Value.absent(),
                Value<int?> folderId = const Value.absent(),
              }) => GamesCompanion(
                id: id,
                title: title,
                exePath: exePath,
                dirPath: dirPath,
                iconPng: iconPng,
                backgroundPath: backgroundPath,
                detailBackgroundPath: detailBackgroundPath,
                backgroundBlurAmount: backgroundBlurAmount,
                launchArgs: launchArgs,
                useLocaleEmulator: useLocaleEmulator,
                leProfile: leProfile,
                createdAt: createdAt,
                lastPlayedAt: lastPlayedAt,
                totalPlaySeconds: totalPlaySeconds,
                favorite: favorite,
                folderId: folderId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required String exePath,
                required String dirPath,
                Value<Uint8List?> iconPng = const Value.absent(),
                Value<String?> backgroundPath = const Value.absent(),
                Value<String?> detailBackgroundPath = const Value.absent(),
                Value<double> backgroundBlurAmount = const Value.absent(),
                Value<String> launchArgs = const Value.absent(),
                Value<bool> useLocaleEmulator = const Value.absent(),
                Value<String> leProfile = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastPlayedAt = const Value.absent(),
                Value<int> totalPlaySeconds = const Value.absent(),
                Value<bool> favorite = const Value.absent(),
                Value<int?> folderId = const Value.absent(),
              }) => GamesCompanion.insert(
                id: id,
                title: title,
                exePath: exePath,
                dirPath: dirPath,
                iconPng: iconPng,
                backgroundPath: backgroundPath,
                detailBackgroundPath: detailBackgroundPath,
                backgroundBlurAmount: backgroundBlurAmount,
                launchArgs: launchArgs,
                useLocaleEmulator: useLocaleEmulator,
                leProfile: leProfile,
                createdAt: createdAt,
                lastPlayedAt: lastPlayedAt,
                totalPlaySeconds: totalPlaySeconds,
                favorite: favorite,
                folderId: folderId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$GamesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({folderId = false, playSessionsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (playSessionsRefs) db.playSessions,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (folderId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.folderId,
                                    referencedTable: $$GamesTableReferences
                                        ._folderIdTable(db),
                                    referencedColumn: $$GamesTableReferences
                                        ._folderIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (playSessionsRefs)
                        await $_getPrefetchedData<
                          Game,
                          $GamesTable,
                          PlaySession
                        >(
                          currentTable: table,
                          referencedTable: $$GamesTableReferences
                              ._playSessionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GamesTableReferences(
                                db,
                                table,
                                p0,
                              ).playSessionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.gameId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$GamesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GamesTable,
      Game,
      $$GamesTableFilterComposer,
      $$GamesTableOrderingComposer,
      $$GamesTableAnnotationComposer,
      $$GamesTableCreateCompanionBuilder,
      $$GamesTableUpdateCompanionBuilder,
      (Game, $$GamesTableReferences),
      Game,
      PrefetchHooks Function({bool folderId, bool playSessionsRefs})
    >;
typedef $$PlaySessionsTableCreateCompanionBuilder =
    PlaySessionsCompanion Function({
      Value<int> id,
      Value<int?> gameId,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
      Value<int> durationSeconds,
    });
typedef $$PlaySessionsTableUpdateCompanionBuilder =
    PlaySessionsCompanion Function({
      Value<int> id,
      Value<int?> gameId,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<int> durationSeconds,
    });

final class $$PlaySessionsTableReferences
    extends BaseReferences<_$AppDatabase, $PlaySessionsTable, PlaySession> {
  $$PlaySessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $GamesTable _gameIdTable(_$AppDatabase db) =>
      db.games.createAlias('play_sessions__game_id__games__id');

  $$GamesTableProcessedTableManager? get gameId {
    final $_column = $_itemColumn<int>('game_id');
    if ($_column == null) return null;
    final manager = $$GamesTableTableManager(
      $_db,
      $_db.games,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_gameIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlaySessionsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaySessionsTable> {
  $$PlaySessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  $$GamesTableFilterComposer get gameId {
    final $$GamesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gameId,
      referencedTable: $db.games,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GamesTableFilterComposer(
            $db: $db,
            $table: $db.games,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaySessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaySessionsTable> {
  $$PlaySessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  $$GamesTableOrderingComposer get gameId {
    final $$GamesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gameId,
      referencedTable: $db.games,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GamesTableOrderingComposer(
            $db: $db,
            $table: $db.games,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaySessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaySessionsTable> {
  $$PlaySessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  $$GamesTableAnnotationComposer get gameId {
    final $$GamesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gameId,
      referencedTable: $db.games,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GamesTableAnnotationComposer(
            $db: $db,
            $table: $db.games,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaySessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaySessionsTable,
          PlaySession,
          $$PlaySessionsTableFilterComposer,
          $$PlaySessionsTableOrderingComposer,
          $$PlaySessionsTableAnnotationComposer,
          $$PlaySessionsTableCreateCompanionBuilder,
          $$PlaySessionsTableUpdateCompanionBuilder,
          (PlaySession, $$PlaySessionsTableReferences),
          PlaySession,
          PrefetchHooks Function({bool gameId})
        > {
  $$PlaySessionsTableTableManager(_$AppDatabase db, $PlaySessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaySessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaySessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaySessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> gameId = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
              }) => PlaySessionsCompanion(
                id: id,
                gameId: gameId,
                startedAt: startedAt,
                endedAt: endedAt,
                durationSeconds: durationSeconds,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> gameId = const Value.absent(),
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
              }) => PlaySessionsCompanion.insert(
                id: id,
                gameId: gameId,
                startedAt: startedAt,
                endedAt: endedAt,
                durationSeconds: durationSeconds,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PlaySessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({gameId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (gameId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.gameId,
                                referencedTable: $$PlaySessionsTableReferences
                                    ._gameIdTable(db),
                                referencedColumn: $$PlaySessionsTableReferences
                                    ._gameIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlaySessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaySessionsTable,
      PlaySession,
      $$PlaySessionsTableFilterComposer,
      $$PlaySessionsTableOrderingComposer,
      $$PlaySessionsTableAnnotationComposer,
      $$PlaySessionsTableCreateCompanionBuilder,
      $$PlaySessionsTableUpdateCompanionBuilder,
      (PlaySession, $$PlaySessionsTableReferences),
      PlaySession,
      PrefetchHooks Function({bool gameId})
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$GameFoldersTableTableManager get gameFolders =>
      $$GameFoldersTableTableManager(_db, _db.gameFolders);
  $$GamesTableTableManager get games =>
      $$GamesTableTableManager(_db, _db.games);
  $$PlaySessionsTableTableManager get playSessions =>
      $$PlaySessionsTableTableManager(_db, _db.playSessions);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
}
