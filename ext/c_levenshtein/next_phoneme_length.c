// This is compiled from Ruby, in phonetics/lib/phonetics/code_generator.rb:158
int next_phoneme_length(int *string, int cursor, int length) {

  int max_length;
  max_length = length - cursor;

    switch(string[cursor + 0]) {

    case 105:
     // Phoneme: 'i', bytes: [105]
     // vowel features: {"F1":240,"F2":2400,"rounded":false}
     return 1;
        break;
    case 121:
     // Phoneme: 'y', bytes: [121]
     // vowel features: {"F1":235,"F2":2100,"rounded":false}
     return 1;
        break;
    case 201:
     if (max_length > 1) {
     switch(string[cursor + 1]) {

     case 170:
      // Phoneme: 'ɪ', bytes: [201, 170]
      // vowel features: {"F1":300,"F2":2100,"rounded":false}
      return 2;
         break;
     case 155:
      // Phoneme: 'ɛ', bytes: [201, 155]
      // vowel features: {"F1":610,"F2":1900,"rounded":false}
      return 2;
         break;
     case 182:
      // Phoneme: 'ɶ', bytes: [201, 182]
      // vowel features: {"F1":820,"F2":1530,"rounded":true}
      return 2;
         break;
     case 145:
      // Phoneme: 'ɑ', bytes: [201, 145]
      // vowel features: {"F1":750,"F2":940,"rounded":false}
      return 2;
         break;
     case 146:
      // Phoneme: 'ɒ', bytes: [201, 146]
      // vowel features: {"F1":700,"F2":760,"rounded":true}
      return 2;
         break;
     case 153:
      // Phoneme: 'ə', bytes: [201, 153]
      // vowel features: {"F1":600,"F2":1170,"rounded":false}
      return 2;
         break;
     case 157:
      // Phoneme: 'ɝ', bytes: [201, 157]
      // vowel features: {"F1":600,"F2":1170,"rounded":false,"rhotic":true}
      return 2;
         break;
     case 148:
      // Phoneme: 'ɔ', bytes: [201, 148]
      // vowel features: {"F1":500,"F2":700,"rounded":true}
      return 2;
         break;
     case 164:
      // Phoneme: 'ɤ', bytes: [201, 164]
      // vowel features: {"F1":460,"F2":1310,"rounded":false}
      return 2;
         break;
     case 175:
      // Phoneme: 'ɯ', bytes: [201, 175]
      // vowel features: {"F1":300,"F2":1390,"rounded":false}
      return 2;
         break;
     case 177:
      // Phoneme: 'ɱ', bytes: [201, 177]
      // consonant features: {"position":"Labio-dental","position_index":2,"manner":"Nasal","voiced":true}
      return 2;
         break;
     case 179:
      // Phoneme: 'ɳ', bytes: [201, 179]
      // consonant features: {"position":"Retro-flex","position_index":7,"manner":"Nasal","voiced":true}
      if (max_length > 2) {
      switch(string[cursor + 2]) {

      case 204:
       if (max_length > 3) {
       switch(string[cursor + 3]) {

       case 138:
        // Phoneme: 'ɳ̊', bytes: [201, 179, 204, 138]
        // consonant features: {"position":"Retro-flex","position_index":7,"manner":"Nasal","voiced":false}
        return 4;
           break;
       }
       } else {
         return 3;
       }
          break;
        default:
          return 2;
      }
      } else {
        return 2;
      }
         break;
     case 178:
      // Phoneme: 'ɲ', bytes: [201, 178]
      // consonant features: {"position":"Palatal","position_index":8,"manner":"Nasal","voiced":true}
      if (max_length > 2) {
      switch(string[cursor + 2]) {

      case 204:
       if (max_length > 3) {
       switch(string[cursor + 3]) {

       case 138:
        // Phoneme: 'ɲ̊', bytes: [201, 178, 204, 138]
        // consonant features: {"position":"Palatal","position_index":8,"manner":"Nasal","voiced":false}
        return 4;
           break;
       }
       } else {
         return 3;
       }
          break;
        default:
          return 2;
      }
      } else {
        return 2;
      }
         break;
     case 180:
      // Phoneme: 'ɴ', bytes: [201, 180]
      // consonant features: {"position":"Uvular","position_index":10,"manner":"Nasal","voiced":true}
      return 2;
         break;
     case 150:
      // Phoneme: 'ɖ', bytes: [201, 150]
      // consonant features: {"position":"Retro-flex","position_index":7,"manner":"Stop","voiced":true}
      return 2;
         break;
     case 159:
      // Phoneme: 'ɟ', bytes: [201, 159]
      // consonant features: {"position":"Palatal","position_index":8,"manner":"Stop","voiced":true}
      return 2;
         break;
     case 162:
      // Phoneme: 'ɢ', bytes: [201, 162]
      // consonant features: {"position":"Uvular","position_index":10,"manner":"Stop","voiced":true}
      if (max_length > 2) {
      switch(string[cursor + 2]) {

      case 204:
       if (max_length > 3) {
       switch(string[cursor + 3]) {

       case 134:
        // Phoneme: 'ɢ̆', bytes: [201, 162, 204, 134]
        // consonant features: {"position":"Uvular","position_index":10,"manner":"Tap/flap","voiced":true}
        return 4;
           break;
       }
       } else {
         return 3;
       }
          break;
        default:
          return 2;
      }
      } else {
        return 2;
      }
         break;
     case 149:
      // Phoneme: 'ɕ', bytes: [201, 149]
      // consonant features: {"position":"Palatal","position_index":8,"manner":"Sibilant fricative","voiced":false}
      return 2;
         break;
     case 184:
      // Phoneme: 'ɸ', bytes: [201, 184]
      // consonant features: {"position":"Bi-labial","position_index":1,"manner":"Non-sibilant fricative","voiced":false}
      return 2;
         break;
     case 185:
      // Phoneme: 'ɹ', bytes: [201, 185]
      // consonant features: {"position":"Alveolar","position_index":5,"manner":"Approximant","voiced":true}
      if (max_length > 2) {
      switch(string[cursor + 2]) {

      case 204:
       if (max_length > 3) {
       switch(string[cursor + 3]) {

       case 160:
        if (max_length > 4) {
        switch(string[cursor + 4]) {

        case 204:
         if (max_length > 5) {
         switch(string[cursor + 5]) {

         case 138:
          if (max_length > 6) {
          switch(string[cursor + 6]) {

          case 203:
           if (max_length > 7) {
           switch(string[cursor + 7]) {

           case 148:
            // Phoneme: 'ɹ̠̊˔', bytes: [201, 185, 204, 160, 204, 138, 203, 148]
            // consonant features: {"position":"Post-alveolar","position_index":6,"manner":"Non-sibilant fricative","voiced":false}
            return 8;
               break;
           }
           } else {
             return 7;
           }
              break;
          }
          } else {
            return 6;
          }
             break;
         }
         } else {
           return 5;
         }
            break;
        case 203:
         if (max_length > 5) {
         switch(string[cursor + 5]) {

         case 148:
          // Phoneme: 'ɹ̠˔', bytes: [201, 185, 204, 160, 203, 148]
          // consonant features: {"position":"Post-alveolar","position_index":6,"manner":"Non-sibilant fricative","voiced":true}
          return 6;
             break;
         }
         } else {
           return 5;
         }
            break;
        }
        } else {
          return 4;
        }
           break;
       case 165:
        // Phoneme: 'ɹ̥', bytes: [201, 185, 204, 165]
        // consonant features: {"position":"Alveolar","position_index":5,"manner":"Approximant","voiced":false}
        return 4;
           break;
       }
       } else {
         return 3;
       }
          break;
        default:
          return 2;
      }
      } else {
        return 2;
      }
         break;
     case 187:
      // Phoneme: 'ɻ', bytes: [201, 187]
      // consonant features: {"position":"Retro-flex","position_index":7,"manner":"Approximant","voiced":true}
      if (max_length > 2) {
      switch(string[cursor + 2]) {

      case 203:
       if (max_length > 3) {
       switch(string[cursor + 3]) {

       case 148:
        // Phoneme: 'ɻ˔', bytes: [201, 187, 203, 148]
        // consonant features: {"position":"Retro-flex","position_index":7,"manner":"Non-sibilant fricative","voiced":true}
        return 4;
           break;
       }
       } else {
         return 3;
       }
          break;
      case 204:
       if (max_length > 3) {
       switch(string[cursor + 3]) {

       case 138:
        // Phoneme: 'ɻ̊', bytes: [201, 187, 204, 138]
        // consonant features: {"position":"Retro-flex","position_index":7,"manner":"Approximant","voiced":false}
        return 4;
           break;
       }
       } else {
         return 3;
       }
          break;
        default:
          return 2;
      }
      } else {
        return 2;
      }
         break;
     case 163:
      // Phoneme: 'ɣ', bytes: [201, 163]
      // consonant features: {"position":"Velar","position_index":9,"manner":"Non-sibilant fricative","voiced":true}
      return 2;
         break;
     case 166:
      // Phoneme: 'ɦ', bytes: [201, 166]
      // consonant features: {"position":"Glottal","position_index":12,"manner":"Non-sibilant fricative","voiced":true}
      return 2;
         break;
     case 176:
      // Phoneme: 'ɰ', bytes: [201, 176]
      // consonant features: {"position":"Velar","position_index":9,"manner":"Approximant","voiced":true}
      if (max_length > 2) {
      switch(string[cursor + 2]) {

      case 204:
       if (max_length > 3) {
       switch(string[cursor + 3]) {

       case 138:
        // Phoneme: 'ɰ̊', bytes: [201, 176, 204, 138]
        // consonant features: {"position":"Velar","position_index":9,"manner":"Approximant","voiced":false}
        return 4;
           break;
       }
       } else {
         return 3;
       }
          break;
        default:
          return 2;
      }
      } else {
        return 2;
      }
         break;
     case 190:
      // Phoneme: 'ɾ', bytes: [201, 190]
      // consonant features: {"position":"Alveolar","position_index":5,"manner":"Tap/flap","voiced":true}
      if (max_length > 2) {
      switch(string[cursor + 2]) {

      case 204:
       if (max_length > 3) {
       switch(string[cursor + 3]) {

       case 188:
        // Phoneme: 'ɾ̼', bytes: [201, 190, 204, 188]
        // consonant features: {"position":"Linguo-labial","position_index":3,"manner":"Tap/flap","voiced":true}
        return 4;
           break;
       case 165:
        // Phoneme: 'ɾ̥', bytes: [201, 190, 204, 165]
        // consonant features: {"position":"Alveolar","position_index":5,"manner":"Tap/flap","voiced":false}
        return 4;
           break;
       }
       } else {
         return 3;
       }
          break;
        default:
          return 2;
      }
      } else {
        return 2;
      }
         break;
     case 189:
      // Phoneme: 'ɽ', bytes: [201, 189]
      // consonant features: {"position":"Retro-flex","position_index":7,"manner":"Tap/flap","voiced":true}
      if (max_length > 2) {
      switch(string[cursor + 2]) {

      case 204:
       if (max_length > 3) {
       switch(string[cursor + 3]) {

       case 138:
        // Phoneme: 'ɽ̊', bytes: [201, 189, 204, 138]
        // consonant features: {"position":"Retro-flex","position_index":7,"manner":"Tap/flap","voiced":false}
        return 4;
           break;
       }
       } else {
         return 3;
       }
          break;
        default:
          return 2;
      }
      } else {
        return 2;
      }
         break;
     case 172:
      // Phoneme: 'ɬ', bytes: [201, 172]
      // consonant features: {"position":"Alveolar","position_index":5,"manner":"Lateral fricative","voiced":false}
      return 2;
         break;
     case 174:
      // Phoneme: 'ɮ', bytes: [201, 174]
      // consonant features: {"position":"Alveolar","position_index":5,"manner":"Lateral fricative","voiced":true}
      return 2;
         break;
     case 173:
      // Phoneme: 'ɭ', bytes: [201, 173]
      // consonant features: {"position":"Retro-flex","position_index":7,"manner":"Lateral approximant","voiced":true}
      if (max_length > 2) {
      switch(string[cursor + 2]) {

      case 204:
       if (max_length > 3) {
       switch(string[cursor + 3]) {

       case 138:
        // Phoneme: 'ɭ̊', bytes: [201, 173, 204, 138]
        // consonant features: {"position":"Retro-flex","position_index":7,"manner":"Lateral approximant","voiced":false}
        if (max_length > 4) {
        switch(string[cursor + 4]) {

        case 203:
         if (max_length > 5) {
         switch(string[cursor + 5]) {

         case 148:
          // Phoneme: 'ɭ̊˔', bytes: [201, 173, 204, 138, 203, 148]
          // consonant features: {"position":"Retro-flex","position_index":7,"manner":"Lateral fricative","voiced":false}
          return 6;
             break;
         }
         } else {
           return 5;
         }
            break;
          default:
            return 4;
        }
        } else {
          return 4;
        }
           break;
       case 134:
        // Phoneme: 'ɭ̆', bytes: [201, 173, 204, 134]
        // consonant features: {"position":"Retro-flex","position_index":7,"manner":"Lateral tap/flap","voiced":true}
        return 4;
           break;
       }
       } else {
         return 3;
       }
          break;
      case 203:
       if (max_length > 3) {
       switch(string[cursor + 3]) {

       case 148:
        // Phoneme: 'ɭ˔', bytes: [201, 173, 203, 148]
        // consonant features: {"position":"Retro-flex","position_index":7,"manner":"Lateral fricative","voiced":true}
        return 4;
           break;
       }
       } else {
         return 3;
       }
          break;
        default:
          return 2;
      }
      } else {
        return 2;
      }
         break;
     case 186:
      // Phoneme: 'ɺ', bytes: [201, 186]
      // consonant features: {"position":"Alveolar","position_index":5,"manner":"Lateral tap/flap","voiced":true}
      return 2;
         break;
     }
     } else {
       return 1;
     }
        break;
    case 101:
     // Phoneme: 'e', bytes: [101]
     // vowel features: {"F1":390,"F2":2300,"rounded":false}
     return 1;
        break;
    case 195:
     if (max_length > 1) {
     switch(string[cursor + 1]) {

     case 184:
      // Phoneme: 'ø', bytes: [195, 184]
      // vowel features: {"F1":370,"F2":1900,"rounded":true}
      return 2;
         break;
     case 166:
      // Phoneme: 'æ', bytes: [195, 166]
      // vowel features: {"F1":800,"F2":1900,"rounded":false}
      return 2;
         break;
     case 176:
      // Phoneme: 'ð', bytes: [195, 176]
      // consonant features: {"position":"Dental","position_index":4,"manner":"Non-sibilant fricative","voiced":true}
      if (max_length > 2) {
      switch(string[cursor + 2]) {

      case 204:
       if (max_length > 3) {
       switch(string[cursor + 3]) {

       case 188:
        // Phoneme: 'ð̼', bytes: [195, 176, 204, 188]
        // consonant features: {"position":"Linguo-labial","position_index":3,"manner":"Non-sibilant fricative","voiced":true}
        return 4;
           break;
       case 160:
        // Phoneme: 'ð̠', bytes: [195, 176, 204, 160]
        // consonant features: {"position":"Alveolar","position_index":5,"manner":"Non-sibilant fricative","voiced":true}
        return 4;
           break;
       }
       } else {
         return 3;
       }
          break;
        default:
          return 2;
      }
      } else {
        return 2;
      }
         break;
     case 167:
      // Phoneme: 'ç', bytes: [195, 167]
      // consonant features: {"position":"Palatal","position_index":8,"manner":"Non-sibilant fricative","voiced":false}
      return 2;
         break;
     }
     } else {
       return 1;
     }
        break;
    case 197:
     if (max_length > 1) {
     switch(string[cursor + 1]) {

     case 147:
      // Phoneme: 'œ', bytes: [197, 147]
      // vowel features: {"F1":585,"F2":1710,"rounded":true}
      return 2;
         break;
     case 139:
      // Phoneme: 'ŋ', bytes: [197, 139]
      // consonant features: {"position":"Velar","position_index":9,"manner":"Nasal","voiced":true}
      if (max_length > 2) {
      switch(string[cursor + 2]) {

      case 204:
       if (max_length > 3) {
       switch(string[cursor + 3]) {

       case 138:
        // Phoneme: 'ŋ̊', bytes: [197, 139, 204, 138]
        // consonant features: {"position":"Velar","position_index":9,"manner":"Nasal","voiced":false}
        return 4;
           break;
       }
       } else {
         return 3;
       }
          break;
        default:
          return 2;
      }
      } else {
        return 2;
      }
         break;
     }
     } else {
       return 1;
     }
        break;
    case 97:
     // Phoneme: 'a', bytes: [97]
     // vowel features: {"F1":850,"F2":1610,"rounded":false}
     return 1;
        break;
    case 202:
     if (max_length > 1) {
     switch(string[cursor + 1]) {

     case 140:
      // Phoneme: 'ʌ', bytes: [202, 140]
      // vowel features: {"F1":600,"F2":1170,"rounded":false}
      return 2;
         break;
     case 138:
      // Phoneme: 'ʊ', bytes: [202, 138]
      // vowel features: {"F1":350,"F2":650,"rounded":true}
      return 2;
         break;
     case 136:
      // Phoneme: 'ʈ', bytes: [202, 136]
      // consonant features: {"position":"Retro-flex","position_index":7,"manner":"Stop","voiced":false}
      return 2;
         break;
     case 161:
      // Phoneme: 'ʡ', bytes: [202, 161]
      // consonant features: {"position":"Pharyngeal","position_index":11,"manner":"Stop","voiced":false}
      if (max_length > 2) {
      switch(string[cursor + 2]) {

      case 204:
       if (max_length > 3) {
       switch(string[cursor + 3]) {

       case 134:
        // Phoneme: 'ʡ̆', bytes: [202, 161, 204, 134]
        // consonant features: {"position":"Pharyngeal","position_index":11,"manner":"Tap/flap","voiced":true}
        return 4;
           break;
       }
       } else {
         return 3;
       }
          break;
        default:
          return 2;
      }
      } else {
        return 2;
      }
         break;
     case 148:
      // Phoneme: 'ʔ', bytes: [202, 148]
      // consonant features: {"position":"Glottal","position_index":12,"manner":"Stop","voiced":false}
      if (max_length > 2) {
      switch(string[cursor + 2]) {

      case 204:
       if (max_length > 3) {
       switch(string[cursor + 3]) {

       case 158:
        // Phoneme: 'ʔ̞', bytes: [202, 148, 204, 158]
        // consonant features: {"position":"Glottal","position_index":12,"manner":"Approximant","voiced":true}
        return 4;
           break;
       }
       } else {
         return 3;
       }
          break;
        default:
          return 2;
      }
      } else {
        return 2;
      }
         break;
     case 131:
      // Phoneme: 'ʃ', bytes: [202, 131]
      // consonant features: {"position":"Post-alveolar","position_index":6,"manner":"Sibilant fricative","voiced":false}
      return 2;
         break;
     case 146:
      // Phoneme: 'ʒ', bytes: [202, 146]
      // consonant features: {"position":"Post-alveolar","position_index":6,"manner":"Sibilant fricative","voiced":true}
      return 2;
         break;
     case 130:
      // Phoneme: 'ʂ', bytes: [202, 130]
      // consonant features: {"position":"Retro-flex","position_index":7,"manner":"Sibilant fricative","voiced":false}
      return 2;
         break;
     case 144:
      // Phoneme: 'ʐ', bytes: [202, 144]
      // consonant features: {"position":"Retro-flex","position_index":7,"manner":"Sibilant fricative","voiced":true}
      return 2;
         break;
     case 145:
      // Phoneme: 'ʑ', bytes: [202, 145]
      // consonant features: {"position":"Palatal","position_index":8,"manner":"Sibilant fricative","voiced":true}
      return 2;
         break;
     case 157:
      // Phoneme: 'ʝ', bytes: [202, 157]
      // consonant features: {"position":"Palatal","position_index":8,"manner":"Non-sibilant fricative","voiced":true}
      return 2;
         break;
     case 129:
      // Phoneme: 'ʁ', bytes: [202, 129]
      // consonant features: {"position":"Uvular","position_index":10,"manner":"Non-sibilant fricative","voiced":true}
      return 2;
         break;
     case 149:
      // Phoneme: 'ʕ', bytes: [202, 149]
      // consonant features: {"position":"Pharyngeal","position_index":11,"manner":"Non-sibilant fricative","voiced":true}
      return 2;
         break;
     case 139:
      // Phoneme: 'ʋ', bytes: [202, 139]
      // consonant features: {"position":"Labio-dental","position_index":2,"manner":"Approximant","voiced":true}
      if (max_length > 2) {
      switch(string[cursor + 2]) {

      case 204:
       if (max_length > 3) {
       switch(string[cursor + 3]) {

       case 165:
        // Phoneme: 'ʋ̥', bytes: [202, 139, 204, 165]
        // consonant features: {"position":"Labio-dental","position_index":2,"manner":"Approximant","voiced":false}
        return 4;
           break;
       }
       } else {
         return 3;
       }
          break;
        default:
          return 2;
      }
      } else {
        return 2;
      }
         break;
     case 153:
      // Phoneme: 'ʙ', bytes: [202, 153]
      // consonant features: {"position":"Bi-labial","position_index":1,"manner":"Trill","voiced":true}
      if (max_length > 2) {
      switch(string[cursor + 2]) {

      case 204:
       if (max_length > 3) {
       switch(string[cursor + 3]) {

       case 165:
        // Phoneme: 'ʙ̥', bytes: [202, 153, 204, 165]
        // consonant features: {"position":"Bi-labial","position_index":1,"manner":"Trill","voiced":false}
        return 4;
           break;
       }
       } else {
         return 3;
       }
          break;
        default:
          return 2;
      }
      } else {
        return 2;
      }
         break;
     case 128:
      // Phoneme: 'ʀ', bytes: [202, 128]
      // consonant features: {"position":"Uvular","position_index":10,"manner":"Trill","voiced":true}
      if (max_length > 2) {
      switch(string[cursor + 2]) {

      case 204:
       if (max_length > 3) {
       switch(string[cursor + 3]) {

       case 165:
        // Phoneme: 'ʀ̥', bytes: [202, 128, 204, 165]
        // consonant features: {"position":"Uvular","position_index":10,"manner":"Trill","voiced":false}
        return 4;
           break;
       }
       } else {
         return 3;
       }
          break;
        default:
          return 2;
      }
      } else {
        return 2;
      }
         break;
     case 156:
      // Phoneme: 'ʜ', bytes: [202, 156]
      // consonant features: {"position":"Pharyngeal","position_index":11,"manner":"Trill","voiced":false}
      return 2;
         break;
     case 162:
      // Phoneme: 'ʢ', bytes: [202, 162]
      // consonant features: {"position":"Pharyngeal","position_index":11,"manner":"Trill","voiced":true}
      return 2;
         break;
     case 142:
      // Phoneme: 'ʎ', bytes: [202, 142]
      // consonant features: {"position":"Palatal","position_index":8,"manner":"Lateral approximant","voiced":true}
      if (max_length > 2) {
      switch(string[cursor + 2]) {

      case 204:
       if (max_length > 3) {
       switch(string[cursor + 3]) {

       case 157:
        // Phoneme: 'ʎ̝', bytes: [202, 142, 204, 157]
        // consonant features: {"position":"Palatal","position_index":8,"manner":"Lateral fricative","voiced":true}
        if (max_length > 4) {
        switch(string[cursor + 4]) {

        case 204:
         if (max_length > 5) {
         switch(string[cursor + 5]) {

         case 138:
          // Phoneme: 'ʎ̝̊', bytes: [202, 142, 204, 157, 204, 138]
          // consonant features: {"position":"Palatal","position_index":8,"manner":"Lateral fricative","voiced":false}
          return 6;
             break;
         }
         } else {
           return 5;
         }
            break;
          default:
            return 4;
        }
        } else {
          return 4;
        }
           break;
       case 165:
        // Phoneme: 'ʎ̥', bytes: [202, 142, 204, 165]
        // consonant features: {"position":"Palatal","position_index":8,"manner":"Lateral approximant","voiced":false}
        return 4;
           break;
       case 134:
        // Phoneme: 'ʎ̆', bytes: [202, 142, 204, 134]
        // consonant features: {"position":"Palatal","position_index":8,"manner":"Lateral tap/flap","voiced":true}
        return 4;
           break;
       }
       } else {
         return 3;
       }
          break;
        default:
          return 2;
      }
      } else {
        return 2;
      }
         break;
     case 159:
      // Phoneme: 'ʟ', bytes: [202, 159]
      // consonant features: {"position":"Velar","position_index":9,"manner":"Lateral approximant","voiced":true}
      if (max_length > 2) {
      switch(string[cursor + 2]) {

      case 204:
       if (max_length > 3) {
       switch(string[cursor + 3]) {

       case 157:
        // Phoneme: 'ʟ̝', bytes: [202, 159, 204, 157]
        // consonant features: {"position":"Velar","position_index":9,"manner":"Lateral fricative","voiced":true}
        if (max_length > 4) {
        switch(string[cursor + 4]) {

        case 204:
         if (max_length > 5) {
         switch(string[cursor + 5]) {

         case 138:
          // Phoneme: 'ʟ̝̊', bytes: [202, 159, 204, 157, 204, 138]
          // consonant features: {"position":"Velar","position_index":9,"manner":"Lateral fricative","voiced":false}
          return 6;
             break;
         }
         } else {
           return 5;
         }
            break;
          default:
            return 4;
        }
        } else {
          return 4;
        }
           break;
       case 165:
        // Phoneme: 'ʟ̥', bytes: [202, 159, 204, 165]
        // consonant features: {"position":"Velar","position_index":9,"manner":"Lateral approximant","voiced":false}
        return 4;
           break;
       case 160:
        // Phoneme: 'ʟ̠', bytes: [202, 159, 204, 160]
        // consonant features: {"position":"Uvular","position_index":10,"manner":"Lateral approximant","voiced":true}
        return 4;
           break;
       case 134:
        // Phoneme: 'ʟ̆', bytes: [202, 159, 204, 134]
        // consonant features: {"position":"Velar","position_index":9,"manner":"Lateral tap/flap","voiced":true}
        return 4;
           break;
       }
       } else {
         return 3;
       }
          break;
        default:
          return 2;
      }
      } else {
        return 2;
      }
         break;
     }
     } else {
       return 1;
     }
        break;
    case 111:
     // Phoneme: 'o', bytes: [111]
     // vowel features: {"F1":360,"F2":640,"rounded":true}
     return 1;
        break;
    case 117:
     // Phoneme: 'u', bytes: [117]
     // vowel features: {"F1":350,"F2":650,"rounded":true}
     return 1;
        break;
    case 109:
     // Phoneme: 'm', bytes: [109]
     // consonant features: {"position":"Bi-labial","position_index":1,"manner":"Nasal","voiced":true}
     if (max_length > 1) {
     switch(string[cursor + 1]) {

     case 204:
      if (max_length > 2) {
      switch(string[cursor + 2]) {

      case 165:
       // Phoneme: 'm̥', bytes: [109, 204, 165]
       // consonant features: {"position":"Bi-labial","position_index":1,"manner":"Nasal","voiced":false}
       return 3;
          break;
      }
      } else {
        return 2;
      }
         break;
       default:
         return 1;
     }
     } else {
       return 1;
     }
        break;
    case 110:
     // Phoneme: 'n', bytes: [110]
     // consonant features: {"position":"Alveolar","position_index":5,"manner":"Nasal","voiced":true}
     if (max_length > 1) {
     switch(string[cursor + 1]) {

     case 204:
      if (max_length > 2) {
      switch(string[cursor + 2]) {

      case 188:
       // Phoneme: 'n̼', bytes: [110, 204, 188]
       // consonant features: {"position":"Linguo-labial","position_index":3,"manner":"Nasal","voiced":true}
       return 3;
          break;
      case 165:
       // Phoneme: 'n̥', bytes: [110, 204, 165]
       // consonant features: {"position":"Alveolar","position_index":5,"manner":"Nasal","voiced":false}
       return 3;
          break;
      }
      } else {
        return 2;
      }
         break;
       default:
         return 1;
     }
     } else {
       return 1;
     }
        break;
    case 112:
     // Phoneme: 'p', bytes: [112]
     // consonant features: {"position":"Bi-labial","position_index":1,"manner":"Stop","voiced":false}
     if (max_length > 1) {
     switch(string[cursor + 1]) {

     case 204:
      if (max_length > 2) {
      switch(string[cursor + 2]) {

      case 170:
       // Phoneme: 'p̪', bytes: [112, 204, 170]
       // consonant features: {"position":"Labio-dental","position_index":2,"manner":"Stop","voiced":false}
       return 3;
          break;
      }
      } else {
        return 2;
      }
         break;
       default:
         return 1;
     }
     } else {
       return 1;
     }
        break;
    case 98:
     // Phoneme: 'b', bytes: [98]
     // consonant features: {"position":"Bi-labial","position_index":1,"manner":"Stop","voiced":true}
     if (max_length > 1) {
     switch(string[cursor + 1]) {

     case 204:
      if (max_length > 2) {
      switch(string[cursor + 2]) {

      case 170:
       // Phoneme: 'b̪', bytes: [98, 204, 170]
       // consonant features: {"position":"Labio-dental","position_index":2,"manner":"Stop","voiced":true}
       return 3;
          break;
      }
      } else {
        return 2;
      }
         break;
       default:
         return 1;
     }
     } else {
       return 1;
     }
        break;
    case 116:
     // Phoneme: 't', bytes: [116]
     // consonant features: {"position":"Alveolar","position_index":5,"manner":"Stop","voiced":false}
     if (max_length > 1) {
     switch(string[cursor + 1]) {

     case 204:
      if (max_length > 2) {
      switch(string[cursor + 2]) {

      case 188:
       // Phoneme: 't̼', bytes: [116, 204, 188]
       // consonant features: {"position":"Linguo-labial","position_index":3,"manner":"Stop","voiced":false}
       return 3;
          break;
      }
      } else {
        return 2;
      }
         break;
       default:
         return 1;
     }
     } else {
       return 1;
     }
        break;
    case 100:
     // Phoneme: 'd', bytes: [100]
     // consonant features: {"position":"Alveolar","position_index":5,"manner":"Stop","voiced":true}
     if (max_length > 1) {
     switch(string[cursor + 1]) {

     case 204:
      if (max_length > 2) {
      switch(string[cursor + 2]) {

      case 188:
       // Phoneme: 'd̼', bytes: [100, 204, 188]
       // consonant features: {"position":"Linguo-labial","position_index":3,"manner":"Stop","voiced":true}
       return 3;
          break;
      }
      } else {
        return 2;
      }
         break;
       default:
         return 1;
     }
     } else {
       return 1;
     }
        break;
    case 99:
     // Phoneme: 'c', bytes: [99]
     // consonant features: {"position":"Palatal","position_index":8,"manner":"Stop","voiced":false}
     return 1;
        break;
    case 107:
     // Phoneme: 'k', bytes: [107]
     // consonant features: {"position":"Velar","position_index":9,"manner":"Stop","voiced":false}
     return 1;
        break;
    case 103:
     // Phoneme: 'g', bytes: [103]
     // consonant features: {"position":"Velar","position_index":9,"manner":"Stop","voiced":true}
     return 1;
        break;
    case 113:
     // Phoneme: 'q', bytes: [113]
     // consonant features: {"position":"Uvular","position_index":10,"manner":"Stop","voiced":false}
     return 1;
        break;
    case 115:
     // Phoneme: 's', bytes: [115]
     // consonant features: {"position":"Alveolar","position_index":5,"manner":"Sibilant fricative","voiced":false}
     return 1;
        break;
    case 122:
     // Phoneme: 'z', bytes: [122]
     // consonant features: {"position":"Alveolar","position_index":5,"manner":"Sibilant fricative","voiced":true}
     return 1;
        break;
    case 206:
     if (max_length > 1) {
     switch(string[cursor + 1]) {

     case 178:
      // Phoneme: 'β', bytes: [206, 178]
      // consonant features: {"position":"Bi-labial","position_index":1,"manner":"Non-sibilant fricative","voiced":true}
      return 2;
         break;
     case 184:
      // Phoneme: 'θ', bytes: [206, 184]
      // consonant features: {"position":"Dental","position_index":4,"manner":"Non-sibilant fricative","voiced":false}
      if (max_length > 2) {
      switch(string[cursor + 2]) {

      case 204:
       if (max_length > 3) {
       switch(string[cursor + 3]) {

       case 188:
        // Phoneme: 'θ̼', bytes: [206, 184, 204, 188]
        // consonant features: {"position":"Linguo-labial","position_index":3,"manner":"Non-sibilant fricative","voiced":false}
        return 4;
           break;
       case 160:
        // Phoneme: 'θ̠', bytes: [206, 184, 204, 160]
        // consonant features: {"position":"Alveolar","position_index":5,"manner":"Non-sibilant fricative","voiced":false}
        return 4;
           break;
       }
       } else {
         return 3;
       }
          break;
        default:
          return 2;
      }
      } else {
        return 2;
      }
         break;
     }
     } else {
       return 1;
     }
        break;
    case 102:
     // Phoneme: 'f', bytes: [102]
     // consonant features: {"position":"Labio-dental","position_index":2,"manner":"Non-sibilant fricative","voiced":false}
     return 1;
        break;
    case 118:
     // Phoneme: 'v', bytes: [118]
     // consonant features: {"position":"Labio-dental","position_index":2,"manner":"Non-sibilant fricative","voiced":true}
     return 1;
        break;
    case 120:
     // Phoneme: 'x', bytes: [120]
     // consonant features: {"position":"Velar","position_index":9,"manner":"Non-sibilant fricative","voiced":false}
     return 1;
        break;
    case 207:
     if (max_length > 1) {
     switch(string[cursor + 1]) {

     case 135:
      // Phoneme: 'χ', bytes: [207, 135]
      // consonant features: {"position":"Uvular","position_index":10,"manner":"Non-sibilant fricative","voiced":false}
      return 2;
         break;
     }
     } else {
       return 1;
     }
        break;
    case 196:
     if (max_length > 1) {
     switch(string[cursor + 1]) {

     case 167:
      // Phoneme: 'ħ', bytes: [196, 167]
      // consonant features: {"position":"Pharyngeal","position_index":11,"manner":"Non-sibilant fricative","voiced":false}
      return 2;
         break;
     }
     } else {
       return 1;
     }
        break;
    case 104:
     // Phoneme: 'h', bytes: [104]
     // consonant features: {"position":"Glottal","position_index":12,"manner":"Non-sibilant fricative","voiced":false}
     return 1;
        break;
    case 119:
     // Phoneme: 'w', bytes: [119]
     // consonant features: {"position":"Labio-velar","position_index":0,"manner":"Approximant","voiced":true}
     return 1;
        break;
    case 106:
     // Phoneme: 'j', bytes: [106]
     // consonant features: {"position":"Palatal","position_index":8,"manner":"Approximant","voiced":true}
     if (max_length > 1) {
     switch(string[cursor + 1]) {

     case 204:
      if (max_length > 2) {
      switch(string[cursor + 2]) {

      case 138:
       // Phoneme: 'j̊', bytes: [106, 204, 138]
       // consonant features: {"position":"Palatal","position_index":8,"manner":"Approximant","voiced":false}
       return 3;
          break;
      }
      } else {
        return 2;
      }
         break;
       default:
         return 1;
     }
     } else {
       return 1;
     }
        break;
    case 226:
     if (max_length > 1) {
     switch(string[cursor + 1]) {

     case 177:
      if (max_length > 2) {
      switch(string[cursor + 2]) {

      case 177:
       // Phoneme: 'ⱱ', bytes: [226, 177, 177]
       // consonant features: {"position":"Labio-dental","position_index":2,"manner":"Tap/flap","voiced":true}
       if (max_length > 3) {
       switch(string[cursor + 3]) {

       case 204:
        if (max_length > 4) {
        switch(string[cursor + 4]) {

        case 159:
         // Phoneme: 'ⱱ̟', bytes: [226, 177, 177, 204, 159]
         // consonant features: {"position":"Bi-labial","position_index":1,"manner":"Tap/flap","voiced":true}
         return 5;
            break;
        }
        } else {
          return 4;
        }
           break;
         default:
           return 3;
       }
       } else {
         return 3;
       }
          break;
      }
      } else {
        return 2;
      }
         break;
     }
     } else {
       return 1;
     }
        break;
    case 114:
     // Phoneme: 'r', bytes: [114]
     // consonant features: {"position":"Alveolar","position_index":5,"manner":"Trill","voiced":true}
     if (max_length > 1) {
     switch(string[cursor + 1]) {

     case 204:
      if (max_length > 2) {
      switch(string[cursor + 2]) {

      case 165:
       // Phoneme: 'r̥', bytes: [114, 204, 165]
       // consonant features: {"position":"Alveolar","position_index":5,"manner":"Trill","voiced":false}
       return 3;
          break;
      }
      } else {
        return 2;
      }
         break;
       default:
         return 1;
     }
     } else {
       return 1;
     }
        break;
    case 108:
     // Phoneme: 'l', bytes: [108]
     // consonant features: {"position":"Alveolar","position_index":5,"manner":"Lateral approximant","voiced":true}
     if (max_length > 1) {
     switch(string[cursor + 1]) {

     case 204:
      if (max_length > 2) {
      switch(string[cursor + 2]) {

      case 165:
       // Phoneme: 'l̥', bytes: [108, 204, 165]
       // consonant features: {"position":"Alveolar","position_index":5,"manner":"Lateral approximant","voiced":false}
       return 3;
          break;
      }
      } else {
        return 2;
      }
         break;
       default:
         return 1;
     }
     } else {
       return 1;
     }
        break;
    }
  return 0;
}
