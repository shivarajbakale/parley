import { describe, expect, it } from 'vitest';

import { isTerminal, paragraphAt, terminalInput } from '../terminal-input';

/** The value with `|` marking the caret, as the helper would report it. */
function at(screen: string) {
  const caret = screen.indexOf('|');
  return { value: screen.replace('|', ''), caret };
}

const RULE = '─'.repeat(40);

describe('isTerminal', () => {
  it('knows the common terminals and nothing else', () => {
    expect(isTerminal('com.googlecode.iterm2')).toBe(true);
    expect(isTerminal('com.apple.Terminal')).toBe(true);
    expect(isTerminal('com.mitchellh.ghostty')).toBe(true);
    expect(isTerminal('com.apple.TextEdit')).toBe(false);
    expect(isTerminal(null)).toBe(false);
  });
});

describe('terminalInput', () => {
  it('takes only what is typed after a Claude Code prompt, not the scrollback', () => {
    const { value, caret } = at(
      `earlier output\n$ npm test\nall green\n${RULE}\n❯ make this shorter please|\n${RULE}\n  ⏵⏵ auto mode on`
    );
    expect(terminalInput(value, caret)).toEqual({ text: 'make this shorter please', erase: 24 });
  });

  it('reads a prompt drawn with a non-breaking space', () => {
    const { value, caret } = at(`${RULE}\n❯\u00a0tidy this up|\n${RULE}`);
    expect(terminalInput(value, caret)).toEqual({ text: 'tidy this up', erase: 12 });
  });

  it('joins a wrapped input back into one line, and erases every cell of it', () => {
    const { value, caret } = at(`${RULE}\n❯ first half of a long\n  request that wrapped|\n${RULE}`);
    const input = terminalInput(value, caret);
    expect(input?.text).toBe('first half of a long request that wrapped');
    // The raw span from the prompt to the caret, newline and indent included:
    // erasing too much stops harmlessly at the start of the input.
    expect(input?.erase).toBe('first half of a long\n  request that wrapped'.length);
  });

  it('takes the command after a shell prompt', () => {
    const { value, caret } = at('Last login: today\nshiv@mac parley % git comit -m wip|');
    expect(terminalInput(value, caret)).toEqual({ text: 'git comit -m wip', erase: 16 });
  });

  it('skips the directory and branch in oh-my-zsh\'s default prompt', () => {
    const home = at('➜  ~ echo hello wrld|');
    expect(terminalInput(home.value, home.caret)).toEqual({ text: 'echo hello wrld', erase: 15 });
    const repo = at('➜  parley git:(main) ✗ git comit|');
    expect(terminalInput(repo.value, repo.caret)?.text).toBe('git comit');
  });

  it('uses the last prompt marker on the line, so a path with one in it is not the input', () => {
    const { value, caret } = at('~/a$b $ echo hi|');
    expect(terminalInput(value, caret)?.text).toBe('echo hi');
  });

  it('counts a character the user sees as one backspace', () => {
    const { value, caret } = at('❯ ship it 👍🏽|');
    expect(terminalInput(value, caret)?.erase).toBe('ship it '.length + 1);
  });

  it('leaves text after the caret alone', () => {
    const { value, caret } = at('❯ fix this| and not this');
    expect(terminalInput(value, caret)).toEqual({ text: 'fix this', erase: 8 });
  });

  it('falls back to the caret line when no prompt is recognised', () => {
    const { value, caret } = at('output\nsome input|');
    expect(terminalInput(value, caret)).toEqual({ text: 'some input', erase: 10 });
  });

  it('never reaches above a rule line for the input', () => {
    const { value, caret } = at(`$ old command\n${RULE}\nno marker here|`);
    expect(terminalInput(value, caret)?.text).toBe('no marker here');
  });

  it('is null when nothing is typed', () => {
    const { value, caret } = at(`${RULE}\n❯ |\n${RULE}`);
    expect(terminalInput(value, caret)).toBeNull();
  });
});

describe('paragraphAt', () => {
  it('is the line the caret is on, trimmed', () => {
    const { value, caret } = at('Title\n\nFirst para|graph here.  \nSecond one.');
    const range = paragraphAt(value, caret);
    expect(range).toEqual({ location: 7, length: 'First paragraph here.'.length });
    expect(value.slice(range!.location, range!.location + range!.length)).toBe(
      'First paragraph here.'
    );
  });

  it('works at the very start and end of the value', () => {
    expect(paragraphAt('only line', 0)).toEqual({ location: 0, length: 9 });
    expect(paragraphAt('a\nlast', 6)).toEqual({ location: 2, length: 4 });
  });

  it('is null on an empty line', () => {
    const { value, caret } = at('one\n|\ntwo');
    expect(paragraphAt(value, caret)).toBeNull();
  });
});
