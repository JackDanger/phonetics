/*
 * Phonetics::Confusion — listener-perception distance, C implementation.
 *
 * Gotoh (1982) three-matrix affine-gap dynamic programming over IPA phoneme
 * streams, with per-phoneme cost taken from the (codegen-generated)
 * confusion_sub_cost() lookup. The Ruby reference implementation lives in
 * lib/phonetics/confusion.rb and this file mirrors it constant-for-constant.
 *
 * Three matrices:
 *
 *   M[i][j]  — best score ending in a substitution/match at (i, j)
 *   X[i][j]  — best score ending in an a-consuming gap
 *   Y[i][j]  — best score ending in a b-consuming gap
 *
 * Indexing convention here: M[i * (n+1) + j], where i indexes string1
 * (rows) and j indexes string2 (columns).
 */
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "ruby.h"
#include "ruby/encoding.h"
#include "./phonemes.h"
#include "./next_phoneme_length.h"
#include "./confusion_cost.h"

/* Affine-gap tuning, mirroring lib/phonetics/confusion.rb. Change one and
 * change the other. */
#define GAP_OPEN              0.60f
#define GAP_EXTEND            0.25f
#define WEAK_INDEL_COST       0.15f
#define BOUNDARY_INDEL_COST   0.02f

/* ASCII '#' as the boundary token, single-byte uint64_t. */
#define BOUNDARY_PACKED       0x23ULL

/* UTF-8 byte sequences for the weak phonemes, packed big-endian into a
 * uint64_t to match set_phonemes(). Kept here as a static table rather
 * than codegen because the set is small and stable; if it ever grows
 * past a handful of entries we should generate it.
 *
 *   'h'  = 0x68            (1 byte)
 *   'ə'  = 0xC9 0x99       (2 bytes)
 *   'ʔ'  = 0xCA 0x94       (2 bytes)
 *   'ɦ'  = 0xC9 0xA6       (2 bytes)
 */
static inline bool is_weak_strict(uint64_t p) {
  return p == 0x68ULL ||
         p == 0xC999ULL ||
         p == 0xCA94ULL ||
         p == 0xC9A6ULL;
}

static inline bool is_boundary(uint64_t p) {
  return p == BOUNDARY_PACKED;
}

/* Returns the indel cost for `p` if it qualifies for the discounted tier,
 * or a negative sentinel if it should fall through to the affine
 * GAP_OPEN/GAP_EXTEND machinery. */
static inline float weak_indel_cost(uint64_t p) {
  if (is_boundary(p))    return BOUNDARY_INDEL_COST;
  if (is_weak_strict(p)) return WEAK_INDEL_COST;
  return -1.0f;
}

static inline float fminf3(float a, float b, float c) {
  float m = a < b ? a : b;
  return m < c ? m : c;
}

/* Tokenise a Ruby string into a uint64_t phoneme stream. Whitespace and a
 * couple of explicit boundary characters are remapped to the ASCII '#'
 * byte before the trie-driven tokenizer runs, so the boundary token
 * ends up in the output stream as a single-byte phoneme. */
static void tokenize_with_boundaries(VALUE input, uint64_t **out_phonemes, int *out_count) {
  long raw_len = RSTRING_LEN(input);
  const char *raw = RSTRING_PTR(input);

  int *bytes = calloc(raw_len + 1, sizeof(int));
  int *sizes = calloc(raw_len + 1, sizeof(int));

  for (long i = 0; i < raw_len; i++) {
    unsigned char c = (unsigned char) raw[i];
    if (c == ' ' || c == '\t' || c == '_' || c == '|') {
      bytes[i] = 0x23; /* '#' */
    } else {
      bytes[i] = c;
    }
  }

  int count = 0;
  find_phonemes(bytes, (int) raw_len, &count, sizes);

  uint64_t *phonemes = calloc(count + 1, sizeof(uint64_t));
  set_phonemes(phonemes, bytes, count, sizes);

  free(bytes);
  free(sizes);

  *out_phonemes = phonemes;
  *out_count = count;
}

