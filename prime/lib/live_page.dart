import 'package:flutter/material.dart';
import 'package:prime/pk_widgets/config.dart';

import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';

import 'package:prime/common.dart';
import 'package:prime/constants.dart';
import 'package:prime/pk_widgets/events.dart';
import 'package:prime/pk_widgets/widgets/mute_button.dart';
import 'package:prime/pk_widgets/surface.dart';

class LivePage extends StatefulWidget {
  final String liveID;
  final String localUserID;
  final bool isHost;

  const LivePage({
    Key? key,
    required this.liveID,
    required this.localUserID,
    this.isHost = false,
  }) : super(key: key);

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  final liveStateNotifier = ValueNotifier<ZegoLiveStreamingState>(
    ZegoLiveStreamingState.idle,
  );

  final requestingHostsMapRequestIDNotifier =
      ValueNotifier<Map<String, List<String>>>({});
  final requestIDNotifier = ValueNotifier<String>('');
  PKEvents? pkEvents;

  @override
  void initState() {
    super.initState();

    pkEvents = PKEvents(
      requestIDNotifier: requestIDNotifier,
      requestingHostsMapRequestIDNotifier: requestingHostsMapRequestIDNotifier,
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = (widget.isHost
        ? (ZegoUIKitPrebuiltLiveStreamingConfig.host(
            plugins: [ZegoUIKitSignalingPlugin()],
          )

          /// on host can control pk
          ..foreground = PKV2Surface(
            requestIDNotifier: requestIDNotifier,
            liveStateNotifier: liveStateNotifier,
            requestingHostsMapRequestIDNotifier:
                requestingHostsMapRequestIDNotifier,
          ))
        : ZegoUIKitPrebuiltLiveStreamingConfig.audience(
            plugins: [ZegoUIKitSignalingPlugin()],
          ))
      ..avatarBuilder = customAvatarBuilder
      ..audioVideoView.foregroundBuilder = foregroundBuilder
      ..pkBattle = pkConfig()

      /// support minimizing
      ..topMenuBar.buttons = [
        ZegoLiveStreamingMenuBarButtonName.minimizingButton
      ];

    return SafeArea(
      child: Scaffold(
        body: Stack(
          children: [
            ZegoUIKitPrebuiltLiveStreaming(
              appID: 615877954, // input your AppID
              appSign: '12e07321bd8231dda371ea9235e274178403bd97a7ccabcb09e22474c42da3a4', 
              userID: widget.localUserID,
              userName: 'user_${widget.localUserID}',
              liveID: widget.liveID,
              config: config,
              events: ZegoUIKitPrebuiltLiveStreamingEvents(
                pk: pkEvents?.event,
                onStateUpdated: (state) {
                  liveStateNotifier.value = state;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget foregroundBuilder(context, size, ZegoUIKitUser? user, _) {
    if (user == null) {
      return Container();
    }

    final hostWidgets = [
      /// mute pk user
      Positioned(
        top: 5,
        left: 5,
        child: SizedBox(
          width: 40,
          height: 40,
          child: PKMuteButton(userID: user.id),
        ),
      ),
    ];

    return Stack(
      children: [
        ...((widget.isHost && user.id != widget.localUserID)
            ? hostWidgets
            : []),

        /// camera state
        Positioned(
          top: 5,
          right: 35,
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircleAvatar(
              backgroundColor: Colors.purple.withOpacity(0.6),
              child: Icon(
                user.camera.value ? Icons.videocam : Icons.videocam_off,
                color: Colors.white,
                size: 15,
              ),
            ),
          ),
        ),

        /// microphone state
        Positioned(
          top: 5,
          right: 5,
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircleAvatar(
              backgroundColor: Colors.purple.withOpacity(0.6),
              child: Icon(
                user.microphone.value ? Icons.mic : Icons.mic_off,
                color: Colors.white,
                size: 15,
              ),
            ),
          ),
        ),

        /// name
        Positioned(
          top: 25,
          right: 5,
          child: Container(
            // width: 30,
            height: 18,
            color: Colors.purple,
            child: Text(user.name),
          ),
        ),
      ],
    );
  }
}
