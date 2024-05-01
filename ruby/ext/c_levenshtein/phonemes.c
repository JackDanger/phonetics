#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include "./next_phoneme_length.h"

void find_phonemes(int *string, int string_length, int *count, int *lengths) {
  int length;
  int i;

  i = 0;
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

// Collect between 1 and 8 bytes of a phoneme into a single 64-bit word so we can compare two
// phonemes using just one instruction.
// These 64-bit words are how we implement the lookup table in phonetic_cost
void set_phonemes(uint64_t* phonemes, int* string, int count, int* lengths) {
  int idx = 0;
  int i, j;
  for (i = 0; i < count; i++) {
    phonemes[i] = 0;
    for (j = 0; j < lengths[i]; j++) {
      phonemes[i] = (uint64_t) ( phonemes[i] << 8 | string[idx] );
      idx++;
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
