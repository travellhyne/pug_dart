extension Substr on String {
  String substr(int startIndex, [int len]) {
    startIndex ??= 0;

    int start;

    if (startIndex < 0) {
      start = length + startIndex;
    } else {
      start = startIndex;
    }

    if (len == null) {
      return start < length ? substring(start) : '';
    } else {
      var end = (start + len) > length ? length : start + len;
      return start < length ? substring(start, end) : '';
    }
  }
}
