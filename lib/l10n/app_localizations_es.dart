// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get language => 'Idioma';

  @override
  String get useDeviceLanguage => 'Usar idioma del dispositivo';

  @override
  String get english => 'English';

  @override
  String get spanishMexico => 'Español (México)';

  @override
  String get cancel => 'Cancelar';

  @override
  String get done => 'Listo';

  @override
  String get retry => 'Reintentar';

  @override
  String get loading => 'Cargando';

  @override
  String get somethingWentWrong => 'Algo salió mal';

  @override
  String get settings => 'Configuración';

  @override
  String get authHeadline => 'Encuentra tu próximo partido.';

  @override
  String get authSubtitle => 'Juega más pádel con jugadores cerca de ti.';

  @override
  String get continueWithEmail => 'Continuar con correo';

  @override
  String get termsOfUse => 'Términos de uso';

  @override
  String get privacyPolicy => 'Aviso de privacidad';

  @override
  String get chooseLanguage => 'Elegir idioma';

  @override
  String get languageSelectorTooltip => 'Cambiar idioma';

  @override
  String get languageSelectorSemantics => 'Cambiar el idioma de la aplicación';

  @override
  String welcomePlayer(String name) {
    return 'Te damos la bienvenida, $name';
  }

  @override
  String matchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count partidos',
      one: '1 partido',
      zero: 'No hay partidos',
    );
    return '$_temp0';
  }

  @override
  String get tryAgain => 'Volver a intentar';

  @override
  String get tryAgainLower => 'Volver a intentar';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get logOut => 'Cerrar sesión';

  @override
  String get continueLabel => 'Continuar';

  @override
  String get back => 'Atrás';

  @override
  String get close => 'Cerrar';

  @override
  String get remove => 'Eliminar';

  @override
  String get saveProfile => 'Guardar perfil';

  @override
  String get email => 'Correo electrónico';

  @override
  String get password => 'Contraseña';

  @override
  String get enterEmail => 'Ingresa tu correo electrónico';

  @override
  String get forgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get resetPassword => 'Restablecer contraseña';

  @override
  String get sendResetEmail => 'Enviar correo de restablecimiento';

  @override
  String get signInOrCreate => 'Inicia sesión o crea tu cuenta.';

  @override
  String get verifyEmail => 'Verifica tu correo electrónico';

  @override
  String get openVerificationLink =>
      'Abre el enlace de ese mensaje y luego regresa aquí para continuar.';

  @override
  String get beforeContinuing => 'Antes de continuar';

  @override
  String get ageConfirmation => 'Confirmo que tengo 18 años o más.';

  @override
  String get ageRequired =>
      'Para continuar, confirma que tienes al menos 18 años.';

  @override
  String get ageEligibility => 'Elegibilidad para mayores de 18';

  @override
  String get ageCheckFailed => 'No se pudo verificar la elegibilidad de edad.';

  @override
  String get adultOnly => 'PadelX es para personas mayores de 18 años.';

  @override
  String get legalAcknowledgement => 'Aceptación legal';

  @override
  String get legalReviewIntro =>
      'Revisa los Términos de uso y el Aviso de privacidad de la beta cerrada de PadelX.';

  @override
  String get legalLoadFailed => 'No se pudo consultar el estado de aceptación.';

  @override
  String get matches => 'Partidos';

  @override
  String get discover => 'Descubrir';

  @override
  String get myMatches => 'Mis partidos';

  @override
  String get upcoming => 'Próximos';

  @override
  String get past => 'Anteriores';

  @override
  String get create => 'Crear';

  @override
  String get createMatch => 'Crear partido';

  @override
  String get createAMatch => 'Crear partido';

  @override
  String get editMatch => 'Editar partido';

  @override
  String get matchDetails => 'Detalles del partido';

  @override
  String get findMatch => 'Buscar partidos';

  @override
  String get findMatchesHomeDescription =>
      'Explora por tu cuenta los partidos disponibles.';

  @override
  String get quickMatchHomeDescription => 'PadelX encuentra el partido por ti.';

  @override
  String get createMatchHomeDescription => 'Organiza tu propio partido.';

  @override
  String get reliabilityNewPlayer => 'Confiabilidad: jugador nuevo';

  @override
  String reliabilityPercent(int percent) {
    return 'Confiabilidad: $percent%';
  }

  @override
  String get findPlayers => 'Buscar jugadores';

  @override
  String get players => 'Jugadores';

  @override
  String get messages => 'Mensajes';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get profile => 'Perfil';

  @override
  String get editProfile => 'Editar perfil';

  @override
  String get playerProfile => 'Perfil del jugador';

  @override
  String get friends => 'Amigos';

  @override
  String get friend => 'Amigo';

  @override
  String get addFriend => 'Agregar amigo';

  @override
  String get requested => 'Solicitud enviada';

  @override
  String get accept => 'Aceptar';

  @override
  String get decline => 'Rechazar';

  @override
  String get unfriend => 'Eliminar amistad';

  @override
  String get block => 'Bloquear';

  @override
  String get unblock => 'Desbloquear';

  @override
  String get reportPlayer => 'Reportar jugador';

  @override
  String get reportMessage => 'Reportar mensaje';

  @override
  String get reportMatch => 'Reportar partido';

  @override
  String get reportSubmitted => 'Reporte enviado';

  @override
  String get matchChat => 'Chat del partido';

  @override
  String get message => 'Mensaje';

  @override
  String get sendMessage => 'Enviar mensaje';

  @override
  String get refreshMessages => 'Actualizar mensajes';

  @override
  String get noMessages => '¡Aún no hay mensajes! Di hola.';

  @override
  String get noConversations => 'Aún no hay conversaciones.';

  @override
  String get messagesUnavailable =>
      'Los mensajes no están disponibles por el momento.';

  @override
  String get couldNotSendMessage => 'No se pudo enviar este mensaje.';

  @override
  String get loadOlder => 'Cargar anteriores';

  @override
  String get loadingEllipsis => 'Cargando…';

  @override
  String get markRead => 'Marcar como leída';

  @override
  String get markAsRead => 'Marcar como leída';

  @override
  String get markAllRead => 'Marcar todas como leídas';

  @override
  String get noNotifications => 'Aún no hay notificaciones';

  @override
  String get viewMatch => 'Ver partido';

  @override
  String get dismiss => 'Descartar';

  @override
  String get level => 'Nivel';

  @override
  String get playerLevel => 'Nivel de jugador';

  @override
  String get chooseLevel => 'Elige un nivel';

  @override
  String get preferredSide => 'Lado preferido';

  @override
  String get areaOptional => 'Zona / Colonia (opcional)';

  @override
  String get anyArea => 'Cualquier zona';

  @override
  String get searchAreas => 'Buscar zonas';

  @override
  String get city => 'Ciudad';

  @override
  String get country => 'País';

  @override
  String get countryCode => 'Código de país';

  @override
  String get changeCity => 'Cambiar ciudad';

  @override
  String get searchCitiesOnly => 'Buscar solo ciudades';

  @override
  String get displayName => 'Nombre visible';

  @override
  String get shortBio => 'Descripción breve (opcional)';

  @override
  String get discoverability => 'Permitir que otros jugadores me encuentren';

  @override
  String get preferredLocation =>
      'Ubicación preferida para aparecer en búsquedas';

  @override
  String get profileUpdated => 'Perfil actualizado.';

  @override
  String get helpSafety => 'Ayuda y seguridad';

  @override
  String get supportSafety => 'Soporte y seguridad';

  @override
  String get communityGuidelines => 'Normas de la comunidad';

  @override
  String get blockedPlayers => 'Jugadores bloqueados';

  @override
  String get contactSupport => 'Contactar al soporte de PadelX';

  @override
  String get deleteAccount => 'Eliminar cuenta';

  @override
  String get deleteAccountLower => 'Eliminar cuenta';

  @override
  String get account => 'Cuenta';

  @override
  String get safety => 'Seguridad';

  @override
  String get reportingBlockingAge =>
      'Reportes, bloqueos y elegibilidad de edad';

  @override
  String get emergency => 'Emergencia';

  @override
  String get ratingSubmitted => 'Calificación enviada.';

  @override
  String get ratePlayer => 'Calificar jugador';

  @override
  String get ratePlayers => 'Calificar jugadores';

  @override
  String get submitRating => 'Enviar calificación';

  @override
  String get playAgain => 'Jugar de nuevo';

  @override
  String get cancelMatch => 'Cancelar partido';

  @override
  String get leaveMatch => 'Salir del partido';

  @override
  String get matchUnavailable => 'Partido no disponible';

  @override
  String get noMatchesNearby => 'Aún no hay partidos cercanos.';

  @override
  String get matchesUnavailable =>
      'Los partidos no están disponibles por el momento.';

  @override
  String get findingMatches => 'Buscando partidos cercanos…';

  @override
  String get clearFilters => 'Borrar filtros';

  @override
  String get filterMatches => 'Filtrar partidos';

  @override
  String get club => 'Club';

  @override
  String get dateTime => 'Fecha y hora';

  @override
  String get chooseDateTime => 'Elegir fecha y hora';

  @override
  String get totalPlayers => 'Total de jugadores';

  @override
  String get spots => 'Lugares';

  @override
  String get submit => 'Enviar';

  @override
  String get whyReporting => '¿Por qué quieres reportarlo?';

  @override
  String get additionalDetails => 'Detalles adicionales (opcional)';

  @override
  String couldNotOpenPage(String email) {
    return 'No se pudo abrir esta página. Escribe a $email.';
  }

  @override
  String get today => 'Hoy';

  @override
  String get yesterday => 'Ayer';

  @override
  String get player => 'Jugador';

  @override
  String get noMessagesYet => 'Aún no hay mensajes';

  @override
  String unreadMessages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes sin leer',
      one: '1 mensaje sin leer',
    );
    return '$_temp0';
  }

  @override
  String get unread => 'Sin leer';

  @override
  String get read => 'Leída';

  @override
  String get unreadNotification => 'Notificación sin leer';

  @override
  String get timeUnavailable => 'Hora no disponible';

  @override
  String get newJoinRequest => 'Nueva solicitud para unirse';

  @override
  String joinRequestBody(String name, String club) {
    return '$name solicitó unirse a tu partido en $club.';
  }

  @override
  String get requestApproved => 'Solicitud aprobada';

  @override
  String get requestDeclined => 'Solicitud rechazada';

  @override
  String requestApprovedBody(String club) {
    return 'Tu solicitud para unirte al partido en $club fue aprobada.';
  }

  @override
  String requestDeclinedBody(String club) {
    return 'Tu solicitud para unirte al partido en $club fue rechazada.';
  }

  @override
  String get newDirectMessage => 'Nuevo mensaje';

  @override
  String get newDirectMessageBody => 'Tienes un mensaje directo sin leer.';

  @override
  String get newMatchMessage => 'Nuevo mensaje del partido';

  @override
  String get newMatchMessageBody =>
      'Tienes un mensaje sin leer en el chat del partido.';

  @override
  String get newFriendRequest => 'Nueva solicitud de amistad';

  @override
  String friendRequestBody(String name) {
    return '$name te envió una solicitud de amistad.';
  }

  @override
  String get friendRequestAccepted => 'Solicitud de amistad aceptada';

  @override
  String friendAcceptedBody(String name) {
    return '$name aceptó tu solicitud de amistad.';
  }

  @override
  String get playAgainInvite => 'Jugar de nuevo';

  @override
  String playAgainBody(String name) {
    return '$name te invitó a jugar de nuevo.';
  }

  @override
  String get harassmentBullying => 'Acoso o intimidación';

  @override
  String get hateAbuse => 'Odio o contenido abusivo';

  @override
  String get sexualInappropriate => 'Contenido sexual o inapropiado';

  @override
  String get threatsUnsafe => 'Amenazas o conducta insegura';

  @override
  String get spamScam => 'Spam o estafa';

  @override
  String get impersonation => 'Suplantación de identidad';

  @override
  String get other => 'Otro motivo';

  @override
  String reportSubject(String subject) {
    return 'Reportar $subject';
  }

  @override
  String get reportAlreadySubmitted => 'Ya reportaste esto.';

  @override
  String get reportRateLimited =>
      'Enviaste varios reportes recientemente. Inténtalo de nuevo más tarde.';

  @override
  String get reportFailed =>
      'No se pudo enviar el reporte. Inténtalo de nuevo.';

  @override
  String get thanksForSafety => 'Gracias por ayudar a mantener PadelX seguro.';

  @override
  String get blockPlayer => 'Bloquear jugador';

  @override
  String get blockThisPlayer => '¿Bloquear a este jugador?';

  @override
  String get playerBlocked => 'Jugador bloqueado.';

  @override
  String get playerBlockFailed => 'No se pudo bloquear al jugador.';

  @override
  String get sharedMatchBlockExplanation =>
      'El bloqueo impide la búsqueda social y el contacto normales. El acceso a partidos compartidos sigue dependiendo de la participación.';

  @override
  String get friendBlockExplanation =>
      'Se eliminará su amistad y se impedirán la búsqueda social y el contacto normales. El acceso a partidos compartidos sigue dependiendo de la participación.';

  @override
  String get nonFriendBlockExplanation =>
      'Se impedirán la búsqueda social y el contacto normales con este jugador. El acceso a partidos compartidos sigue dependiendo de la participación.';

  @override
  String get approve => 'Aprobar';

  @override
  String get allPlayersRated => 'Todos los jugadores están calificados.';

  @override
  String get areaSuggestionsUnavailable =>
      'Las sugerencias de zona no están disponibles. Puedes elegir Cualquier zona.';

  @override
  String get beFirstMatch => 'Sé la primera persona en organizar un partido.';

  @override
  String get cancelMatchQuestion => '¿Cancelar el partido?';

  @override
  String get checkAccessAgain => 'Volver a verificar el acceso';

  @override
  String get connectionRetry => 'Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get chooseClubTimePlayers =>
      'Elige un club, horario y para quién es el partido.';

  @override
  String get cityOrArea => 'Ciudad o zona';

  @override
  String get citySuggestionsUnavailable =>
      'Las sugerencias de ciudad no están disponibles. Ingresa los datos de tu ciudad; la zona puede quedar vacía.';

  @override
  String get clearLocation => 'Borrar ubicación';

  @override
  String get closeAreaSelector => 'Cerrar selector de zona';

  @override
  String get closeLevelSelector => 'Cerrar selector de nivel';

  @override
  String get clubName => 'Nombre del club';

  @override
  String get clubNameAddress => 'Nombre o dirección del club';

  @override
  String get completed => 'Completados';

  @override
  String get confirmPassword => 'Confirma tu contraseña';

  @override
  String get preservePlayersRequests =>
      'Se conservarán los jugadores confirmados y las solicitudes para unirse.';

  @override
  String get createMatchFailed => 'No se pudo crear el partido.';

  @override
  String get dismissInviteFailed => 'No se pudo descartar esta invitación.';

  @override
  String get loadLocationFailed => 'No se pudo cargar esa ubicación.';

  @override
  String get loadProfileFailed => 'No se pudo cargar tu perfil.';

  @override
  String get markReadFailed => 'No se pudo marcar la notificación como leída.';

  @override
  String get markAllReadFailed =>
      'No se pudieron marcar las notificaciones como leídas.';

  @override
  String get ratingSubmitFailed => 'No se pudo enviar la calificación.';

  @override
  String get accessCheckFailed => 'No se pudo verificar el acceso a la cuenta.';

  @override
  String get editProfileLocation => 'Editar ubicación del perfil';

  @override
  String get enablePushQuestion => '¿Activar notificaciones push?';

  @override
  String get endFriendship => 'Terminar esta amistad y conexión social directa';

  @override
  String get expand100 => 'Ampliar a 100 km';

  @override
  String get findMatchesNear => 'Buscar partidos cerca de';

  @override
  String get findPadelMatches => 'Encuentra partidos de pádel cerca de ti.';

  @override
  String get findPadelPlayers =>
      'Encuentra jugadores de pádel con quienes quieras jugar.';

  @override
  String get playFrequency => '¿Con qué frecuencia juegas?';

  @override
  String get howReportMatch => 'Cómo reportar un partido';

  @override
  String get howReportMessage => 'Cómo reportar un mensaje';

  @override
  String get howReportPlayer => 'Cómo reportar a un jugador';

  @override
  String get isoCountryCode => 'Código de país ISO';

  @override
  String get immediateDanger => 'Peligro inmediato';

  @override
  String get joinRequests => 'Solicitudes para unirse';

  @override
  String get joinGames => 'Únete a partidos que necesitan jugadores.';

  @override
  String get keepMatch => 'Conservar partido';

  @override
  String get loadingPadelX => 'CARGANDO PADELX';

  @override
  String get leaveMatchQuestion => '¿Salir del partido?';

  @override
  String get loadMore => 'Cargar más';

  @override
  String get loadMoreNearby => 'Cargar más partidos cercanos';

  @override
  String get loadOlderMatches => 'Cargar partidos anteriores';

  @override
  String get loadOlderNotifications => 'Cargar notificaciones anteriores';

  @override
  String get loadingJoinRequests => 'Cargando solicitudes para unirse...';

  @override
  String get matchCancelled => 'Partido cancelado.';

  @override
  String get matchDiscovery => 'Búsqueda de partidos';

  @override
  String get matchUpdated => 'Partido actualizado correctamente.';

  @override
  String get notificationEmptyBody =>
      'Aquí aparecerán actualizaciones de partidos, mensajes y actividad social.';

  @override
  String get organizedJoinedMatches =>
      'Partidos que organizas o a los que te uniste.';

  @override
  String get acceptedFriendsMessaging =>
      'Los mensajes están disponibles entre amigos aceptados.';

  @override
  String get moreActions => 'Más acciones';

  @override
  String get moreSafetyActions => 'Más acciones de seguridad';

  @override
  String get needHelp =>
      '¿Necesitas ayuda o quieres reportar un asunto de seguridad?';

  @override
  String get neighborhoodArea => 'Colonia o zona';

  @override
  String get noOtherPlayersRate =>
      'No hay otros jugadores de este partido por calificar.';

  @override
  String get noPendingRequests => 'No hay solicitudes pendientes';

  @override
  String get noRatings => 'Aún no hay calificaciones';

  @override
  String get notNow => 'Ahora no';

  @override
  String get notificationPreferencesFailed =>
      'No se pudieron guardar las preferencias de notificaciones.';

  @override
  String get notificationsUnavailable =>
      'Las notificaciones no están disponibles por el momento.';

  @override
  String get openReportMatchHelp =>
      'Abre Detalles del partido y elige Reportar partido en las acciones de seguridad.';

  @override
  String get openMatches => 'Partidos abiertos';

  @override
  String get openReportPlayerHelp =>
      'Abre el perfil del jugador, toca Más acciones y luego Reportar jugador.';

  @override
  String get pendingRequests => 'Solicitudes pendientes';

  @override
  String get playedWith => 'Personas con quienes jugaste';

  @override
  String get permanentlyDelete =>
      'Eliminar permanentemente tu cuenta de PadelX';

  @override
  String get photoCropHelp =>
      'Las fotos se recortan al centro y se guardan como JPEG de 512×512.';

  @override
  String get unblockedNotice =>
      'Jugador desbloqueado. La amistad no se restaura automáticamente.';

  @override
  String get chooseFutureDate => 'Elige una fecha y hora futuras.';

  @override
  String get policyCategory => 'Categoría de la política';

  @override
  String get pressHoldReport =>
      'Mantén presionado un mensaje de otro jugador y elige Reportar mensaje.';

  @override
  String get preventSocialContact =>
      'Impedir la búsqueda social y el contacto normales';

  @override
  String get pushUpdateFailed =>
      'No se pudo actualizar la configuración de notificaciones push.';

  @override
  String get pushNotifications => 'Notificaciones push';

  @override
  String get pushPermissionCategories =>
      'Permiso push y categorías de notificaciones';

  @override
  String get questionsSafety => 'Preguntas o asuntos de seguridad';

  @override
  String get rateInDetails => 'Calificar en los detalles del partido';

  @override
  String get refreshMatches => 'Actualizar partidos';

  @override
  String get regionOptional => 'Región / Estado / Provincia (opcional)';

  @override
  String get relationshipActions => 'Acciones de relación';

  @override
  String get restrictionEnds => 'La restricción termina';

  @override
  String get reviewUnblock => 'Revisar y desbloquear jugadores';

  @override
  String get safetyExpectations =>
      'Expectativas de seguridad para la beta de PadelX';

  @override
  String get searchClubLocation => 'Buscar club o ubicación';

  @override
  String get searchCityArea => 'Buscar una ciudad o zona';

  @override
  String get searchPadelClub => 'Buscar un club de pádel';

  @override
  String get seeAll => 'Ver todo';

  @override
  String get sendPrivateReport => 'Enviar un reporte de seguridad privado';

  @override
  String get setUpGame => 'Configura tu partido';

  @override
  String get sharedMatchRatings => 'Calificaciones del partido compartido';

  @override
  String get stay => 'Quedarme';

  @override
  String get tellPlayersGame =>
      'Cuéntales a los jugadores un poco sobre tu juego';

  @override
  String get thisMatchUnavailable => 'Este partido ya no está disponible.';

  @override
  String get matchMayRemoved => 'Este partido pudo cancelarse o eliminarse.';

  @override
  String get notificationUnavailable => 'Esta notificación no está disponible.';

  @override
  String get socialUnavailable => 'Esta acción social no está disponible.';

  @override
  String get cancelMatchWarning =>
      'Esto eliminará el partido para todos y no se puede deshacer.';

  @override
  String get totalCapacity => 'Capacidad total de jugadores';

  @override
  String get widerRadius => 'Prueba un radio mayor o cambia la ubicación.';

  @override
  String get loadMoreRetry => 'Intenta cargar más de nuevo';

  @override
  String get upcomingMatches => 'Próximos partidos';

  @override
  String get updateMatchDetails => 'Actualizar detalles del partido';

  @override
  String get matchUpdates => 'Actualizaciones de tus partidos y solicitudes.';

  @override
  String get usePhoto => 'Usar foto';

  @override
  String get viewAll => 'Ver todo';

  @override
  String get profileVisibilityHelp =>
      'Al desactivarlo, tu perfil no aparecerá en Buscar jugadores. Aún podrán verlo mediante partidos, amistades, mensajes, invitaciones o historial compartido.';

  @override
  String get capacityHelp => 'Tú cuentas como un jugador · máximo 4';

  @override
  String get noBlockedPlayers => 'No has bloqueado a ningún jugador.';

  @override
  String get spotAvailable => 'Tu lugar confirmado quedará disponible.';

  @override
  String get padelProfile => 'Tu perfil de pádel';

  @override
  String get couldNotOpenEmail =>
      'No se pudo abrir el correo. Escribe a support.padelx@gmail.com.';

  @override
  String get blockedPlayersUnavailable =>
      'Los jugadores bloqueados no están disponibles por el momento.';

  @override
  String get startupFailed => 'No se pudo iniciar PadelX.';

  @override
  String get verificationSent => 'Enviamos un enlace de verificación a';

  @override
  String get legalAgreement =>
      'Acepto los Términos de uso y reconozco el Aviso de privacidad.';

  @override
  String get resetEmailHelp =>
      'Ingresa tu correo y te enviaremos un enlace para restablecer tu contraseña.';

  @override
  String get signInDiscoverPlayers => 'Inicia sesión para buscar jugadores.';

  @override
  String get locationNoCoordinates => 'Esa ubicación no tiene coordenadas.';

  @override
  String levelValue(String level) {
    return 'Nivel $level';
  }

  @override
  String radiusKm(String distance) {
    return '$distance km';
  }

  @override
  String playerCountChoice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jugadores',
      one: '1 jugador',
    );
    return '$_temp0';
  }

  @override
  String playersIn(String city) {
    return 'Jugadores en\n$city';
  }

  @override
  String chooseAreaIn(String city) {
    return 'Elige una zona en $city';
  }

  @override
  String chooseAreaInCountry(String city, String countryCode) {
    return 'Elige una zona en $city, $countryCode.';
  }

  @override
  String currentArea(String area) {
    return 'Zona actual: $area';
  }

  @override
  String preferredSideDisplay(String side) {
    return 'Lado: $side';
  }

  @override
  String get leftSide => 'Izquierda';

  @override
  String get rightSide => 'Derecha';

  @override
  String get eitherSide => 'Cualquiera';

  @override
  String playedTogetherCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count veces',
      one: '1 vez',
    );
    return 'Jugaron juntos $_temp0';
  }

  @override
  String lastPlayed(String date) {
    return 'Último partido: $date';
  }

  @override
  String ratingAverage(String average) {
    return '$average estrellas';
  }

  @override
  String rateNamedPlayer(String name) {
    return 'Calificar a $name';
  }

  @override
  String howWasPlaying(String name) {
    return '¿Cómo fue jugar con $name?';
  }

  @override
  String get everyone => 'Todos';

  @override
  String get playedWithFilter => 'Jugaste con';

  @override
  String get noAreasFound => 'No se encontraron zonas.';

  @override
  String playerLevelSide(String level, String side) {
    return 'Nivel $level · lado $side';
  }

  @override
  String playerNoRatingsMatches(int matches) {
    String _temp0 = intl.Intl.pluralLogic(
      matches,
      locale: localeName,
      other: '$matches partidos completados',
      one: '1 partido completado',
    );
    return 'Aún no hay calificaciones · $_temp0';
  }

  @override
  String playerRatingMatches(String rating, int ratings, int matches) {
    String _temp0 = intl.Intl.pluralLogic(
      matches,
      locale: localeName,
      other: '$matches partidos completados',
      one: '1 partido completado',
    );
    return '$rating estrellas ($ratings) · $_temp0';
  }

  @override
  String emailAppFailed(String email) {
    return 'No se pudo abrir tu app de correo. Puedes escribirnos a $email.';
  }

  @override
  String get pushPermissionExplanation =>
      'PadelX solicitará permiso en iOS y registrará este dispositivo. Puedes cambiar cada categoría cuando quieras.';

  @override
  String get pushBlockedHelp =>
      'Las notificaciones están bloqueadas en la configuración del dispositivo. Actívalas ahí para recibir notificaciones push de PadelX.';

  @override
  String get pushBuildUnavailable =>
      'Las notificaciones push no están configuradas para esta versión. Puedes preparar las categorías abajo.';

  @override
  String get pushSettingsHelp =>
      'Abre Configuración en tu dispositivo, selecciona PadelX y activa Notificaciones antes de volver a intentarlo.';

  @override
  String get pushCategoriesFuture =>
      'Estas categorías se guardan ahora y controlarán la entrega push cuando se habiliten los tipos de notificación en fases posteriores.';

  @override
  String inviteAfterCreate(String name) {
    return 'Invitar a $name después de crear el partido';
  }

  @override
  String ratingSummary(String average, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count calificaciones',
      one: '1 calificación',
    );
    return '$average estrellas ($_temp0)';
  }

  @override
  String get home => 'Inicio';

  @override
  String get browseMatches => 'Ver partidos';

  @override
  String get loadingNotifications => 'Cargando notificaciones';

  @override
  String get loadingYourMatches => 'Cargando tus partidos…';

  @override
  String get yourMatchesUnavailable =>
      'Tus partidos no están disponibles por el momento.';

  @override
  String get noUpcomingMatches => 'No hay próximos partidos.';

  @override
  String get findOpenOrOrganize =>
      'Busca un partido abierto u organiza tu próximo partido.';

  @override
  String get noPastMatches => 'Aún no hay partidos anteriores.';

  @override
  String get completedAppearHere => 'Los partidos completados aparecerán aquí.';

  @override
  String get profileNeedsInfo =>
      'Tu perfil necesita un poco más de información';

  @override
  String get addNameLevel =>
      'Agrega tu nombre visible y nivel para terminar la configuración.';

  @override
  String get profileStatsFailed =>
      'No se pudieron cargar las estadísticas de tu perfil';

  @override
  String get rating => 'Calificación';

  @override
  String get ratings => 'Calificaciones';

  @override
  String get completedMatches => 'Partidos completados';

  @override
  String get repeatPlayers => 'Jugadores recurrentes';

  @override
  String get sharedMatches => 'Partidos compartidos';

  @override
  String get playerProfileFailed =>
      'No se pudo cargar el perfil de este jugador';

  @override
  String get loadingSubmittedRatings => 'Cargando calificaciones enviadas';

  @override
  String get submittedRatingsFailed =>
      'No se pudieron cargar las calificaciones enviadas.';

  @override
  String get playerUnavailable => 'Jugador no disponible';

  @override
  String get dateUnavailable => 'Fecha no disponible';

  @override
  String get occasional => 'Ocasionalmente';

  @override
  String get weekly => 'Semanalmente';

  @override
  String get severalPerWeek => 'Varias veces por semana';

  @override
  String get legalAgreePrefix => 'Acepto los ';

  @override
  String get legalAgreeMiddle => ' y reconozco el ';

  @override
  String get period => '.';

  @override
  String matchesTogether(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count partidos juntos',
      one: '1 partido juntos',
    );
    return '$_temp0';
  }

  @override
  String get completeProfile => 'Completar perfil';

  @override
  String get requestPending => 'Solicitud pendiente';

  @override
  String get organizing => 'Organizando';

  @override
  String get joined => 'Te uniste';

  @override
  String get ratingNotEligible =>
      'Esta calificación ya se envió o no es elegible.';

  @override
  String get match => 'Partido';

  @override
  String get findingOpenMatches => 'Buscando partidos abiertos…';

  @override
  String get deletedPlayer => 'Jugador eliminado';

  @override
  String get signOutLower => 'Cerrar sesión';

  @override
  String get createMatchGetStarted => 'Crea un partido y empieza a jugar.';

  @override
  String get creatingMatch => 'Creando...';

  @override
  String get emailAddressFallback => 'tu dirección de correo';

  @override
  String get checkingEllipsis => 'Comprobando...';

  @override
  String get verifiedMyEmail => 'Ya verifiqué mi correo';

  @override
  String get sendingEllipsis => 'Enviando...';

  @override
  String resendAvailableIn(Object seconds) {
    return 'Podrás reenviar en $seconds s';
  }

  @override
  String get resendVerificationEmail => 'Reenviar correo de verificación';

  @override
  String get signingOutEllipsis => 'Cerrando sesión...';

  @override
  String get emailNotVerified =>
      'Tu correo aún no está verificado. Abre el enlace del correo y vuelve a intentarlo.';

  @override
  String get emailCheckFailed =>
      'No pudimos comprobar tu correo. Inténtalo de nuevo.';

  @override
  String get verificationEmailSent =>
      'Se envió un nuevo correo de verificación.';

  @override
  String get verificationResendFailed =>
      'No pudimos reenviar el correo. Inténtalo de nuevo.';

  @override
  String get signOutFailed =>
      'No pudimos cerrar la sesión. Inténtalo de nuevo.';

  @override
  String get tooManyAttemptsWait =>
      'Demasiados intentos. Espera un momento y vuelve a intentarlo.';

  @override
  String get networkRetry =>
      'Revisa tu conexión a internet y vuelve a intentarlo.';

  @override
  String get accountUnavailableSupport =>
      'Esta cuenta no está disponible. Contacta al soporte de PadelX.';

  @override
  String get recentLoginRequired =>
      'Cierra sesión, vuelve a iniciarla e inténtalo de nuevo.';

  @override
  String get requestFailedGeneric =>
      'No pudimos completar la solicitud. Inténtalo de nuevo.';

  @override
  String get ageConfirmContinue =>
      'Confirma que tienes 18 años o más para continuar.';

  @override
  String get legalAgreeContinue =>
      'Acepta los Términos de uso y reconoce el Aviso de privacidad para continuar.';

  @override
  String get enterEmailPeriod => 'Ingresa tu correo.';

  @override
  String get validEmailRequired => 'Ingresa una dirección de correo válida.';

  @override
  String get enterPasswordPeriod => 'Ingresa tu contraseña.';

  @override
  String get ageRecordAfterCreateFailed =>
      'Tu cuenta se creó, pero no pudimos confirmar la elegibilidad de edad. Inténtalo de nuevo para continuar.';

  @override
  String get legalRecordAfterCreateFailed =>
      'Tu cuenta se creó, pero no pudimos registrar el reconocimiento legal. Inténtalo de nuevo para continuar.';

  @override
  String get accountNotFound => 'No encontramos una cuenta con ese correo.';

  @override
  String get incorrectCredentials => 'Correo o contraseña incorrectos.';

  @override
  String get createAccountFailed =>
      'No pudimos crear tu cuenta. Inténtalo de nuevo.';

  @override
  String get emailAlreadyUsed =>
      'Ya existe una cuenta con ese correo. Intenta iniciar sesión.';

  @override
  String get weakPassword => 'Tu contraseña debe tener al menos 6 caracteres.';

  @override
  String get tooManyAttemptsLater =>
      'Demasiados intentos. Inténtalo de nuevo más tarde.';

  @override
  String get loginFailed => 'No pudimos iniciar sesión. Inténtalo de nuevo.';

  @override
  String get genericCreateAccountFailed =>
      'No pudimos crear tu cuenta. Inténtalo de nuevo.';

  @override
  String get somethingWrongRetry => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get passwordResetSent =>
      'Se envió el correo para restablecer tu contraseña. Revisa tu bandeja de entrada.';

  @override
  String get logIn => 'Iniciar sesión';

  @override
  String get signUp => 'Registrarse';

  @override
  String get welcomeBackAuth =>
      'Qué gusto verte. Tu próximo partido te espera.';

  @override
  String get createVerifyAuth =>
      'Crea tu cuenta y verifica tu correo para comenzar.';

  @override
  String get createPassword => 'Crea una contraseña';

  @override
  String get showPassword => 'Mostrar contraseña';

  @override
  String get hidePassword => 'Ocultar contraseña';

  @override
  String get loggingIn => 'Iniciando sesión...';

  @override
  String get creatingAccount => 'Creando cuenta...';

  @override
  String get retryAgeConfirmation => 'Reintentar confirmación de edad';

  @override
  String get createAccount => 'Crear cuenta';

  @override
  String get switchToSignUp => '¿No tienes cuenta? Regístrate';

  @override
  String get switchToLogin => '¿Ya tienes cuenta? Inicia sesión';

  @override
  String get resetEmailFailed =>
      'No pudimos enviar el correo de restablecimiento. Inténtalo de nuevo.';

  @override
  String get tooManyRequestsLater =>
      'Demasiadas solicitudes. Inténtalo de nuevo más tarde.';

  @override
  String get notSelected => 'Sin seleccionar';

  @override
  String legacyLevelHelp(Object value) {
    return 'El valor actual \"$value\" es heredado. Elige un nivel numérico.';
  }

  @override
  String get choosePhoto => 'Elegir foto';

  @override
  String get chooseAnotherPhoto => 'Elegir otra';

  @override
  String get unblockingEllipsis => 'Desbloqueando…';

  @override
  String get profileUnavailable => 'Perfil no disponible';

  @override
  String get levelNotSet => 'Nivel sin definir';

  @override
  String get couldNotLoadPlayers => 'No pudimos cargar a los jugadores.';

  @override
  String get playedWithEmpty =>
      'Las personas con las que juegues aparecerán aquí después de partidos completados.';

  @override
  String get notRated => 'Sin calificar';

  @override
  String get locationSuggestionsUnavailable =>
      'Las sugerencias de ubicación no están disponibles temporalmente.';

  @override
  String get conversationUnavailable => 'Conversación no disponible';

  @override
  String get conversationReadOnly => 'Esta conversación es de solo lectura.';

  @override
  String get loadOlderMessages => 'Cargar mensajes anteriores';

  @override
  String messageFrom(Object name) {
    return 'Mensaje de $name';
  }

  @override
  String get you => 'Tú';

  @override
  String get enterPasswordHint => 'Ingresa tu contraseña';

  @override
  String get reasonHarassmentAbuse => 'Acoso o conducta abusiva';

  @override
  String get reasonHateDiscrimination => 'Odio o conducta discriminatoria';

  @override
  String get reasonSexualMisconduct => 'Conducta sexual o inapropiada';

  @override
  String get reasonThreatsUnsafe => 'Amenazas o conducta insegura';

  @override
  String get reasonSpamScams => 'Spam o estafas';

  @override
  String get reasonPrivacyViolation => 'Violación de privacidad';

  @override
  String get reasonFraudDeception => 'Fraude o engaño';

  @override
  String get reasonMaliciousReporting => 'Uso indebido de reportes';

  @override
  String get accountTemporarilySuspended => 'Cuenta suspendida temporalmente';

  @override
  String get accountRestricted => 'Cuenta restringida';

  @override
  String get accessTemporarilyRestricted =>
      'Tu acceso a PadelX se restringió temporalmente.';

  @override
  String get accessRestricted => 'Tu acceso a PadelX está restringido.';

  @override
  String get currentLocation => 'Ubicación actual';

  @override
  String get findingYourLocation => 'Buscando tu ubicación…';

  @override
  String get useCurrentLocation => 'Usar mi ubicación actual';

  @override
  String currentLocationRadius(Object distance) {
    return 'Ubicación actual · radio de $distance km';
  }

  @override
  String searchRadius(Object distance) {
    return 'Radio de búsqueda: $distance km';
  }

  @override
  String get all => 'Todos';

  @override
  String get tomorrow => 'Mañana';

  @override
  String get thisWeek => 'Esta semana';

  @override
  String get noOpenMatches => 'Aún no hay partidos abiertos';

  @override
  String get noMatchesFilters => 'Ningún partido coincide con tus filtros';

  @override
  String noMatchesRadius(Object distance) {
    return 'No hay partidos en un radio de $distance km';
  }

  @override
  String get organizer => 'Organizador';

  @override
  String get pending => 'Pendiente';

  @override
  String get full => 'Lleno';

  @override
  String get open => 'Abierto';

  @override
  String get profileDetailsSafe =>
      'Los datos de tu perfil están seguros. Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get visibleDiscovery => 'Visible en Buscar jugadores';

  @override
  String get hiddenDiscovery => 'Oculto en Buscar jugadores';

  @override
  String get setCityPlayers => 'Define tu ciudad para buscar jugadores';

  @override
  String get addCoarseCity =>
      'Agrega una ciudad general a tu perfil. Tu ubicación precisa nunca se comparte.';

  @override
  String get playersUnavailable =>
      'Los jugadores no están disponibles en este momento';

  @override
  String get morePlayersMayMatch => 'Podría haber más jugadores compatibles';

  @override
  String get noPlayersFilters => 'Ningún jugador coincide con estos filtros';

  @override
  String get continueSearchingPlayers =>
      'Continúa buscando entre los jugadores restantes.';

  @override
  String get broadenPlayerFilters =>
      'Prueba una zona, nivel, lado o relación más amplia.';

  @override
  String get anyLevel => 'Cualquier nivel';

  @override
  String get anySide => 'Cualquier lado';

  @override
  String get eitherOnly => 'Solo cualquiera';

  @override
  String get unfriendQuestion => '¿Eliminar amistad con este jugador?';

  @override
  String get unfriendExplanation =>
      'La amistad y la conexión social directa terminarán.';

  @override
  String get incomingRequests => 'Solicitudes recibidas';

  @override
  String get outgoingRequests => 'Solicitudes enviadas';

  @override
  String get acceptedFriends => 'Amistades aceptadas';

  @override
  String get noFriendsYet => 'Aún no tienes amistades.';

  @override
  String get noRequests => 'No hay solicitudes.';

  @override
  String get privacy => 'Privacidad';

  @override
  String get legal => 'Legal';

  @override
  String get accountDeletionInfo => 'Eliminación de cuenta';

  @override
  String get categories => 'Categorías';

  @override
  String get matchMessages => 'Mensajes de partidos';

  @override
  String get joinRequestsCategory => 'Solicitudes para unirse';

  @override
  String get friendRequestsCategory => 'Solicitudes de amistad';

  @override
  String get friendAcceptedCategory => 'Amistad aceptada';

  @override
  String get matchUpdatesCategory => 'Actualizaciones de partidos';

  @override
  String get accountManagement => 'Administración de cuenta';

  @override
  String get pushOn => 'Notificaciones push activadas';

  @override
  String get pushOff => 'Notificaciones push desactivadas';

  @override
  String get notificationsBlockedSettings =>
      'Notificaciones bloqueadas en la configuración del dispositivo';

  @override
  String get pushUnavailableBuild => 'No disponible en esta versión';

  @override
  String get checkingDevicePermission => 'Comprobando permiso del dispositivo…';

  @override
  String get deletionExplanation =>
      'La eliminación es permanente. Los partidos futuros que organices se cancelarán y saldrás de los partidos futuros a los que te hayas unido. La participación histórica se anonimizará. Se eliminarán las calificaciones relacionadas con tu cuenta.';

  @override
  String get deletionPasswordRequired =>
      'Ingresa tu contraseña para este intento de eliminación.';

  @override
  String get deletionRequested =>
      'Se solicitó la eliminación de la cuenta. Cerraste sesión y la limpieza continúa de forma segura en segundo plano.';

  @override
  String get signedOutNotice => 'Cerraste sesión.';

  @override
  String get requestingDeletion => 'Solicitando eliminación…';

  @override
  String get permanentlyDeleteAccount => 'Eliminar mi cuenta permanentemente';

  @override
  String get eligibilityConfirmFailed =>
      'No pudimos confirmar la elegibilidad. Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get confirmingEllipsis => 'Confirmando...';

  @override
  String get legalRecordFailed =>
      'No pudimos registrar tu reconocimiento. Inténtalo de nuevo.';

  @override
  String get legalRefreshFailed =>
      'Se registró tu reconocimiento, pero no pudimos actualizar su estado. Inténtalo de nuevo.';

  @override
  String get savingEllipsis => 'Guardando...';

  @override
  String get guidelineAdultsTitle => 'Solo personas adultas';

  @override
  String get guidelineAdultsBody =>
      'PadelX es para personas mayores de 18 años.';

  @override
  String get guidelineRespectTitle => 'Respeta a otros jugadores';

  @override
  String get guidelineRespectBody =>
      'Trata a los jugadores con respeto. No se permite el acoso, la intimidación ni el abuso dirigido.';

  @override
  String get guidelineHateTitle => 'Odio y discriminación';

  @override
  String get guidelineHateBody =>
      'No se permite contenido ni conducta de odio o discriminación.';

  @override
  String get guidelineSexualTitle => 'Conducta sexual o inapropiada';

  @override
  String get guidelineSexualBody =>
      'No envíes contenido sexual no solicitado ni incurras en acoso sexual u otra conducta inapropiada.';

  @override
  String get guidelineThreatsTitle => 'Amenazas y conducta insegura';

  @override
  String get guidelineThreatsBody =>
      'No se permiten amenazas, violencia, intimidación ni conductas deliberadamente inseguras.';

  @override
  String get guidelineSpamTitle => 'Spam, estafas y engaño';

  @override
  String get guidelineSpamBody =>
      'No publiques estafas, spam, anuncios engañosos, solicitudes de pago fraudulentas ni información de partidos intencionalmente falsa.';

  @override
  String get guidelineImpersonationBody =>
      'No suplantes a otro jugador, sede, organización o persona.';

  @override
  String get guidelinePrivacyTitle => 'Privacidad';

  @override
  String get guidelinePrivacyBody =>
      'No compartas información privada de otra persona sin permiso ni expongas indebidamente ubicaciones privadas o residenciales.';

  @override
  String get guidelineProfilesTitle => 'Perfiles y contenido';

  @override
  String get guidelineProfilesBody =>
      'Los nombres, avatares, biografías, datos de partidos y mensajes deben cumplir estas normas.';

  @override
  String get guidelineMessagingTitle => 'Mensajería';

  @override
  String get guidelineMessagingBody =>
      'No uses mensajes directos ni el chat del partido para acosar, amenazar, estafar, enviar spam o compartir contenido inapropiado no solicitado.';

  @override
  String get guidelineMatchesTitle => 'Partidos';

  @override
  String get guidelineMatchesBody =>
      'Crea anuncios honestos. No tergiverses intencionalmente la ubicación, hora, costo, nivel, disponibilidad ni al organizador.';

  @override
  String get guidelineBlockingTitle => 'Bloqueos y reportes';

  @override
  String get guidelineBlockingBody =>
      'Respeta la decisión de otra persona de bloquear o dejar de comunicarse. No tomes represalias ni envíes reportes maliciosos o inventados.';

  @override
  String get guidelineRealWorldTitle => 'Seguridad presencial';

  @override
  String get guidelineRealWorldBody =>
      'Usa un criterio razonable al conocer personas en la vida real. Trata con cuidado las ubicaciones privadas y residenciales.';

  @override
  String get guidelineReliabilityTitle => 'Confiabilidad futura';

  @override
  String get guidelineReliabilityBody =>
      'PadelX podría usar más adelante conductas objetivas de participación, como cancelaciones y ausencias, para mejorar el emparejamiento.';

  @override
  String get guidelineEnforcementTitle => 'Medidas';

  @override
  String get guidelineEnforcementBody =>
      'PadelX puede revisar conductas reportadas y restringir el acceso cuando corresponda.';

  @override
  String get immediateDangerBody =>
      'Si tú u otra persona están en peligro inmediato, contacta a los servicios de emergencia locales.';

  @override
  String get notEmergencyService =>
      'Los reportes y el soporte de PadelX no son servicios de emergencia.';

  @override
  String get emergencySafetyGuidanceLabel =>
      'Orientación de seguridad para emergencias';

  @override
  String get where => 'Dónde';

  @override
  String get when => 'Cuándo';

  @override
  String get hideLocationDetails => 'Ocultar detalles de ubicación';

  @override
  String get editLocationDetails => 'Editar detalles de ubicación';

  @override
  String get matchDetailsSection => 'Detalles del partido';

  @override
  String get saveChanges => 'Guardar cambios';

  @override
  String get completeYourProfile => 'Completa tu perfil';

  @override
  String get profileRequiredIntro =>
      'Cuéntales a otros jugadores con quién compartirán la cancha.';

  @override
  String get profileEditIntro =>
      'Mantén tus datos actualizados para encontrar partidos más compatibles.';

  @override
  String get chooseCity => 'Elegir ciudad';

  @override
  String get optionalNeighborhoodCity =>
      'Colonia o zona opcional dentro de tu ciudad';

  @override
  String get legacyAreaHelp =>
      'Zona actual; elimínala o reemplázala con un resultado de búsqueda';

  @override
  String get displayNameTooShort =>
      'Ingresa un nombre de al menos 2 caracteres.';

  @override
  String get displayNameTooLong =>
      'El nombre debe tener 40 caracteres o menos.';

  @override
  String get chooseLevelRange => 'Elige un nivel del 1 al 7.';

  @override
  String get bioTooLong => 'La biografía debe tener 160 caracteres o menos.';

  @override
  String get discoveryLocationRequired =>
      'Ingresa país, código de país de 2 letras y ciudad para aparecer en búsquedas.';

  @override
  String get profileSaveFailed =>
      'No pudimos guardar tu perfil. Inténtalo de nuevo.';

  @override
  String get selectPadelClub => 'Selecciona un club de pádel.';

  @override
  String get chooseDateTimePeriod => 'Elige una fecha y hora.';

  @override
  String get choosePlayerLevel => 'Elige un nivel de jugador.';

  @override
  String get matchCreatedInvited => 'Partido creado e invitación enviada.';

  @override
  String get matchCreatedInviteFailed =>
      'El partido se creó, pero no pudimos enviar la invitación.';

  @override
  String get matchCreated => 'Partido creado correctamente.';

  @override
  String get legacyLocationHelp =>
      'Ubicación heredada: busca arriba para elegir una ubicación estructurada.';

  @override
  String get saveMatchFailed =>
      'No pudimos guardar los cambios del partido. Inténtalo de nuevo.';

  @override
  String confirmedPlayersCapacity(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jugadores confirmados actualmente · máximo 4',
      one: '1 jugador confirmado actualmente · máximo 4',
    );
    return '$_temp0';
  }

  @override
  String get matchChatUnavailable => 'El chat del partido no está disponible.';

  @override
  String get completedMatchNoChanges => 'Este partido ya terminó.';

  @override
  String get loginJoinMatch =>
      'Inicia sesión para solicitar unirte a un partido.';

  @override
  String get joinRequestSent => 'Solicitud enviada.';

  @override
  String get joinRequestFailed =>
      'No pudimos enviar tu solicitud. Inténtalo de nuevo.';

  @override
  String get completedMatchesNoChanges =>
      'Los partidos terminados no se pueden modificar.';

  @override
  String get joinRequestApproved => 'Solicitud aprobada.';

  @override
  String get joinRequestDeclined => 'Solicitud rechazada.';

  @override
  String get approveRequestFailed =>
      'No pudimos aprobar la solicitud. Inténtalo de nuevo.';

  @override
  String get declineRequestFailed =>
      'No pudimos rechazar la solicitud. Inténtalo de nuevo.';

  @override
  String get loginLeaveMatch => 'Inicia sesión para salir de un partido.';

  @override
  String get leftMatch => 'Saliste del partido.';

  @override
  String get leaveMatchFailed =>
      'No pudimos sacarte del partido. Inténtalo de nuevo.';

  @override
  String get loginCancelMatch => 'Inicia sesión para cancelar un partido.';

  @override
  String get cancelMatchFailed =>
      'No pudimos cancelar el partido. Inténtalo de nuevo.';

  @override
  String get playersFromMatch => 'Jugadores de este partido';

  @override
  String get confirmedRole => 'Confirmado';

  @override
  String get cancellingEllipsis => 'Cancelando...';

  @override
  String get leavingEllipsis => 'Saliendo...';

  @override
  String get requestStatusFailed =>
      'No pudimos cargar el estado de la solicitud';

  @override
  String get loadingRequestStatus => 'Cargando estado de la solicitud…';

  @override
  String get matchFull => 'Partido lleno';

  @override
  String get requestingEllipsis => 'Solicitando...';

  @override
  String get loadingRequest => 'Cargando solicitud...';

  @override
  String get loadRequestFailed => 'No pudimos cargar la solicitud';

  @override
  String get dateTimeUnavailable => 'Fecha y hora no disponibles';

  @override
  String ratingSelected(Object count) {
    return '$count de 5';
  }

  @override
  String get selectRating => 'Selecciona una calificación';

  @override
  String ratingSubmittedStars(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count estrellas',
      one: '1 estrella',
    );
    return 'Calificación enviada · $_temp0';
  }

  @override
  String submittedStars(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count estrellas',
      one: '1 estrella',
    );
    return 'Enviada · $_temp0';
  }

  @override
  String get startupLoadingSemantics => 'PadelX cargando';

  @override
  String privateVenueExactLocation(String address) {
    return 'Ubicación exacta: $address';
  }

  @override
  String get findMeAMatch => 'Quick Match';

  @override
  String get matchmakingActionFailed =>
      'No se pudo completar esa acción. Intenta de nuevo.';

  @override
  String get completeMatchmakingRequest =>
      'Elige un horario válido y un compañero cuando corresponda.';

  @override
  String get matchmakingIntro =>
      'Dile a PadelX cuándo quieres jugar. Armaremos el partido por ti.';

  @override
  String get solo => 'Solo';

  @override
  String get withPartner => 'Con un compañero';

  @override
  String get choosePartner => 'Elegir compañero';

  @override
  String get availableFrom => 'Disponible desde';

  @override
  String get availableUntil => 'Disponible hasta';

  @override
  String searchLocationSummary(String city, String area) {
    String _temp0 = intl.Intl.selectLogic(area, {
      'other': '$area, $city',
      'empty': '$city',
    });
    return '$_temp0';
  }

  @override
  String get travelRadius => 'Radio de traslado';

  @override
  String get startSearching => 'Empezar búsqueda';

  @override
  String get startQuickMatch => 'Iniciar Quick Match';

  @override
  String get partnerInvitation => 'Invitación de compañero';

  @override
  String get findingYourMatch => 'Buscando tu partido…';

  @override
  String invitedBy(String name) {
    return 'Invitación de $name';
  }

  @override
  String get cancelSearch => 'Cancelar búsqueda';

  @override
  String get matchFound => 'Partido encontrado';

  @override
  String get playersReady => 'Jugadores listos';

  @override
  String get confirmMySpot => 'Confirmar mi lugar';

  @override
  String get courtNotSelected => 'La cancha aún no está seleccionada';

  @override
  String offerExpiresMinutes(String minutes) {
    return 'La oferta vence en aproximadamente $minutes min';
  }

  @override
  String get confirmed => 'Confirmado';

  @override
  String get waiting => 'En espera';

  @override
  String teamNumber(String number) {
    return 'Equipo $number';
  }

  @override
  String get matchmakingSpotFound => 'Lugar encontrado';

  @override
  String get matchmakingMatchConfirmed => 'Partido confirmado';

  @override
  String get matchmakingPartnerInviteBody =>
      'Tienes una invitación de compañero para matchmaking.';

  @override
  String get matchmakingMatchFoundBody =>
      'Hay una propuesta de partido lista para que la confirmes.';

  @override
  String get matchmakingSpotFoundBody =>
      'Hay un lugar listo para que lo confirmes.';

  @override
  String get matchmakingMatchConfirmedBody => 'Tu partido está confirmado.';

  @override
  String get acceptMatch => 'Aceptar partido';

  @override
  String get chooseVenueToFinish =>
      'Todos aceptaron. Elige una cancha para terminar de crear el partido.';

  @override
  String get waitingForVenue =>
      'Todos aceptaron. Esperando que el coordinador elija la cancha.';

  @override
  String get chooseVenue => 'Elegir cancha';

  @override
  String get openMatchDetails => 'Abrir detalles del partido';

  @override
  String get privateCourt => 'Cancha privada';

  @override
  String get clubPublicCourt => 'Cancha de club / pública';

  @override
  String get privateCourtLocation => 'Ubicación de la cancha privada';

  @override
  String get searchVenue => 'Buscar la ubicación de la cancha';

  @override
  String get courtBookingSeparate =>
      'La reservación de la cancha se gestiona por separado.';

  @override
  String get confirmVenue => 'Confirmar cancha';

  @override
  String get matchmakingUnavailable =>
      'La búsqueda de partido no está disponible por ahora.';

  @override
  String get findAPlayer => 'Buscar un jugador';

  @override
  String get autoFillExplanation =>
      'Deja que PadelX encuentre un jugador compatible para este lugar.';

  @override
  String get stopAutoFill => 'Detener AutoFill';

  @override
  String get findingAnotherPlayer => 'Buscando otro jugador…';

  @override
  String get padelVenueSearchLabel => 'Club o cancha de pádel';

  @override
  String get padelVenueSearchHint => 'Buscar canchas de pádel cercanas';

  @override
  String padelVenueRadiusExplanation(String distance) {
    return 'Mostrando canchas de pádel dentro del área acordada de $distance km.';
  }

  @override
  String get noPadelVenuesInArea =>
      'No se encontraron canchas de pádel dentro de tu área de búsqueda.';

  @override
  String get padelVenueOutsideArea =>
      'Esa cancha está fuera del área de búsqueda acordada.';

  @override
  String get padelVenueSearchUnavailable =>
      'La búsqueda de canchas de pádel no está disponible por ahora.';

  @override
  String get privateCourtAddressHelp =>
      '¿No encuentras tu cancha privada? Busca su dirección.';

  @override
  String get yourSpotConfirmed => 'Tu lugar está confirmado';

  @override
  String get findingRemainingPlayers =>
      'Estamos buscando a los jugadores restantes.';

  @override
  String playersConfirmedCount(String confirmed) {
    return '$confirmed de 4 confirmados';
  }

  @override
  String get versus => 'VS';
}

