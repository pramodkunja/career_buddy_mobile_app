/// The three difficulty levels the web's Level 1/2/3 buttons offer
/// (`templates/activities/modules/reading.html:131-133`) and the 5 fixed
/// passages each cycles through (`static/activities/js/reading.js:10-337`'s
/// `passages` object — read verbatim, not reworded, generated, or
/// reordered). [text] is each passage's `displayLines` array already
/// joined with single spaces, exactly matching
/// `currentPassageText = passage.displayLines.join(" ")` — the same string
/// actually sent server-side as `reference_text`. Only the English
/// `title`/`text` are ported — the `titleVN`/`titleRU`/`titleAR`/`badge*`
/// cosmetic translations are the same kind of decorative-only overlay
/// already skipped for Speaking/Writing/Listening.
class ReadingPassage {
  const ReadingPassage({required this.title, required this.text});

  final String title;
  final String text;
}

const int kReadingDefaultLevel = 1;

const Map<int, List<ReadingPassage>> kReadingPassagesByLevel = {
  1: [
    ReadingPassage(
      title: 'My Classroom Day',
      text:
          'Every morning we greet our friends warmly. Our classroom is bright and very neat. The teacher writes the '
          'spelling words on the board. We read a short interesting story together. During recess, we play fun '
          'games outside. We share our snacks with each other. The bell rings and we go back inside. Our teacher '
          'reads us one last book. We learn new words and paint beautiful pictures. School is always a fun and '
          'happy place. We always help the teacher clean up the desks. Our principal sometimes visits to say a '
          'quick hello. I love seeing all my friends every single morning.',
    ),
    ReadingPassage(
      title: 'The Little Kitten',
      text:
          'A little kitten played in the green garden. She chased colorful butterflies near the flowers. Her owner '
          'called and she ran back fast. Then she drank warm milk and rested quietly. She curled up inside her '
          'soft blue basket. When she woke up, she wanted to play again. She found a small red ball on the floor. '
          'She rolled it around the whole living room. Her owner laughed and gave her a gentle pat. She purred '
          'loudly and fell asleep again. Her small bell jingles when she walks around. She likes to watch the '
          'birds through the window. Sometimes she tries to catch the little flies.',
    ),
    ReadingPassage(
      title: 'A Trip to the Zoo',
      text:
          'We went to the big zoo yesterday afternoon. The tall giraffes were eating fresh green leaves. I saw '
          'funny monkeys swinging from high branches. A large grey elephant was splashing in water. We took many '
          'nice photos of the animals. Next, we visited the scary lions and tigers. They were sleeping under a '
          'large shady tree. A colourful parrot said hello to us loudly. We ate tasty ice cream before going home. '
          'It was the best day ever with my family. The zookeeper fed the hungry penguins some small fish. We '
          'bought some colorful souvenirs at the gift shop. My favorite part was seeing the tall funny ostriches.',
    ),
    ReadingPassage(
      title: 'My New Bicycle',
      text:
          'I got a shiny new red bicycle today. It has a loud silver bell on the handle. I rode it down the bumpy '
          'street quickly. My neighborhood friends watched me go very fast. The cool breeze felt great on my face. '
          'My dad taught me how to use the brakes securely. We practiced riding around the park all morning. I '
          "only fell down once but it didn't hurt. Now I can ride without any training wheels. I love exploring "
          'the streets on my new bike. I made sure to always wear my bright yellow helmet. We rode all the way to '
          'the end of our street. Tomorrow I want to ride it to the local park.',
    ),
    ReadingPassage(
      title: 'Baking a Cake',
      text:
          'We decided to bake a large chocolate cake. I carefully mixed the flour, sugar, and eggs. My mom put the '
          'soft batter in the hot oven. The whole kitchen smelled very sweet and delicious. We prepared some '
          'creamy vanilla icing together. Once the cake cooled, we spread the icing evenly. I placed five '
          'colourful candles on the top. We sang happy birthday to my little brother loudly. It tasted wonderful '
          'with a cold glass of milk. Everyone asked for a second piece because it was great. My dad took a '
          'picture of the beautiful final cake. We made sure to clean up the messy kitchen carefully. It was the '
          'best birthday surprise we ever made.',
    ),
  ],
  2: [
    ReadingPassage(
      title: 'A Day at the Market',
      text:
          'Every Saturday morning, we visit the bustling community market. We cautiously navigate through the '
          'crowded aisles to buy vegetables. The fragrant aroma of ripe cantaloupe and strawberries fills the '
          'air. My father thoughtfully negotiates prices with familiar vendors. Carrying heavy grocery bags makes '
          'us feel exhausted but satisfied. My mother thoroughly inspects exactly which tomatoes are perfectly '
          'ripe. We occasionally purchase deliciously seasoned artisan cheeses from the dairy stall. The energetic '
          'atmosphere is consistently accompanied by cheerful instrumental music. I always eagerly anticipate '
          'tasting the complimentary bakery samples. Unexpectedly meeting friendly neighbors is another wonderful '
          'characteristic of the marketplace. Eventually, we load the trunk with our weekly nutritional '
          'provisions.',
    ),
    ReadingPassage(
      title: 'The Helpful Robot',
      text:
          'A fascinating robot now independently assists nurses in the hospital. It accurately delivers necessary '
          'medicine through the lengthy corridors. The technology utilizes multiple sophisticated cameras to '
          'avoid unexpected obstacles. Medical practitioners genuinely appreciate this remarkable engineering '
          'advancement. Patients consistently find it thoroughly entertaining to watch. Its sleek metallic '
          'exterior reflects the sterile fluorescent lighting perfectly. The automated voice politely requests '
          'clearance when traversing crowded hallways. Efficiently completing numerous deliveries simultaneously '
          'drastically reduces human fatigue. Consequently, healthcare professionals can dedicate substantially '
          'more time to direct patient interaction. Programmable schedules guarantee that critical supplies '
          'arrive precisely when required. Specialized sensors prevent disastrous collisions with fragile medical '
          'equipment.',
    ),
    ReadingPassage(
      title: 'The School Football Match',
      text:
          'Our academy organized a highly anticipated football tournament recently. Enthusiastic spectators '
          'cheered passionately from the fully occupied bleachers. The courageous goalkeeper miraculously blocked '
          'a potentially devastating penalty kick. Ultimately, our resilient athletes celebrated a triumphant '
          'victory together. Strategic coordination enabled our midfielders to flawlessly execute complex '
          'formations. The opposing defenders aggressively challenged every single offensive maneuver. '
          'Fortunately, our determined forwards successfully capitalized on a critical defensive vulnerability. '
          'The deafening roar of the audience echoed throughout the entire stadium. Post-game festivities '
          'included an unexpectedly elaborate fireworks display. Everyone enthusiastically congratulated the '
          'exhausted players afterwards. Developing exceptional teamwork remains a fundamental characteristic of '
          'successful athletics.',
    ),
    ReadingPassage(
      title: 'A Weekend Camping Trip',
      text:
          'We excitedly packed our complicated equipment for the wilderness excursion. Pitching the enormous '
          'canvas tent required considerable collaborative effort. Surrounded by picturesque scenery, we '
          'immediately gathered combustible firewood. The temperature plummeted dramatically when evening finally '
          'approached. Nevertheless, roasting marshmallows created a wonderfully memorable experience. The '
          'nocturnal symphony of crickets provided miraculously peaceful background acoustics. Waking up to '
          'magnificent mountainous panoramas felt truly extraordinary. We courageously embarked upon a remarkably '
          'challenging hiking expedition subsequently. Discovering an undiscovered cascading waterfall was the '
          'absolute highlight of the afternoon. Cautiously navigating the slippery terrain tested our physical '
          'endurance completely. Reconnecting with nature successfully eliminated our accumulated psychological '
          'stress.',
    ),
    ReadingPassage(
      title: 'Learning to Play Guitar',
      text:
          'I enthusiastically began practicing acoustic guitar several months ago. Initially, establishing the '
          'correct finger placement felt incredibly awkward. Memorizing specific chord progressions demanded '
          'extraordinary patience and determination. Gradually, the previously frustrating melodies became much '
          'more automatic. My instructor emphasizes the paramount importance of consistent rhythmic '
          'interpretation. Developing adequate calluses eliminated the initially excruciating physical '
          'discomfort. I persistently struggle with seamlessly transitioning between complicated minor chords. '
          'Nonetheless, successfully performing an entire composition generates profound psychological '
          'satisfaction. Analyzing classical masterpieces provides tremendous inspiration for my continuing '
          'education. Experimenting with unconventional strumming techniques encourages spontaneous creative '
          'expression. I occasionally participate in collaborative improvisational sessions with fellow '
          'musicians.',
    ),
  ],
  3: [
    ReadingPassage(
      title: 'Ocean Wonders',
      text:
          'The vast ocean constitutes an extraordinarily complex and enigmatic ecosystem encompassing unparalleled '
          'biodiversity. Oceanographers continually investigate the unfathomable depths, occasionally encountering '
          'bioluminescent phenomena. Surprisingly resilient microorganisms thrive in extreme environments adjacent '
          'to hydrothermal vents. Nevertheless, fragile coral reefs remain increasingly susceptible to detrimental '
          'consequences of anthropogenic negligence. Furthermore, the systematic acidification of seawater '
          'jeopardizes the intricate hierarchy of the marine food web. Simultaneously, unprecedented plastic '
          'accumulation dramatically threatens the viability of migratory aquatic species. Phytoplankton '
          'populations essentially regulate the indispensable oxygen production sustaining global atmospheric '
          'equilibrium. Submarine topography features spectacular geographical formations eclipsing terrestrial '
          'mountain ranges magnitude. Unregulated commercial dredging irreparably damages prehistoric geological '
          'structures spanning countless millennia. Consequently, establishing comprehensive marine sanctuaries '
          'represents a fundamentally critical ecological prerogative.',
    ),
    ReadingPassage(
      title: 'The Power of Habits',
      text:
          'Psychological literature consistently highlights the profound significance of unconscious repetitive '
          'behavior. Fundamentally, establishing beneficial routines requires circumventing ingrained neurological '
          'pathways. Procrastination frequently manifests as an involuntary psychological defense mechanism '
          'against perceived inadequacy. Overcoming such detrimental tendencies necessitates establishing '
          'deliberately constructed environmental cues. For instance, intentionally eliminating omnipresent '
          'distractions effectively counteracts our inherent susceptibility to interruptions. Consistency is '
          'mathematically advantageous, as exponential compounding predictably magnifies seemingly '
          'inconsequential daily actions. Furthermore, cultivating an attitude of unyielding perseverance '
          'inevitably reinforces the underlying cognitive architecture. Individuals who systematically analyze '
          'their habitual triggers ostensibly achieve more sustainable self-discipline. Neuroplasticity ensures '
          'that continuously modifying behavioral expressions fundamentally alters synaptic structural '
          'connectivity. However, attempting simultaneous multidimensional transformations frequently '
          'precipitates catastrophic psychological fatigue.',
    ),
    ReadingPassage(
      title: 'Artificial Intelligence in Medicine',
      text:
          'The ubiquitous integration of artificial intelligence is irrevocably reshaping contemporary '
          'technological infrastructures. Sophisticated neural networks autonomously process incomprehensible '
          'volumes of heterogeneous data with terrifying efficiency. Algorithmic bias, unfortunately, remains a '
          'particularly insidious concern requiring meticulous mitigation strategies. Consequently, technologists '
          'must prioritize ethical considerations while simultaneously pursuing unprecedented computational '
          'innovation. The implementation of natural language processing facilitates remarkably intuitive '
          'human-computer interaction paradigms. Moreover, autonomous vehicular navigation exemplifies the '
          'extraordinary potential of continuous real-time spatial analysis. However, widespread automation '
          'inevitably provokes legitimate socioeconomic anxieties regarding imminent widespread occupational '
          'displacement. The symbiotic relationship between human intuition and machine reliability must be '
          'carefully calibrated. Ultimately, establishing robust legislative frameworks will dictate the '
          'trajectory of this unprecedented technological revolution. Medical diagnostic applications currently '
          'demonstrate unparalleled capability identifying microscopic pathological abnormalities.',
    ),
    ReadingPassage(
      title: 'The Architecture of Ancient Rome',
      text:
          'Classical antiquity provided an indispensable architectural vernacular that continually influences '
          'contemporary structural engineering. The ingenious utilization of durable concrete empowered the '
          'Romans to construct breathtakingly voluminous amphitheaters. Furthermore, subterranean aqueduct '
          'networks brilliantly exemplified their unparalleled mastery of utilitarian hydrodynamics. The '
          'ubiquitous hemispherical dome ingeniously distributed tremendous gravitational stress with impeccable '
          'mathematical precision. Similarly, the meticulous integration of aesthetic symmetry with utilitarian '
          'pragmatism characterized their monumental basilicas. Today, modern architects frequently draw '
          'inspiration from these remarkably sophisticated geometrical proportions. Preserving such irreplaceable '
          'archaeological heritage necessitates employing exceptionally specialized restorative techniques. These '
          'surviving edifices eloquently testify to the profound ingenuity of ancient civilization. Unequivocally, '
          'the legacy of Roman ingenuity remains permanently etched into the consciousness of Western '
          'civilization. Their architectural vocabulary perpetually informs contemporary ubiquitous institutional '
          'monuments.',
    ),
    ReadingPassage(
      title: 'Sustainable Urban Planning',
      text:
          'Accelerating metropolitan expansion inextricably demands the adoption of comprehensively sustainable '
          'urban planning methodologies. Planners must intricately balance burgeoning demographic requirements '
          'against increasingly perilous ecological constraints. Integrating decentralized renewable energy grids '
          'substantially mitigates reliance on deleterious fossil fuel consumption. Furthermore, encouraging '
          'non-motorized transportation necessitates developing meticulously interconnected pedestrian and '
          'cycling infrastructure. Innovative municipal waste management systems prioritize comprehensive '
          'subterranean recycling over traditional landfill accumulation. Cultivating expansive biodiversity '
          'corridors is absolutely indispensable for preserving indigenous flora within concrete environments. '
          'Consequently, implementing stringent architectural regulations ensures the ubiquitous construction of '
          'exceptionally energy-efficient skyscrapers. Engaging marginalized demographics in these bureaucratic '
          'processes guarantees equitably distributed environmental benefits. Conclusively, achieving authentic '
          'metropolitan sustainability requires an unprecedented synthesis of political willpower and '
          'technological ingenuity. This interdisciplinary collaborative endeavor remains ostensibly the most '
          'consequential challenge confronting modern humanity.',
    ),
  ],
};
