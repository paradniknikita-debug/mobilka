import 'attachment_reader_stub.dart'
    if (dart.library.io) 'attachment_reader_io.dart' as reader;

Future<List<int>> readAttachmentBytes(String path) =>
    reader.readAttachmentBytes(path);
