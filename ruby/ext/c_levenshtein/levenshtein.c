#include <stdbool.h>
#include <stdint.h>
#include "ruby.h"
#include "ruby/encoding.h"
#include "ruby/re.h"
#include "./phonemes.h"
#include "./next_phoneme_length.h"
#include "./phonetic_cost.h"

// #define DEBUG

#ifdef DEBUG
#define debug(M, ...) if (verbose) printf(M, ##__VA_ARGS__)
#else
#define debug(M, ...)
#endif

// Standard weighted-Levenshtein constants. INDEL_COST is fixed at 1.0 so
// inserting or deleting a single phoneme always costs one indel regardless
// of the neighbours that happen to surround it. TRANSPOSE_COST < 2 * INDEL
// makes adjacent transposition (Damerau) cheaper than two separate edits.
#define INDEL_COST     1.0f
#define TRANSPOSE_COST 0.8f

VALUE Binding = Qnil;

/* Function declarations */

void Init_c_levenshtein();

void set_initial(float *d, int string1_phoneme_count, int string2_phoneme_count, bool verbose);
void print_matrix(float *d, int *string1, int string1_phoneme_count, int *string1_phoneme_sizes, int *string2, int string2_phoneme_count, int *string2_phoneme_sizes, bool verbose);
VALUE method_internal_phonetic_distance(VALUE self, VALUE _string1, VALUE _string2, VALUE _verbose);

/* Forward declaration: the confusion module lives in confusion.c but is
 * compiled into the same shared object as this file so a single bundle
 * load registers both binding modules. */
void Init_c_confusion(void);

/* Function implemitations */

void Init_c_levenshtein() {
	Binding = rb_define_module("PhoneticsLevenshteinCBinding");
	rb_define_method(Binding, "internal_phonetic_distance", method_internal_phonetic_distance, 3);
	Init_c_confusion();
}

VALUE method_internal_phonetic_distance(VALUE self, VALUE _string1, VALUE _string2, VALUE _verbose){
  bool verbose = _verbose;

  // Type-check first so we never call RSTRING_LEN on a non-string.
  if (!RB_TYPE_P(_string1, T_STRING)) {
    rb_raise(rb_eArgError, "must pass string as first argument");
  }
  if (!RB_TYPE_P(_string2, T_STRING)) {
    rb_raise(rb_eArgError, "must pass string as second argument");
  }

  int string1_length = (int) RSTRING_LEN(_string1);
  int string2_length = (int) RSTRING_LEN(_string2);

  // Stack VLAs were fine in practice but failed for very long inputs (e.g.
  // whole-phrase Mad-Gab comparisons) and on stricter compilers. Move to
  // heap allocations so callers can pass arbitrarily long phrases.
  int string1_phoneme_count = 0;
  int string2_phoneme_count = 0;
  int *string1_phoneme_sizes = calloc(string1_length + 1, sizeof(int));
  int *string2_phoneme_sizes = calloc(string2_length + 1, sizeof(int));
  int *string1 = calloc(string1_length + 1, sizeof(int));
  int *string2 = calloc(string2_length + 1, sizeof(int));

  float *d = NULL;       // The (flattened) 2-dimensional matrix
  uint64_t *string1_phonemes = NULL;
  uint64_t *string2_phonemes = NULL;

  float distance;        // Return value of this function
  float min, delete,     // Reusable cost calculations
         insert, replace,
         cost;
  int i, j;               // Frequently overwritten loop vars

  for (i = 0; i < string1_length; i++) {
    string1[i] = (RSTRING_PTR(_string1)[i] & 0xff);
  }
  for (i = 0; i < string2_length; i++) {
    string2[i] = RSTRING_PTR(_string2)[i] & 0xff;
  }

  find_phonemes(string1, string1_length, &string1_phoneme_count, string1_phoneme_sizes);
  string1_phonemes = calloc(string1_phoneme_count + 1, sizeof(uint64_t));
  set_phonemes(string1_phonemes, string1, string1_phoneme_count, string1_phoneme_sizes);

  find_phonemes(string2, string2_length, &string2_phoneme_count, string2_phoneme_sizes);
  string2_phonemes = calloc(string2_phoneme_count + 1, sizeof(uint64_t));
  set_phonemes(string2_phonemes, string2, string2_phoneme_count, string2_phoneme_sizes);

  // Guard clauses for empty inputs. We've allocated above, so jump to a
  // single cleanup path to free everything.
  if (string1_phoneme_count == 0 && string2_phoneme_count == 0) {
    distance = 0.0f;
    goto cleanup;
  }

  debug("\n");

  // one-dimensional representation of 2 dimensional array
  d = calloc((string1_phoneme_count+1) * (string2_phoneme_count+1), sizeof(float));

  // Seed the top row and left column with cumulative indel costs (j or i
  // copies of INDEL_COST), matching the standard weighted-Levenshtein form.
  set_initial(d, string1_phoneme_count, string2_phoneme_count, verbose);

  print_matrix(d, string1, string1_phoneme_count, string1_phoneme_sizes, string2, string2_phoneme_count, string2_phoneme_sizes, verbose);

  // Fill the matrix using the recurrence
  //
  //   d[i][j] = min(
  //     d[i-1][j]   + INDEL_COST,                              (delete)
  //     d[i][j-1]   + INDEL_COST,                              (insert)
  //     d[i-1][j-1] + phonetic_cost(s1[j-1], s2[i-1]),         (substitute)
  //     d[i-2][j-2] + TRANSPOSE_COST     when adjacent swap    (Damerau)
  //   )
  //
  // Indel cost is the FIXED INDEL_COST — not the phonetic_cost between
  // strings — which is what the original implementation accidentally added.
  for (j = 1; j <= string2_phoneme_count; j++){
    for (i = 1; i <= string1_phoneme_count; i++){

      debug("------- %d/%d (%d) \n", i, j, j*(string1_phoneme_count+1) + i);

      cost = phonetic_cost(string1_phonemes[i-1], string2_phonemes[j-1]);

      insert = d[j*(string1_phoneme_count+1) + i-1] + INDEL_COST;
      delete = d[(j-1)*(string1_phoneme_count+1) + i] + INDEL_COST;
      replace = d[(j-1)*(string1_phoneme_count+1) + i-1] + cost;

      min = insert;
      if (delete < min) min = delete;
      if (replace < min) min = replace;

      // Damerau adjacent-transposition: only valid when we have at least
      // two prior phonemes on both sides and the adjacent pair is swapped.
      if (i > 1 && j > 1
          && string1_phonemes[i-1] == string2_phonemes[j-2]
          && string1_phonemes[i-2] == string2_phonemes[j-1]) {
        float transpose = d[(j-2)*(string1_phoneme_count+1) + i-2] + TRANSPOSE_COST;
        if (transpose < min) min = transpose;
      }

      d[(j * (string1_phoneme_count+1)) + i] = min;
      debug("\n");
      if (verbose) {
        print_matrix(d, string1, string1_phoneme_count, string1_phoneme_sizes, string2, string2_phoneme_count, string2_phoneme_sizes, verbose);
      }

    }
  }

  // The final element in the `d` array is the value of the shortest path from
  // the top-left to the bottom-right of the matrix.
  distance = d[(string1_phoneme_count + 1) * (string2_phoneme_count + 1) - 1];

cleanup:
  debug("distance: %f\n", distance);
  free(d);
  free(string1);
  free(string2);
  free(string1_phoneme_sizes);
  free(string2_phoneme_sizes);
  free(string1_phonemes);
  free(string2_phonemes);

  return DBL2NUM(distance);
}

