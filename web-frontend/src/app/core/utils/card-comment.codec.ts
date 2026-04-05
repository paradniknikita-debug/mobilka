import { CardCommentMessage } from '../models/card-comment.model';
import { User } from '../models/user.model';

function randomId(): string {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) {
    return crypto.randomUUID();
  }
  return `m-${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;
}

/** Разбор: JSON-массив, объект { messages }, или устаревшая одна строка текста. */
export function parseCardCommentMessages(raw: string | null | undefined): CardCommentMessage[] {
  if (!raw?.trim()) {
    return [];
  }
  const s = raw.trim();
  if (s.startsWith('[') || s.startsWith('{')) {
    try {
      const j = JSON.parse(s) as unknown;
      const arr: unknown[] | null = Array.isArray(j)
        ? j
        : j && typeof j === 'object' && j !== null && Array.isArray((j as { messages?: unknown }).messages)
          ? (j as { messages: unknown[] }).messages
          : null;
      if (arr) {
        const out: CardCommentMessage[] = arr
          .filter((x): x is Record<string, unknown> => !!x && typeof x === 'object')
          .map((x) => {
            const text =
              typeof x['text'] === 'string' ? (x['text'] as string).trim() : '';
            return {
              id: typeof x['id'] === 'string' ? (x['id'] as string) : randomId(),
              text,
              at: typeof x['at'] === 'string' ? (x['at'] as string) : '',
              user_id: typeof x['user_id'] === 'number' ? (x['user_id'] as number) : undefined,
              user_name: typeof x['user_name'] === 'string' ? (x['user_name'] as string) : ''
            };
          })
          .filter((m) => m.text.length > 0);
        out.sort((a, b) => (a.at || '').localeCompare(b.at || ''));
        return out;
      }
    } catch {
      /* legacy plain text */
    }
  }
  return [
    {
      id: randomId(),
      text: s,
      at: '',
      user_name: ''
    }
  ];
}

export function serializeCardCommentMessages(messages: CardCommentMessage[]): string | undefined {
  if (!messages.length) {
    return undefined;
  }
  return JSON.stringify(messages);
}

/** Дата/время для подписи сбоку (локаль ru-RU). */
export function formatCardCommentDateTime(at?: string): string {
  if (!at?.trim()) {
    return '—';
  }
  try {
    const d = new Date(at);
    if (isNaN(d.getTime())) {
      return at;
    }
    return d.toLocaleString('ru-RU', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  } catch {
    return at;
  }
}

export function appendCardCommentMessage(
  messages: CardCommentMessage[],
  text: string,
  user: User
): CardCommentMessage[] {
  const t = text.trim();
  if (!t) {
    return messages;
  }
  const at = new Date().toISOString();
  const next: CardCommentMessage = {
    id: randomId(),
    text: t,
    at,
    user_id: user.id,
    user_name: (user.full_name || user.username || '').trim() || user.username
  };
  return [...messages, next];
}
