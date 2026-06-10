part of 'app_models.dart';


class ServiceOffer {
  const ServiceOffer({
    required this.id,
    required this.name,
    required this.offerType,
    required this.destinationIds,
    required this.studyLevels,
    required this.priceLabel,
    required this.benefits,
    required this.ctaLabel,
    required this.status,
  });

  final String id;
  final LocalizedText name;
  final String offerType;
  final List<String> destinationIds;
  final List<String> studyLevels;
  final LocalizedText priceLabel;
  final List<LocalizedText> benefits;
  final LocalizedText ctaLabel;
  final PublicationStatus status;
}
class SupportDestination {
  const SupportDestination({
    required this.id,
    required this.countryId,
    required this.supportLanguages,
    required this.availableServiceTypes,
    required this.conditions,
    required this.counselorNames,
    required this.isVisible,
    required this.status,
  });

  final String id;
  final String countryId;
  final List<String> supportLanguages;
  final List<String> availableServiceTypes;
  final List<LocalizedText> conditions;
  final List<String> counselorNames;
  final bool isVisible;
  final PublicationStatus status;
}
