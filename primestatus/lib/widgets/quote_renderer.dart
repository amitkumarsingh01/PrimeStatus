import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/quote_template.dart';
import '../models/user_model.dart';

class QuoteRenderer extends StatelessWidget {
  final QuoteTemplate template;
  final UserModel user;
  final GlobalKey repaintKey = GlobalKey();

  QuoteRenderer({
    Key? key,
    required this.template,
    required this.user,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: repaintKey,
      child: Container(
        width: 400,
        height: 400,
        child: Stack(
          children: [
            // Background image
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: template.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => Icon(Icons.error),
              ),
            ),
            
            // Text overlays
            ...template.txtLocation.map((textLoc) => Positioned(
              left: textLoc.x,
              top: textLoc.y,
              child: Container(
                padding: template.placeholderWithBackground 
                    ? EdgeInsets.all(8) 
                    : EdgeInsets.zero,
                decoration: template.placeholderWithBackground
                    ? BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(4),
                      )
                    : null,
                child: Text(
                  _replacePlaceholder(textLoc.placeholder, user),
                  style: TextStyle(
                    fontSize: textLoc.fontSize,
                    color: Color(int.parse(textLoc.color.replaceFirst('#', '0xFF'))),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )),
            
            // Image placeholders (profile photos)
            ...template.imgPlaceholderLocation.map((imgLoc) => Positioned(
              left: imgLoc.x,
              top: imgLoc.y,
              child: Container(
                width: imgLoc.size,
                height: imgLoc.size,
                decoration: BoxDecoration(
                  shape: imgLoc.shape == 'circle' ? BoxShape.circle : BoxShape.rectangle,
                  image: user.profilePhotoUrl != null
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(user.profilePhotoUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: user.profilePhotoUrl == null
                    ? Icon(Icons.person, size: imgLoc.size * 0.6)
                    : null,
              ),
            )),
          ],
        ),
      ),
    );
  }

  String _replacePlaceholder(String placeholder, UserModel user) {
    return placeholder
        .replaceAll('{name}', user.name)
        .replaceAll('{mobile_number}', user.mobileNumber ?? '')
        .replaceAll('{state}', user.state)
        .replaceAll('{religion}', user.religion);
  }

  Future<Uint8List?> captureWidget() async {
    try {
      RenderRepaintBoundary boundary = 
          repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('Error capturing widget: $e');
      return null;
    }
  }
} 