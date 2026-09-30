import 'dart:io';

/// Deletes a file the fit loop no longer needs. Safe to call on a path that is gone.
void deleteFileQuietly(String path) {
  try {
    File(path).deleteSync();
  } on FileSystemException {
    // A leftover in the cache directory is harmless; the plugin's clearCache sweeps it.
  }
}
