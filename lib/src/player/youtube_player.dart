// Copyright 2019 Sarbagya Dhaubanjar. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../enums/thumbnail_quality.dart';
import '../utils/errors.dart';
import '../utils/youtube_meta_data.dart';
import '../utils/youtube_player_controller.dart';
import '../utils/youtube_player_flags.dart';
import '../widgets/widgets.dart';
import 'fullscreen_youtube_player.dart';
import 'raw_youtube_player.dart';

/// A widget to play or stream YouTube videos using the official [YouTube IFrame Player API](https://developers.google.com/youtube/iframe_api_reference).
///
/// In order to play live videos, set `isLive` property to true in [YoutubePlayerFlags].
///
///
/// Using YoutubePlayer widget:
///
/// ```dart
/// YoutubePlayer(
///    context: context,
///    initialVideoId: 'iLnmTe5Q2Qw',
///    flags: YoutubePlayerFlags(
///      autoPlay: true,
///      showVideoProgressIndicator: true,
///    ),
///    videoProgressIndicatorColor: Colors.amber,
///    progressColors: ProgressColors(
///      playedColor: Colors.amber,
///      handleColor: Colors.amberAccent,
///    ),
///    onPlayerInitialized: (controller) {
///      _controller = controller..addListener(listener);
///    },
///)
/// ```
///
class YoutubePlayer extends StatefulWidget {
  /// Sets [Key] as an identification to underlying web view associated to the player.
  final Key webViewKey;

  /// A [YoutubePlayerController] to control the player.
  final YoutubePlayerController controller;

  /// {@template youtube_player_flutter.width}
  /// Defines the width of the player.
  ///
  /// Default is devices's width.
  /// {@endtemplate}
  final double width;

  /// {@template youtube_player_flutter.aspectRatio}
  /// Defines the aspect ratio to be assigned to the player. This property along with [width] calculates the player size.
  ///
  /// Default is 16 / 9.
  /// {@endtemplate}
  final double aspectRatio;

  /// {@template youtube_player_flutter.controlsTimeOut}
  /// The duration for which controls in the player will be visible.
  ///
  /// Default is 3 seconds.
  /// {@endtemplate}
  final Duration controlsTimeOut;

  /// {@template youtube_player_flutter.bufferIndicator}
  /// Overrides the default buffering indicator for the player.
  /// {@endtemplate}
  final Widget bufferIndicator;

  /// {@template youtube_player_flutter.progressColors}
  /// Overrides default colors of the progress bar, takes [ProgressColors].
  /// {@endtemplate}
  final ProgressBarColors progressColors;

  /// {@template youtube_player_flutter.progressIndicatorColor}
  /// Overrides default color of progress indicator shown below the player(if enabled).
  /// {@endtemplate}
  final Color progressIndicatorColor;

  /// {@template youtube_player_flutter.onReady}
  /// Called when player is ready to perform control methods like:
  /// play(), pause(), load(), cue(), etc.
  /// {@endtemplate}
  final VoidCallback onReady;

  /// {@template youtube_player_flutter.onEnded}
  /// Called when player had ended playing a video.
  ///
  /// Returns [YoutubeMetaData] for the video that has just ended playing.
  /// {@endtemplate}
  final void Function(YoutubeMetaData metaData) onEnded;

  /// {@template youtube_player_flutter.liveUIColor}
  /// Overrides color of Live UI when enabled.
  /// {@endtemplate}
  final Color liveUIColor;

  /// {@template youtube_player_flutter.topActions}
  /// Adds custom top bar widgets.
  /// {@endtemplate}
  final List<Widget> topActions;

  /// {@template youtube_player_flutter.bottomActions}
  /// Adds custom bottom bar widgets.
  /// {@endtemplate}
  final List<Widget> bottomActions;

  /// {@template youtube_player_flutter.actionsPadding}
  /// Defines padding for [topActions] and [bottomActions].
  ///
  /// Default is EdgeInsets.all(8.0).
  /// {@endtemplate}
  final EdgeInsetsGeometry actionsPadding;

  /// {@template youtube_player_flutter.thumbnailUrl}
  /// Thumbnail to show when player is loading.
  ///
  /// If not set, default thumbnail of the video is shown.
  /// {@endtemplate}
  final String thumbnailUrl;

