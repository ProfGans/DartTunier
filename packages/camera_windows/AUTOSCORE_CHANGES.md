# Local camera_windows extension

Based on camera_windows 0.3.0. Original BSD license and public API retained.

The optional `dart_tournament/autoscore_video` method channel adds `configure`
(up to three camera texture IDs; empty list disables) and `read` (drains bounded
RGB queues). Preview callbacks provide host-monotonic microsecond timestamps,
per-camera sequence numbers and dropped-frame counts. Frames are converted
from packed Media Foundation RGB32/BGRA to RGB; unsupported strides are rejected.
No frame allocation or conversion occurs unless that camera is enabled.

Files changed: camera_plugin.{h,cpp}, texture_handler.cpp, CMakeLists.txt.
Added: autoscore_video_buffer.{h,cpp}. Camera destruction releases its queue.
Callbacks do not call Flutter directly; the UI thread reads through the channel.

Limits: six frames per camera, at most 1280 pixels wide and one frame per 20 ms.
This is approximate host-arrival alignment, not exposure/hardware synchronization.