// Seed the top row and left column of the matrix with cumulative indel
// costs: matching the empty string against a prefix of length k of the
// other string costs k * INDEL_COST.
//
// The old implementation seeded with cumulative *phonetic* distances
// between consecutive phonemes inside the same string, which made
// "abcabcabcabcabc" cheap to insert and "aeiou" expensive — neither of
// which corresponds to the standard weighted-Levenshtein interpretation.
void set_initial(float *d, int string1_phoneme_count, int string2_phoneme_count, bool verbose) {
  int i, j;
  (void) verbose;

  d[0] = (float) 0.0;

  for (i = 1; i <= string1_phoneme_count; i++) {
    d[i] = i * INDEL_COST;
  }

  for (j = 1; j <= string2_phoneme_count; j++) {
    d[j * (string1_phoneme_count + 1)] = j * INDEL_COST;
  }
}

// A handy visualization for developers
void print_matrix(float *d, int *string1, int string1_phoneme_count, int *string1_phoneme_sizes, int *string2, int string2_phoneme_count, int *string2_phoneme_sizes, bool verbose) {

  int i, j;
  int string1_offset = 0;
  int string2_offset = 0;

  if (!verbose)
    return;

  printf("           ");
  for (i=0; i < string1_phoneme_count; i++) {
    print_phoneme(string1, string1_offset, string1_phoneme_sizes[i], 9);
    string1_offset += string1_phoneme_sizes[i];
  }
  printf("\n");
  for (j=0; j <= string2_phoneme_count; j++) {
    if (j==0) {
      printf("  ");
    } else {
      print_phoneme(string2, string2_offset, string2_phoneme_sizes[j-1], 2);
      string2_offset += string2_phoneme_sizes[j-1];
    } 
    for (i=0; i <= string1_phoneme_count; i++) {
      printf("%f ", d[j * (string1_phoneme_count+1) + i]) ;
    }
    printf("\n");
  }
}
