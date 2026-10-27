/// Models for the pamplemousse destination API (see Features/Destinations/DestinationContracts.cs).
library;

DateTime _date(Object? value) => DateTime.parse(value! as String);
double? _double(Object? value) => (value as num?)?.toDouble();
List<T> _list<T>(Object? value, T Function(Map<String, dynamic>) read) =>
    (value as List? ?? const []).cast<Map<String, dynamic>>().map(read).toList();

class DestinationSummary {
  const DestinationSummary({
    required this.id,
    required this.name,
    required this.region,
    required this.countryCode,
    required this.countryName,
    required this.flag,
    required this.lat,
    required this.lng,
    required this.timeZone,
  });

  factory DestinationSummary.fromJson(Map<String, dynamic> json) => DestinationSummary(
    id: json['id'] as String,
    name: json['name'] as String,
    region: json['region'] as String? ?? '',
    countryCode: json['countryCode'] as String,
    countryName: json['countryName'] as String,
    flag: json['flag'] as String?,
    lat: _double(json['lat'])!,
    lng: _double(json['lng'])!,
    timeZone: json['timeZone'] as String? ?? '',
  );

  final String id;
  final String name;
  final String region;
  final String countryCode;
  final String countryName;
  final String? flag;
  final double lat;
  final double lng;
  final String timeZone;

  /// "Lazio, Italy" (region omitted when it repeats the city name).
  String get subtitle => region.isEmpty || region == name ? countryName : '$region, $countryName';
}

class Country {
  const Country({
    required this.code,
    required this.name,
    required this.capital,
    required this.currencies,
    required this.languages,
    required this.callingCode,
    required this.flag,
  });

  factory Country.fromJson(Map<String, dynamic> json) => Country(
    code: json['code'] as String,
    name: json['name'] as String,
    capital: json['capital'] as String?,
    currencies: _list(json['currencies'], (c) => c['code'] as String),
    languages: (json['languages'] as List? ?? const []).cast<String>(),
    callingCode: json['callingCode'] as String?,
    flag: json['flag'] as String?,
  );

  final String code;
  final String name;
  final String? capital;
  final List<String> currencies;
  final List<String> languages;
  final String? callingCode;
  final String? flag;
}

class WeatherDay {
  const WeatherDay({
    required this.date,
    required this.maxC,
    required this.minC,
    required this.rainChance,
    required this.summary,
  });

  factory WeatherDay.fromJson(Map<String, dynamic> json) => WeatherDay(
    date: _date(json['date']),
    maxC: _double(json['maxC'])!,
    minC: _double(json['minC'])!,
    rainChance: json['rainChance'] as int?,
    summary: json['summary'] as String? ?? '',
  );

  final DateTime date;
  final double maxC;
  final double minC;
  final int? rainChance;
  final String summary;
}

class WeatherReport {
  const WeatherReport({required this.isForecast, required this.days});

  factory WeatherReport.fromJson(Map<String, dynamic> json) =>
      WeatherReport(isForecast: json['kind'] == 'forecast', days: _list(json['days'], WeatherDay.fromJson));

  /// false = last year's weather on the same dates (trip beyond the 16-day forecast).
  final bool isForecast;
  final List<WeatherDay> days;
}

class ExchangeRate {
  const ExchangeRate({required this.base, required this.quote, required this.rate, required this.date});

  factory ExchangeRate.fromJson(Map<String, dynamic> json) => ExchangeRate(
    base: json['base'] as String,
    quote: json['quote'] as String,
    rate: _double(json['rate'])!,
    date: _date(json['date']),
  );

  final String base;
  final String quote;
  final double rate;
  final DateTime date;
}

class Holiday {
  const Holiday({required this.date, required this.name, required this.localName});

  factory Holiday.fromJson(Map<String, dynamic> json) =>
      Holiday(date: _date(json['date']), name: json['name'] as String, localName: json['localName'] as String? ?? '');

  final DateTime date;
  final String name;
  final String localName;
}

class VisaRequirement {
  const VisaRequirement({required this.requirement, required this.visaFreeDays});

  factory VisaRequirement.fromJson(Map<String, dynamic> json) =>
      VisaRequirement(requirement: json['requirement'] as String, visaFreeDays: json['visaFreeDays'] as int?);

  final String requirement;
  final int? visaFreeDays;

  bool get isFree => requirement == 'visa free' || requirement == 'own country';

  String get label => switch (requirement) {
    'visa free' when visaFreeDays != null => 'Visa free · $visaFreeDays days',
    'eta' => 'ETA required',
    'e-visa' => 'e-Visa',
    _ => requirement[0].toUpperCase() + requirement.substring(1),
  };
}

class TravelAdvisory {
  const TravelAdvisory({required this.level, required this.label, required this.summary, required this.sourceUrl});

  factory TravelAdvisory.fromJson(Map<String, dynamic> json) => TravelAdvisory(
    level: json['level'] as int,
    label: json['label'] as String,
    summary: json['summary'] as String? ?? '',
    sourceUrl: json['sourceUrl'] as String? ?? '',
  );

