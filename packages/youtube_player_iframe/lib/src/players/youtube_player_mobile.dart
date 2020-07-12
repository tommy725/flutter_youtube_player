// Copyright 2020 Sarbagya Dhaubanjar. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:youtube_player_iframe/src/enums/youtube_error.dart';
import 'package:youtube_player_iframe/src/helpers/player_fragments.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../controller.dart';
import '../enums/player_state.dart';
import '../meta_data.dart';

/// A youtube player widget which interacts with the underlying webview inorder to play YouTube videos.
///
/// Use [YoutubePlayerIFrame] instead.
class RawYoutubePlayer extends StatefulWidget {
  /// Sets [Key] as an identification to underlying web view associated to the player.
  final Key key;

  /// The [YoutubePlayerController].
  final YoutubePlayerController controller;

  /// Creates a [RawYoutubePlayer] widget.
  RawYoutubePlayer(
    this.controller, {
    this.key,
  });

  @override
  _MobileYoutubePlayerState createState() => _MobileYoutubePlayerState();
}

class _MobileYoutubePlayerState extends State<RawYoutubePlayer>
    with WidgetsBindingObserver {
  YoutubePlayerController controller;
  InAppWebViewController _webController;
  PlayerState _cachedPlayerState;
  bool _isPlayerReady = false;
  bool _onLoadStopCalled = false;

  @override
  void initState() {
    super.initState();
    controller = widget.controller;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_cachedPlayerState != null &&
            _cachedPlayerState == PlayerState.playing) {
          controller?.play();
        }
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.paused:
        _cachedPlayerState = controller.value.playerState;
        controller?.pause();
        break;
      default:
    }
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      key: widget.key,
      initialData: InAppWebViewInitialData(
        data: player,
        baseUrl: 'https://www.youtube.com',
        encoding: 'utf-8',
        mimeType: 'text/html',
      ),
      initialOptions: InAppWebViewGroupOptions(
        ios: IOSInAppWebViewOptions(allowsInlineMediaPlayback: true),
        crossPlatform: InAppWebViewOptions(
          userAgent: userAgent,
          mediaPlaybackRequiresUserGesture: false,
          transparentBackground: true,
        ),
      ),
      onWebViewCreated: (webController) {
        controller.invokeJavascript = _callMethod;
        _webController = webController;
        webController
          ..addJavaScriptHandler(
            handlerName: 'Ready',
            callback: (_) {
              _isPlayerReady = true;
              if (_onLoadStopCalled) {
                controller.add(
                  controller.value.copyWith(isReady: true),
                );
              }
            },
          )
          ..addJavaScriptHandler(
            handlerName: 'StateChange',
            callback: (args) {
              switch (args.first as int) {
                case -1:
                  controller.add(
                    controller.value.copyWith(
                      playerState: PlayerState.unStarted,
                      isReady: true,
                    ),
                  );
                  break;
                case 0:
                  controller.add(
                    controller.value.copyWith(
                      playerState: PlayerState.ended,
                    ),
                  );
                  break;
                case 1:
                  controller.add(
                    controller.value.copyWith(
                      playerState: PlayerState.playing,
                      hasPlayed: true,
                      error: YoutubeError.none,
                    ),
                  );
                  break;
                case 2:
                  controller.add(
                    controller.value.copyWith(
                      playerState: PlayerState.paused,
                    ),
                  );
                  break;
                case 3:
                  controller.add(
                    controller.value.copyWith(
                      playerState: PlayerState.buffering,
                    ),
                  );
                  break;
                case 5:
                  controller.add(
                    controller.value.copyWith(
                      playerState: PlayerState.cued,
                    ),
                  );
                  break;
                default:
                  throw Exception("Invalid player state obtained.");
              }
            },
          )
          ..addJavaScriptHandler(
            handlerName: 'PlaybackQualityChange',
            callback: (args) {
              controller.add(
                controller.value
                    .copyWith(playbackQuality: args.first as String),
              );
            },
          )
          ..addJavaScriptHandler(
            handlerName: 'PlaybackRateChange',
            callback: (args) {
              final num rate = args.first;
              controller.add(
                controller.value.copyWith(playbackRate: rate.toDouble()),
              );
            },
          )
          ..addJavaScriptHandler(
            handlerName: 'Errors',
            callback: (args) {
              controller.add(
                controller.value.copyWith(error: errorEnum(args.first as int)),
              );
            },
          )
          ..addJavaScriptHandler(
            handlerName: 'VideoData',
            callback: (args) {
              controller.add(
                controller.value.copyWith(
                    metaData: YoutubeMetaData.fromRawData(args.first)),
              );
            },
          )
          ..addJavaScriptHandler(
            handlerName: 'VideoTime',
            callback: (args) {
              final position = args.first * 1000;
              final num buffered = args.last;
              controller.add(
                controller.value.copyWith(
                  position: Duration(milliseconds: position.floor()),
                  buffered: buffered.toDouble(),
                ),
              );
            },
          );
      },
      onLoadStop: (_, __) {
        _onLoadStopCalled = true;
        if (_isPlayerReady) {
          controller.add(
            controller.value.copyWith(isReady: true),
          );
        }
      },
      onConsoleMessage: (_, message) {
        log(message.message);
      },
      onEnterFullscreen: (_) {
        if (controller.onEnterFullscreen != null) {
          controller.onEnterFullscreen();
        }
      },
      onExitFullscreen: (_) {
        if (controller.onExitFullscreen != null) {
          controller.onExitFullscreen();
        }
      },
    );
  }

  void _callMethod(String methodName) {
    if (_webController == null) {
      log('Youtube Player is not ready for method calls.');
    }
    _webController.evaluateJavascript(source: methodName);
  }

  String get player => '''
    <!DOCTYPE html>
    <html>
    $playerDocHead
    <body>
        <div id="player"></div>
        <script>
            $initPlayerIFrame
            var player;
            var timerId;
            function onYouTubeIframeAPIReady() {
                player = new YT.Player('player', {
                    height: '100%',
                    width: '100%',
                    videoId: '${controller.initialVideoId}',
                    playerVars: ${playerVars(controller)},
                    events: {
                        onReady: function(event) { window.flutter_inappwebview.callHandler('Ready'); },
                        onStateChange: function(event) { sendPlayerStateChange(event.data); },
                        onPlaybackQualityChange: function(event) { window.flutter_inappwebview.callHandler('PlaybackQualityChange', event.data); },
                        onPlaybackRateChange: function(event) { window.flutter_inappwebview.callHandler('PlaybackRateChange', event.data); },
                        onError: function(error) { window.flutter_inappwebview.callHandler('Errors', error.data); }
                    },
                });
            }

            function sendPlayerStateChange(playerState) {
                clearTimeout(timerId);
                window.flutter_inappwebview.callHandler('StateChange', playerState);
                if (playerState == 1) {
                    startSendCurrentTimeInterval();
                    sendVideoData(player);
                }
            }

            function sendVideoData(player) {
                var videoData = {
                    'duration': player.getDuration(),
                    'title': player.getVideoData().title,
                    'author': player.getVideoData().author,
                    'videoId': player.getVideoData().video_id
                };
                window.flutter_inappwebview.callHandler('VideoData', videoData);
            }

            function startSendCurrentTimeInterval() {
                timerId = setInterval(function () {
                    window.flutter_inappwebview.callHandler('VideoTime', player.getCurrentTime(), player.getVideoLoadedFraction());
                }, 100);
            }

            $youtubeIFrameFunctions
        </script>
    </body>
    </html>
  ''';

  String boolean({@required bool value}) => value ? "'1'" : "'0'";

  String get userAgent => controller.params.forceHD
      ? 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36'
      : null;
}
