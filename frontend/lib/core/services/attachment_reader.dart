import 'attachment_reader_stub.dart'
    if (dart.library.io) 'attachment_reader_io.dart'
    if (dart.library.html) 'attachment_reader_web.dart' as reader;

Future<List<int>> readAttachmentBytes(String path) =>
    reader.readAttachmentBytes(path);