  /// {@template youtube_player_flutter.showVideoProgressIndicator}
  /// Defines whether to show or hide progress indicator below the player.
  ///
  /// Default is false.
  /// {@endtemplate}
  final bool showVideoProgressIndicator;

  /// Creates [YoutubePlayer] widget.
  const YoutubePlayer({
    this.webViewKey,
    @required this.controller,
    this.width,
    this.aspectRatio = 16 / 9,
    this.controlsTimeOut = const Duration(seconds: 3),
    this.bufferIndicator,
    this.progressIndicatorColor = Colors.red,
    this.progressColors,
    this.onReady,
    this.onEnded,
    this.liveUIColor = Colors.red,
    this.topActions,
    this.bottomActions,
    this.actionsPadding = const EdgeInsets.all(8.0),
    this.thumbnailUrl,
    this.showVideoProgressIndicator = false,
  });

  /// Converts fully qualified YouTube Url to video id.
  ///
  /// If videoId is passed as url then no conversion is done.
  static String convertUrlToId(String url, {bool trimWhitespaces = true}) {
    assert(url?.isNotEmpty ?? false, 'Url cannot be empty');
    if (!url.contains('http') && (url.length == 11)) {
      return url;
    }
    if (trimWhitespaces) {
      url = url.trim();
    }

    for (final exp in [
      RegExp(
          r'^https:\/\/(?:www\.|m\.)?youtube\.com\/watch\?v=([_\-a-zA-Z0-9]{11}).*$'),
      RegExp(
          r'^https:\/\/(?:www\.|m\.)?youtube(?:-nocookie)?\.com\/embed\/([_\-a-zA-Z0-9]{11}).*$'),
      RegExp(r'^https:\/\/youtu\.be\/([_\-a-zA-Z0-9]{11}).*$')
    ]) {
      final Match match = exp.firstMatch(url);
      if (match != null && match.groupCount >= 1) {
        return match.group(1);
      }
    }

    return null;
  }

  /// Grabs YouTube video's thumbnail for provided video id.
  static String getThumbnail({
    @required String videoId,
    String quality = ThumbnailQuality.standard,
  }) =>
      'https://i3.ytimg.com/vi_webp/$videoId/$quality';

  @override
  _YoutubePlayerState createState() => _YoutubePlayerState();
}

class _YoutubePlayerState extends State<YoutubePlayer> {
  double _aspectRatio;
  bool _initialLoad = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(listener);

