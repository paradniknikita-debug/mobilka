import { User } from '../models/user.model';

export const ROLE_ADMIN = 'admin';
export const ROLE_PASSPORT_CLERK = 'passport_clerk';
export const ROLE_FIELD_ENGINEER = 'field_engineer';

const LEGACY_MAP: Record<string, string> = {
  admin: ROLE_ADMIN,
  dispatcher: ROLE_PASSPORT_CLERK,
  passport_clerk: ROLE_PASSPORT_CLERK,
  engineer: ROLE_FIELD_ENGINEER,
  field_engineer: ROLE_FIELD_ENGINEER,
};

export function normalizeRole(role: string | undefined | null): string {
  const key = (role || '').trim().toLowerCase();
  if (key in LEGACY_MAP) {
    return LEGACY_MAP[key];
  }
  if (key === ROLE_ADMIN || key === ROLE_PASSPORT_CLERK || key === ROLE_FIELD_ENGINEER) {
    return key;
  }
  return ROLE_FIELD_ENGINEER;
}

export function canUseExports(user: User | null | undefined): boolean {
  if (!user) {
    return false;
  }
  if (user.is_superuser) {
    return true;
  }
  const r = normalizeRole(user.role);
  return r === ROLE_ADMIN || r === ROLE_PASSPORT_CLERK;
}

/** Доступ к разделу «Паспортизация» (все штатные роли, включая инженера-обходчика — только просмотр). */
export function canAccessPassportization(user: User | null | undefined): boolean {
  if (!user) {
    return false;
  }
  if (user.is_superuser) {
    return true;
  }
  const r = normalizeRole(user.role);
  return r === ROLE_ADMIN || r === ROLE_PASSPORT_CLERK || r === ROLE_FIELD_ENGINEER;
}

export function isAdminUser(user: User | null | undefined): boolean {
  if (!user) {
    return false;
  }
  if (user.is_superuser) {
    return true;
  }
  return normalizeRole(user.role) === ROLE_ADMIN;
}

export function canManageCatalog(user: User | null | undefined): boolean {
  return canUseExports(user);
}

export const ROLE_LABELS: Record<string, string> = {
  [ROLE_ADMIN]: 'Администратор',
  [ROLE_PASSPORT_CLERK]: 'Паспортист',
  [ROLE_FIELD_ENGINEER]: 'Инженер-обходчик',
};
