/// Настройки Agora для аудиозвонков тройки.
///
/// App ID — из консоли Agora (console.agora.io → проект → App ID).
const String kAgoraAppId = 'd3526b7dcaa04e358c8d638f5eba9beb';

/// App Certificate (Primary Certificate) — если у проекта включён App
/// Certificate (звонок падал с errInvalidToken). Возьмите в консоли Agora:
/// проект → раздел App Certificate → Primary Certificate.
///
/// Если App Certificate у проекта ОТКЛЮЧЁН — оставьте пустым, токен не нужен.
///
/// Внимание: сертификат — секрет; здесь он встроен в приложение (упрощение для
/// небольшой частной группы). Позже безопаснее выдавать токен с сервера.
const String kAgoraAppCertificate = '';
