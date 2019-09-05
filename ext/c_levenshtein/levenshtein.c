#include <stdbool.h>
#include "ruby.h"
#include "ruby/encoding.h"
#include "ruby/re.h"
#include "./phonemes.h"
#include "./next_phoneme_length.h"
#include "./phonetic_cost.h"

#define debug(M, ...) if (verbose) printf(M, ##__VA_ARGS__)

VALUE Binding = Qnil;

/* Function declarations */

void Init_c_levenshtein();

void set_initial(double *d, int *string1, int string1_phoneme_count, int *string1_phoneme_sizes, int *string2, int string2_phoneme_count, int *string2_phoneme_sizes, bool verbose);
void print_matrix(double *d, int *string1, int string1_phoneme_count, int *string1_phoneme_sizes, int *string2, int string2_phoneme_count, int *string2_phoneme_sizes, bool verbose);
VALUE method_internal_phonetic_distance(VALUE self, VALUE _string1, VALUE _string2, VALUE _verbose);

/* Function implemitations */

void Init_c_levenshtein() {
	Binding = rb_define_module("PhoneticsLevenshteinCBinding");
	rb_define_method(Binding, "internal_phonetic_distance", method_internal_phonetic_distance, 3);
}

VALUE method_internal_phonetic_distance(VALUE self, VALUE _string1, VALUE _string2, VALUE _verbose){
  if (!RB_TYPE_P(_string1, T_STRING)) {
    rb_raise(rb_eArgError, "must pass string as first argument");
  }
  if (!RB_TYPE_P(_string2, T_STRING)) {
    rb_raise(rb_eArgError, "must pass string as second argument");
  }

  bool verbose = _verbose;
  int string1_length = (int) RSTRING_LEN(_string1);
  int string2_length = (int) RSTRING_LEN(_string2);

  // Given the input strings, we count the phonemes in each and store both the
  // total and, in a phoneme_sizes array, the length of each.
  int string1_phoneme_count = 0;
  int string2_phoneme_count = 0;
  int string1_phoneme_sizes[string1_length + 1];
  int string2_phoneme_sizes[string2_length + 1];
  int string1[string1_length + 1];
  int string2[string2_length + 1];

  double *d;              // The (flattened) 2-dimensional matrix
                          // underlying this algorithm

  double distance;        // Return value of this function
  double min, delete,     // Reusable cost calculations
         insert, replace,
         cost;
  int i, j;               // Frequently overwritten loop vars
  int string1_offset = 0;
  int string2_offset = 0;

  for (i = 0; i < string1_length; i++) {
    string1[i] = (RSTRING_PTR(_string1)[i] & 0xff);
  }
  for (i = 0; i < string2_length; i++) {
    string2[i] = RSTRING_PTR(_string2)[i] & 0xff;
  }

  find_phonemes(string1, string1_length, &string1_phoneme_count, string1_phoneme_sizes);
  find_phonemes(string2, string2_length, &string2_phoneme_count, string2_phoneme_sizes);

  // Guard clauses for empty strings
  if (string1_phoneme_count == 0 && string2_phoneme_count == 0)
    return DBL2NUM(0.0);
  
  // one-dimensional representation of 2 dimensional array
  d = malloc((sizeof(double)) * (string1_phoneme_count+1) * (string2_phoneme_count+1));

  // First, set the top row and left column of the matrix using the sequential
  // phonetic edit distance of string1 and string2, respectively
  set_initial(d, string1, string1_phoneme_count, string1_phoneme_sizes, string2, string2_phoneme_count, string2_phoneme_sizes, verbose);

  print_matrix(d, string1, string1_phoneme_count, string1_phoneme_sizes, string2, string2_phoneme_count, string2_phoneme_sizes, verbose);

  // Then Fill in the (flattened) matrix using the Levenshtein algorithm so we can
  // pluck the lowest-cost edit distance (stored in the lower-right corner, in
  // this case the last spot in the array).
  // We'll use phonetic distance instead of '1' as the edit cost.
  //
  // (Skipping i=0 and j=0 because set_initial filled in all cells where i
  // or j are zero-valued)
  for (j = 1; j <= string2_phoneme_count; j++){

    for (i = 1; i <= string1_phoneme_count; i++){

      // The cost of deletion or addition is the Levenshtein distance
      // calculation (the value in the cell to the left, upper-left, or above)
      // plus the phonetic distance between the sound we're moving from to the
      // new one.

      debug("------- %d/%d (%d) \n", i, j, j*(string1_phoneme_count+1) + i);

      // TODO: increment i and j by the phoneme lengths
      cost = phonetic_cost(string1, string1_offset, string1_phoneme_sizes[i-1], string2, string2_offset, string2_phoneme_sizes[j-1]);

      insert = d[j*(string1_phoneme_count+1) + i-1];
      debug("insert proposes cell %d,%d - %f\n", i-1, j, insert);
      min = insert;
      debug("min (insert): %f\n", min);

      delete = d[(j-1)*(string1_phoneme_count+1) + i];
      debug("delete proposes cell %d,%d - %f\n", i, j-1, delete);
      if (delete < min) {
        debug("delete is %f, better than %f for %d/%d\n", delete, min, i, j);
        min = delete;
      }

      replace = d[(j-1)*(string1_phoneme_count+1) + i-1];
      debug("replace proposes cell %d,%d - %f\n", i-1, j-1, replace);
      if (replace < min) {
        debug("replace is %f, better than %f for %d/%d\n", replace, min, i, j);
        min = replace;
      }

      d[(j * (string1_phoneme_count+1)) + i] = min + cost;
      debug("\n");
      print_matrix(d, string1, string1_phoneme_count, string1_phoneme_sizes, string2, string2_phoneme_count, string2_phoneme_sizes, verbose);

      string1_offset += string1_phoneme_sizes[i-1];
    }
    string1_offset = 0;
    string2_offset += string2_phoneme_sizes[j-1];
  }

  // The final element in the `d` array is the value of the shortest path from
  // the top-left to the bottom-right of the matrix.
  distance = d[(string1_phoneme_count + 1) * (string2_phoneme_count + 1) - 1];

  free(d);
  debug("distance: %f\n", distance);

  return DBL2NUM(distance);
}