/// The translations for Spanish Castilian, as used in Mexico (`es_MX`).
class AppLocalizationsEsMx extends AppLocalizationsEs {
  AppLocalizationsEsMx() : super('es_MX');

  @override
  String get language => 'Idioma';

  @override
  String get useDeviceLanguage => 'Usar idioma del dispositivo';

  @override
  String get english => 'English';

  @override
  String get spanishMexico => 'Español (México)';

  @override
  String get cancel => 'Cancelar';

  @override
  String get done => 'Listo';

  @override
  String get retry => 'Reintentar';

  @override
  String get loading => 'Cargando';

  @override
  String get somethingWentWrong => 'Algo salió mal';

  @override
  String get settings => 'Configuración';

  @override
  String get authHeadline => 'Encuentra tu próximo partido.';

  @override
  String get authSubtitle => 'Juega más pádel con jugadores cerca de ti.';

  @override
  String get continueWithEmail => 'Continuar con correo';

  @override
  String get termsOfUse => 'Términos de uso';

  @override
  String get privacyPolicy => 'Aviso de privacidad';

  @override
  String get chooseLanguage => 'Elegir idioma';

  @override
  String get languageSelectorTooltip => 'Cambiar idioma';

  @override
  String get languageSelectorSemantics => 'Cambiar el idioma de la aplicación';

