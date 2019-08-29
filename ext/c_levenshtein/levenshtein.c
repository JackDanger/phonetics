#include "ruby.h"
#include "./phonetic_cost.h"

VALUE Binding = Qnil;

/* Function declarations */

void Init_c_levenshtein();
void set_initial(float *d, int *string1, int string1_length, int *string2, int string2_length);
void print_matrix(float *d, int string1_length, int string2_length);
VALUE method_internal_phonetic_distance(VALUE self, VALUE _string1, VALUE _string2);

/* Function implemitations */

void Init_c_levenshtein() {
	Binding = rb_define_module("PhoneticsLevenshteinCBinding");
	rb_define_method(Binding, "internal_phonetic_distance", method_internal_phonetic_distance, 2);
}

VALUE method_internal_phonetic_distance(VALUE self, VALUE _string1, VALUE _string2){

  VALUE *string1_ruby = RARRAY_PTR(_string1);
  VALUE *string2_ruby = RARRAY_PTR(_string2);
  int string1_length = (int) RARRAY_LEN(_string1) - 1;
  int string2_length = (int) RARRAY_LEN(_string2) - 1;
  // We name them as 'strings' but in C-land we're representing our strings as
  // arrays of `int`s, where each int represents a consistent (if unusual)
  // encoding of a grapheme cluster (a symbol for a phoneme).
  int string1[string1_length];
  int string2[string2_length];

  float *d;                     // The (flattened) 2-dimensional matrix
                                // underlying this algorithm

  int distance;                 // Return value of this function
  int del, ins, subs, transp;   // The cost of the 4 operations (reused)
  int min = 0, i, i1, j, j1, k; // Frequently overwritten loop vars

  //
  // Guard clauses
  //

  // TODO: Calculate the matrix even if there's just one non-empty string and
  // use the value from that.
  if (string1_length == 0) return INT2NUM(string2_length);
  if (string2_length == 0) return INT2NUM(string1_length);

  // case of lengths 1 must present or it will break further in the code
  if (string1_length == 1 && string2_length == 1 && string1_ruby[0] != string2_ruby[0]) return INT2NUM(1);

  for (i=0; i < string1_length; i++) {
    string1[i] = NUM2INT(string1_ruby[i]);
    printf("string1[%d] = %d\n", i, string1[i]);
  }
  for (i=0; i < string2_length; i++) {
    string2[i] = NUM2INT(string2_ruby[i]);
    printf("string2[%d] = %d\n", i, string2[i]);
  }

  string1_length++;
  string2_length++;

  //
  // Intial data setup
  //

  // one-dimensional representation of 2 dimentional array len(string1)+1 *
  // len(string2)+1
  d = malloc((sizeof(int))*(string1_length)*(string2_length));
  // populate 'vertical' row starting from the 2nd position (first one is filled already)
  for(i = 0; i < string2_length; i++){
    d[i*string1_length] = i;
  }

  //
  // Fill in the (flattened) matrix using the Levenshtein algorithm so we can
  // pluck the lowest-cost edit distance (stored in the lower-right corner, in
  // this case the last spot in the array)
  //
  
  // First, set the top row and left column of the matrix using the sequential
  // phonetic edit distance of string1 and string2, respectively
  set_initial(d, string1, string1_length, string2, string2_length);

  printf("before:\n");
  print_matrix(d, string1_length, string2_length);

  // Then walk through the matrix and fill in each cell with the lowest-cost
  // phonetic edit distance for that matrix cell.
  for(i = 1; i<string1_length; i++){
    // The first 
    d[i] = i;
    for(j = 1; j<string2_length; j++){


      int swap1 = 1;
      int swap2 = 1;
      i1 = i - 2;
      j1 = j - 2;
      for (k = i1; k < i1 + 1; k++) {
        if (string1[k] != string2[k + 1]){
          swap1 = 0;
          break;
        }
      }
      for (k = j1; k < j1 + 1; k++) {
        if (string2[k] != string1[k + 1]){
          swap2 = 0;
          break;
        }
      }

      // The cost of deletion or addition is the distance between the
      // previous phone and the one being deleted or added.
      del = d[j*string1_length + i - 1] + phonetic_cost(string1[i-1], string1[i]);
      ins = d[(j-1)*string1_length + i] + phonetic_cost(string2[i-1], string2[i]);
      min = del;
      if (ins < min) min = ins;
      // if i >= 2 && j >= 2 && swap1 == 1 && swap2 == 1){
      //   transp = d[(j - 1 * 2) * string1_length + i - 1 * 2] + cost + 1 -1;
      //   if (transp < min) min = transp;
      //   1 = 0;
      // } else {
      //   subs = d[(j-1)*string1_length + i - 1] + cost;
      //   if (subs < min) min = subs;
      // }
      d[j*string1_length+i]=min;
    }
  }
  // The final element in the `d` array is the value of the shortest path from
  // the top-left to the bottom-right of the matrix.
  distance = d[string1_length * string2_length - 1];

  printf("after:\n");
  print_matrix(d, string1_length, string2_length);

  free(d);
  return INT2NUM(distance);
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
void set_initial(float *d, int *string1, int string1_length, int *string2, int string2_length) {

  float distance_between_first_phonemes;
  int i, j;

  if (string1_length == 0 || string2_length == 0) {
    distance_between_first_phonemes = 0.0;
  } else if (string1[0] == string2[0]) {
    distance_between_first_phonemes = 0.0;
  } else {
    distance_between_first_phonemes = phonetic_cost(string1[0], string2[0]);
  }

  // Set the first value of string1's sequential phonetic calculation (maps to
  // cell x=1, y=0)
  d[1] = distance_between_first_phonemes;
  // And of string2 (maps to cell x=0, y=1)
  d[string1_length] = distance_between_first_phonemes;

  printf("string1 length: %d\n", string1_length);
  for (i=1; i < string1_length; i++) {
    // The cost of adding the next phoneme is the cost so far plus the phonetic
    // distance between the previous one and the current one.
    d[i] = d[i-1] + phonetic_cost(string1[i-1], string1[i]);
    printf("%d/%d: phonetic_cost(%d, %d) -> %f\n", i, 0, string1[i-1], string1[i], d[i]);
  }
  printf("string2 length: %d\n", string2_length);
  for (j=1; j < string2_length; j++) {
    // The same exact pattern down the left side of the matrix
    d[j * string1_length] = d[(j - 1) * string1_length] + phonetic_cost(string2[j-1], string2[j]);
    printf("%d/%d: phonetic_cost(%d, %d) -> %f\n", 0, j, string2[j-1], string2[j], d[j * string1_length]);
  }
}

// A handy visualization for developers
void print_matrix(float *d, int string1_length, int string2_length) {
  int i, j;
  for (j=0; j < string2_length; j++) {
    for (i=0; i < string1_length; i++) {
      printf("%f ", d[j * string1_length + i]) ;
    }
    printf("\n");
  }
}