// Set the minimum scores equal to the distance between each phoneme,
// sequentially.
//
// The first value is always zero.
// The second value is always the phonetic distance between the first
// phonemes of each string.
// Subsequent values are the cumulative phonetic distance between each
// phoneme within the same string.
// "aek" -> [0.0, 1.0, 1.61, 2.61]
void set_initial(double *d, int *string1, int string1_phoneme_count, int *string1_phoneme_sizes, int *string2, int string2_phoneme_count, int *string2_phoneme_sizes, bool verbose) {

  double initial_distance;
  int string1_offset = 0;
  int string2_offset = 0;
  int i, j;

  if (string1_phoneme_count == 0 || string2_phoneme_count == 0) {
    initial_distance = 0.0;
  } else {
    initial_distance = 1.0;
  }

  // The top-left is 0, the cell to the right and down are each 1 to start
  d[0] = (double) 0.0;
  if (string1_phoneme_count > 0) {
    d[1] = initial_distance;
  }
  if (string2_phoneme_count > 0) {
    d[string1_phoneme_count+1] = initial_distance;
  }

  debug("string1 phoneme count: %d\n", string1_phoneme_count);

  for (i=2; i <= string1_phoneme_count; i++) {
    // The cost of adding the next phoneme is the cost so far plus the phonetic
    // distance between the previous one and the current one.
    d[i] = d[i-1] +
      phonetic_cost(string1, string1_offset, string1_phoneme_sizes[i-2], string1, string1_offset + string1_phoneme_sizes[i-2], string1_phoneme_sizes[i-1]);
    string1_offset += string1_phoneme_sizes[i-2];
  }

  debug("string2 phoneme count: %d\n", string2_phoneme_count);

  for (j=2; j <= string2_phoneme_count; j++) {
    // The same exact pattern down the left side of the matrix
    d[j * (string1_phoneme_count+1)] = d[(j - 1) * (string1_phoneme_count+1)] +
      phonetic_cost(string2, string2_offset, string2_phoneme_sizes[j-2], string2, string2_offset + string2_phoneme_sizes[j-2], string2_phoneme_sizes[j-1]);
    string2_offset += string2_phoneme_sizes[j-1];
  }

  // And zero out the rest. If you're reading this please show me a way to do
  // this faster.
  for (j=1; j <= string2_phoneme_count; j++) {
    for (i=1; i <= string1_phoneme_count; i++) {
      d[j * (string1_phoneme_count+1) + i] = (double) 0.0;
    }
  }
}

// A handy visualization for developers
void print_matrix(double *d, int *string1, int string1_phoneme_count, int *string1_phoneme_sizes, int *string2, int string2_phoneme_count, int *string2_phoneme_sizes, bool verbose) {

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
