#include <stdio.h>
#include "./next_phoneme_length.h"
void find_phonemes(int *string, int string_length, int *count, int *lengths) {
  int i = 0;
  int length;
  while (i < string_length) {
    length = next_phoneme_length(string, i, string_length);
    if (length) {
      lengths[(*count)++] = length;
      i += length;
    } else {
      i++;
    }
  }
}

void print_phoneme(int *string, int offset, int length, int padding) {
  int p;
  int max = padding;
  if (length > max) {
    max = length;
  }

  for (p = 0; p < length; p++) {
    putchar(string[offset + p]);
  }
  // The printable characters take up to four bytes. If a phoneme takes 1-4 we
  // assume the padding is the same. If it takes 5-8 we subtract one from the
  // padding because it'll have printed another character.
  for (p = (length / 4)+1; p < max; p++) {
    printf(" ");
  }
}
