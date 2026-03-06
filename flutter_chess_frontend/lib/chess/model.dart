import 'dart:convert';

/// Chess colors.
enum PieceColor { white, black }

/// Chess piece types.
enum PieceType { king, queen, rook, bishop, knight, pawn }

/// Board coordinate (file 0..7 for a..h, rank 0..7 for 1..8).
///
/// rank=0 corresponds to rank "1" (White home rank). file=0 is file "a".
class Square {
  final int file;
  final int rank;

  const Square(this.file, this.rank);

  bool get isValid => file >= 0 && file < 8 && rank >= 0 && rank < 8;

  String get algebraic => '${String.fromCharCode('a'.codeUnitAt(0) + file)}${rank + 1}';

  static Square? tryParse(String value) {
    if (value.length != 2) return null;
    final int file = value.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final int rank = int.tryParse(value[1]) == null ? -1 : int.parse(value[1]) - 1;
    final sq = Square(file, rank);
    return sq.isValid ? sq : null;
  }

  @override
  bool operator ==(Object other) => other is Square && other.file == file && other.rank == rank;

  @override
  int get hashCode => Object.hash(file, rank);

  @override
  String toString() => algebraic;
}

/// A chess piece.
class Piece {
  final PieceType type;
  final PieceColor color;

  const Piece({required this.type, required this.color});

  String get fenChar {
    final String c = switch (type) {
      PieceType.king => 'k',
      PieceType.queen => 'q',
      PieceType.rook => 'r',
      PieceType.bishop => 'b',
      PieceType.knight => 'n',
      PieceType.pawn => 'p',
    };
    return color == PieceColor.white ? c.toUpperCase() : c;
  }

  static Piece? fromFenChar(String c) {
    if (c.length != 1) return null;
    final bool isUpper = c.toUpperCase() == c;
    final PieceColor color = isUpper ? PieceColor.white : PieceColor.black;
    final String lower = c.toLowerCase();
    final PieceType? type = switch (lower) {
      'k' => PieceType.king,
      'q' => PieceType.queen,
      'r' => PieceType.rook,
      'b' => PieceType.bishop,
      'n' => PieceType.knight,
      'p' => PieceType.pawn,
      _ => null,
    };
    if (type == null) return null;
    return Piece(type: type, color: color);
  }

  Map<String, dynamic> toJson() => {'t': type.name, 'c': color.name};

  static Piece fromJson(Map<String, dynamic> json) => Piece(
        type: PieceType.values.firstWhere((e) => e.name == json['t']),
        color: PieceColor.values.firstWhere((e) => e.name == json['c']),
      );
}

/// Castling rights flags.
class CastlingRights {
  final bool whiteKingSide;
  final bool whiteQueenSide;
  final bool blackKingSide;
  final bool blackQueenSide;

  const CastlingRights({
    required this.whiteKingSide,
    required this.whiteQueenSide,
    required this.blackKingSide,
    required this.blackQueenSide,
  });

  static const none = CastlingRights(
    whiteKingSide: false,
    whiteQueenSide: false,
    blackKingSide: false,
    blackQueenSide: false,
  );

  CastlingRights copyWith({
    bool? whiteKingSide,
    bool? whiteQueenSide,
    bool? blackKingSide,
    bool? blackQueenSide,
  }) {
    return CastlingRights(
      whiteKingSide: whiteKingSide ?? this.whiteKingSide,
      whiteQueenSide: whiteQueenSide ?? this.whiteQueenSide,
      blackKingSide: blackKingSide ?? this.blackKingSide,
      blackQueenSide: blackQueenSide ?? this.blackQueenSide,
    );
  }

  Map<String, dynamic> toJson() => {
        'wk': whiteKingSide,
        'wq': whiteQueenSide,
        'bk': blackKingSide,
        'bq': blackQueenSide,
      };

  static CastlingRights fromJson(Map<String, dynamic> json) => CastlingRights(
        whiteKingSide: json['wk'] as bool,
        whiteQueenSide: json['wq'] as bool,
        blackKingSide: json['bk'] as bool,
        blackQueenSide: json['bq'] as bool,
      );
}

/// A move in chess.
///
/// For castling, [isCastleKingSide]/[isCastleQueenSide] are set.
/// For en-passant, [isEnPassant] is set.
/// For promotions, [promotion] is non-null.
class ChessMove {
  final Square from;
  final Square to;
  final PieceType? promotion;
  final bool isEnPassant;
  final bool isCastleKingSide;
  final bool isCastleQueenSide;

  const ChessMove({
    required this.from,
    required this.to,
    this.promotion,
    this.isEnPassant = false,
    this.isCastleKingSide = false,
    this.isCastleQueenSide = false,
  });

  String get uciLike {
    final promo = promotion == null ? '' : promotion!.name[0];
    return '${from.algebraic}${to.algebraic}$promo';
  }

  Map<String, dynamic> toJson() => {
        'f': from.algebraic,
        't': to.algebraic,
        'p': promotion?.name,
        'ep': isEnPassant,
        'ck': isCastleKingSide,
        'cq': isCastleQueenSide,
      };

  static ChessMove fromJson(Map<String, dynamic> json) {
    final Square from = Square.tryParse(json['f'] as String)!;
    final Square to = Square.tryParse(json['t'] as String)!;
    final String? p = json['p'] as String?;
    return ChessMove(
      from: from,
      to: to,
      promotion: p == null ? null : PieceType.values.firstWhere((e) => e.name == p),
      isEnPassant: (json['ep'] as bool?) ?? false,
      isCastleKingSide: (json['ck'] as bool?) ?? false,
      isCastleQueenSide: (json['cq'] as bool?) ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ChessMove &&
        other.from == from &&
        other.to == to &&
        other.promotion == promotion &&
        other.isEnPassant == isEnPassant &&
        other.isCastleKingSide == isCastleKingSide &&
        other.isCastleQueenSide == isCastleQueenSide;
  }

  @override
  int get hashCode => Object.hash(from, to, promotion, isEnPassant, isCastleKingSide, isCastleQueenSide);

  @override
  String toString() => uciLike;
}

/// Simple helpers for encoding/decoding JSON strings.
class JsonCodecHelper {
  const JsonCodecHelper._();

  static String encode(Object value) => jsonEncode(value);
  static dynamic decode(String value) => jsonDecode(value);
}
