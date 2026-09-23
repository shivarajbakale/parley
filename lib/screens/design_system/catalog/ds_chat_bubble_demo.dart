import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/catalog/story.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

final dsChatBubbleDemo = DSComponentDemo(
  name: 'DSChatBubble',
  summary: 'One turn in a thread, on the side of whoever said it.',
  stories: [
    DSStory(
      title: 'A run of turns',
      note:
          'Three messages in ten seconds are one utterance. The run keeps '
          'the corner nearest its speaker tight all the way down and '
          'closes the gap between its turns to a hairline, so it reads as '
          'one block with one time on it rather than as three lozenges '
          'dating the same moment three times. The side and the fill say '
          'who is speaking before a word is read.',
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DSChatBubble(
            author: DSChatAuthor.them,
            text: 'The delivery slot moved to Thursday.',
            group: DSChatGroup.first,
          ),
          SizedBox(height: DSChatBubble.gapBefore(context, DSChatGroup.middle)),
          const DSChatBubble(
            author: DSChatAuthor.them,
            text: 'Same window — 9 to 11.',
            group: DSChatGroup.middle,
          ),
          SizedBox(height: DSChatBubble.gapBefore(context, DSChatGroup.last)),
          const DSChatBubble(
            author: DSChatAuthor.them,
            text: 'Let me know if that is no good.',
            group: DSChatGroup.last,
            timeLabel: '09:41',
          ),
          SizedBox(height: DSChatBubble.gapBefore(context, DSChatGroup.alone)),
          const DSChatBubble(
            author: DSChatAuthor.me,
            text: 'That works.',
            timeLabel: '09:42',
          ),
        ],
      ),
    ),
    DSStory(
      title: 'The four states',
      note:
          'Sending is dimmed rather than spinning, streaming carries a '
          'caret and no animation so a golden of it is deterministic, and '
          'failed is the only one that takes a tone and offers a way back.',
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DSChatBubble(
            author: DSChatAuthor.me,
            text: 'On my way.',
            status: DSChatStatus.sending,
          ),
          context.design.space.verticalSm,
          const DSChatBubble(
            author: DSChatAuthor.them,
            text: 'Checking the schedule now',
            status: DSChatStatus.streaming,
          ),
          context.design.space.verticalSm,
          DSChatBubble(
            author: DSChatAuthor.me,
            text: 'Send it to the old address.',
            status: DSChatStatus.failed,
            onRetry: () {},
          ),
        ],
      ),
    ),
  ],
);
