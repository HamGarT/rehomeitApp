import 'package:flutter_test/flutter_test.dart';
import 'package:rehomeitapp/shared/data/short_name_registry.dart';
import 'package:rehomeitapp/shared/domain/person_name.dart';

void main() {
  const garcia = PersonName(firstNames: 'Hamer', lastNames: 'García');

  ShortNameOwnerLookup owners(Map<String, String> taken) =>
      (shortName) async => taken[shortName];

  group('chooseShortName', () {
    test('con el nombre libre toma el preferido y pide reservarlo', () async {
      final choice = await chooseShortName(garcia, 'me', ownerOf: owners({}));
      expect(choice, (shortName: 'Hamer G.', needsReservation: true));
    });

    test('si otra persona ya es "Hamer G." suma letras del apellido', () async {
      final choice = await chooseShortName(
        garcia,
        'me',
        ownerOf: owners({'Hamer G.': 'other', 'Hamer Ga.': 'another'}),
      );
      expect(choice, (shortName: 'Hamer Gar.', needsReservation: true));
    });

    test('dos personas con el mismo nombre y apellido acaban con número', () async {
      final taken = {
        for (final candidate in garcia.shortCandidates.take(6))
          candidate: 'other',
      };
      final choice = await chooseShortName(
        garcia,
        'me',
        ownerOf: owners(taken),
      );
      expect(choice, (shortName: 'Hamer García 2', needsReservation: true));
    });

    test('conserva el nombre actual aunque el preferido haya quedado libre', () async {
      final choice = await chooseShortName(
        garcia,
        'me',
        ownerOf: owners({'Hamer Ga.': 'me'}),
        current: 'Hamer Ga.',
      );
      expect(choice, (shortName: 'Hamer Ga.', needsReservation: false));
    });

    test('un nombre actual que ya no corresponde al nombre se abandona', () async {
      final choice = await chooseShortName(
        garcia,
        'me',
        ownerOf: owners({'Ana T.': 'me'}),
        current: 'Ana T.',
      );
      expect(choice, (shortName: 'Hamer G.', needsReservation: true));
    });

    test('un perfil anterior a las reservas reserva su nombre actual', () async {
      final choice = await chooseShortName(
        garcia,
        'me',
        ownerOf: owners({}),
        current: 'Hamer G.',
      );
      expect(choice, (shortName: 'Hamer G.', needsReservation: true));
    });
  });
}
