import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rehomeitapp/shared/data/photo_screening_service.dart';
import 'package:rehomeitapp/shared/domain/prohibited_content.dart';

void main() {
  final photos = [File('evidencia.jpg')];

  PhotoScreeningService serviceReturning(String? text) =>
      PhotoScreeningService((_) async => text);

  PhotoScreeningService serviceThrowing(Object error) =>
      PhotoScreeningService((_) async => throw error);

  Future<PhotoScreeningException> failureOf(PhotoScreeningService service) {
    return service.screen(photos).then(
      (_) => fail('se esperaba PhotoScreeningException'),
      onError: (Object error) => error as PhotoScreeningException,
    );
  }

  group('PhotoScreeningService.screen', () {
    test('termina sin error cuando la lista viene vacía', () async {
      await serviceReturning('{"prohibitedContent": []}').screen(photos);
    });

    test('lanza prohibited con lo detectado, sin repetidos ni desconocidos', () async {
      final failure = await failureOf(
        serviceReturning(
          '{"prohibitedContent": ["rostro", "rostro", "tarjeta_pago", "otro"]}',
        ),
      );

      expect(failure.cause, PhotoScreeningCause.prohibited);
      expect(failure.prohibited, isTrue);
      expect(failure.content, [
        ProhibitedContent.face,
        ProhibitedContent.paymentCard,
      ]);
      expect(
        failure.contentDescription,
        'rostros o personas, tarjetas de crédito o débito',
      );
    });

    test('una respuesta vacía o ilegible no cuenta como veredicto', () async {
      for (final text in [null, '', 'no es json', '[1, 2]']) {
        final failure = await failureOf(serviceReturning(text));
        expect(failure.cause, PhotoScreeningCause.unavailable, reason: '$text');
        expect(failure.prohibited, isFalse);
        expect(failure.content, isEmpty);
      }
    });

    test('el corte de tiempo se reporta como timeout', () async {
      final failure = await failureOf(
        serviceThrowing(TimeoutException('tardó demasiado')),
      );
      expect(failure.cause, PhotoScreeningCause.timeout);
    });

    test('la falta de red se reporta como offline, venga como venga', () async {
      final socket = await failureOf(
        serviceThrowing(const SocketException('sin red')),
      );
      expect(socket.cause, PhotoScreeningCause.offline);

      // El SDK de Firebase AI envuelve la falta de red en sus propios errores.
      final wrapped = await failureOf(
        serviceThrowing(StateError('Failed host lookup: firebase.google.com')),
      );
      expect(wrapped.cause, PhotoScreeningCause.offline);
    });

    test('cualquier otro fallo del servicio es unavailable', () async {
      final failure = await failureOf(
        serviceThrowing(StateError('quota exceeded')),
      );
      expect(failure.cause, PhotoScreeningCause.unavailable);
    });
  });
}
