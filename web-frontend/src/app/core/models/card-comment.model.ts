/** Одно сообщение в истории комментариев карточки опоры (поле pole.card_comment как JSON-массив). */
export interface CardCommentMessage {
  id?: string;
  text: string;
  /** ISO 8601 UTC */
  at?: string;
  user_id?: number;
  /** Отображаемое имя (ФИО или логин) */
  user_name?: string;
}
