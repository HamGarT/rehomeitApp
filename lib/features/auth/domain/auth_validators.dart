String? validateRequired(String? value, String label) {
  if (value == null || value.trim().isEmpty) {
    return '$label es obligatorio.';
  }
  return null;
}

String? validateEmail(String? value) {
  final required = validateRequired(value, 'El correo electrónico');
  if (required != null) return required;

  final email = value!.trim();
  final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  return valid ? null : 'Ingresa un correo electrónico válido.';
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) return 'La contraseña es obligatoria.';
  if (value.length < 8) {
    return 'La contraseña debe tener al menos 8 caracteres.';
  }
  return null;
}

String? validatePasswordConfirmation(String? value, String password) {
  if (value == null || value.isEmpty) return 'Confirma tu contraseña.';
  if (value != password) return 'Las contraseñas no coinciden.';
  return null;
}
