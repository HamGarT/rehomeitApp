import 'package:flutter/material.dart';

/// Rutas que no deben apilarse dos veces: detalle, perfil público,
/// conversación y actividad de intercambio se enlazan entre sí (detalle →
/// perfil → detalle → perfil...) y cada salto empujaba otra copia, con lo que
/// "atrás" recorría todo el bucle. Con un nombre por pantalla, si ya está
/// abierta se vuelve a ella en vez de apilar otra.
abstract final class AppRoutes {
  static String publication(String id) => 'publication/$id';
  static String profile(String userId) => 'profile/$userId';
  static String conversation(String id) => 'conversation/$id';
  static String journey(String publicationId) => 'journey/$publicationId';
  static const exchanges = 'exchanges';
  static const moderation = 'moderation';
}

/// Lleva la cuenta de los nombres de ruta abiertos. Hay que registrarlo en
/// `MaterialApp.navigatorObservers`; sin él, [pushUnique] siempre apila.
class RouteStackObserver extends NavigatorObserver {
  final _names = <String>[];

  bool contains(String name) => _names.contains(name);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name != null) _names.add(name);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _remove(oldRoute);
    final name = newRoute?.settings.name;
    if (name != null) _names.add(name);
  }

  void _remove(Route<dynamic> route) {
    final name = route.settings.name;
    if (name == null) return;
    final index = _names.lastIndexOf(name);
    if (index >= 0) _names.removeAt(index);
  }
}

final routeStackObserver = RouteStackObserver();

/// Abre [builder] bajo [name], o vuelve a esa pantalla si ya está en la pila.
Future<T?> pushUnique<T>(
  BuildContext context, {
  required String name,
  required WidgetBuilder builder,
}) {
  final navigator = Navigator.of(context);
  if (routeStackObserver.contains(name)) {
    navigator.popUntil((route) => route.settings.name == name);
    return Future<T?>.value(null);
  }
  return navigator.push<T>(
    MaterialPageRoute(settings: RouteSettings(name: name), builder: builder),
  );
}