  /// 1 (normal precautions) to 4 (do not travel).
  final int level;
  final String label;
  final String summary;
  final String sourceUrl;
}

class DestinationOverview {
  const DestinationOverview({
    required this.destination,
    required this.country,
    required this.from,
    required this.to,
    required this.weather,
    required this.exchange,
    required this.holidays,
    required this.visa,
    required this.advisory,
    required this.warnings,
  });

  factory DestinationOverview.fromJson(Map<String, dynamic> json) {
    T? section<T>(String key, T Function(Map<String, dynamic>) read) =>
        json[key] == null ? null : read(json[key] as Map<String, dynamic>);
    final dates = json['dates'] as Map<String, dynamic>;
    return DestinationOverview(
      destination: DestinationSummary.fromJson(json['destination'] as Map<String, dynamic>),
      country: section('country', Country.fromJson),
      from: _date(dates['from']),
      to: _date(dates['to']),
      weather: section('weather', WeatherReport.fromJson),
      exchange: section('exchange', ExchangeRate.fromJson),
      holidays: json['holidays'] == null ? null : _list(json['holidays'], Holiday.fromJson),
      visa: section('visa', VisaRequirement.fromJson),
      advisory: section('advisory', TravelAdvisory.fromJson),
      warnings: (json['warnings'] as List? ?? const []).cast<String>(),
    );
  }

  final DestinationSummary destination;
  final Country? country;
  final DateTime from;
  final DateTime to;
  final WeatherReport? weather;
  final ExchangeRate? exchange;
  final List<Holiday>? holidays;
  final VisaRequirement? visa;
  final TravelAdvisory? advisory;
  final List<String> warnings;
}

enum PlaceCategory {
  attraction('Attractions'),
  restaurant('Restaurants');

  PlaceCategory(this.label);

  final String label;
}

class Place {
  const Place({
    required this.id,
    required this.name,
    required this.category,
    required this.lat,
    required this.lng,
    required this.kind,
    required this.rating,
    required this.ratingCount,
    required this.priceLevel,
    required this.address,
    required this.description,
    required this.imageUrl,
    required this.website,
    required this.openingHours,
    required this.source,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>;
    return Place(
      id: json['id'] as String,
      name: json['name'] as String,
      category: PlaceCategory.values.byName(json['category'] as String),
      lat: _double(location['lat'])!,
      lng: _double(location['lng'])!,
      kind: json['kind'] as String?,
      rating: _double(json['rating']),
      ratingCount: json['ratingCount'] as int?,
      priceLevel: json['priceLevel'] as String?,
      address: json['address'] as String?,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      website: json['website'] as String?,
      openingHours: (json['openingHours'] as List? ?? const []).cast<String>(),
      source: json['source'] as String? ?? '',
    );
  }

  final String id;
  final String name;
  final PlaceCategory category;
  final double lat;
  final double lng;
  final String? kind;
  final double? rating;
  final int? ratingCount;
  final String? priceLevel;
  final String? address;
  final String? description;
  final String? imageUrl;
  final String? website;
  final List<String> openingHours;
  final String source;
}

class PlacesResult {
  const PlacesResult({required this.items, required this.warnings});

  factory PlacesResult.fromJson(Map<String, dynamic> json) => PlacesResult(
    items: _list(json['items'], Place.fromJson),
    warnings: (json['warnings'] as List? ?? const []).cast<String>(),
  );

  final List<Place> items;
  final List<String> warnings;
}

class TravelEvent {
  const TravelEvent({
    required this.id,
    required this.name,
    required this.date,
    required this.time,
    required this.venue,
    required this.category,
    required this.priceFrom,
    required this.url,
  });

  factory TravelEvent.fromJson(Map<String, dynamic> json) {
    final price = json['priceFrom'] as Map<String, dynamic>?;
    return TravelEvent(
      id: json['id'] as String,
      name: json['name'] as String,
      date: _date(json['date']),
      time: json['time'] as String?,
      venue: json['venue'] as String?,
      category: json['category'] as String?,
      priceFrom: price == null ? null : '${(price['amount'] as num).round()} ${price['currency']}',
      url: json['url'] as String,
    );
  }

  final String id;
  final String name;
  final DateTime date;
  final String? time;
  final String? venue;
  final String? category;
  final String? priceFrom;
  final String url;
}

class EventsResult {
  const EventsResult({required this.items, required this.warnings});

  factory EventsResult.fromJson(Map<String, dynamic> json) => EventsResult(
    items: _list(json['items'], TravelEvent.fromJson),
    warnings: (json['warnings'] as List? ?? const []).cast<String>(),
  );

  final List<TravelEvent> items;
  final List<String> warnings;
}

class CountryOption {
  const CountryOption({required this.code, required this.name, required this.flag, required this.currencies});

  factory CountryOption.fromJson(Map<String, dynamic> json) => CountryOption(
    code: json['code'] as String,
    name: json['name'] as String,
    flag: json['flag'] as String?,
    currencies: (json['currencies'] as List? ?? const []).cast<String>(),
  );

  final String code;
  final String name;
  final String? flag;
  final List<String> currencies;
}
