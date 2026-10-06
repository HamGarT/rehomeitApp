import 'package:flutter/material.dart';

/// Paleta tomada de los paneles de inicio: amarillo de marca y crema cálido
/// para el contenido. El verde queda para donación y éxito. El marrón de marca
/// se retiró: la interacción va en negro y gris, y el amarillo es el único
/// color de acento.
abstract final class AppColors {
  /// Acción e interacción: botones rellenos, enlaces, iconos Selected. Negro
  /// en claro; en oscuro se resuelve a gris claro vía [AppColorsDark.primary].
  static const primary = Color(0xFF000000);

  /// Contenedor suave de `primary`. Sobre él va texto oscuro, no blanco.
  static const primaryLight = Color(0xFFE5E5E5);

  /// Contenido dentro de un círculo o botón de [primary]: la inicial de un
  /// avatar, por ejemplo. Blanco sobre el negro de claro, negro sobre el gris
  /// claro de oscuro.
  static const onPrimary = Color(0xFFFFFFFF);

  /// Amarillo de marca. Fondo de onboarding, acceso, carga y análisis, e
  /// indicador de navegación. Solo lleva texto en [textPrimary].
  static const accent = Color.fromARGB(255, 255, 230, 0);

  /// Amarillo suave para fondos de chips, distintivos y avisos.
  static const accentSoft = Color(0xFFFFF0B3);

  /// Texto sobre un relleno de marca brillante (amarillo o verde). Es oscuro
  /// en ambos modos porque el relleno que acompaña nunca es oscuro.
  static const onAccent = Color(0xFF111111);

  /// Velo degradado que se echa encima de las fotos de publicación para que el
  /// texto de abajo se lea. En oscuro pasa a negro.
  static const imageScrim = Color(0xFFFFFFFF);

  /// Texto que va sobre [imageScrim]. El velo es blanco en claro y negro en
  /// oscuro, así que el texto hace lo contrario: oscuro sobre claro, blanco
  /// sobre negro.
  static const onImageScrim = Color(0xFF000000);

  /// Crema para pantallas de contenido: cálido sin competir con las fotos.
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF2A1A0E);
  static const textSecondary = Color(0xFF7A6652);
  static const border = Color(0xFFEADFC4);
  static const success = Color(0xFF00D76B);
  static const warning = Color(0xFFD97706);
  static const error = Color(0xFFC0392B);

  /// Azul de los hashtags del feed. Es fijo, no un token de paleta que cambie
  /// con el brillo: el azul se pide igual en claro y en oscuro.
  ///
  /// Contraste: 5.7:1 sobre el blanco de claro y 3.7:1 sobre el negro de
  /// [AppColorsDark.background]. El de oscuro se queda algo corto para texto
  /// pequeño, así que aquí el peso de la fuente hace el trabajo de que se lea.
  static const hashtag = Color(0xFF4150F7);
}

/// Paleta oscura: neutra y sin tono, al estilo de Instagram. Negro puro de
/// fondo, gris carbón para lo que flota por encima y texto casi blanco. Los
/// tonos de marca (marrón, amarillo, verde) no se repiten aquí: son los mismos
/// en ambos modos porque ya contrastan contra claro y oscuro.
abstract final class AppColorsDark {
  static const background = Color(0xFF000000);
  static const surface = Color(0xFF121212);

  /// Gris para SnackBar y capas que flotan sobre la superficie sin competir
  /// con el contenido.
  static const elevated = Color(0xFF262626);

  static const textPrimary = Color(0xFFF5F5F5);
  static const textSecondary = Color(0xFFA8A8A8);
  static const border = Color(0xFF262626);

  /// Relleno del chip en reposo: gris un punto más claro que la tarjeta, para
  /// que se distinga del fondo negro sin recurrir a un borde.
  static const chipFill = Color(0xFF1C1C1E);

  /// El velo de las fotos pasa de blanco a negro, o aclara la parte de abajo
  /// de la imagen en lugar de quemarla.
  static const imageScrim = Color(0xFF000000);

  /// Texto sobre el velo: al volverse negro el velo, el texto pasa a blanco.
  static const onImageScrim = Color(0xFFFFFFFF);

  /// El rojo de marca se apaga contra el negro: en oscuro sube tono y pierde
  /// el matiz anaranjado.
  static const error = Color(0xFFED4956);

  /// El negro de acción no existiría sobre un fondo negro, así que en oscuro
  /// la interacción sube a un gris casi blanco.
  static const primary = Color(0xFFE8E8E8);

  /// Texto e iconos dentro de un `primary` claro, para que no se pierdan.
  static const onPrimary = Color(0xFF000000);
}
