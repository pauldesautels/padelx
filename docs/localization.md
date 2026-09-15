# PadelX localization

PadelX supports English (`en`) and Mexican Spanish (`es-MX`) with Flutter's
generated ARB localization. A saved local override wins over the device locale;
otherwise any Spanish device locale resolves to `es-MX` and all unsupported
locales fall back to English. The stored values are `system`, `en`, and `es-MX`.

Add user-facing copy to both `lib/l10n/app_en.arb` and
`lib/l10n/app_es_MX.arb`. Use ICU placeholders and plurals with matching metadata
and types in both files. Keep translations concise, neutral, and natural for
Mexico.

Canonical product terms include: Match → Partido, Find Players → Buscar
jugadores, Court → Cancha, Level → Nivel, Preferred side → Lado preferido,
Played With → Jugaste con, Rating → Calificación, Match Chat → Chat del partido,
and Area / Neighborhood → Zona / Colonia.

Never translate persisted or transmitted identifiers: Firestore fields,
callable names, request IDs, report reason codes, statuses, side values, numeric
levels, schema versions, `cityId`, or `areaId`. Legal acceptance always uses the
same `terms-beta-v1`, `privacy-beta-v1`, and `community-beta-v1` identities in
every language.

Firebase Authentication verification and password-reset templates must be
reviewed and configured for English and Spanish in Firebase Console before the
beta. The client already sets the Auth language code; this repository task does
not change provider templates or Console configuration.

Localized legal routes are `/es-MX/privacy`, `/es-MX/terms`,
`/es-MX/community-guidelines`, and `/es-MX/account-deletion`. Their Spanish
copy remains subject to the legal review checklist.
