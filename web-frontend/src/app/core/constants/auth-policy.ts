/** Должно совпадать с backend/app/core/password_policy.py и Flutter AppConfig. */
export const MIN_PASSWORD_LENGTH = 6;
export const MAX_PASSWORD_LENGTH = 128;

export const MIN_PASSWORD_LENGTH_MSG = `Пароль должен содержать не менее ${MIN_PASSWORD_LENGTH} символов`;

export function isValidNewPassword(password: string | null | undefined): boolean {
  const p = (password ?? '').trim();
  return p.length >= MIN_PASSWORD_LENGTH && p.length <= MAX_PASSWORD_LENGTH;
}
