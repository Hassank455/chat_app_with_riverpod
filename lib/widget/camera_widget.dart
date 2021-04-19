import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

Widget cameraWidget(BuildContext context, CameraController controller) {
  var camera = controller.value;
  final size = MediaQuery.of(context).size;
  var scale = size.aspectRatio * camera.aspectRatio;
  if (scale < 1) scale = 1 / scale;
  return Transform.scale(
    scale: scale,
    child: Center(
      child: CameraPreview(controller),
    ),
  );
}