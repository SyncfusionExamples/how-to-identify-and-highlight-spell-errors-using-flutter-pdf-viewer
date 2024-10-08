import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'words.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PdfViewerPage(),
    );
  }
}

/// Widget to display the PDF document using [SfPdfViewer].
class PdfViewerPage extends StatefulWidget {
  const PdfViewerPage({super.key});

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  late final PdfViewerController _pdfViewerController;

  // PdfDocument instance of the loaded document
  PdfDocument? _document;

  final RegExp websiteRegex = RegExp(
      r'((http|https):\/\/)?(www\.)?[a-zA-Z0-9-]+\.[a-zA-Z]{2,}(\.[a-zA-Z]{2,})?');
  final RegExp onlyNumbersRegex = RegExp(r'\d');
  final RegExp onlySymbolsRegex = RegExp(r'^[^\w\s]+$');

  @override
  void initState() {
    super.initState();
    // Initialize the PdfViewerController
    _pdfViewerController = PdfViewerController();
    // Set the default squiggly annotation color to red
    _pdfViewerController.annotationSettings.squiggly.color = Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0),
          child: Container(
            color: Theme.of(context).colorScheme.outlineVariant,
            height: 1,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.onInverseSurface,
              ),
              onPressed: () => _performSpellCheck(),
              child: const Text('Perform Spell Check'),
            ),
          ),
        ],
      ),
      body: SfPdfViewer.asset(
        'assets/Global warming.pdf',
        // Set the controller to the PdfViewer to add annotations
        controller: _pdfViewerController,
        onDocumentLoaded: (PdfDocumentLoadedDetails details) {
          // PdfDocument instance of the loaded document
          _document = details.document;
        },
      ),
    );
  }

  @override
  void dispose() {
    // Dispose the PdfViewerController
    _pdfViewerController.dispose();
    super.dispose();
  }

  // Method to perform the spell check
  void _performSpellCheck() async {
    if (_document == null) {
      return;
    }

    // Create a text extractor instance to extract text from the PDF document
    final PdfTextExtractor textExtractor = PdfTextExtractor(_document!);

    final Map<int, List<TextWord>> errorWords = <int, List<TextWord>>{};

    for (int pageIndex = 0; pageIndex < _document!.pages.count; pageIndex++) {
      // Extract text lines from the page
      final List<TextLine> textLines =
          textExtractor.extractTextLines(startPageIndex: pageIndex);

      // Iterate through line collection
      for (final TextLine textLine in textLines) {
        // Iterate through word collection
        for (final TextWord textWord in textLine.wordCollection) {
          // Get the word from the text word
          final String word = textWord.text;

          // Check if the word is misspelled
          if (_checkSpellError(word)) {
            if (errorWords.containsKey(pageIndex)) {
              errorWords[pageIndex]!.add(textWord);
            } else {
              errorWords[pageIndex] = <TextWord>[textWord];
            }
          }
        }
      }
    }

    /// Get the total count of misspelled words
    int count = 0;
    for (final MapEntry<int, List<TextWord>> entry in errorWords.entries) {
      count += entry.value.length;
    }

    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog.adaptive(
            title: const Text('Spell Check Completed'),
            content: errorWords.isEmpty
                ? const Text('No spell errors found.')
                : Text('$count spelling errors found.'),
            actions: [
              TextButton(
                onPressed: () {
                  for (final MapEntry<int, List<TextWord>> entry
                      in errorWords.entries) {
                    for (final TextWord textWord in entry.value) {
                      _markSpellError(entry.key, textWord);
                    }
                  }

                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          );
        });
  }

  void _markSpellError(int pageIndex, TextWord textWord) {
    // Create a squiggly annotation for the misspelled word
    final SquigglyAnnotation squigglyAnnotation = SquigglyAnnotation(
      textBoundsCollection: <PdfTextLine>[
        PdfTextLine(
          Rect.fromLTWH(
            textWord.bounds.left,
            textWord.bounds.top,
            textWord.bounds.width,
            textWord.bounds.height,
          ),
          textWord.text,
          pageIndex + 1, // Page index starts from 0
        ),
      ],
    );

    // Add the squiggly annotation to the PDF viewer
    _pdfViewerController.addAnnotation(squigglyAnnotation);
  }

  bool _checkSpellError(String word) {
    bool hasError = false;
    if (word.isEmpty ||
        word.length == 1 ||
        _containsOnlyNumbers(word) ||
        _containsOnlySymbols(word) ||
        _containsWebsite(word)) {
      return hasError;
    }
    final query = word
        // Remove all non-alphanumeric characters
        .replaceAll(RegExp(r'[^\s\w]'), '')
        .trim()
        .toLowerCase();

    if (!words.contains(query)) {
      hasError = true;
    }
    return hasError;
  }

  bool _containsOnlyNumbers(String input) {
    return onlyNumbersRegex.hasMatch(input);
  }

  bool _containsOnlySymbols(String input) {
    return onlySymbolsRegex.hasMatch(input);
  }

  bool _containsWebsite(String input) {
    return websiteRegex.hasMatch(input);
  }
}
