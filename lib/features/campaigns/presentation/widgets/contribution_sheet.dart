import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/choice_sheet.dart';
import '../../../../shared/widgets/sheet_handle.dart';
import '../../domain/campaign.dart';

class ContributionRequest {
  const ContributionRequest({required this.need, required this.quantity});

  final CampaignNeed need;
  final int quantity;
}

Future<ContributionRequest?> showContributionSheet(
  BuildContext context, {
  required Campaign campaign,
}) {
  return showModalBottomSheet<ContributionRequest>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => _ContributionSheet(campaign: campaign),
  );
}

class _ContributionSheet extends StatefulWidget {
  const _ContributionSheet({required this.campaign});

  final Campaign campaign;

  @override
  State<_ContributionSheet> createState() => _ContributionSheetState();
}

class _ContributionSheetState extends State<_ContributionSheet> {
  late final TextEditingController _quantity = TextEditingController();
  CampaignNeed? _need;
  String? _error;

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              const SheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Registrar aporte',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Elige qué necesidad de «${widget.campaign.title}» vas a atender y cuánto aportarás.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.appColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Column(
                  children: [
                    for (final need in widget.campaign.needs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: SelectableRow(
                          key: Key('contribution-need-${need.id}'),
                          label:
                              '${need.name} · ${need.requiredQuantity} requerido',
                          selected: need.id == _need?.id,
                          onTap: () => setState(() {
                            _need = need;
                            _error = null;
                          }),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: TextField(
                  key: const Key('contribution-quantity'),
                  controller: _quantity,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Cantidad que aportarás',
                    hintText: 'Ej. 3',
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: FilledButton(
                  key: const Key('contribution-submit'),
                  onPressed: _submit,
                  child: const Text('Registrar aporte'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final need = _need;
    final quantity = int.tryParse(_quantity.text.trim()) ?? 0;
    if (need == null) {
      setState(() => _error = 'Selecciona la necesidad que atenderás.');
      return;
    }
    if (quantity <= 0) {
      setState(() => _error = 'Indica una cantidad mayor que cero.');
      return;
    }
    Navigator.of(context).pop(ContributionRequest(need: need, quantity: quantity));
  }
}
