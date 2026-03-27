class ScannedPage {
  const ScannedPage({
    required this.path,
    required this.pageNumber,
  });

  final String path;
  final int pageNumber;

  factory ScannedPage.fromPath(String path, int pageNumber) {
    return ScannedPage(path: path, pageNumber: pageNumber);
  }
}
