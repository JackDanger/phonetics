"""Public API tests for the phonetics Python package.

Mirrors ruby/spec/phonetics/public_api_spec.rb so that the same
contract is asserted in both ecosystems. The Rust core has its own
unit tests pinned to f64 reference values; here we only verify that
the Python facade exposes the same observable behaviour.
"""

import math

import phonetics


# ---------------------------------------------------------------------
# distance — per-phoneme acoustic
# ---------------------------------------------------------------------

def test_distance_zero_for_identity():
    for p in ["p", "b", "t", "i", "ɑ", "æ", "tʃ", "aɪ", "ɝ"]:
        assert phonetics.distance(p, p) == 0


def test_distance_p_b_is_voicing_penalty():
    assert math.isclose(phonetics.distance("p", "b"), 0.15, abs_tol=1e-9)


def test_distance_l_and_r_are_not_tied_at_zero():
    # The lateral feature was added precisely so /l/-/ɹ/ doesn't come
    # out as 0.0; without it both were ranked as alveolar approximants
    # with manner score 1.0.
    assert phonetics.distance("l", "ɹ") > 0


def test_distance_schwa_and_rhotic_schwa_differ():
    assert phonetics.distance("ə", "ɝ") > 0


def test_distance_approximants_bridge_to_vowels():
    assert phonetics.distance("j", "i") < phonetics.distance("t", "i")
    assert phonetics.distance("w", "u") < phonetics.distance("t", "u")
    assert phonetics.distance("ɹ", "ɝ") < phonetics.distance("t", "ɝ")


def test_distance_stays_acoustic_on_cot_caught():
    # Strict acoustic distance: /ɑ/ vs /ɔ/ have meaningful formant
    # separation. The perceptual overlay merges them; this metric
    # doesn't.
    assert phonetics.distance("ɑ", "ɔ") > 0.15


# ---------------------------------------------------------------------
# levenshtein — strict edit distance
# ---------------------------------------------------------------------

def test_levenshtein_zero_for_identity():
    assert phonetics.levenshtein("kæt", "kæt") == 0


def test_levenshtein_single_head_deletion_is_one_indel():
    assert math.isclose(phonetics.levenshtein("dɪsug", "ɪsug"), 1.0, abs_tol=0.05)


def test_levenshtein_symmetric():
    for a, b in [("kæt", "kʌt"), ("stupɪd", "dupɪd"), ("hɪt", "ɪt")]:
        assert math.isclose(
            phonetics.levenshtein(a, b),
            phonetics.levenshtein(b, a),
            abs_tol=1e-9,
        )


# ---------------------------------------------------------------------
# confusion — listener perception
# ---------------------------------------------------------------------

TARGET = "ɪtsdʒʌstəstupɪdgeɪm"
CLUE   = "hɪtsdʒʌstɪsduphɪdkeɪm"
DECOY  = "jɔrmʌðɝwɛrzsneɪkɝz"


def test_confusion_zero_for_identity():
    assert phonetics.confusion("kæt", "kæt") == 0


def test_confusion_cheaper_than_strict_on_mad_gab_pair():
    assert phonetics.confusion(TARGET, CLUE) < phonetics.levenshtein(TARGET, CLUE)


def test_confusion_discriminates_clue_from_decoy_by_5x():
    assert phonetics.confusion(TARGET, DECOY) > 5 * phonetics.confusion(TARGET, CLUE)


def test_confusion_near_zero_for_moved_word_boundary():
    assert phonetics.confusion("ɪts dʒʌst", "ɪt sdʒʌst") < 0.05


# ---------------------------------------------------------------------
# similarity
# ---------------------------------------------------------------------

def test_similarity_is_one_for_identity():
    assert phonetics.similarity("kæt", "kæt") == 1.0


def test_similarity_separates_clue_and_decoy_by_at_least_02():
    delta = phonetics.similarity(TARGET, CLUE) - phonetics.similarity(TARGET, DECOY)
    assert delta >= 0.2


# ---------------------------------------------------------------------
# sub_cost — perceptual per-phoneme
# ---------------------------------------------------------------------

def test_sub_cost_t_flapping_is_cheap():
    assert phonetics.sub_cost("t", "ɾ") < 0.15


def test_sub_cost_cot_caught_merger_is_near_zero():
    assert phonetics.sub_cost("ɑ", "ɔ") < 0.10


def test_sub_cost_symmetric():
    for a, b in [("θ", "t"), ("t", "ɾ"), ("l", "ɹ"), ("p", "f")]:
        assert math.isclose(
            phonetics.sub_cost(a, b),
            phonetics.sub_cost(b, a),
            abs_tol=1e-9,
        )


# ---------------------------------------------------------------------
# tokenize
# ---------------------------------------------------------------------

def test_tokenize_basic():
    assert phonetics.tokenize("kæt") == ["k", "æ", "t"]


def test_tokenize_recognises_diphthongs():
    assert phonetics.tokenize("kɑɪt") == ["k", "ɑɪ", "t"]


def test_tokenize_recognises_affricates():
    assert phonetics.tokenize("dʒʌdʒ") == ["dʒ", "ʌ", "dʒ"]


def test_tokenize_absorbs_aspiration():
    assert phonetics.tokenize("pʰɪt") == ["pʰ", "ɪ", "t"]


def test_tokenize_drops_whitespace_by_default():
    assert phonetics.tokenize("kæt dɔg") == ["k", "æ", "t", "d", "ɔ", "g"]


def test_tokenize_emits_boundary_when_requested():
    assert phonetics.tokenize("kæt dɔg", boundaries=True) == [
        "k", "æ", "t", "#", "d", "ɔ", "g",
    ]
