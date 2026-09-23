import 'package:flutter_test/flutter_test.dart';
import 'package:rehomeitapp/features/exchange/domain/exchange_proposal.dart';
import 'package:rehomeitapp/shared/domain/publication.dart';

ExchangeProposal proposal({
  ExchangeProposalStatus status = ExchangeProposalStatus.accepted,
  DateTime? requestedConfirmation,
  DateTime? offeredConfirmation,
}) {
  return ExchangeProposal(
    id: 'proposal-1',
    requestedPublicationId: 'requested',
    requestedPublicationTitle: 'Mesa',
    requestedOwnerId: 'owner',
    offeredPublicationId: 'offered',
    offeredPublicationTitle: 'Silla',
    offeredOwnerId: 'proposer',
    status: status,
    proposedAt: DateTime.utc(2026, 9, 20),
    requestedOwnerConfirmedAt: requestedConfirmation,
    offeredOwnerConfirmedAt: offeredConfirmation,
  );
}

void main() {
  test('accepted exchange starts as committed', () {
    final exchange = proposal();

    expect(
      exchange.effectivePublicationStatus(DateTime.utc(2026, 9, 22)),
      PublicationStatus.committed,
    );
  });

  test(
    'one confirmation derives delivered, pending and closed time states',
    () {
      final firstConfirmation = DateTime.utc(2026, 9, 20, 12);
      final exchange = proposal(requestedConfirmation: firstConfirmation);

      expect(
        exchange.effectivePublicationStatus(
          firstConfirmation.add(const Duration(hours: 47)),
        ),
        PublicationStatus.delivered,
      );
      expect(
        exchange.effectivePublicationStatus(
          firstConfirmation.add(const Duration(hours: 48)),
        ),
        PublicationStatus.pendingConfirmation,
      );
      expect(
        exchange.effectivePublicationStatus(
          firstConfirmation.add(const Duration(hours: 72)),
        ),
        PublicationStatus.closedWithoutConfirmation,
      );
    },
  );

  test('both independent confirmations close the exchange', () {
    final exchange = proposal(
      requestedConfirmation: DateTime.utc(2026, 9, 20, 12),
      offeredConfirmation: DateTime.utc(2026, 9, 20, 15),
    );

    expect(exchange.hasConfirmed('owner'), isTrue);
    expect(exchange.hasConfirmed('proposer'), isTrue);
    expect(
      exchange.effectivePublicationStatus(DateTime.utc(2026, 9, 24)),
      PublicationStatus.confirmed,
    );
  });

  test('proposal status serialization is consistent', () {
    final map = proposal(status: ExchangeProposalStatus.rejected).toMap();

    expect(map['status'], 'rechazada');
    expect(map['participantIds'], ['owner', 'proposer']);
  });
}
