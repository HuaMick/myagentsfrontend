import 'package:flutter_test/flutter_test.dart';
import 'package:myagents_frontend/core/config/environment.dart';
import 'package:myagents_frontend/core/config/environment_config.dart';

void main() {
  group('Environment', () {
    test('has correct enum values', () {
      expect(Environment.values.length, 2);
      expect(Environment.values, contains(Environment.development));
      expect(Environment.values, contains(Environment.production));
    });

    test('name extension returns correct names', () {
      expect(Environment.development.name, 'Development');
      expect(Environment.production.name, 'Production');
    });

    test('isDevelopment extension works correctly', () {
      expect(Environment.development.isDevelopment, isTrue);
      expect(Environment.production.isDevelopment, isFalse);
    });

    test('isProduction extension works correctly', () {
      expect(Environment.production.isProduction, isTrue);
      expect(Environment.development.isProduction, isFalse);
    });
  });

  group('EnvironmentConfig', () {
    group('development configuration', () {
      test('has correct environment', () {
        expect(EnvironmentConfig.development.environment,
            Environment.development);
      });

      test('has correct relay URL', () {
        expect(EnvironmentConfig.development.relayUrl, 'localhost:8080');
      });

      test('uses non-secure WebSocket', () {
        expect(EnvironmentConfig.development.useSecureWebSocket, isFalse);
      });

      test('generates correct WebSocket URL', () {
        final config = EnvironmentConfig.development;
        final wsUrl = config.getRelayWebSocketUrl('ABC123');
        expect(wsUrl, 'ws://localhost:8080/ws/client/ABC123');
      });
    });

    group('production configuration', () {
      test('has correct environment', () {
        expect(
            EnvironmentConfig.production.environment, Environment.production);
      });

      test('has correct relay URL', () {
        expect(EnvironmentConfig.production.relayUrl, 'relay.remoteagents.dev');
      });

      test('uses secure WebSocket', () {
        expect(EnvironmentConfig.production.useSecureWebSocket, isTrue);
      });

      test('generates correct WebSocket URL', () {
        final config = EnvironmentConfig.production;
        final wsUrl = config.getRelayWebSocketUrl('ABC123');
        expect(wsUrl, 'wss://relay.remoteagents.dev/ws/client/ABC123');
      });
    });

    group('current configuration', () {
      test('defaults to development when no environment is set', () {
        // By default, tests run without --dart-define, so should use development
        final config = EnvironmentConfig.current;
        expect(config.environment, Environment.development);
        expect(config.relayUrl, 'localhost:8080');
        expect(config.useSecureWebSocket, isFalse);
      });

      // Note: Testing production environment requires running tests with:
      // flutter test --dart-define=ENVIRONMENT=production
      // This is typically done in CI/CD pipelines or manual testing
    });

    group('getRelayWebSocketUrl', () {
      test('formats URL correctly for development', () {
        final url = EnvironmentConfig.development.getRelayWebSocketUrl('XYZ789');
        expect(url, 'ws://localhost:8080/ws/client/XYZ789');
      });

      test('formats URL correctly for production', () {
        final url = EnvironmentConfig.production.getRelayWebSocketUrl('XYZ789');
        expect(url, 'wss://relay.remoteagents.dev/ws/client/XYZ789');
      });

      test('handles different pairing codes', () {
        final config = EnvironmentConfig.production;
        expect(config.getRelayWebSocketUrl('A1B2C3'),
            'wss://relay.remoteagents.dev/ws/client/A1B2C3');
        expect(config.getRelayWebSocketUrl('TESTCD'),
            'wss://relay.remoteagents.dev/ws/client/TESTCD');
      });
    });

    group('equality and hashCode', () {
      test('two development configs are equal', () {
        const config1 = EnvironmentConfig.development;
        const config2 = EnvironmentConfig.development;
        expect(config1, equals(config2));
        expect(config1.hashCode, equals(config2.hashCode));
      });

      test('two production configs are equal', () {
        const config1 = EnvironmentConfig.production;
        const config2 = EnvironmentConfig.production;
        expect(config1, equals(config2));
        expect(config1.hashCode, equals(config2.hashCode));
      });

      test('development and production configs are not equal', () {
        const config1 = EnvironmentConfig.development;
        const config2 = EnvironmentConfig.production;
        expect(config1, isNot(equals(config2)));
      });
    });

    group('toString', () {
      test('development config has readable string representation', () {
        final str = EnvironmentConfig.development.toString();
        expect(str, contains('Development'));
        expect(str, contains('localhost:8080'));
        expect(str, contains('useSecureWebSocket: false'));
      });

      test('production config has readable string representation', () {
        final str = EnvironmentConfig.production.toString();
        expect(str, contains('Production'));
        expect(str, contains('relay.remoteagents.dev'));
        expect(str, contains('useSecureWebSocket: true'));
      });
    });

    group('environment switching verification', () {
      test('verifies correct URL per environment', () {
        // Development environment
        final devConfig = EnvironmentConfig.development;
        expect(devConfig.relayUrl, 'localhost:8080');
        expect(devConfig.useSecureWebSocket, isFalse);
        expect(
          devConfig.getRelayWebSocketUrl('TEST01'),
          'ws://localhost:8080/ws/client/TEST01',
        );

        // Production environment
        final prodConfig = EnvironmentConfig.production;
        expect(prodConfig.relayUrl, 'relay.remoteagents.dev');
        expect(prodConfig.useSecureWebSocket, isTrue);
        expect(
          prodConfig.getRelayWebSocketUrl('TEST01'),
          'wss://relay.remoteagents.dev/ws/client/TEST01',
        );
      });

      test('WebSocket protocol matches environment security setting', () {
        // Development uses non-secure WebSocket (ws://)
        final devUrl = EnvironmentConfig.development.getRelayWebSocketUrl('ABC');
        expect(devUrl.startsWith('ws://'), isTrue);
        expect(devUrl.startsWith('wss://'), isFalse);

        // Production uses secure WebSocket (wss://)
        final prodUrl = EnvironmentConfig.production.getRelayWebSocketUrl('ABC');
        expect(prodUrl.startsWith('wss://'), isTrue);
        expect(prodUrl.startsWith('ws://'), isFalse);
      });
    });
  });
}
