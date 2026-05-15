/** Элемент JSON в поле pole.card_comment_attachment */
export interface PoleCardAttachmentItem {
  t: string;
  url: string;
  thumbnail?: string;
  thumbnail_url?: string;
  filename?: string;
  /** Имя файла с устройства пользователя (для отображения и скачивания); ключ в URL остаётся uuid. */
  original_filename?: string | null;
  added_at?: string;
  added_by_id?: number;
  added_by_name?: string;
}
