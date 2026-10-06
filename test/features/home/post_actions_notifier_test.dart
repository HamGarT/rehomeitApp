import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehomeitapp/features/home/presentation/post_actions_notifier.dart';

PostReactionsNotifier _notifier(ProviderContainer container) =>
    container.read(postReactionsProvider.notifier);

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('sin reacción, una publicación está en neutro', () {
    expect(_notifier(container).of('a'), PostReaction.none);
    expect(PostReaction.none.loved, isFalse);
  });

  test('me encanta se marca y un segundo toque la retira', () {
    final notifier = _notifier(container);

    notifier.toggleLoved('a');
    expect(notifier.of('a').loved, isTrue);

    notifier.toggleLoved('a');
    expect(notifier.of('a').loved, isFalse);
  });

  test('la reacción se guarda por publicación y no se mezclan', () {
    final notifier = _notifier(container);

    notifier.toggleLoved('a');
    notifier.toggleLoved('b');

    expect(notifier.of('a').loved, isTrue);
    expect(notifier.of('b').loved, isTrue);
    expect(notifier.of('c'), PostReaction.none);
  });
}
