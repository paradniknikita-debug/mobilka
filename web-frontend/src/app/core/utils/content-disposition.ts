/** Имя файла из заголовка Content-Disposition (filename / filename* UTF-8). */
export function filenameFromContentDisposition(header: string | null | undefined): string | null {
  if (!header || !header.trim()) return null;
  const star = /filename\*\s*=\s*UTF-8''([^;\s]+)/i.exec(header);
  if (star?.[1]) {
    try {
      return decodeURIComponent(star[1].replace(/\+/g, ' '));
    } catch {
      return star[1];
    }
  }
  const plain = /filename\s*=\s*"([^"]+)"/i.exec(header) || /filename\s*=\s*([^;\s]+)/i.exec(header);
  if (plain?.[1]) {
    return plain[1].replace(/^["']|["']$/g, '');
  }
  return null;
}