VALUE method_internal_confusion_distance(VALUE self, VALUE _string1, VALUE _string2, VALUE _verbose) {
  (void) self;
  (void) _verbose;

  if (!RB_TYPE_P(_string1, T_STRING)) {
    rb_raise(rb_eArgError, "must pass string as first argument");
  }
  if (!RB_TYPE_P(_string2, T_STRING)) {
    rb_raise(rb_eArgError, "must pass string as second argument");
  }

  uint64_t *p1 = NULL, *p2 = NULL;
  int m = 0, n = 0;
  tokenize_with_boundaries(_string1, &p1, &m);
  tokenize_with_boundaries(_string2, &p2, &n);

  float distance = 0.0f;
  float *M = NULL, *X = NULL, *Y = NULL;

  if (m == 0 && n == 0) goto cleanup;

  size_t cells = (size_t)(m + 1) * (size_t)(n + 1);
  size_t W = (size_t)(n + 1);
  M = malloc(cells * sizeof(float));
  X = malloc(cells * sizeof(float));
  Y = malloc(cells * sizeof(float));
  if (!M || !X || !Y) {
    rb_raise(rb_eNoMemError, "confusion DP allocation");
  }

  /* Initialise to +inf using a large finite value so adding GAP_EXTEND
   * doesn't overflow into nan. */
  const float BIG = 1e18f;
  for (size_t k = 0; k < cells; k++) {
    M[k] = X[k] = Y[k] = BIG;
  }
  M[0] = 0.0f;

  /* Seed the gap-only edges. */
  for (int i = 1; i <= m; i++) {
    uint64_t ph = p1[i - 1];
    float w = weak_indel_cost(ph);
    float step = (w >= 0.0f) ? w : ((i == 1) ? GAP_OPEN : GAP_EXTEND);
    float prev = (i == 1) ? 0.0f : X[(size_t)(i - 1) * W + 0];
    X[(size_t) i * W + 0] = prev + step;
  }
  for (int j = 1; j <= n; j++) {
    uint64_t ph = p2[j - 1];
    float w = weak_indel_cost(ph);
    float step = (w >= 0.0f) ? w : ((j == 1) ? GAP_OPEN : GAP_EXTEND);
    float prev = (j == 1) ? 0.0f : Y[(size_t) 0 * W + (j - 1)];
    Y[(size_t) 0 * W + j] = prev + step;
  }

  for (int i = 1; i <= m; i++) {
    uint64_t ai = p1[i - 1];
    float a_weak = weak_indel_cost(ai);

    for (int j = 1; j <= n; j++) {
      uint64_t bj = p2[j - 1];
      float b_weak = weak_indel_cost(bj);

      size_t here     = (size_t) i       * W + (size_t) j;
      size_t up       = (size_t)(i - 1)  * W + (size_t) j;
      size_t left     = (size_t) i       * W + (size_t)(j - 1);
      size_t diagonal = (size_t)(i - 1)  * W + (size_t)(j - 1);

      /* M: any state, then match/mismatch a[i-1] with b[j-1]. */
      float sub = confusion_sub_cost((int64_t) ai, (int64_t) bj);
      M[here] = fminf3(M[diagonal], X[diagonal], Y[diagonal]) + sub;

      /* X: end in an a-consuming gap. */
      if (a_weak >= 0.0f) {
        X[here] = fminf3(M[up], X[up], Y[up]) + a_weak;
      } else {
        float best = M[up] + GAP_OPEN;
        float ext  = X[up] + GAP_EXTEND;
        float swap = Y[up] + GAP_OPEN;
        if (ext  < best) best = ext;
        if (swap < best) best = swap;
        X[here] = best;
      }

      /* Y: end in a b-consuming gap. */
      if (b_weak >= 0.0f) {
        Y[here] = fminf3(M[left], X[left], Y[left]) + b_weak;
      } else {
        float best = M[left] + GAP_OPEN;
        float ext  = Y[left] + GAP_EXTEND;
        float swap = X[left] + GAP_OPEN;
        if (ext  < best) best = ext;
        if (swap < best) best = swap;
        Y[here] = best;
      }
    }
  }

  size_t last = (size_t) m * W + (size_t) n;
  distance = fminf3(M[last], X[last], Y[last]);

cleanup:
  free(p1);
  free(p2);
  free(M);
  free(X);
  free(Y);
  return DBL2NUM((double) distance);
}

VALUE ConfusionBinding = Qnil;

void Init_c_confusion(void) {
  ConfusionBinding = rb_define_module("PhoneticsConfusionCBinding");
  rb_define_method(ConfusionBinding, "internal_confusion_distance",
                   method_internal_confusion_distance, 3);
}