    _aspectRatio = widget.aspectRatio;
  }

  @override
  void didUpdateWidget(YoutubePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.controller?.removeListener(listener);
    widget.controller?.addListener(listener);
    widget.controller.value = oldWidget.controller.value;
  }

  Future<void> listener() async {
    if (widget.controller.value.isReady && _initialLoad) {
      _initialLoad = false;
      if (widget.controller.flags.autoPlay) {
        widget.controller.play();
      }
      if (widget.controller.flags.mute) {
        widget.controller.mute();
      }
      if (widget.onReady != null) {
        widget.onReady();
      }
      if (widget.controller.flags.controlsVisibleAtStart) {
        widget.controller.updateValue(
          widget.controller.value.copyWith(isControlsVisible: true),
        );
      }
    }
    if (widget.controller.value.toggleFullScreen) {
      widget.controller.updateValue(
        widget.controller.value.copyWith(
          toggleFullScreen: false,
          isControlsVisible: false,
        ),
      );
      if (widget.controller.value.isFullScreen) {
        Navigator.pop(context);
      } else {
        widget.controller.pause();

        await showFullScreenYoutubePlayer(
          context: context,
          videoId: widget.controller.metadata.videoId,
          actionsPadding: widget.actionsPadding,
          bottomActions: widget.bottomActions,
          bufferIndicator: widget.bufferIndicator,
          controlsTimeOut: widget.controlsTimeOut,
          liveUIColor: widget.liveUIColor,
          onReady: (ctrl) {
            ctrl.load(widget.controller.metadata.videoId,
                startAt: widget.controller.value.position.inSeconds);
          },
          progressColors: widget.progressColors,
          thumbnailUrl: widget.thumbnailUrl,
          topActions: widget.topActions,
        );

        Future.delayed(
            const Duration(seconds: 2), () => widget.controller.play());
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 0,
      color: Colors.black,
      child: InheritedYoutubePlayer(
        controller: widget.controller,
        child: Container(
          color: Colors.black,
          width: widget.width ?? MediaQuery.of(context).size.width,
          child: _buildPlayer(
            errorWidget: Container(
              color: Colors.black87,
              padding:
                  const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 5.0),
                      Expanded(
                        child: Text(
                          errorString(
                            widget.controller.value.errorCode,
                            videoId: widget.controller.metadata.videoId ??
                                widget.controller.initialVideoId,
                          ),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w300,
                            fontSize: 15.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  Text(
                    'Error Code: ${widget.controller.value.errorCode}',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayer({Widget errorWidget}) {
    return AspectRatio(
      aspectRatio: _aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        overflow: Overflow.visible,
        children: [
          RawYoutubePlayer(
            webViewKey: widget.webViewKey,
            onEnded: (YoutubeMetaData metaData) {
              if (widget.controller.flags.loop) {
                widget.controller.load(widget.controller.metadata.videoId);
              }
              if (widget.onEnded != null) {
                widget.onEnded(metaData);
              }
            },
          ),
          if (!widget.controller.flags.hideThumbnail)
            AnimatedOpacity(
              opacity: widget.controller.value.hasPlayed ? 0 : 1,
              duration: const Duration(milliseconds: 300),
              child: Image.network(
                widget.thumbnailUrl ??
                    YoutubePlayer.getThumbnail(
                      videoId: widget.controller.metadata.videoId.isEmpty
                          ? widget.controller.initialVideoId
                          : widget.controller.metadata.videoId,
                    ),
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(
                        color: Colors.black,
                      ),
              ),
            ),
          if (!widget.controller.flags.hideControls &&
              widget.controller.value.position >
                  const Duration(milliseconds: 100) &&
              !widget.controller.value.isControlsVisible &&
              widget.showVideoProgressIndicator &&
              !widget.controller.flags.isLive &&
              !widget.controller.value.isFullScreen)
            Positioned(
              bottom: -7.0,
              left: -7.0,
              right: -7.0,
              child: IgnorePointer(
                ignoring: true,
                child: ProgressBar(
                  colors: ProgressBarColors(
                    handleColor: Colors.transparent,
                    bufferedColor: Colors.white,
                    backgroundColor: Colors.black,
                  ),
                ),
              ),
            ),
          if (!widget.controller.flags.hideControls) ...[
            TouchShutter(
              disableDragSeek: widget.controller.flags.disableDragSeek,
              timeOut: widget.controlsTimeOut,
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: !widget.controller.flags.hideControls &&
                        widget.controller.value.isControlsVisible
                    ? 1
                    : 0,
                duration: const Duration(milliseconds: 300),
                child: widget.controller.flags.isLive
                    ? LiveBottomBar(liveUIColor: widget.liveUIColor)
                    : Padding(
                        padding: widget.bottomActions == null
                            ? const EdgeInsets.all(0.0)
                            : widget.actionsPadding,
                        child: Row(
                          children: widget.bottomActions ??
                              [
                                const SizedBox(width: 14.0),
                                const CurrentPosition(),
                                const SizedBox(width: 8.0),
                                const ProgressBar(isExpanded: true),
                                const RemainingDuration(),
                                const PlaybackSpeedButton(),
                                const FullScreenButton(),
                              ],
                        ),
                      ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: !widget.controller.flags.hideControls &&
                        widget.controller.value.isControlsVisible
                    ? 1
                    : 0,
                duration: const Duration(milliseconds: 300),
                child: Padding(
                  padding: widget.actionsPadding,
                  child: Row(
                    children: widget.topActions ?? [Container()],
                  ),
                ),
              ),
            ),
          ],
          if (!widget.controller.flags.hideControls)
            const Center(
              child: PlayPauseButton(),
            ),
          if (widget.controller.value.hasError) errorWidget,
        ],
      ),
    );
  }
}
