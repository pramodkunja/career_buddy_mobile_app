/// The two story pools `storyLevel` offers (`templates/activities/modules/listening.html:160-163`)
/// and the 6 fixed stories each cycles through
/// (`static/activities/js/listening.js:10-87`'s `stories` object — read
/// verbatim, not reworded, generated, or reordered). Only the English
/// `text`/`title` are ported — the `titleVN`/`titleRU` cosmetic
/// translations are the same kind of decorative-only overlay already
/// skipped for Speaking/Writing.
///
/// Unlike both Speaking (no fixed initial topic — hardcoded value is never
/// a pool member) and Writing (fixed initial topic that IS the pool's
/// first entry), Listening has **no persistent initial story at all**:
/// `listening.js` calls `pickStory()` unconditionally at the very end of
/// its setup (line 671), which immediately overwrites the `stories.beginner[0]`
/// placeholder with a **random** pick from the full pool — confirmed by
/// reading the load sequence, not assumed from the other two modules.
class ListeningStory {
  const ListeningStory({required this.title, required this.text});

  final String title;
  final String text;
}

const String kListeningDefaultLevel = 'beginner';

const Map<String, List<ListeningStory>> kListeningStoriesByLevel = {
  'beginner': [
    ListeningStory(
      title: 'The Missed Bus Morning',
      text:
          'Riya woke up late because her alarm did not ring. She rushed to get ready for school and ran to the bus '
          'stop. The bus had already left, so she called her father for help. He dropped her at school just before '
          'class started. Riya promised to check her alarm every night after that.',
    ),
    ListeningStory(
      title: 'A Rainy School Day',
      text:
          'Heavy rain started while Arjun was walking to school. He opened his umbrella and shared it with his '
          'friend. Their shoes were wet, but they still reached class on time. The teacher asked everyone to dry '
          'their bags and sit quietly. During lunch, they watched the rain and talked about their favorite weather.',
    ),
    ListeningStory(
      title: 'The Lost Key',
      text:
          'Mother could not find her house key anywhere. She looked in her bag and under the sofa. Finally, little '
          'Rahul pointed at the table near the door. The key was hiding under a magazine all along. They laughed '
          'and quickly left for the market before it closed.',
    ),
    ListeningStory(
      title: 'A New Pet',
      text:
          'Samir brought home a small brown puppy yesterday. The puppy was very playful and ran around the living '
          'room. It chased a red ball and fell asleep under a chair. Samir decided to name the puppy Bruno. They '
          'are already the best of friends.',
    ),
    ListeningStory(
      title: 'Painting The Fence',
      text:
          'My grandfather needed help painting his old wooden fence. My sister and I wore our old clothes and '
          'grabbed some brushes. We painted the whole fence bright white. It took us three hours to finish the '
          'job. Grandfather thanked us by baking our favorite chocolate cookies.',
    ),
    ListeningStory(
      title: 'A Day at the Park',
      text:
          'The sun was shining brightly, so we went to the park. Children were playing on the swings and flying '
          'colorful kites. We spread a blanket on the grass and ate some sandwiches. Later, we fed bread pieces to '
          'the ducks in the pond. It was a very relaxing and happy afternoon.',
    ),
  ],
  'intermediate': [
    ListeningStory(
      title: 'The Team Project Delay',
      text:
          'Our college team was building a presentation for a technical event. Two members fell sick, so tasks '
          'were delayed for several days. We reorganized responsibilities and held short check-ins every evening. '
          'I focused on data analysis while my friend handled slide design. We submitted the project on time and '
          'received positive feedback from the judges.',
    ),
    ListeningStory(
      title: 'A Helpful Neighbor',
      text:
          'Last month, our neighborhood faced a sudden power cut during a storm. An elderly couple nearby needed '
          'support because their phone battery was low. My neighbor shared a backup light and helped them contact '
          'their family. We all stayed together until electricity returned. That night reminded me how important '
          'community support can be.',
    ),
    ListeningStory(
      title: 'The Surprise Birthday Party',
      text:
          'We planned a secret birthday party for my best friend Sarah. I invited all her close friends and '
          'ordered a large chocolate cake. We hid in her darkened living room until she opened the front door. '
          'Everyone yelled surprise when she walked in, completely shocking her. The evening was filled with '
          'laughter, music, and wonderful memories.',
    ),
    ListeningStory(
      title: 'Learning to Swim',
      text:
          'I was always afraid of deep water until I joined swimming classes. My instructor was very patient and '
          'taught me breathing techniques first. For the first two weeks, I only practiced floating near the '
          'shallow edge. Gradually, I gained confidence and learned different swimming strokes. Now, swimming is '
          'my favorite weekend exercise.',
    ),
    ListeningStory(
      title: 'The Forgotten Homework',
      text:
          'I organized my backpack carefully but entirely forgot my math assignment on my desk. When the teacher '
          'asked us to submit our work, I panicked completely. I honestly explained the situation and promised to '
          'bring it the next morning. Fortunately, she appreciated my honesty and gave me an extension. I learned '
          'to double-check my bag every single night.',
    ),
    ListeningStory(
      title: 'A Visit to the Museum',
      text:
          'Our history teacher organized a fascinating trip to the national museum. We observed ancient artifacts '
          'and learned about ancient civilizations from an expert guide. My favorite section displayed historical '
          'armors securely kept behind thick glass cases. We took many notes for our upcoming school project. The '
          'interactive exhibits made learning history incredibly enjoyable and memorable.',
    ),
  ],
};