  @override
  String welcomePlayer(String name) {
    return 'Te damos la bienvenida, $name';
  }

  @override
  String matchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count partidos',
      one: '1 partido',
      zero: 'No hay partidos',
    );
    return '$_temp0';
  }

  @override
  String get tryAgain => 'Volver a intentar';

  @override
  String get tryAgainLower => 'Volver a intentar';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get logOut => 'Cerrar sesión';

  @override
  String get continueLabel => 'Continuar';

  @override
  String get back => 'Atrás';

  @override
  String get close => 'Cerrar';

  @override
  String get remove => 'Eliminar';

  @override
  String get saveProfile => 'Guardar perfil';

  @override
  String get email => 'Correo electrónico';

  @override
  String get password => 'Contraseña';

  @override
  String get enterEmail => 'Ingresa tu correo electrónico';

  @override
  String get forgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get resetPassword => 'Restablecer contraseña';

  @override
  String get sendResetEmail => 'Enviar correo de restablecimiento';

  @override
  String get signInOrCreate => 'Inicia sesión o crea tu cuenta.';

  @override
  String get verifyEmail => 'Verifica tu correo electrónico';

  @override
  String get openVerificationLink =>
      'Abre el enlace de ese mensaje y luego regresa aquí para continuar.';

  @override
  String get beforeContinuing => 'Antes de continuar';

  @override
  String get ageConfirmation => 'Confirmo que tengo 18 años o más.';

  @override
  String get ageRequired =>
      'Para continuar, confirma que tienes al menos 18 años.';

  @override
  String get ageEligibility => 'Elegibilidad para mayores de 18';

  @override
  String get ageCheckFailed => 'No se pudo verificar la elegibilidad de edad.';

  @override
  String get adultOnly => 'PadelX es para personas mayores de 18 años.';

  @override
  String get legalAcknowledgement => 'Aceptación legal';

  @override
  String get legalReviewIntro =>
      'Revisa los Términos de uso y el Aviso de privacidad de la beta cerrada de PadelX.';

  @override
  String get legalLoadFailed => 'No se pudo consultar el estado de aceptación.';

  @override
  String get matches => 'Partidos';

  @override
  String get discover => 'Descubrir';

  @override
  String get myMatches => 'Mis partidos';

  @override
  String get upcoming => 'Próximos';

  @override
  String get past => 'Anteriores';

  @override
  String get create => 'Crear';

  @override
  String get createMatch => 'Crear partido';

  @override
  String get createAMatch => 'Crear partido';

  @override
  String get editMatch => 'Editar partido';

  @override
  String get matchDetails => 'Detalles del partido';

  @override
  String get findMatch => 'Buscar partidos';

  @override
  String get findMatchesHomeDescription =>
      'Explora por tu cuenta los partidos disponibles.';

  @override
  String get quickMatchHomeDescription => 'PadelX encuentra el partido por ti.';

  @override
  String get createMatchHomeDescription => 'Organiza tu propio partido.';

  @override
  String get reliabilityNewPlayer => 'Confiabilidad: jugador nuevo';

  @override
  String reliabilityPercent(int percent) {
    return 'Confiabilidad: $percent%';
  }

  @override
  String get findPlayers => 'Buscar jugadores';

  @override
  String get players => 'Jugadores';

  @override
  String get messages => 'Mensajes';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get profile => 'Perfil';

  @override
  String get editProfile => 'Editar perfil';

  @override
  String get playerProfile => 'Perfil del jugador';

  @override
  String get friends => 'Amigos';

  @override
  String get friend => 'Amigo';

  @override
  String get addFriend => 'Agregar amigo';

  @override
  String get requested => 'Solicitud enviada';

  @override
  String get accept => 'Aceptar';

  @override
  String get decline => 'Rechazar';

  @override
  String get unfriend => 'Eliminar amistad';

  @override
  String get block => 'Bloquear';

  @override
  String get unblock => 'Desbloquear';

  @override
  String get reportPlayer => 'Reportar jugador';

  @override
  String get reportMessage => 'Reportar mensaje';

  @override
  String get reportMatch => 'Reportar partido';

  @override
  String get reportSubmitted => 'Reporte enviado';

  @override
  String get matchChat => 'Chat del partido';

  @override
  String get message => 'Mensaje';

  @override
  String get sendMessage => 'Enviar mensaje';

  @override
  String get refreshMessages => 'Actualizar mensajes';

  @override
  String get noMessages => '¡Aún no hay mensajes! Di hola.';

  @override
  String get noConversations => 'Aún no hay conversaciones.';

  @override
  String get messagesUnavailable =>
      'Los mensajes no están disponibles por el momento.';

  @override
  String get couldNotSendMessage => 'No se pudo enviar este mensaje.';

  @override
  String get loadOlder => 'Cargar anteriores';

  @override
  String get loadingEllipsis => 'Cargando…';

  @override
  String get markRead => 'Marcar como leída';

  @override
  String get markAsRead => 'Marcar como leída';

  @override
  String get markAllRead => 'Marcar todas como leídas';

  @override
  String get noNotifications => 'Aún no hay notificaciones';

  @override
  String get viewMatch => 'Ver partido';

  @override
  String get dismiss => 'Descartar';

  @override
  String get level => 'Nivel';

  @override
  String get playerLevel => 'Nivel de jugador';

  @override
  String get chooseLevel => 'Elige un nivel';

  @override
  String get preferredSide => 'Lado preferido';

  @override
  String get areaOptional => 'Zona / Colonia (opcional)';

  @override
  String get anyArea => 'Cualquier zona';

  @override
  String get searchAreas => 'Buscar zonas';

  @override
  String get city => 'Ciudad';

  @override
  String get country => 'País';

  @override
  String get countryCode => 'Código de país';

  @override
  String get changeCity => 'Cambiar ciudad';

  @override
  String get searchCitiesOnly => 'Buscar solo ciudades';

  @override
  String get displayName => 'Nombre visible';

  @override
  String get shortBio => 'Descripción breve (opcional)';

  @override
  String get discoverability => 'Permitir que otros jugadores me encuentren';

  @override
  String get preferredLocation =>
      'Ubicación preferida para aparecer en búsquedas';

  @override
  String get profileUpdated => 'Perfil actualizado.';

  @override
  String get helpSafety => 'Ayuda y seguridad';

  @override
  String get supportSafety => 'Soporte y seguridad';

  @override
  String get communityGuidelines => 'Normas de la comunidad';

  @override
  String get blockedPlayers => 'Jugadores bloqueados';

  @override
  String get contactSupport => 'Contactar al soporte de PadelX';

  @override
  String get deleteAccount => 'Eliminar cuenta';

  @override
  String get deleteAccountLower => 'Eliminar cuenta';

  @override
  String get account => 'Cuenta';

  @override
  String get safety => 'Seguridad';

  @override
  String get reportingBlockingAge =>
      'Reportes, bloqueos y elegibilidad de edad';

  @override
  String get emergency => 'Emergencia';

  @override
  String get ratingSubmitted => 'Calificación enviada.';

  @override
  String get ratePlayer => 'Calificar jugador';

  @override
  String get ratePlayers => 'Calificar jugadores';

  @override
  String get submitRating => 'Enviar calificación';

  @override
  String get playAgain => 'Jugar de nuevo';

  @override
  String get cancelMatch => 'Cancelar partido';

  @override
  String get leaveMatch => 'Salir del partido';

  @override
  String get matchUnavailable => 'Partido no disponible';

  @override
  String get noMatchesNearby => 'Aún no hay partidos cercanos.';

  @override
  String get matchesUnavailable =>
      'Los partidos no están disponibles por el momento.';

  @override
  String get findingMatches => 'Buscando partidos cercanos…';

  @override
  String get clearFilters => 'Borrar filtros';

  @override
  String get filterMatches => 'Filtrar partidos';

  @override
  String get club => 'Club';

  @override
  String get dateTime => 'Fecha y hora';

  @override
  String get chooseDateTime => 'Elegir fecha y hora';

  @override
  String get totalPlayers => 'Total de jugadores';

  @override
  String get spots => 'Lugares';

  @override
  String get submit => 'Enviar';

  @override
  String get whyReporting => '¿Por qué quieres reportarlo?';

  @override
  String get additionalDetails => 'Detalles adicionales (opcional)';

  @override
  String couldNotOpenPage(String email) {
    return 'No se pudo abrir esta página. Escribe a $email.';
  }

  @override
  String get today => 'Hoy';

  @override
  String get yesterday => 'Ayer';

  @override
  String get player => 'Jugador';

  @override
  String get noMessagesYet => 'Aún no hay mensajes';

  @override
  String unreadMessages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes sin leer',
      one: '1 mensaje sin leer',
    );
    return '$_temp0';
  }

  @override
  String get unread => 'Sin leer';

  @override
  String get read => 'Leída';

  @override
  String get unreadNotification => 'Notificación sin leer';

  @override
  String get timeUnavailable => 'Hora no disponible';

  @override
  String get newJoinRequest => 'Nueva solicitud para unirse';

  @override
  String joinRequestBody(String name, String club) {
    return '$name solicitó unirse a tu partido en $club.';
  }

  @override
  String get requestApproved => 'Solicitud aprobada';

  @override
  String get requestDeclined => 'Solicitud rechazada';

  @override
  String requestApprovedBody(String club) {
    return 'Tu solicitud para unirte al partido en $club fue aprobada.';
  }

  @override
  String requestDeclinedBody(String club) {
    return 'Tu solicitud para unirte al partido en $club fue rechazada.';
  }

  @override
  String get newDirectMessage => 'Nuevo mensaje';

  @override
  String get newDirectMessageBody => 'Tienes un mensaje directo sin leer.';

  @override
  String get newMatchMessage => 'Nuevo mensaje del partido';

  @override
  String get newMatchMessageBody =>
      'Tienes un mensaje sin leer en el chat del partido.';

  @override
  String get newFriendRequest => 'Nueva solicitud de amistad';

  @override
  String friendRequestBody(String name) {
    return '$name te envió una solicitud de amistad.';
  }

  @override
  String get friendRequestAccepted => 'Solicitud de amistad aceptada';

  @override
  String friendAcceptedBody(String name) {
    return '$name aceptó tu solicitud de amistad.';
  }

  @override
  String get playAgainInvite => 'Jugar de nuevo';

  @override
  String playAgainBody(String name) {
    return '$name te invitó a jugar de nuevo.';
  }

  @override
  String get harassmentBullying => 'Acoso o intimidación';

  @override
  String get hateAbuse => 'Odio o contenido abusivo';

  @override
  String get sexualInappropriate => 'Contenido sexual o inapropiado';

  @override
  String get threatsUnsafe => 'Amenazas o conducta insegura';

  @override
  String get spamScam => 'Spam o estafa';

  @override
  String get impersonation => 'Suplantación de identidad';

  @override
  String get other => 'Otro motivo';

  @override
  String reportSubject(String subject) {
    return 'Reportar $subject';
  }

  @override
  String get reportAlreadySubmitted => 'Ya reportaste esto.';

  @override
  String get reportRateLimited =>
      'Enviaste varios reportes recientemente. Inténtalo de nuevo más tarde.';

  @override
  String get reportFailed =>
      'No se pudo enviar el reporte. Inténtalo de nuevo.';

  @override
  String get thanksForSafety => 'Gracias por ayudar a mantener PadelX seguro.';

  @override
  String get blockPlayer => 'Bloquear jugador';

  @override
  String get blockThisPlayer => '¿Bloquear a este jugador?';

  @override
  String get playerBlocked => 'Jugador bloqueado.';

  @override
  String get playerBlockFailed => 'No se pudo bloquear al jugador.';

  @override
  String get sharedMatchBlockExplanation =>
      'El bloqueo impide la búsqueda social y el contacto normales. El acceso a partidos compartidos sigue dependiendo de la participación.';

  @override
  String get friendBlockExplanation =>
      'Se eliminará su amistad y se impedirán la búsqueda social y el contacto normales. El acceso a partidos compartidos sigue dependiendo de la participación.';

  @override
  String get nonFriendBlockExplanation =>
      'Se impedirán la búsqueda social y el contacto normales con este jugador. El acceso a partidos compartidos sigue dependiendo de la participación.';

  @override
  String get approve => 'Aprobar';

  @override
  String get allPlayersRated => 'Todos los jugadores están calificados.';

  @override
  String get areaSuggestionsUnavailable =>
      'Las sugerencias de zona no están disponibles. Puedes elegir Cualquier zona.';

  @override
  String get beFirstMatch => 'Sé la primera persona en organizar un partido.';

  @override
  String get cancelMatchQuestion => '¿Cancelar el partido?';

  @override
  String get checkAccessAgain => 'Volver a verificar el acceso';

  @override
  String get connectionRetry => 'Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get chooseClubTimePlayers =>
      'Elige un club, horario y para quién es el partido.';

  @override
  String get cityOrArea => 'Ciudad o zona';

  @override
  String get citySuggestionsUnavailable =>
      'Las sugerencias de ciudad no están disponibles. Ingresa los datos de tu ciudad; la zona puede quedar vacía.';

  @override
  String get clearLocation => 'Borrar ubicación';

  @override
  String get closeAreaSelector => 'Cerrar selector de zona';

  @override
  String get closeLevelSelector => 'Cerrar selector de nivel';

  @override
  String get clubName => 'Nombre del club';

  @override
  String get clubNameAddress => 'Nombre o dirección del club';

  @override
  String get completed => 'Completados';

  @override
  String get confirmPassword => 'Confirma tu contraseña';

  @override
  String get preservePlayersRequests =>
      'Se conservarán los jugadores confirmados y las solicitudes para unirse.';

  @override
  String get createMatchFailed => 'No se pudo crear el partido.';

  @override
  String get dismissInviteFailed => 'No se pudo descartar esta invitación.';

  @override
  String get loadLocationFailed => 'No se pudo cargar esa ubicación.';

  @override
  String get loadProfileFailed => 'No se pudo cargar tu perfil.';

  @override
  String get markReadFailed => 'No se pudo marcar la notificación como leída.';

  @override
  String get markAllReadFailed =>
      'No se pudieron marcar las notificaciones como leídas.';

  @override
  String get ratingSubmitFailed => 'No se pudo enviar la calificación.';

  @override
  String get accessCheckFailed => 'No se pudo verificar el acceso a la cuenta.';

  @override
  String get editProfileLocation => 'Editar ubicación del perfil';

  @override
  String get enablePushQuestion => '¿Activar notificaciones push?';

  @override
  String get endFriendship => 'Terminar esta amistad y conexión social directa';

  @override
  String get expand100 => 'Ampliar a 100 km';

  @override
  String get findMatchesNear => 'Buscar partidos cerca de';

  @override
  String get findPadelMatches => 'Encuentra partidos de pádel cerca de ti.';

  @override
  String get findPadelPlayers =>
      'Encuentra jugadores de pádel con quienes quieras jugar.';

  @override
  String get playFrequency => '¿Con qué frecuencia juegas?';

  @override
  String get howReportMatch => 'Cómo reportar un partido';

  @override
  String get howReportMessage => 'Cómo reportar un mensaje';

  @override
  String get howReportPlayer => 'Cómo reportar a un jugador';

  @override
  String get isoCountryCode => 'Código de país ISO';

  @override
  String get immediateDanger => 'Peligro inmediato';

  @override
  String get joinRequests => 'Solicitudes para unirse';

  @override
  String get joinGames => 'Únete a partidos que necesitan jugadores.';

  @override
  String get keepMatch => 'Conservar partido';

  @override
  String get loadingPadelX => 'CARGANDO PADELX';

  @override
  String get leaveMatchQuestion => '¿Salir del partido?';

  @override
  String get loadMore => 'Cargar más';

  @override
  String get loadMoreNearby => 'Cargar más partidos cercanos';

  @override
  String get loadOlderMatches => 'Cargar partidos anteriores';

  @override
  String get loadOlderNotifications => 'Cargar notificaciones anteriores';

  @override
  String get loadingJoinRequests => 'Cargando solicitudes para unirse...';

  @override
  String get matchCancelled => 'Partido cancelado.';

  @override
  String get matchDiscovery => 'Búsqueda de partidos';

  @override
  String get matchUpdated => 'Partido actualizado correctamente.';

  @override
  String get notificationEmptyBody =>
      'Aquí aparecerán actualizaciones de partidos, mensajes y actividad social.';

  @override
  String get organizedJoinedMatches =>
      'Partidos que organizas o a los que te uniste.';

  @override
  String get acceptedFriendsMessaging =>
      'Los mensajes están disponibles entre amigos aceptados.';

  @override
  String get moreActions => 'Más acciones';

  @override
  String get moreSafetyActions => 'Más acciones de seguridad';

  @override
  String get needHelp =>
      '¿Necesitas ayuda o quieres reportar un asunto de seguridad?';

  @override
  String get neighborhoodArea => 'Colonia o zona';

  @override
  String get noOtherPlayersRate =>
      'No hay otros jugadores de este partido por calificar.';

  @override
  String get noPendingRequests => 'No hay solicitudes pendientes';

  @override
  String get noRatings => 'Aún no hay calificaciones';

  @override
  String get notNow => 'Ahora no';

  @override
  String get notificationPreferencesFailed =>
      'No se pudieron guardar las preferencias de notificaciones.';

  @override
  String get notificationsUnavailable =>
      'Las notificaciones no están disponibles por el momento.';

  @override
  String get openReportMatchHelp =>
      'Abre Detalles del partido y elige Reportar partido en las acciones de seguridad.';

  @override
  String get openMatches => 'Partidos abiertos';

  @override
  String get openReportPlayerHelp =>
      'Abre el perfil del jugador, toca Más acciones y luego Reportar jugador.';

  @override
  String get pendingRequests => 'Solicitudes pendientes';

  @override
  String get playedWith => 'Personas con quienes jugaste';

  @override
  String get permanentlyDelete =>
      'Eliminar permanentemente tu cuenta de PadelX';

  @override
  String get photoCropHelp =>
      'Las fotos se recortan al centro y se guardan como JPEG de 512×512.';

  @override
  String get unblockedNotice =>
      'Jugador desbloqueado. La amistad no se restaura automáticamente.';

  @override
  String get chooseFutureDate => 'Elige una fecha y hora futuras.';

  @override
  String get policyCategory => 'Categoría de la política';

  @override
  String get pressHoldReport =>
      'Mantén presionado un mensaje de otro jugador y elige Reportar mensaje.';

  @override
  String get preventSocialContact =>
      'Impedir la búsqueda social y el contacto normales';

  @override
  String get pushUpdateFailed =>
      'No se pudo actualizar la configuración de notificaciones push.';

  @override
  String get pushNotifications => 'Notificaciones push';

  @override
  String get pushPermissionCategories =>
      'Permiso push y categorías de notificaciones';

  @override
  String get questionsSafety => 'Preguntas o asuntos de seguridad';

  @override
  String get rateInDetails => 'Calificar en los detalles del partido';

  @override
  String get refreshMatches => 'Actualizar partidos';

  @override
  String get regionOptional => 'Región / Estado / Provincia (opcional)';

  @override
  String get relationshipActions => 'Acciones de relación';

  @override
  String get restrictionEnds => 'La restricción termina';

  @override
  String get reviewUnblock => 'Revisar y desbloquear jugadores';

  @override
  String get safetyExpectations =>
      'Expectativas de seguridad para la beta de PadelX';

  @override
  String get searchClubLocation => 'Buscar club o ubicación';

  @override
  String get searchCityArea => 'Buscar una ciudad o zona';

  @override
  String get searchPadelClub => 'Buscar un club de pádel';

  @override
  String get seeAll => 'Ver todo';

  @override
  String get sendPrivateReport => 'Enviar un reporte de seguridad privado';

  @override
  String get setUpGame => 'Configura tu partido';

  @override
  String get sharedMatchRatings => 'Calificaciones del partido compartido';

  @override
  String get stay => 'Quedarme';

  @override
  String get tellPlayersGame =>
      'Cuéntales a los jugadores un poco sobre tu juego';

  @override
  String get thisMatchUnavailable => 'Este partido ya no está disponible.';

  @override
  String get matchMayRemoved => 'Este partido pudo cancelarse o eliminarse.';

  @override
  String get notificationUnavailable => 'Esta notificación no está disponible.';

  @override
  String get socialUnavailable => 'Esta acción social no está disponible.';

  @override
  String get cancelMatchWarning =>
      'Esto eliminará el partido para todos y no se puede deshacer.';

  @override
  String get totalCapacity => 'Capacidad total de jugadores';

  @override
  String get widerRadius => 'Prueba un radio mayor o cambia la ubicación.';

  @override
  String get loadMoreRetry => 'Intenta cargar más de nuevo';

  @override
  String get upcomingMatches => 'Próximos partidos';

  @override
  String get updateMatchDetails => 'Actualizar detalles del partido';

  @override
  String get matchUpdates => 'Actualizaciones de tus partidos y solicitudes.';

  @override
  String get usePhoto => 'Usar foto';

  @override
  String get viewAll => 'Ver todo';

  @override
  String get profileVisibilityHelp =>
      'Al desactivarlo, tu perfil no aparecerá en Buscar jugadores. Aún podrán verlo mediante partidos, amistades, mensajes, invitaciones o historial compartido.';

  @override
  String get capacityHelp => 'Tú cuentas como un jugador · máximo 4';

  @override
  String get noBlockedPlayers => 'No has bloqueado a ningún jugador.';

  @override
  String get spotAvailable => 'Tu lugar confirmado quedará disponible.';

  @override
  String get padelProfile => 'Tu perfil de pádel';

  @override
  String get couldNotOpenEmail =>
      'No se pudo abrir el correo. Escribe a support.padelx@gmail.com.';

  @override
  String get blockedPlayersUnavailable =>
      'Los jugadores bloqueados no están disponibles por el momento.';

  @override
  String get startupFailed => 'No se pudo iniciar PadelX.';

  @override
  String get verificationSent => 'Enviamos un enlace de verificación a';

  @override
  String get legalAgreement =>
      'Acepto los Términos de uso y reconozco el Aviso de privacidad.';

  @override
  String get resetEmailHelp =>
      'Ingresa tu correo y te enviaremos un enlace para restablecer tu contraseña.';

  @override
  String get signInDiscoverPlayers => 'Inicia sesión para buscar jugadores.';

  @override
  String get locationNoCoordinates => 'Esa ubicación no tiene coordenadas.';

  @override
  String levelValue(String level) {
    return 'Nivel $level';
  }

  @override
  String radiusKm(String distance) {
    return '$distance km';
  }

  @override
  String playerCountChoice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jugadores',
      one: '1 jugador',
    );
    return '$_temp0';
  }

  @override
  String playersIn(String city) {
    return 'Jugadores en\n$city';
  }

  @override
  String chooseAreaIn(String city) {
    return 'Elige una zona en $city';
  }

  @override
  String chooseAreaInCountry(String city, String countryCode) {
    return 'Elige una zona en $city, $countryCode.';
  }

  @override
  String currentArea(String area) {
    return 'Zona actual: $area';
  }

  @override
  String preferredSideDisplay(String side) {
    return 'Lado: $side';
  }

  @override
  String get leftSide => 'Izquierda';

  @override
  String get rightSide => 'Derecha';

  @override
  String get eitherSide => 'Cualquiera';

  @override
  String playedTogetherCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count veces',
      one: '1 vez',
    );
    return 'Jugaron juntos $_temp0';
  }

  @override
  String lastPlayed(String date) {
    return 'Último partido: $date';
  }

  @override
  String ratingAverage(String average) {
    return '$average estrellas';
  }

  @override
  String rateNamedPlayer(String name) {
    return 'Calificar a $name';
  }

  @override
  String howWasPlaying(String name) {
    return '¿Cómo fue jugar con $name?';
  }

  @override
  String get everyone => 'Todos';

  @override
  String get playedWithFilter => 'Jugaste con';

  @override
  String get noAreasFound => 'No se encontraron zonas.';

  @override
  String playerLevelSide(String level, String side) {
    return 'Nivel $level · lado $side';
  }

  @override
  String playerNoRatingsMatches(int matches) {
    String _temp0 = intl.Intl.pluralLogic(
      matches,
      locale: localeName,
      other: '$matches partidos completados',
      one: '1 partido completado',
    );
    return 'Aún no hay calificaciones · $_temp0';
  }

  @override
  String playerRatingMatches(String rating, int ratings, int matches) {
    String _temp0 = intl.Intl.pluralLogic(
      matches,
      locale: localeName,
      other: '$matches partidos completados',
      one: '1 partido completado',
    );
    return '$rating estrellas ($ratings) · $_temp0';
  }

  @override
  String emailAppFailed(String email) {
    return 'No se pudo abrir tu app de correo. Puedes escribirnos a $email.';
  }

  @override
  String get pushPermissionExplanation =>
      'PadelX solicitará permiso en iOS y registrará este dispositivo. Puedes cambiar cada categoría cuando quieras.';

  @override
  String get pushBlockedHelp =>
      'Las notificaciones están bloqueadas en la configuración del dispositivo. Actívalas ahí para recibir notificaciones push de PadelX.';

  @override
  String get pushBuildUnavailable =>
      'Las notificaciones push no están configuradas para esta versión. Puedes preparar las categorías abajo.';

  @override
  String get pushSettingsHelp =>
      'Abre Configuración en tu dispositivo, selecciona PadelX y activa Notificaciones antes de volver a intentarlo.';

  @override
  String get pushCategoriesFuture =>
      'Estas categorías se guardan ahora y controlarán la entrega push cuando se habiliten los tipos de notificación en fases posteriores.';

  @override
  String inviteAfterCreate(String name) {
    return 'Invitar a $name después de crear el partido';
  }

  @override
  String ratingSummary(String average, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count calificaciones',
      one: '1 calificación',
    );
    return '$average estrellas ($_temp0)';
  }

  @override
  String get home => 'Inicio';

  @override
  String get browseMatches => 'Ver partidos';

  @override
  String get loadingNotifications => 'Cargando notificaciones';

  @override
  String get loadingYourMatches => 'Cargando tus partidos…';

  @override
  String get yourMatchesUnavailable =>
      'Tus partidos no están disponibles por el momento.';

  @override
  String get noUpcomingMatches => 'No hay próximos partidos.';

  @override
  String get findOpenOrOrganize =>
      'Busca un partido abierto u organiza tu próximo partido.';

  @override
  String get noPastMatches => 'Aún no hay partidos anteriores.';

  @override
  String get completedAppearHere => 'Los partidos completados aparecerán aquí.';

  @override
  String get profileNeedsInfo =>
      'Tu perfil necesita un poco más de información';

  @override
  String get addNameLevel =>
      'Agrega tu nombre visible y nivel para terminar la configuración.';

  @override
  String get profileStatsFailed =>
      'No se pudieron cargar las estadísticas de tu perfil';

  @override
  String get rating => 'Calificación';

  @override
  String get ratings => 'Calificaciones';

  @override
  String get completedMatches => 'Partidos completados';

  @override
  String get repeatPlayers => 'Jugadores recurrentes';

  @override
  String get sharedMatches => 'Partidos compartidos';

  @override
  String get playerProfileFailed =>
      'No se pudo cargar el perfil de este jugador';

  @override
  String get loadingSubmittedRatings => 'Cargando calificaciones enviadas';

  @override
  String get submittedRatingsFailed =>
      'No se pudieron cargar las calificaciones enviadas.';

  @override
  String get playerUnavailable => 'Jugador no disponible';

  @override
  String get dateUnavailable => 'Fecha no disponible';

  @override
  String get occasional => 'Ocasionalmente';

  @override
  String get weekly => 'Semanalmente';

  @override
  String get severalPerWeek => 'Varias veces por semana';

  @override
  String get legalAgreePrefix => 'Acepto los ';

  @override
  String get legalAgreeMiddle => ' y reconozco el ';

  @override
  String get period => '.';

  @override
  String matchesTogether(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count partidos juntos',
      one: '1 partido juntos',
    );
    return '$_temp0';
  }

  @override
  String get completeProfile => 'Completar perfil';

  @override
  String get requestPending => 'Solicitud pendiente';

  @override
  String get organizing => 'Organizando';

  @override
  String get joined => 'Te uniste';

  @override
  String get ratingNotEligible =>
      'Esta calificación ya se envió o no es elegible.';

  @override
  String get match => 'Partido';

  @override
  String get findingOpenMatches => 'Buscando partidos abiertos…';

  @override
  String get deletedPlayer => 'Jugador eliminado';

  @override
  String get signOutLower => 'Cerrar sesión';

  @override
  String get createMatchGetStarted => 'Crea un partido y empieza a jugar.';

  @override
  String get creatingMatch => 'Creando...';

  @override
  String get emailAddressFallback => 'tu dirección de correo';

  @override
  String get checkingEllipsis => 'Comprobando...';

  @override
  String get verifiedMyEmail => 'Ya verifiqué mi correo';

  @override
  String get sendingEllipsis => 'Enviando...';

  @override
  String resendAvailableIn(Object seconds) {
    return 'Podrás reenviar en $seconds s';
  }

  @override
  String get resendVerificationEmail => 'Reenviar correo de verificación';

  @override
  String get signingOutEllipsis => 'Cerrando sesión...';

  @override
  String get emailNotVerified =>
      'Tu correo aún no está verificado. Abre el enlace del correo y vuelve a intentarlo.';

  @override
  String get emailCheckFailed =>
      'No pudimos comprobar tu correo. Inténtalo de nuevo.';

  @override
  String get verificationEmailSent =>
      'Se envió un nuevo correo de verificación.';

  @override
  String get verificationResendFailed =>
      'No pudimos reenviar el correo. Inténtalo de nuevo.';

  @override
  String get signOutFailed =>
      'No pudimos cerrar la sesión. Inténtalo de nuevo.';

  @override
  String get tooManyAttemptsWait =>
      'Demasiados intentos. Espera un momento y vuelve a intentarlo.';

  @override
  String get networkRetry =>
      'Revisa tu conexión a internet y vuelve a intentarlo.';

  @override
  String get accountUnavailableSupport =>
      'Esta cuenta no está disponible. Contacta al soporte de PadelX.';

  @override
  String get recentLoginRequired =>
      'Cierra sesión, vuelve a iniciarla e inténtalo de nuevo.';

  @override
  String get requestFailedGeneric =>
      'No pudimos completar la solicitud. Inténtalo de nuevo.';

  @override
  String get ageConfirmContinue =>
      'Confirma que tienes 18 años o más para continuar.';

  @override
  String get legalAgreeContinue =>
      'Acepta los Términos de uso y reconoce el Aviso de privacidad para continuar.';

  @override
  String get enterEmailPeriod => 'Ingresa tu correo.';

  @override
  String get validEmailRequired => 'Ingresa una dirección de correo válida.';

  @override
  String get enterPasswordPeriod => 'Ingresa tu contraseña.';

  @override
  String get ageRecordAfterCreateFailed =>
      'Tu cuenta se creó, pero no pudimos confirmar la elegibilidad de edad. Inténtalo de nuevo para continuar.';

  @override
  String get legalRecordAfterCreateFailed =>
      'Tu cuenta se creó, pero no pudimos registrar el reconocimiento legal. Inténtalo de nuevo para continuar.';

  @override
  String get accountNotFound => 'No encontramos una cuenta con ese correo.';

  @override
  String get incorrectCredentials => 'Correo o contraseña incorrectos.';

  @override
  String get createAccountFailed =>
      'No pudimos crear tu cuenta. Inténtalo de nuevo.';

  @override
  String get emailAlreadyUsed =>
      'Ya existe una cuenta con ese correo. Intenta iniciar sesión.';

  @override
  String get weakPassword => 'Tu contraseña debe tener al menos 6 caracteres.';

  @override
  String get tooManyAttemptsLater =>
      'Demasiados intentos. Inténtalo de nuevo más tarde.';

  @override
  String get loginFailed => 'No pudimos iniciar sesión. Inténtalo de nuevo.';

  @override
  String get genericCreateAccountFailed =>
      'No pudimos crear tu cuenta. Inténtalo de nuevo.';

  @override
  String get somethingWrongRetry => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get passwordResetSent =>
      'Se envió el correo para restablecer tu contraseña. Revisa tu bandeja de entrada.';

  @override
  String get logIn => 'Iniciar sesión';

  @override
  String get signUp => 'Registrarse';

  @override
  String get welcomeBackAuth =>
      'Qué gusto verte. Tu próximo partido te espera.';

  @override
  String get createVerifyAuth =>
      'Crea tu cuenta y verifica tu correo para comenzar.';

  @override
  String get createPassword => 'Crea una contraseña';

  @override
  String get showPassword => 'Mostrar contraseña';

  @override
  String get hidePassword => 'Ocultar contraseña';

  @override
  String get loggingIn => 'Iniciando sesión...';

  @override
  String get creatingAccount => 'Creando cuenta...';

  @override
  String get retryAgeConfirmation => 'Reintentar confirmación de edad';

  @override
  String get createAccount => 'Crear cuenta';

  @override
  String get switchToSignUp => '¿No tienes cuenta? Regístrate';

  @override
  String get switchToLogin => '¿Ya tienes cuenta? Inicia sesión';

  @override
  String get resetEmailFailed =>
      'No pudimos enviar el correo de restablecimiento. Inténtalo de nuevo.';

  @override
  String get tooManyRequestsLater =>
      'Demasiadas solicitudes. Inténtalo de nuevo más tarde.';

  @override
  String get notSelected => 'Sin seleccionar';

  @override
  String legacyLevelHelp(Object value) {
    return 'El valor actual \"$value\" es heredado. Elige un nivel numérico.';
  }

  @override
  String get choosePhoto => 'Elegir foto';

  @override
  String get chooseAnotherPhoto => 'Elegir otra';

  @override
  String get unblockingEllipsis => 'Desbloqueando…';

  @override
  String get profileUnavailable => 'Perfil no disponible';

  @override
  String get levelNotSet => 'Nivel sin definir';

  @override
  String get couldNotLoadPlayers => 'No pudimos cargar a los jugadores.';

  @override
  String get playedWithEmpty =>
      'Las personas con las que juegues aparecerán aquí después de partidos completados.';

  @override
  String get notRated => 'Sin calificar';

  @override
  String get locationSuggestionsUnavailable =>
      'Las sugerencias de ubicación no están disponibles temporalmente.';

  @override
  String get conversationUnavailable => 'Conversación no disponible';

  @override
  String get conversationReadOnly => 'Esta conversación es de solo lectura.';

  @override
  String get loadOlderMessages => 'Cargar mensajes anteriores';

  @override
  String messageFrom(Object name) {
    return 'Mensaje de $name';
  }

  @override
  String get you => 'Tú';

  @override
  String get enterPasswordHint => 'Ingresa tu contraseña';

  @override
  String get reasonHarassmentAbuse => 'Acoso o conducta abusiva';

  @override
  String get reasonHateDiscrimination => 'Odio o conducta discriminatoria';

  @override
  String get reasonSexualMisconduct => 'Conducta sexual o inapropiada';

  @override
  String get reasonThreatsUnsafe => 'Amenazas o conducta insegura';

  @override
  String get reasonSpamScams => 'Spam o estafas';

  @override
  String get reasonPrivacyViolation => 'Violación de privacidad';

  @override
  String get reasonFraudDeception => 'Fraude o engaño';

  @override
  String get reasonMaliciousReporting => 'Uso indebido de reportes';

  @override
  String get accountTemporarilySuspended => 'Cuenta suspendida temporalmente';

  @override
  String get accountRestricted => 'Cuenta restringida';

  @override
  String get accessTemporarilyRestricted =>
      'Tu acceso a PadelX se restringió temporalmente.';

  @override
  String get accessRestricted => 'Tu acceso a PadelX está restringido.';

  @override
  String get currentLocation => 'Ubicación actual';

  @override
  String get findingYourLocation => 'Buscando tu ubicación…';

  @override
  String get useCurrentLocation => 'Usar mi ubicación actual';

  @override
  String currentLocationRadius(Object distance) {
    return 'Ubicación actual · radio de $distance km';
  }

  @override
  String searchRadius(Object distance) {
    return 'Radio de búsqueda: $distance km';
  }

  @override
  String get all => 'Todos';

  @override
  String get tomorrow => 'Mañana';

  @override
  String get thisWeek => 'Esta semana';

  @override
  String get noOpenMatches => 'Aún no hay partidos abiertos';

  @override
  String get noMatchesFilters => 'Ningún partido coincide con tus filtros';

  @override
  String noMatchesRadius(Object distance) {
    return 'No hay partidos en un radio de $distance km';
  }

  @override
  String get organizer => 'Organizador';

  @override
  String get pending => 'Pendiente';

  @override
  String get full => 'Lleno';

  @override
  String get open => 'Abierto';

  @override
  String get profileDetailsSafe =>
      'Los datos de tu perfil están seguros. Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get visibleDiscovery => 'Visible en Buscar jugadores';

  @override
  String get hiddenDiscovery => 'Oculto en Buscar jugadores';

  @override
  String get setCityPlayers => 'Define tu ciudad para buscar jugadores';

  @override
  String get addCoarseCity =>
      'Agrega una ciudad general a tu perfil. Tu ubicación precisa nunca se comparte.';

  @override
  String get playersUnavailable =>
      'Los jugadores no están disponibles en este momento';

  @override
  String get morePlayersMayMatch => 'Podría haber más jugadores compatibles';

  @override
  String get noPlayersFilters => 'Ningún jugador coincide con estos filtros';

  @override
  String get continueSearchingPlayers =>
      'Continúa buscando entre los jugadores restantes.';

  @override
  String get broadenPlayerFilters =>
      'Prueba una zona, nivel, lado o relación más amplia.';

  @override
  String get anyLevel => 'Cualquier nivel';

  @override
  String get anySide => 'Cualquier lado';

  @override
  String get eitherOnly => 'Solo cualquiera';

  @override
  String get unfriendQuestion => '¿Eliminar amistad con este jugador?';

  @override
  String get unfriendExplanation =>
      'La amistad y la conexión social directa terminarán.';

  @override
  String get incomingRequests => 'Solicitudes recibidas';

  @override
  String get outgoingRequests => 'Solicitudes enviadas';

  @override
  String get acceptedFriends => 'Amistades aceptadas';

  @override
  String get noFriendsYet => 'Aún no tienes amistades.';

  @override
  String get noRequests => 'No hay solicitudes.';

  @override
  String get privacy => 'Privacidad';

  @override
  String get legal => 'Legal';

  @override
  String get accountDeletionInfo => 'Eliminación de cuenta';

  @override
  String get categories => 'Categorías';

  @override
  String get matchMessages => 'Mensajes de partidos';

  @override
  String get joinRequestsCategory => 'Solicitudes para unirse';

  @override
  String get friendRequestsCategory => 'Solicitudes de amistad';

  @override
  String get friendAcceptedCategory => 'Amistad aceptada';

  @override
  String get matchUpdatesCategory => 'Actualizaciones de partidos';

  @override
  String get accountManagement => 'Administración de cuenta';

  @override
  String get pushOn => 'Notificaciones push activadas';

  @override
  String get pushOff => 'Notificaciones push desactivadas';

  @override
  String get notificationsBlockedSettings =>
      'Notificaciones bloqueadas en la configuración del dispositivo';

  @override
  String get pushUnavailableBuild => 'No disponible en esta versión';

  @override
  String get checkingDevicePermission => 'Comprobando permiso del dispositivo…';

  @override
  String get deletionExplanation =>
      'La eliminación es permanente. Los partidos futuros que organices se cancelarán y saldrás de los partidos futuros a los que te hayas unido. La participación histórica se anonimizará. Se eliminarán las calificaciones relacionadas con tu cuenta.';

  @override
  String get deletionPasswordRequired =>
      'Ingresa tu contraseña para este intento de eliminación.';

  @override
  String get deletionRequested =>
      'Se solicitó la eliminación de la cuenta. Cerraste sesión y la limpieza continúa de forma segura en segundo plano.';

  @override
  String get signedOutNotice => 'Cerraste sesión.';

  @override
  String get requestingDeletion => 'Solicitando eliminación…';

  @override
  String get permanentlyDeleteAccount => 'Eliminar mi cuenta permanentemente';

  @override
  String get eligibilityConfirmFailed =>
      'No pudimos confirmar la elegibilidad. Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get confirmingEllipsis => 'Confirmando...';

  @override
  String get legalRecordFailed =>
      'No pudimos registrar tu reconocimiento. Inténtalo de nuevo.';

  @override
  String get legalRefreshFailed =>
      'Se registró tu reconocimiento, pero no pudimos actualizar su estado. Inténtalo de nuevo.';

  @override
  String get savingEllipsis => 'Guardando...';

  @override
  String get guidelineAdultsTitle => 'Solo personas adultas';

  @override
  String get guidelineAdultsBody =>
      'PadelX es para personas mayores de 18 años.';

  @override
  String get guidelineRespectTitle => 'Respeta a otros jugadores';

  @override
  String get guidelineRespectBody =>
      'Trata a los jugadores con respeto. No se permite el acoso, la intimidación ni el abuso dirigido.';

  @override
  String get guidelineHateTitle => 'Odio y discriminación';

  @override
  String get guidelineHateBody =>
      'No se permite contenido ni conducta de odio o discriminación.';

  @override
  String get guidelineSexualTitle => 'Conducta sexual o inapropiada';

  @override
  String get guidelineSexualBody =>
      'No envíes contenido sexual no solicitado ni incurras en acoso sexual u otra conducta inapropiada.';

  @override
  String get guidelineThreatsTitle => 'Amenazas y conducta insegura';

  @override
  String get guidelineThreatsBody =>
      'No se permiten amenazas, violencia, intimidación ni conductas deliberadamente inseguras.';

  @override
  String get guidelineSpamTitle => 'Spam, estafas y engaño';

  @override
  String get guidelineSpamBody =>
      'No publiques estafas, spam, anuncios engañosos, solicitudes de pago fraudulentas ni información de partidos intencionalmente falsa.';

  @override
  String get guidelineImpersonationBody =>
      'No suplantes a otro jugador, sede, organización o persona.';

  @override
  String get guidelinePrivacyTitle => 'Privacidad';

  @override
  String get guidelinePrivacyBody =>
      'No compartas información privada de otra persona sin permiso ni expongas indebidamente ubicaciones privadas o residenciales.';

  @override
  String get guidelineProfilesTitle => 'Perfiles y contenido';

  @override
  String get guidelineProfilesBody =>
      'Los nombres, avatares, biografías, datos de partidos y mensajes deben cumplir estas normas.';

  @override
  String get guidelineMessagingTitle => 'Mensajería';

  @override
  String get guidelineMessagingBody =>
      'No uses mensajes directos ni el chat del partido para acosar, amenazar, estafar, enviar spam o compartir contenido inapropiado no solicitado.';

  @override
  String get guidelineMatchesTitle => 'Partidos';

  @override
  String get guidelineMatchesBody =>
      'Crea anuncios honestos. No tergiverses intencionalmente la ubicación, hora, costo, nivel, disponibilidad ni al organizador.';

  @override
  String get guidelineBlockingTitle => 'Bloqueos y reportes';

  @override
  String get guidelineBlockingBody =>
      'Respeta la decisión de otra persona de bloquear o dejar de comunicarse. No tomes represalias ni envíes reportes maliciosos o inventados.';

  @override
  String get guidelineRealWorldTitle => 'Seguridad presencial';

  @override
  String get guidelineRealWorldBody =>
      'Usa un criterio razonable al conocer personas en la vida real. Trata con cuidado las ubicaciones privadas y residenciales.';

  @override
  String get guidelineReliabilityTitle => 'Confiabilidad futura';

  @override
  String get guidelineReliabilityBody =>
      'PadelX podría usar más adelante conductas objetivas de participación, como cancelaciones y ausencias, para mejorar el emparejamiento.';

  @override
  String get guidelineEnforcementTitle => 'Medidas';

  @override
  String get guidelineEnforcementBody =>
      'PadelX puede revisar conductas reportadas y restringir el acceso cuando corresponda.';

  @override
  String get immediateDangerBody =>
      'Si tú u otra persona están en peligro inmediato, contacta a los servicios de emergencia locales.';

  @override
  String get notEmergencyService =>
      'Los reportes y el soporte de PadelX no son servicios de emergencia.';

  @override
  String get emergencySafetyGuidanceLabel =>
      'Orientación de seguridad para emergencias';

  @override
  String get where => 'Dónde';

  @override
  String get when => 'Cuándo';

  @override
  String get hideLocationDetails => 'Ocultar detalles de ubicación';

  @override
  String get editLocationDetails => 'Editar detalles de ubicación';

  @override
  String get matchDetailsSection => 'Detalles del partido';

  @override
  String get saveChanges => 'Guardar cambios';

  @override
  String get completeYourProfile => 'Completa tu perfil';

  @override
  String get profileRequiredIntro =>
      'Cuéntales a otros jugadores con quién compartirán la cancha.';

  @override
  String get profileEditIntro =>
      'Mantén tus datos actualizados para encontrar partidos más compatibles.';

  @override
  String get chooseCity => 'Elegir ciudad';

  @override
  String get optionalNeighborhoodCity =>
      'Colonia o zona opcional dentro de tu ciudad';

  @override
  String get legacyAreaHelp =>
      'Zona actual; elimínala o reemplázala con un resultado de búsqueda';

  @override
  String get displayNameTooShort =>
      'Ingresa un nombre de al menos 2 caracteres.';

  @override
  String get displayNameTooLong =>
      'El nombre debe tener 40 caracteres o menos.';

  @override
  String get chooseLevelRange => 'Elige un nivel del 1 al 7.';

  @override
  String get bioTooLong => 'La biografía debe tener 160 caracteres o menos.';

  @override
  String get discoveryLocationRequired =>
      'Ingresa país, código de país de 2 letras y ciudad para aparecer en búsquedas.';

  @override
  String get profileSaveFailed =>
      'No pudimos guardar tu perfil. Inténtalo de nuevo.';

  @override
  String get selectPadelClub => 'Selecciona un club de pádel.';

  @override
  String get chooseDateTimePeriod => 'Elige una fecha y hora.';

  @override
  String get choosePlayerLevel => 'Elige un nivel de jugador.';

  @override
  String get matchCreatedInvited => 'Partido creado e invitación enviada.';

  @override
  String get matchCreatedInviteFailed =>
      'El partido se creó, pero no pudimos enviar la invitación.';

  @override
  String get matchCreated => 'Partido creado correctamente.';

  @override
  String get legacyLocationHelp =>
      'Ubicación heredada: busca arriba para elegir una ubicación estructurada.';

  @override
  String get saveMatchFailed =>
      'No pudimos guardar los cambios del partido. Inténtalo de nuevo.';

  @override
  String confirmedPlayersCapacity(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jugadores confirmados actualmente · máximo 4',
      one: '1 jugador confirmado actualmente · máximo 4',
    );
    return '$_temp0';
  }

  @override
  String get matchChatUnavailable => 'El chat del partido no está disponible.';

  @override
  String get completedMatchNoChanges => 'Este partido ya terminó.';

  @override
  String get loginJoinMatch =>
      'Inicia sesión para solicitar unirte a un partido.';

  @override
  String get joinRequestSent => 'Solicitud enviada.';

  @override
  String get joinRequestFailed =>
      'No pudimos enviar tu solicitud. Inténtalo de nuevo.';

  @override
  String get completedMatchesNoChanges =>
      'Los partidos terminados no se pueden modificar.';

  @override
  String get joinRequestApproved => 'Solicitud aprobada.';

  @override
  String get joinRequestDeclined => 'Solicitud rechazada.';

  @override
  String get approveRequestFailed =>
      'No pudimos aprobar la solicitud. Inténtalo de nuevo.';

  @override
  String get declineRequestFailed =>
      'No pudimos rechazar la solicitud. Inténtalo de nuevo.';

  @override
  String get loginLeaveMatch => 'Inicia sesión para salir de un partido.';

  @override
  String get leftMatch => 'Saliste del partido.';

  @override
  String get leaveMatchFailed =>
      'No pudimos sacarte del partido. Inténtalo de nuevo.';

  @override
  String get loginCancelMatch => 'Inicia sesión para cancelar un partido.';

  @override
  String get cancelMatchFailed =>
      'No pudimos cancelar el partido. Inténtalo de nuevo.';

  @override
  String get playersFromMatch => 'Jugadores de este partido';

  @override
  String get confirmedRole => 'Confirmado';

  @override
  String get cancellingEllipsis => 'Cancelando...';

  @override
  String get leavingEllipsis => 'Saliendo...';

  @override
  String get requestStatusFailed =>
      'No pudimos cargar el estado de la solicitud';

  @override
  String get loadingRequestStatus => 'Cargando estado de la solicitud…';

  @override
  String get matchFull => 'Partido lleno';

  @override
  String get requestingEllipsis => 'Solicitando...';

  @override
  String get loadingRequest => 'Cargando solicitud...';

  @override
  String get loadRequestFailed => 'No pudimos cargar la solicitud';

  @override
  String get dateTimeUnavailable => 'Fecha y hora no disponibles';

  @override
  String ratingSelected(Object count) {
    return '$count de 5';
  }

  @override
  String get selectRating => 'Selecciona una calificación';

  @override
  String ratingSubmittedStars(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count estrellas',
      one: '1 estrella',
    );
    return 'Calificación enviada · $_temp0';
  }

  @override
  String submittedStars(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count estrellas',
      one: '1 estrella',
    );
    return 'Enviada · $_temp0';
  }

  @override
  String get startupLoadingSemantics => 'PadelX cargando';

  @override
  String privateVenueExactLocation(String address) {
    return 'Ubicación exacta: $address';
  }

  @override
  String get findMeAMatch => 'Quick Match';

  @override
  String get matchmakingActionFailed =>
      'No se pudo completar esa acción. Intenta de nuevo.';

  @override
  String get completeMatchmakingRequest =>
      'Elige un horario válido y un compañero cuando corresponda.';

  @override
  String get matchmakingIntro =>
      'Dile a PadelX cuándo quieres jugar. Armaremos el partido por ti.';

  @override
  String get solo => 'Solo';

  @override
  String get withPartner => 'Con un compañero';

  @override
  String get choosePartner => 'Elegir compañero';

  @override
  String get availableFrom => 'Disponible desde';

  @override
  String get availableUntil => 'Disponible hasta';

  @override
  String searchLocationSummary(String city, String area) {
    String _temp0 = intl.Intl.selectLogic(area, {
      'other': '$area, $city',
      'empty': '$city',
    });
    return '$_temp0';
  }

  @override
  String get travelRadius => 'Radio de traslado';

  @override
  String get startSearching => 'Empezar búsqueda';

  @override
  String get startQuickMatch => 'Iniciar Quick Match';

  @override
  String get partnerInvitation => 'Invitación de compañero';

  @override
  String get findingYourMatch => 'Buscando tu partido…';

  @override
  String invitedBy(String name) {
    return 'Invitación de $name';
  }

  @override
  String get cancelSearch => 'Cancelar búsqueda';

  @override
  String get matchFound => 'Partido encontrado';

  @override
  String get playersReady => 'Jugadores listos';

  @override
  String get confirmMySpot => 'Confirmar mi lugar';

  @override
  String get courtNotSelected => 'La cancha aún no está seleccionada';

  @override
  String offerExpiresMinutes(String minutes) {
    return 'La oferta vence en aproximadamente $minutes min';
  }

  @override
  String get confirmed => 'Confirmado';

  @override
  String get waiting => 'En espera';

  @override
  String teamNumber(String number) {
    return 'Equipo $number';
  }

  @override
  String get matchmakingSpotFound => 'Lugar encontrado';

  @override
  String get matchmakingMatchConfirmed => 'Partido confirmado';

  @override
  String get matchmakingPartnerInviteBody =>
      'Tienes una invitación de compañero para matchmaking.';

  @override
  String get matchmakingMatchFoundBody =>
      'Hay una propuesta de partido lista para que la confirmes.';

  @override
  String get matchmakingSpotFoundBody =>
      'Hay un lugar listo para que lo confirmes.';

  @override
  String get matchmakingMatchConfirmedBody => 'Tu partido está confirmado.';

  @override
  String get acceptMatch => 'Aceptar partido';

  @override
  String get chooseVenueToFinish =>
      'Todos aceptaron. Elige una cancha para terminar de crear el partido.';

  @override
  String get waitingForVenue =>
      'Todos aceptaron. Esperando que el coordinador elija la cancha.';

  @override
  String get chooseVenue => 'Elegir cancha';

  @override
  String get openMatchDetails => 'Abrir detalles del partido';

  @override
  String get privateCourt => 'Cancha privada';

  @override
  String get clubPublicCourt => 'Cancha de club / pública';

  @override
  String get privateCourtLocation => 'Ubicación de la cancha privada';

  @override
  String get searchVenue => 'Buscar la ubicación de la cancha';

  @override
  String get courtBookingSeparate =>
      'La reservación de la cancha se gestiona por separado.';

  @override
  String get confirmVenue => 'Confirmar cancha';

  @override
  String get matchmakingUnavailable =>
      'La búsqueda de partido no está disponible por ahora.';

  @override
  String get findAPlayer => 'Buscar un jugador';

  @override
  String get autoFillExplanation =>
      'Deja que PadelX encuentre un jugador compatible para este lugar.';

  @override
  String get stopAutoFill => 'Detener AutoFill';

  @override
  String get findingAnotherPlayer => 'Buscando otro jugador…';

  @override
  String get padelVenueSearchLabel => 'Club o cancha de pádel';

  @override
  String get padelVenueSearchHint => 'Buscar canchas de pádel cercanas';

  @override
  String padelVenueRadiusExplanation(String distance) {
    return 'Mostrando canchas de pádel dentro del área acordada de $distance km.';
  }

  @override
  String get noPadelVenuesInArea =>
      'No se encontraron canchas de pádel dentro de tu área de búsqueda.';

  @override
  String get padelVenueOutsideArea =>
      'Esa cancha está fuera del área de búsqueda acordada.';

  @override
  String get padelVenueSearchUnavailable =>
      'La búsqueda de canchas de pádel no está disponible por ahora.';

  @override
  String get privateCourtAddressHelp =>
      '¿No encuentras tu cancha privada? Busca su dirección.';

  @override
  String get yourSpotConfirmed => 'Tu lugar está confirmado';

  @override
  String get findingRemainingPlayers =>
      'Estamos buscando a los jugadores restantes.';

  @override
  String playersConfirmedCount(String confirmed) {
    return '$confirmed de 4 confirmados';
  }

  @override
  String get versus => 'VS';
}
