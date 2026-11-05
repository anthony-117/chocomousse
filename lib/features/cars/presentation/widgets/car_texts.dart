import 'package:chocomousse/features/cars/data/car_models.dart';
import 'package:intl/intl.dart';

/// Plain words for the source's fuel policies. A policy not listed is shown as the source writes it.
String fuelPolicyText(String policy) => switch (policy.toLowerCase()) {
  'like for like' => 'return as you found it',
  'full to full' => 'return it full',
  'full to empty' => 'pay for a full tank, return it empty',
  'same to same' => 'return as you found it',
  _ => policy,
};

String daysLabel(int days) => days == 1 ? '1 day' : '$days days';

/// "0.9 km", "24 km".
String kmLabel(double km) => km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';

/// "Fiat 600 or similar".
String carTitle(CarOffer car) => car.orSimilar == null ? car.model : '${car.model} or similar';

/// "Intermediate · Automatic · 5 seats · 3 bags · A/C", leaving out what isn't known.
String carSpecs(CarOffer car) => [
  car.size,
  ?car.gearbox?.label,
  if (car.seats case final seats?) '$seats seats',
  if (car.bags case final bags?) '$bags ${bags == 1 ? 'bag' : 'bags'}',
  if (car.airCon ?? false) 'A/C',
].join(' · ');

/// "via Sardegna · Downtown · 0.9 km from centre".
String pickUpLine(CarPickUp pickUp) => [
  pickUp.name,
  if (pickUp.type != PickUpType.other) pickUp.type.label,
  '${kmLabel(pickUp.distanceKm)} from centre',
].join(' · ');

/// An amount in its own currency, with cents only when it has them ("€3,294", "€12.50").
String formatAmount(Money money) => NumberFormat.simpleCurrency(
  name: money.currency,
  decimalDigits: money.amount == money.amount.roundToDouble() ? 0 : 2,
).format(money.amount);

/// "Fri 4 Dec, 10:00".
String rentalDay(DateTime day) => '${DateFormat('EEE d MMM').format(day)}, 10:00';

/// The note for a young or senior driver, shown as the age is typed (C3). Matches the API's limits.
String? driverAgeNote(int? age) {
  if (age == null) return null;
  if (age < 25) return 'Under 25: the rental company may charge a young driver fee at pick-up.';
  if (age > 70) return 'Over 70: the rental company may charge a senior driver fee at pick-up.';
  return null;
}
