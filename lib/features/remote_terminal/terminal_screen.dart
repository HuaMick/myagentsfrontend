import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart' as xterm;
import '../../core/networking/relay_client.dart';
import '../../core/crypto/key_pair.dart';
import 'terminal_controller.dart';
import 'terminal_state.dart';

/// Main screen for remote terminal display using xterm.dart.
///
/// TerminalScreen renders a full-screen terminal with:
/// - xterm widget for terminal output and ANSI color rendering
/// - Connection status indicator in AppBar
/// - Disconnect button to close connection
/// - Loading, error, and disconnected state handling
///
/// Requires RelayClient and key pairs to be available via Provider or passed.
class TerminalScreen extends StatefulWidget {
  /// Optional RelayClient instance. If not provided, uses Provider.
  final RelayClient? relayClient;

  /// Our encryption keys. If not provided, uses Provider.
  final KeyPair? ourKeys;

  /// Remote peer's encryption keys. If not provided, uses Provider.
  final KeyPair? remoteKeys;

  const TerminalScreen({
    super.key,
    this.relayClient,
    this.ourKeys,
    this.remoteKeys,
  });

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  RemoteTerminalController? _controller;
  RemoteTerminalState? _terminalState;
  FocusNode? _focusNode;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _terminalState = RemoteTerminalState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initializeController();
      _initialized = true;
    }
  }

  void _initializeController() {
    // Get dependencies from widget props or Provider
    final relayClient = widget.relayClient ??
        Provider.of<RelayClient>(context, listen: false);
    final ourKeys = widget.ourKeys ??
        Provider.of<KeyPair>(context, listen: false);

    // For remote keys, we need a way to get them
    // This would typically come from the pairing process
    KeyPair? remoteKeys = widget.remoteKeys;
    if (remoteKeys == null) {
      try {
        remoteKeys = Provider.of<KeyPair>(context, listen: false);
      } catch (e) {
        // Remote keys not available, show error
        _terminalState?.setError('Remote keys not available. Complete pairing first.');
        return;
      }
    }

    // Create terminal controller
    _controller = RemoteTerminalController(
      relayClient: relayClient,
      ourKeys: ourKeys,
      remoteKeys: remoteKeys,
      terminalState: _terminalState!,
    );

    // Update state based on relay connection status
    if (relayClient.isConnected) {
      _terminalState?.setConnectionStatus(RemoteTerminalConnectionStatus.connected);
      // Request focus after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode?.requestFocus();
      });
    } else {
      _terminalState?.setConnectionStatus(RemoteTerminalConnectionStatus.connecting);
    }

    // Listen for connection state changes
    relayClient.stateManager.addListener(_onConnectionStateChanged);
  }

  void _onConnectionStateChanged() {
    if (_controller == null) return;

    final stateManager = _controller!.relayClient.stateManager;

    if (stateManager.isConnected) {
      _terminalState?.setConnectionStatus(RemoteTerminalConnectionStatus.connected);
      // Request focus when connected
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode?.requestFocus();
      });
    } else if (stateManager.isConnecting) {
      _terminalState?.setConnectionStatus(RemoteTerminalConnectionStatus.connecting);
    } else if (stateManager.hasError) {
      _terminalState?.setError(stateManager.errorMessage ?? 'Connection error');
    } else {
      _terminalState?.setConnectionStatus(RemoteTerminalConnectionStatus.disconnected);
    }
  }

  void _handleDisconnect() {
    _controller?.relayClient.disconnect();
    context.go('/');
  }

  void _handleRetry() {
    _terminalState?.setConnectionStatus(RemoteTerminalConnectionStatus.connecting);
    _controller?.relayClient.reconnect().catchError((e) {
      _terminalState?.setError('Reconnection failed: $e');
    });
  }

  @override
  void dispose() {
    _controller?.relayClient.stateManager.removeListener(_onConnectionStateChanged);
    _controller?.dispose();
    _focusNode?.dispose();
    _terminalState?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: const Text('Remote Terminal'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleDisconnect,
        ),
        actions: [
          _buildConnectionStatus(),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Disconnect',
            onPressed: _handleDisconnect,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildConnectionStatus() {
    return ListenableBuilder(
      listenable: _terminalState!,
      builder: (context, child) {
        final Color statusColor;
        final String statusText;

        switch (_terminalState!.connectionStatus) {
          case RemoteTerminalConnectionStatus.connected:
            statusColor = Colors.green;
            statusText = 'Connected';
          case RemoteTerminalConnectionStatus.connecting:
            statusColor = Colors.orange;
            statusText = 'Connecting...';
          case RemoteTerminalConnectionStatus.error:
            statusColor = Colors.red;
            statusText = 'Error';
          case RemoteTerminalConnectionStatus.disconnected:
            statusColor = Colors.grey;
            statusText = 'Disconnected';
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    return ListenableBuilder(
      listenable: _terminalState!,
      builder: (context, child) {
        switch (_terminalState!.connectionStatus) {
          case RemoteTerminalConnectionStatus.connecting:
            return _buildLoadingState();
          case RemoteTerminalConnectionStatus.error:
            return _buildErrorState();
          case RemoteTerminalConnectionStatus.disconnected:
            return _buildDisconnectedState();
          case RemoteTerminalConnectionStatus.connected:
            return _buildTerminalView();
        }
      },
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Colors.green,
          ),
          SizedBox(height: 16),
          Text(
            'Connecting...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            _terminalState?.errorMessage ?? 'Connection error',
            style: const TextStyle(
              color: Colors.red,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _handleRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _handleDisconnect,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDisconnectedState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cloud_off,
            color: Colors.grey,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Disconnected',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _handleRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reconnect'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _handleDisconnect,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalView() {
    if (_controller == null) {
      return const Center(
        child: Text(
          'Terminal not initialized',
          style: TextStyle(color: Colors.red),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate terminal size based on available space
        // Using a monospace font at roughly 8x16 pixels per character
        const charWidth = 8.0;
        const charHeight = 16.0;

        final cols = (constraints.maxWidth / charWidth).floor();
        final rows = (constraints.maxHeight / charHeight).floor();

        // Update terminal size if changed
        if (cols != _terminalState!.cols || rows != _terminalState!.rows) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _controller?.resize(rows, cols);
          });
        }

        return Focus(
          focusNode: _focusNode,
          autofocus: true,
          child: xterm.TerminalView(
            _controller!.terminal,
            textStyle: const xterm.TerminalStyle(
              fontSize: 14,
              fontFamily: 'monospace',
            ),
            theme: const xterm.TerminalTheme(
              cursor: Color(0xFFFFFFFF),
              selection: Color(0x80FFFFFF),
              foreground: Color(0xFFFFFFFF),
              background: Color(0xFF000000),
              black: Color(0xFF000000),
              white: Color(0xFFFFFFFF),
              red: Color(0xFFCD3131),
              green: Color(0xFF0DBC79),
              yellow: Color(0xFFE5E510),
              blue: Color(0xFF2472C8),
              magenta: Color(0xFFBC3FBC),
              cyan: Color(0xFF11A8CD),
              brightBlack: Color(0xFF666666),
              brightRed: Color(0xFFF14C4C),
              brightGreen: Color(0xFF23D18B),
              brightYellow: Color(0xFFF5F543),
              brightBlue: Color(0xFF3B8EEA),
              brightMagenta: Color(0xFFD670D6),
              brightCyan: Color(0xFF29B8DB),
              brightWhite: Color(0xFFFFFFFF),
              searchHitBackground: Color(0xFFFFDF5D),
              searchHitBackgroundCurrent: Color(0xFFFF9632),
              searchHitForeground: Color(0xFF000000),
            ),
          ),
        );
      },
    );
  }
}
