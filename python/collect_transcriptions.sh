#!/bin/bash

set -x

root=$(cd $(dirname $0) && pwd)


##
## From ipa2 project
##
[ -d _python_ipa2 ] || git clone https://github.com/voidful/ipa2.git _python_ipa2

if [ ! -f ${root}/ipa2_lang_pairs.text ]; then
  pushd _python_ipa2
  for file in ipa2/data/*.tsv; do
    filename=$(basename $file)
    lang=${filename/.tsv/}
    awk '{print "'$lang'", $0}' $file
  done > ${root}/ipa2_lang_pairs.text
  popd
fi

# Some of the input texts have multiple transcription options
# We assign the first as the target transcription
< ipa2_lang_pairs.text ruby -ne 'lang, text, ipa = $_.split; ipas = ipa.split(","); puts "#{text} #{ipas[0]}"' > text_to_ipa.txt
# and we use the rest as inputs for reverse transcription
< ipa2_lang_pairs.text ruby -ne ' lang, text, ipa = $_.split; ipas = ipa.split(","); ipas.each {|i| puts "#{i} #{text}" };' > ipa_to_text.txt

# Identify maximum character size of inputs and outputs to help us design our
# encoder/decoder with a helpful sequence length

awk '{print $1, $2, length($1) }' text_to_ipa.txt | sort -k 4 -nr | head
# გადმოსაკონტრრევოლუციონერებლებისნაირებისათვისაცო ɡɑdmɔsɑkʼɔntʼrrɛvɔlut͡siɔnɛrɛblɛbisnɑirɛbisɑtʰvisɑt͡sɔ 141
# สหราชอาณาจักรเกรตบริเตนและนอร์เทิร์นไอร์แลนด์ sa˨˩.ha˨˩.raːt̚˥˩.t͡ɕʰa˦˥.ʔaː˧.naː˧.t͡ɕak̚˨˩.kreːt̚˦˥.bri˨˩.teːn˧.lɛʔ˦˥.nɔt̚˦˥.tʰɤn˥˩.ʔaj˧.lɛn˥˩ 135
# สหราชอาณาจักรบริเตนใหญ่และไอร์แลนด์เหนือ sa˨˩.ha˨˩.raːt̚˥˩.t͡ɕʰa˦˥.ʔaː˧.naː˧.t͡ɕak̚˨˩.bri˨˩.teːn˧.jaj˨˩.lɛʔ˦˥.ʔaj˧.lɛːn˧.nɯa̯˩˩˦ 120
# लौहपथगामिनीसूचकदर्शकहरितताम्रलौहपट्टिका l̪ɔːɦpət̪ʰɡäːmɪn̪iːs̪uːt͡ʃəkd̪əɾʃəkʰəɾɪt̪̚t̪ä̃ːmɾəl̪ɔːɦpəʈ̚ʈɪkäː 117
# กล้องจุลทรรศน์อิเล็กตรอนชนิดส่องผ่าน klɔŋ˥˩.t͡ɕun˧.la˦˥.tʰat̚˦˥.ʔi˨˩.lek̚˦˥.trɔn˧.t͡ɕʰa˦˥.nit̚˦˥.sɔŋ˨˩.pʰaːn˨˩ 108
# กล้องจุลทรรศน์อิเล็กตรอนชนิดส่องกราด klɔŋ˥˩.t͡ɕun˧.la˦˥.tʰat̚˦˥.ʔi˨˩.lek̚˦˥.trɔn˧.t͡ɕʰa˦˥.nit̚˦˥.sɔŋ˨˩.kraːt̚˨˩ 108
# สหราชอาณาจักรเกรตบริเตนและไอร์แลนด์ sa˨˩.ha˨˩.raːt̚˥˩.t͡ɕʰa˦˥.ʔaː˧.naː˧.t͡ɕak̚˨˩.kreːt̚˦˥.bri˨˩.teːn˧.lɛʔ˦˥.ʔaj˧.lɛːn˧ 105
# สหราชอาณาจักรบริเตนใหญ่และไอร์แลนด์ sa˨˩.ha˨˩.raːt̚˥˩.t͡ɕʰa˦˥.ʔaː˧.naː˧.t͡ɕak̚˨˩.bri˨˩.teːn˧.jaj˨˩.lɛʔ˦˥.ʔaj˧.lɛːn˧ 105
# ပြည်ထောင်စုတော်လှန်ရေးကောင်စီအဖွဲ့ pjìdàʊɴzṵtɔ̀l̥àɴjékàʊɴsìʔəpʰwɛ̰ 102
# เอาลูกเขามาเลี้ยงเอาเมี่ยงเขามาอม ʔaw˧.luːk̚˥˩.kʰaw˩˩˦.maː˧.lia̯ŋ˦˥.ʔaw˧.mia̯ŋ˥˩.kʰaw˩˩˦.maː˧.ʔom˧ 99

awk '{ print $1, $2, length($2) }' text_to_ipa.txt | sort -k 4 -nr | head
# 朝鮮民主主義人民共和國 tiaʊ²⁴⁻²²ɕiɛn⁵³⁻⁴⁴bin²⁴⁻²²t͡su⁵³⁻⁴⁴t͡su⁵³⁻⁴⁴ɡi²²⁻²¹lin²⁴⁻²²bin²⁴⁻²²kiɔŋ²²⁻²¹ho²⁴⁻²²kɔk̚³² 175
# 聖文森特和格林納丁斯 ɕiɪŋ²¹⁻⁵³bun²⁴⁻²²ɕim⁴⁴⁻²²tiɪk̚⁴⁻³²ho²⁴⁻²²kiɪk̚³²⁻⁴lim²⁴⁻²²lap̚⁴⁻³²tiɪŋ⁴⁴⁻²²su⁴⁴ 156
# میلادالنبیﷺ mˈiːmcʰoːʈˈiːjeːlˈaːmˈalɪfdˈaːlˈalɪflˈaːmnˈuːnbˈeːcʰoːʈˈiːjeːdˌʊruːdsalˈallaːhˌʊalˌeːhɪʋˌaaːlˌɪhiʋˌasalˌam 152
# สมเด็จพระบรมบพิตรพระราชสมภารเจ้า som˩˩˦.det̚˨˩.pʰra˦˥.bɔː˧.rom˧.ma˦˥.bɔː˧.pʰit̚˦˥.pʰra˦˥.raːt̚˥˩.t͡ɕʰa˦˥.som˩˩˦.pʰaː˧.ra˦˥.t͡ɕaːw˥˩ 145
# สหราชอาณาจักรเกรตบริเตนและนอร์เทิร์นไอร์แลนด์ sa˨˩.ha˨˩.raːt̚˥˩.t͡ɕʰa˦˥.ʔaː˧.naː˧.t͡ɕak̚˨˩.kreːt̚˦˥.bri˨˩.teːn˧.lɛʔ˦˥.nɔt̚˦˥.tʰɤn˥˩.ʔaj˧.lɛn˥˩ 144
# 波斯尼亞和黑塞哥維那 po⁴⁴⁻²²su⁴⁴⁻²²nĩ²⁴⁻²²a⁴⁴⁻²²ho²⁴⁻²²hiɪk̚³²⁻⁴saɪ²¹⁻⁵³ko⁴⁴⁻²²ui²⁴⁻²²nã⁵³ 143
# 特克斯和凱科斯群島 tiɪk̚⁴⁻³²kʰiɪk̚³²⁻⁴su⁴⁴⁻²²ho²⁴⁻²²kʰaɪ⁵³⁻⁴⁴kʰo⁴⁴⁻²²su⁴⁴⁻²²kun²⁴⁻²²to⁵³ 139
# สมเด็จบรมบพิตรพระราชสมภารเจ้า som˩˩˦.det̚˨˩.bɔː˧.rom˧.ma˦˥.bɔː˧.pʰit̚˦˥.pʰra˦˥.raːt̚˥˩.t͡ɕʰa˦˥.som˩˩˦.pʰaː˧.ra˦˥.t͡ɕaːw˥˩ 135
# สหราชอาณาจักรบริเตนใหญ่และไอร์แลนด์เหนือ sa˨˩.ha˨˩.raːt̚˥˩.t͡ɕʰa˦˥.ʔaː˧.naː˧.t͡ɕak̚˨˩.bri˨˩.teːn˧.jaj˨˩.lɛʔ˦˥.ʔaj˧.lɛːn˧.nɯa̯˩˩˦ 130
# 得人心者得天下，失人心者失天下 tɤ˧˥ʐən˧˥ɕɪn˥˥ʈʂɤ˨˩˦tɤ˧˥tʰjɛn˥˥ɕja˥˩ʂɚ˥˥ʐən˧˥ɕɪn˥˥ʈʂɤ˨˩˦ʂɚ˥˥tʰjɛn˥˥ɕja˥˩ 128

# 128/128 keeps virtually all data
