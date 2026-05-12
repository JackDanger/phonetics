#ifndef PHONETICS_CONFUSION_COST_H
#define PHONETICS_CONFUSION_COST_H

#include <stdint.h>

/* Per-phoneme substitution cost for the listener-confusion metric.
 * Acoustic distance with the empirical-confusion overlay applied;
 * generated from lib/phonetics/code_generator.rb (ConfusionCost). */
float confusion_sub_cost(int64_t phoneme1, int64_t phoneme2);

#endif
