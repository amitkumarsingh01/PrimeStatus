import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:no_screenshot/no_screenshot.dart';

class SecurityWrapper extends StatefulWidget {
  final Widget child;

  const SecurityWrapper({Key? key, required this.child}) : super(key: key);

  @override
  State<SecurityWrapper> createState() => _SecurityWrapperState();
}

class _SecurityWrapperState extends State<SecurityWrapper> with WidgetsBindingObserver {
  final _noScreenshot = NoScreenshot.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enableSecurityFeatures();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Stop screenshot listening when widget is disposed
    _noScreenshot.stopScreenshotListening();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _enableSecurityFeatures();
    } else if (state == AppLifecycleState.paused) {
      // Additional security when app goes to background
      _noScreenshot.screenshotOff();
    }
  }

  void _enableSecurityFeatures() async {
    // Disable screenshots using the no_screenshot plugin
    await _noScreenshot.screenshotOff();

    // Start listening for screenshot attempts
    await _noScreenshot.startScreenshotListening();

    // Subscribe to screenshot events (optional - for logging purposes)
    _noScreenshot.screenshotStream.listen((value) {
      if (value.wasScreenshotTaken) {
        debugPrint('Screenshot attempt detected!');
        // You could log this event or take other actions
      }
    });

    // Additional platform security measures
    // For Android
    SystemChannels.platform.invokeMethod('SystemChrome.setEnabledSystemUIMode', [
      'SystemUiMode.manual',
      {'overlays': []}
    ]);

    // For iOS
    const methodChannel = MethodChannel('security_channel');
    methodChannel.invokeMethod('preventScreenCapture');
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}