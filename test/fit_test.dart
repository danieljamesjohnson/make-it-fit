import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_fit/src/fit.dart';

void main() {
  test('limits are decimal megabytes', () {
    expect(mbToBytes(25), 25000000);
    expect(mbToBytes(0.5), 500000);
  });

  test('formatMb rounds sensibly', () {
    expect(formatMb(24990000), '25.0 MB');
    expect(formatMb(143200000), '143 MB');
  });

  test('presets match the limits people hit', () {
    expect(FitPreset.email.mb, 25);
    expect(FitPreset.discord.mb, 20);
    expect(FitPreset.whatsapp.mb, 16);
  });
}
