import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_constants.dart';
import '../widgets/common_widgets.dart';

class QuoteEditorScreen extends StatefulWidget {
  final String initialQuote;

  QuoteEditorScreen({required this.initialQuote});

  @override
  _QuoteEditorScreenState createState() => _QuoteEditorScreenState();
}

class _QuoteEditorScreenState extends State<QuoteEditorScreen> {
  late TextEditingController _quoteController;
  String selectedFont = 'Roboto';
  double fontSize = 24.0;
  Color textColor = Colors.white;
  TextAlign textAlignment = TextAlign.center;
  int selectedBackgroundIndex = 0;

  @override
  void initState() {
    super.initState();
    _quoteController = TextEditingController(text: widget.initialQuote);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.pink.shade50,
            Colors.purple.shade50,
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Quote Editor'),
          backgroundColor: Colors.transparent,
          actions: [
            IconButton(
              icon: Icon(Icons.download),
              onPressed: _downloadQuote,
            ),
            IconButton(
              icon: Icon(Icons.share),
              onPressed: _shareQuote,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                margin: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppConstants.backgrounds[selectedBackgroundIndex],
                    ),
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          _quoteController.text,
                          style: TextStyle(
                            fontFamily: selectedFont,
                            fontSize: fontSize,
                            color: textColor,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                          textAlign: textAlignment,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildEditTextSection(),
                      SizedBox(height: 16),
                      _buildBackgroundSection(),
                      SizedBox(height: 16),
                      _buildTextStyleSection(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditTextSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Edit Quote',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        TextField(
          controller: _quoteController,
          maxLines: 3,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            hintText: 'Enter your quote here...',
          ),
          onChanged: (value) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildBackgroundSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Background',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 12),
        Container(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: AppConstants.backgrounds.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => setState(() => selectedBackgroundIndex = index),
                child: Container(
                  width: 60,
                  height: 60,
                  margin: EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    gradient: AppConstants.backgrounds[index],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selectedBackgroundIndex == index
                          ? Colors.purple
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTextStyleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Text Style',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 12),
        
        // Font Family
        Row(
          children: [
            Text('Font: ', style: TextStyle(fontWeight: FontWeight.w500)),
            Expanded(
              child: DropdownButton<String>(
                value: selectedFont,
                isExpanded: true,
                items: AppConstants.fonts.map((font) {
                  return DropdownMenuItem(
                    value: font,
                    child: Text(font, style: TextStyle(fontFamily: font)),
                  );
                }).toList(),
                onChanged: (value) => setState(() => selectedFont = value!),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        
        // Font Size
        Row(
          children: [
            Text('Size: ', style: TextStyle(fontWeight: FontWeight.w500)),
            Expanded(
              child: Slider(
                value: fontSize,
                min: 12,
                max: 48,
                divisions: 36,
                activeColor: Colors.purple,
                onChanged: (value) => setState(() => fontSize = value),
              ),
            ),
            Text('${fontSize.round()}'),
          ],
        ),
        SizedBox(height: 12),
        
        // Text Color
        Row(
          children: [
            Text('Color: ', style: TextStyle(fontWeight: FontWeight.w500)),
            Expanded(
              child: Container(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: AppConstants.textColors.length,
                  itemBuilder: (context, index) {
                    final color = AppConstants.textColors[index];
                    return GestureDetector(
                      onTap: () => setState(() => textColor = color),
                      child: Container(
                        width: 40,
                        height: 40,
                        margin: EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: textColor == color
                                ? Colors.purple
                                : Colors.grey.shade300,
                            width: textColor == color ? 3 : 1,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        
        // Text Alignment
        Row(
          children: [
            Text('Align: ', style: TextStyle(fontWeight: FontWeight.w500)),
            IconButton(
              onPressed: () => setState(() => textAlignment = TextAlign.left),
              icon: Icon(Icons.format_align_left),
              color: textAlignment == TextAlign.left ? Colors.purple : Colors.grey,
            ),
            IconButton(
              onPressed: () => setState(() => textAlignment = TextAlign.center),
              icon: Icon(Icons.format_align_center),
              color: textAlignment == TextAlign.center ? Colors.purple : Colors.grey,
            ),
            IconButton(
              onPressed: () => setState(() => textAlignment = TextAlign.right),
              icon: Icon(Icons.format_align_right),
              color: textAlignment == TextAlign.right ? Colors.purple : Colors.grey,
            ),
          ],
        ),
      ],
    );
  }

  void _downloadQuote() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.download, color: Colors.white),
            SizedBox(width: 8),
            Text('Quote saved to gallery!'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareQuote() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Share Quote',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CommonWidgets.buildShareOption(
                  'WhatsApp',
                  Icons.message,
                  Colors.green,
                  () => _shareToApp('WhatsApp'),
                ),
                CommonWidgets.buildShareOption(
                  'Instagram',
                  Icons.camera_alt,
                  Colors.purple,
                  () => _shareToApp('Instagram'),
                ),
                CommonWidgets.buildShareOption(
                  'Facebook',
                  Icons.facebook,
                  Colors.blue,
                  () => _shareToApp('Facebook'),
                ),
                CommonWidgets.buildShareOption(
                  'Twitter',
                  Icons.alternate_email,
                  Colors.lightBlue,
                  () => _shareToApp('Twitter'),
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CommonWidgets.buildShareOption(
                  'Copy Link',
                  Icons.link,
                  Colors.grey,
                  () => _copyLink(),
                ),
                CommonWidgets.buildShareOption(
                  'More',
                  Icons.more_horiz,
                  Colors.grey,
                  () => _shareMore(),
                ),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _shareToApp(String app) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sharing to $app...'),
        backgroundColor: Colors.purple,
      ),
    );
  }

  void _copyLink() {
    Navigator.pop(context);
    Clipboard.setData(ClipboardData(text: _quoteController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.copy, color: Colors.white),
            SizedBox(width: 8),
            Text('Quote copied to clipboard!'),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _shareMore() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening share menu...'),
        backgroundColor: Colors.purple,
      ),
    );
  }

  @override
  void dispose() {
    _quoteController.dispose();
    super.dispose();
  }
} 