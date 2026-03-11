import 'package:video_player/video_player.dart';

VideoPlayerController buildVideoControllerFromPath(String path) {
  // On web, ImagePicker returns a blob URL in `path`, which can be played as a network URL.
  return VideoPlayerController.networkUrl(Uri.parse(path));
}
