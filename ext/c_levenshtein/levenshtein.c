#include "ruby.h"
#include <stdbool.h>
#include "./phonetic_cost.h"

#define debug(M, ...) if (verbose) printf(M, ##__VA_ARGS__)

VALUE Binding = Qnil;

/* Function declarations */

void Init_c_levenshtein();

void set_initial(double *d, int *string1, int string1_length, int *string2, int string2_length, bool verbose);
void print_matrix(double *d, int *string1, int string1_length, int *string2, int string2_length, bool verbose);
VALUE method_internal_phonetic_distance(VALUE self, VALUE _string1, VALUE _string2, VALUE _verbose);

/* Function implemitations */

void Init_c_levenshtein() {
	Binding = rb_define_module("PhoneticsLevenshteinCBinding");
	rb_define_method(Binding, "internal_phonetic_distance", method_internal_phonetic_distance, 3);
}

VALUE method_internal_phonetic_distance(VALUE self, VALUE _string1, VALUE _string2, VALUE _verbose){

  VALUE *string1_ruby = RARRAY_PTR(_string1);
  VALUE *string2_ruby = RARRAY_PTR(_string2);
  bool verbose = _verbose;
  int string1_length = (int) RARRAY_LEN(_string1);
  int string2_length = (int) RARRAY_LEN(_string2);
  // We name them as 'strings' but in C-land we're representing our strings as
  // arrays of `int`s, where each int represents a consistent (if unusual)
  // encoding of a grapheme cluster (a symbol for a phoneme).
  int string1[string1_length + 1];
  int string2[string2_length + 1];

  double *d;              // The (flattened) 2-dimensional matrix
                          // underlying this algorithm

  double distance;        // Return value of this function
  double min, delete,     // Reusable cost calculations
         insert, replace,
         cost;
  int i, j;               // Frequently overwritten loop vars

  // Guard clause for two empty strings
  if (string1_length == 0 && string2_length == 0)
    return DBL2NUM(0.0);

  //
  // Intial data setup
  //

  for (i = 0; i < string1_length; i++) {
    string1[i] = NUM2INT(string1_ruby[i]);
    debug("string1[%d] = %d\n", i, string1[i]);
  }
  for (j = 0; j < string2_length; j++) {
    string2[j] = NUM2INT(string2_ruby[j]);
    debug("string2[%d] = %d\n", i, string2[j]);
  }

  // one-dimensional representation of 2 dimentional array len(string1)+1 *
  // len(string2)+1
  d = malloc((sizeof(double)) * (string1_length+1) * (string2_length+1));

  //
  // Fill in the (flattened) matrix using the Levenshtein algorithm so we can
  // pluck the lowest-cost edit distance (stored in the lower-right corner, in
  // this case the last spot in the array)
  //
  
  // First, set the top row and left column of the matrix using the sequential
  // phonetic edit distance of string1 and string2, respectively
  set_initial(d, string1, string1_length, string2, string2_length, verbose);

  debug("before:\n");
  print_matrix(d, string1, string1_length, string2, string2_length, verbose);

  // Then walk through the matrix and fill in each cell with the lowest-cost
  // phonetic edit distance for that matrix cell.
  // (Skipping i=0 and j=0 because set_initial filled in all cells where i
  // or j are zero-valued)
  for (j = 1; j <= string2_length; j++){
    for (i = 1; i <= string1_length; i++){

      // The cost of deletion or addition is the Levenshtein distance
      // calculation (the value in the cell to the left, upper-left, or above)
      // plus the phonetic distance between the sound we're moving from to the
      // new one.

      debug("------- %d/%d (%d) \n", i, j, j*(string1_length+1) + i);

      cost = phonetic_cost(string1, i-1, string1_length, string2, j-1, string2_length);
      debug("phonetic cost of %d to %d is %f\n", string1[i-1], string2[j-1], cost);

      insert = d[j*(string1_length+1) + i-1];
      debug("insert proposes cell %d,%d - %f\n", i-1, j, insert);
      min = insert;
      debug("min (insert): %f\n", min);

      delete = d[(j-1)*(string1_length+1) + i];
      debug("delete proposes cell %d,%d - %f\n", i, j-1, delete);
      if (delete < min) {
        debug("delete is %f, better than %f for %d/%d\n", delete, min, i, j);
        min = delete;
      }

      replace = d[(j-1)*(string1_length+1) + i-1];
      debug("replace proposes cell %d,%d - %f\n", i-1, j-1, replace);
      if (replace < min) {
        debug("replace is %f, better than %f for %d/%d\n", replace, min, i, j);
        min = replace;
      }

      d[(j * (string1_length+1)) + i] = min + cost;
      debug("\n");
      print_matrix(d, string1, string1_length, string2, string2_length, verbose);
    }
  }

  // The final element in the `d` array is the value of the shortest path from
  // the top-left to the bottom-right of the matrix.
  distance = d[(string1_length + 1) * (string2_length + 1) - 1];

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
void set_initial(double *d, int *string1, int string1_length, int *string2, int string2_length, bool verbose) {

  double initial_distance;
  int i, j;

  if (string1_length == 0 || string2_length == 0) {
    initial_distance = 0.0;
  } else {
    initial_distance = 1.0;
  }

  // The top-left is 0, the cell to the right and down are each 1 to start
  d[0] = (double) 0.0;
  if (string1_length > 0) {
    d[1] = initial_distance;
  }
  if (string2_length > 0) {
    d[string1_length+1] = initial_distance;
  }

  debug("string1 length: %d\n", string1_length);
  for (i=2; i <= string1_length; i++) {
    // The cost of adding the next phoneme is the cost so far plus the phonetic
    // distance between the previous one and the current one.
    d[i] = d[i-1] + phonetic_cost(string1, i-2, string1_length, string1, i-1, string1_length);
  }
  debug("string2 length: %d\n", string2_length);
  for (j=2; j <= string2_length; j++) {
    // The same exact pattern down the left side of the matrix
    d[j * (string1_length+1)] = d[(j - 1) * (string1_length+1)] + phonetic_cost(string2, j-2, string2_length, string2, j-1, string2_length);
  }

  // And zero out the rest. If you're reading this please edit this to be
  // faster.
  for (j=1; j <= string2_length; j++) {
    for (i=1; i <= string1_length; i++) {
      d[j * (string1_length+1) + i] = (double) 0.0;
    }
  }
}

// A handy visualization for developers
void print_matrix(double *d, int *string1, int string1_length, int *string2, int string2_length, bool verbose) {
  int i, j;
  debug("              ");
  for (i=0; i < string1_length; i++) {
    debug("%8.d ", string1[i]);
  }
  debug("\n");
  for (j=0; j <= string2_length; j++) {
    if (j==0) {
      debug("     ");
    } else {
      debug("%4.d ", string2[j-1]);
    }
    for (i=0; i <= string1_length; i++) {
      debug("%f ", d[j * (string1_length+1) + i]) ;
    }
    debug("\n");
  }
}
