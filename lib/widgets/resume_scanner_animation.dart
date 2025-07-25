import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class ResumeScannerAnimation extends AnimatedWidget {
  final bool stopped;
  final double width;

  const ResumeScannerAnimation(this.stopped, this.width, {Key? key, required Animation<double> animation})
      : super(key: key, listenable: animation);

  @override
  Widget build(BuildContext context) {
    final animation = listenable as Animation<double>;
    final containerHeight = MediaQuery.of(context).size.height * 0.57;
    // Blue laser line effect
    final linePosition = animation.value * (containerHeight - 4); // 4 is line thickness

    return Positioned(
      top: linePosition,
      left: 17,
      child: Opacity(
        opacity: stopped ? 0.0 : 0.5,
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.93,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blueAccent.withOpacity(0.8),
                  Colors.blueAccent.withOpacity(0.2),
                  Colors.blueAccent.withOpacity(0.8),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: const [0.0, 0.5, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: Offset(0, 0),
                ),
              ],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}