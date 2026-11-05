import '../../../core/utils/firestore_dates.dart';

const accountInactivityThreshold = Duration(days: 365);

enum AccountStatus { active, blocked, retired }

extension AccountStatusX on AccountStatus {
  String get wireValue => switch (this) {
    AccountStatus.active => 'activa',
    AccountStatus.blocked => 'bloqueada',
    AccountStatus.retired => 'retirada',
  };

  String get label => switch (this) {
    AccountStatus.active => 'Activa',
    AccountStatus.blocked => 'Bloqueada',
    AccountStatus.retired => 'Retirada',
  };

  static AccountStatus fromWire(Object? value) => switch (value) {
    'bloqueada' => AccountStatus.blocked,
    'retirada' => AccountStatus.retired,
    _ => AccountStatus.active,
  };
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.status,
    this.joinedAt,
    this.lastActivityAt,
    this.statusReason,
    this.statusAt,
    this.noticeAt,
    this.verifiedAt,
  });

  final String id;
  final String fullName;
  final String email;
  final String role;
  final AccountStatus status;
  final DateTime? joinedAt;
  final DateTime? lastActivityAt;
  final String? statusReason;
  final DateTime? statusAt;
  final DateTime? noticeAt;
  final DateTime? verifiedAt;

  DateTime? get lastSeenAt => lastActivityAt ?? joinedAt;

  bool isInactive({DateTime? now}) {
    final reference = lastSeenAt;
    if (reference == null) return false;
    return reference
        .toUtc()
        .isBefore((now ?? DateTime.now()).toUtc().subtract(accountInactivityThreshold));
  }

  bool needsRetirementNotice({DateTime? now}) =>
      status == AccountStatus.active &&
      isInactive(now: now) &&
      noticeAt == null;

  bool canRetireForInactivity({DateTime? now}) =>
      status == AccountStatus.active &&
      isInactive(now: now) &&
      noticeAt != null;

  bool get isVerified => verifiedAt != null;

  /// Comparación conservadora: solo marca duplicados con el mismo correo
  /// normalizado, sin inferir que dos personas con el mismo nombre sean una.
  String get normalizedEmail => email.trim().toLowerCase();

  String get roleLabel => switch (role) {
    'administrador' => 'Administrador',
    'organizacion' => 'Organización',
    _ => 'Usuario',
  };

  factory AdminUser.fromUserData({
    required String id,
    required Map<String, dynamic> user,
    Map<String, dynamic>? profile,
  }) {
    return AdminUser(
      id: id,
      fullName: (user['nombreCompleto'] as String?)?.trim().isNotEmpty == true
          ? (user['nombreCompleto'] as String).trim()
          : 'Usuario',
      email: (user['correo'] as String?) ?? '',
      role: (user['rol'] as String?) ?? 'usuario',
      status: AccountStatusX.fromWire(user['estadoCuenta']),
      joinedAt: readFirestoreDate(profile?['fechaIngreso']),
      lastActivityAt: readFirestoreDate(user['ultimaActividad']),
      statusReason: user['estadoCuentaMotivo'] as String?,
      statusAt: readFirestoreDate(user['estadoCuentaAt']),
      noticeAt: readFirestoreDate(user['avisoRetiroAt']),
      verifiedAt: readFirestoreDate(user['cuentaVerificadaAt']),
    );
  }
}
