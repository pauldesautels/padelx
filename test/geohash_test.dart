import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/geohash.dart';

void main() {
  test('geohash encoding matches migration/backend implementation', () {
    expect(encodeGeohash(19.4326, -99.1332, precision: 3), '9g3');
    expect(encodeGeohash(19.4326, -99.1332, precision: 4), '9g3w');
  });

  test('radius cells include the center and remain bounded', () {
    final cells = geohashCellsForRadius(19.4326, -99.1332, 100);
    expect(cells, contains('9g3'));
    expect(cells.length, lessThanOrEqualTo(16));
  });

  test('initial discovery expands only to fill an undersized first page', () {
    expect(discoveryInitialCellLimit, 10);
    expect(
      shouldExpandInitialDiscovery(
        requestedLimit: 10,
        filteredResultCount: 4,
        anyCellHasMore: true,
      ),
      isTrue,
    );
    expect(
      shouldExpandInitialDiscovery(
        requestedLimit: 10,
        filteredResultCount: discoveryFirstPageTarget,
        anyCellHasMore: true,
      ),
      isFalse,
    );
    expect(
      shouldExpandInitialDiscovery(
        requestedLimit: 20,
        filteredResultCount: 4,
        anyCellHasMore: true,
      ),
      isFalse,
    );
  });
}
