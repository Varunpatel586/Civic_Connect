import 'package:civic_connect/services/api_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// `ApiClient` reads `API_BASE_URL` once, so the deployment is chosen per
  /// test by re-seeding dotenv before the first `baseUrl` read.
  void configureDeployment(String apiBaseUrl) {
    dotenv.testLoad(fileInput: 'API_BASE_URL=$apiBaseUrl');
  }

  group('normalizeUrl', () {
    test('points a stored localhost photograph at the configured API host', () {
      configureDeployment('https://civic-connect-api-eq0j.onrender.com/api');

      expect(
        ApiClient().normalizeUrl(
          'http://localhost:5000/uploads/photo-1787250320905-618967136.jpg',
        ),
        'https://civic-connect-api-eq0j.onrender.com/uploads/photo-1787250320905-618967136.jpg',
      );
    });

    test('repoints photographs left over from an earlier deployment host', () {
      configureDeployment('https://civic-connect-api-eq0j.onrender.com/api');

      expect(
        ApiClient().normalizeUrl('https://civic-connect-api.onrender.com/uploads/photo-1.jpg'),
        'https://civic-connect-api-eq0j.onrender.com/uploads/photo-1.jpg',
      );
    });

    test('is idempotent, so applying it twice changes nothing', () {
      configureDeployment('https://civic-connect-api-eq0j.onrender.com/api');

      final once = ApiClient().normalizeUrl(
        'https://civic-connect-api-eq0j.onrender.com/uploads/photo-1.jpg',
      );

      expect(ApiClient().normalizeUrl(once), once);
    });

    test('leaves external images alone, because this server does not serve them',
        () {
      configureDeployment('https://civic-connect-api-eq0j.onrender.com/api');

      const unsplash =
          'https://plus.unsplash.com/premium_photo-1663036928694-d218b69cc123?fm=jpg&q=60&w=3000';

      expect(ApiClient().normalizeUrl(unsplash), unsplash);
    });

    test('keeps a local development server reachable', () {
      configureDeployment('http://192.168.29.115:5000/api');

      expect(
        ApiClient().normalizeUrl('http://localhost:5000/uploads/photo-1.jpg'),
        'http://192.168.29.115:5000/uploads/photo-1.jpg',
      );
    });

    test('drops a query string rather than folding it into the filename', () {
      configureDeployment('https://civic-connect-api-eq0j.onrender.com/api');

      expect(
        ApiClient().normalizeUrl('http://localhost:5000/uploads/photo-1.jpg?v=2'),
        'https://civic-connect-api-eq0j.onrender.com/uploads/photo-1.jpg',
      );
    });

    test('returns an empty string unchanged', () {
      configureDeployment('https://civic-connect-api-eq0j.onrender.com/api');

      expect(ApiClient().normalizeUrl(''), '');
    });
  });
}
