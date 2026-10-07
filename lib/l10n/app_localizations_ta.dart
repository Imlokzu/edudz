// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tamil (`ta`).
class AppLocalizationsTa extends AppLocalizations {
  AppLocalizationsTa([String locale = 'ta']) : super(locale);

  @override
  String get loading => 'ஏற்றுகிறது';

  @override
  String get mainHome => 'வீடு';

  @override
  String get mainTimetable => 'நேர அட்டவணை';

  @override
  String get mainICanteen => 'iCanteen';

  @override
  String get mainMessages => 'செய்திகள்';

  @override
  String get mainHomework => 'வீட்டுப்பாடம்';

  @override
  String get mainGrades => 'தரங்கள்';

  @override
  String get homeLunchesNotLoaded => 'மதிய உணவை ஏற்ற முடியவில்லை';

  @override
  String get homeNoLunchToday => 'இன்னைக்கு உனக்கு மதிய உணவு இல்லை';

  @override
  String homeLunchToday(int lunch) {
    return 'உங்களிடம் மதிய உணவு விருப்ப எண் $lunch உள்ளது';
  }

  @override
  String homeLunchDontForget(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateStringக்கு மதிய உணவை ஆர்டர் செய்ய மறக்காதீர்கள்';
  }

  @override
  String get homeLogout => 'வெளியேறு';

  @override
  String get homeOnboarding => 'ஆன்போர்டிங்';

  @override
  String get homeSetupICanteen => 'iCanteen ஐ அமைக்கவும்';

  @override
  String get homeNoClasses => 'இன்று பள்ளி இல்லை: டி';

  @override
  String get homeUpdateTitle => 'புதிய பதிப்பு கிடைக்கிறது';

  @override
  String get homeUpdateDescription =>
      'அண்மைக் கால பதிப்பைப் பதிவிறக்க https://github.com/DislikesSchool/edudz/releases ஐப் பார்வையிடவும்';

  @override
  String get homeQuickstart => 'விரைவு தொடக்கம்';

  @override
  String get homePreview => 'முன்னோட்டம்';

  @override
  String get homePatchAvailable => 'புதிய பேட்சை நிறுவுகிறது…';

  @override
  String get homePatchDownloaded =>
      'ஒட்டு பதிவிறக்கப்பட்டது, edudz ஐ மறுதொடக்கம் செய்யவும்';

  @override
  String get homeDeleteData => 'தரவை நீக்கு';

  @override
  String get homeDeleteDataTitle => 'தரவை நீக்கு';

  @override
  String get homeDeleteDataConfirmation =>
      'சேவையகத்திலிருந்து தரவு நீக்கத்தை நிச்சயமாகக் கோர விரும்புகிறீர்களா?';

  @override
  String get homeDeleteDataProcessing => 'தரவை நீக்குகிறது…';

  @override
  String get homeDeleteDataSuccess => 'தரவு வெற்றிகரமாக நீக்கப்பட்டது';

  @override
  String get homeDeleteDataError => 'தரவை நீக்க முடியவில்லை';

  @override
  String get cancel => 'ரத்துசெய்';

  @override
  String get confirm => 'உறுதிப்படுத்தவும்';

  @override
  String get homeGrades => 'தரங்கள்';

  @override
  String get homeHomework => 'வீட்டுப்பாடம்';

  @override
  String get homeworkTitle => 'வீட்டுப்பாடம்';

  @override
  String get messagesTitle => 'செய்திகள்';

  @override
  String get loginPleaseLogin => 'edudz இல் உள்நுழையவும்';

  @override
  String get loginUseExistingCredentials =>
      'ஏற்கனவே உள்ள EduPage நற்சான்றிதழ்களைப் பயன்படுத்தவும்';

  @override
  String get loginUsername => 'பயனர் பெயர்';

  @override
  String get loginPassword => 'கடவுச்சொல்';

  @override
  String get loginServer => 'சேவையகம் (எ.கா., school.edupage.org)';

  @override
  String get loginLogin => 'புகுபதிவு';

  @override
  String get loggingIn => 'உள்நுழைகிறது...';

  @override
  String get loginCustomEndpointCheckbox =>
      'தனிப்பயன் இறுதிப்புள்ளியைப் பயன்படுத்தவும்';

  @override
  String get loginCustomEndpoint =>
      'தனிப்பயன் இறுதிப்புள்ளி முகவரி ஐ உள்ளிடவும்';

  @override
  String get loginDemoButton => 'அல்லது டெமோவை முயற்சிக்கவும்';

  @override
  String get loginCredentialsRequired => 'பயனர்பெயர் மற்றும் கடவுச்சொல் தேவை';

  @override
  String get loginInvalidCredentials => 'தவறான பயனர்பெயர் அல்லது கடவுச்சொல்';

  @override
  String get loginServerOptional =>
      'சேவையகம் விருப்பமானது, ஆனால் உங்களால் உள்நுழைய முடியவில்லை மற்றும் உங்களிடம் சரியான சான்றுகள் உள்ளதா என உறுதியாக இருந்தால் உதவலாம்';

  @override
  String get setupWelcomeTitle => 'edudz க்கு வரவேற்கிறோம்';

  @override
  String get setupWelcomeBody =>
      'edudz என்பது விரைவு, செயல்திறன் மற்றும் பயனர் அனுபவத்தில் கவனம் செலுத்தும் Edupageக்கான நவீன கிளையன்ட் ஆகும். edudz முற்றிலும் திறந்த மூலமானது மற்றும் பயன்படுத்த இலவசம். செய்திகள் மற்றும் புதுப்பிப்புகளுக்கு எங்கள் டிச்கார்ட் சர்வரில் சேருவதை உறுதிசெய்யவும்.';

  @override
  String get setupQuickStartTitle => 'விரைவு தொடக்கம்';

  @override
  String get setupQuickStartExplanation =>
      'பயன்பாட்டை ஏற்றும் நேரத்தை பெரிதும் விரைவுபடுத்துவதற்கான சோதனை நற்பொருத்தம்.';

  @override
  String get setupQuickStartEnable => 'விரைவான தொடக்கத்தை இயக்கு';

  @override
  String get setupQuickStartDetails =>
      'விரைவு தொடக்கத்தை இயக்குவது, சேவையகத்திலிருந்து தரவைப் பெறுவதை விட, தற்காலிகச் சேமிப்புத் தரவை ஆப்ச் விரும்ப வைக்கும். இதை பின்னர் முடக்கலாம்.';

  @override
  String get setupQuickStartInfo => 'விரைவு தொடக்கம் இன்னும் சோதனைக்குரியது';

  @override
  String get setupQuickStartBenefits =>
      'விரைவு தொடக்கமானது பயன்பாட்டை கிட்டத்தட்ட உடனடியாகத் தொடங்கச் செய்யும், மேலும் சேவையகம் பதிலளிக்கும் வரை காத்திருப்பதற்கு மாறாக, பின்னணியில் உள்ள சேவையகத்திலிருந்து தரவைப் பெறும்.';

  @override
  String get setupQuickStartDrawbacks =>
      'இது ஆரம்ப ஏற்றுதல் நேரத்தை விரைவுபடுத்தும் போது, இது காலாவதியான தரவு சுருக்கமாக காட்டப்படுவதற்கு வழிவகுக்கும்.';

  @override
  String get setupDataStorageTitle => 'தரவு சேமிப்பு';

  @override
  String get setupDataStorageExplanation =>
      'மேம்பட்ட செயல்பாட்டை வழங்க edudz ஆனது edudz சேவையகத்தில் சில பயனர் தரவை விருப்பமாக சேமிக்க முடியும். அது இல்லாமல் பயன்பாடு நன்றாக வேலை செய்யும், ஆனால் சில நற்பொருத்தங்கள் குறைவாக இருக்கலாம்.';

  @override
  String get setupDataStorageDisabled => 'சேவையக சேமிப்பு முடக்கப்பட்டுள்ளது';

  @override
  String get setupDataStorageDisabledExplanation =>
      'நீங்கள் இணைக்கும் edudz சேவையக நிகழ்வில் சர்வர் சேமிப்பகம் முடக்கப்பட்டுள்ளது.';

  @override
  String get setupDataStoragePrivacyEncrypted =>
      'உங்கள் தரவு குறியாக்கம் செய்யப்பட்டுள்ளது';

  @override
  String get setupDataStoragePrivacyUnencrypted =>
      'உங்கள் தரவு குறியாக்கம் செய்யப்படவில்லை';

  @override
  String get setupDataStoragePrivacyDetailsEncrypted =>
      'நீங்கள் இணைக்கும் சேவையகம் உங்கள் நற்சான்றிதழ்களை பாதுகாப்பான மற்றும் மறைகுறியாக்கப்பட்ட முறையில் சேமிக்கிறது.';

  @override
  String get setupDataStoragePrivacyDetailsUnencrypted =>
      'நீங்கள் இணைக்கும் சேவையகம் உங்கள் தரவை குறியாக்கம் செய்யாது. சேவையகத்தில் குறியாக்கத்தை இயக்கவும் அல்லது உங்கள் தரவைப் பாதுகாப்பாகச் சேமிக்க அதிகாரப்பூர்வ edudz சேவையகத்தைப் பயன்படுத்தவும் நாங்கள் பரிந்துரைக்கிறோம்.';

  @override
  String get setupDataStorageEnable => 'தரவு சேமிப்பகத்தை இயக்கு';

  @override
  String get setupDataStorageChoose =>
      'எந்தத் தரவைச் சேமிக்க வேண்டும் என்பதைத் தேர்ந்தெடுக்கவும்';

  @override
  String get setupDataStorageAttendance => 'பயனர் உள்நுழைவு சான்றுகள்';

  @override
  String get setupDataStorageGrades => 'உரை செய்தி சேமிப்பு';

  @override
  String get setupDataStorageMessages => 'காலவரிசை சேமிப்பு';

  @override
  String get setupDataStoragePrivacy => 'edudz தரவு சேமிப்பக பாதுகாப்பு';

  @override
  String get setupDataStoragePrivacyDetails =>
      'edudz சேவையகம் தனிப்பட்ட பிரத்யேக சேவையகத்தில் தரவை பாதுகாப்பாகவும் மறைகுறியாக்கப்பட்ட முறையிலும் சேமிக்கிறது. எந்த வெளி தரப்பினருடனும் தரவு பகிரப்படவில்லை.';

  @override
  String get setupFeaturesAvailable => 'வேலை நற்பொருத்தங்கள்';

  @override
  String get setupFeatureBasic =>
      'அடிப்படை பயன்பாட்டு செயல்பாடு (செய்திகள், கால அட்டவணைகள், கிரேடுகள், ...)';

  @override
  String get setupFeatureNotifications => 'புச் அறிவிப்புகள்';

  @override
  String get setupFeatureSearch => 'முழு-உரை தேடல்';

  @override
  String get setupCompleteTitle => 'அமைவு முடிந்தது';

  @override
  String get setupCompleteBody =>
      'உங்கள் அமைவு முடிந்தது. நீங்கள் இப்போது edudz ஐப் பயன்படுத்தத் தொடங்கலாம்.';

  @override
  String get setupDone => 'அமைவு முடிந்தது';

  @override
  String get today => 'இன்று';

  @override
  String get tomorrow => 'நாளை';

  @override
  String timetableTeacher(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString ஆசிரியர்கள்',
      one: 'Teacher',
    );
    return '$_temp0';
  }

  @override
  String get loadCredentials => 'நற்சான்றிதழ்களை ஏற்றுகிறது…';

  @override
  String get loadLoggingIn => 'உள்நுழைகிறது…';

  @override
  String get loadLoggedIn => 'உள்நுழைந்தேன்';

  @override
  String get loadAccessToken => 'அணுகல் கிள்ளாக்கைப் பெறுகிறது…';

  @override
  String get loadVerify => 'சரிபார்க்கிறது';

  @override
  String get loadDownloadTimetable => 'நேர அட்டவணையைப் பதிவிறக்குகிறது…';

  @override
  String get loadDownloadGrades => 'தரங்களைப் பதிவிறக்குகிறது…';

  @override
  String get loadDownloadMessages => 'செய்திகளைப் பதிவிறக்குகிறது…';

  @override
  String get loadDone => 'முடிந்தது!';

  @override
  String get loadError => 'பிழை';

  @override
  String get loadErrorDescription =>
      'தரவை ஏற்றுவதில் பிழை. இந்த பிழை பதிவாகியுள்ளது.';

  @override
  String get iCanteenLoading =>
      'மதிய உணவுகளை ஏற்றுகிறது (இதற்கு சிறிது நேரம் ஆகலாம்)';

  @override
  String get iCanteenCantLoad => 'மதிய உணவுகளை ஏற்ற முடியவில்லை';

  @override
  String get iCanteenSetupPleaseLogin => 'iCanteen இல் உள்நுழைக';

  @override
  String get iCanteenSetupDetails =>
      'இந்த வடிவத்தில் உள்ள முகவரி முகவரி: https://lunches.yourschool.com/login';

  @override
  String get iCanteenSetupServer => 'சேவையக முகவரி';

  @override
  String get iCanteenSetupEmail => 'பயனர் பெயர்';

  @override
  String get iCanteenSetupPassword => 'கடவுச்சொல்';

  @override
  String get iCanteenSetupError => 'உள்நுழைவதில் பிழை ஏற்பட்டது';

  @override
  String get messagesLoadingAttachment => 'pdf ஏற்றுகிறது…';

  @override
  String messagesAttachments(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString இணைப்புகள்',
      one: '1 Attachment',
    );
    return '$_temp0';
  }

  @override
  String get messagesPoll => 'கருத்துக்கணிப்பு';

  @override
  String get createMessageDiscard => 'செய்தியை நிராகரிக்கவா?';

  @override
  String get createMessageDiscardDescription =>
      'செய்தி இன்னும் அனுப்பப்படவில்லை. நிச்சயமாக அதை நிராகரிக்க விரும்புகிறீர்களா?';

  @override
  String get createMessageDiscardCancel => 'ரத்துசெய்';

  @override
  String get createMessageDiscardDiscard => 'நிராகரி';

  @override
  String get createMessageTitle => 'புதிய செய்தி';

  @override
  String get createMessageSelectRecipient => 'பெறுநரைத் தேர்ந்தெடுக்கவும்';

  @override
  String get createMessageMessageHere => 'உங்கள் செய்தி இங்கே';

  @override
  String get createMessageImportant => 'முக்கியமானது';

  @override
  String get createMessageIncludePoll => 'வாக்கெடுப்பைச் சேர்க்கவும்';

  @override
  String get createMessagePollEnableMultiple => 'பல பதில்களை அனுமதிக்கவும்';

  @override
  String get createMessageNewPollOptionPlaceholder => 'புதிய விருப்பம்';

  @override
  String get createMessageErrorSelectRecipient => 'பெறுநரைத் தேர்ந்தெடுக்கவும்';

  @override
  String get createMessageErrorNoMessage =>
      'தயவுசெய்து ஒரு செய்தியை எழுதுங்கள்';

  @override
  String get createMessageSend => 'அனுப்பு';

  @override
  String get createMessageNotifSending => 'செய்தி அனுப்புகிறது';

  @override
  String get createMessageNotifSendingBody => 'உங்கள் செய்தி அனுப்பப்படுகிறது…';

  @override
  String get createMessageNotifSent => 'செய்தி அனுப்பப்பட்டது';

  @override
  String get createMessageNotifSentBody =>
      'உங்கள் செய்தி வெற்றிகரமாக அனுப்பப்பட்டது';

  @override
  String get createMessageNotifError => 'பிழை';

  @override
  String get createMessageNotifErrorBody =>
      'உங்கள் செய்தியை அனுப்புவதில் சிக்கல் ஏற்பட்டது, அது புகாரளிக்கப்பட்டது!';

  @override
  String get qrLoginPleaseLogin => 'edudz QR உள்நுழைவு';

  @override
  String get qrLoginUseExistingCredentials =>
      'QR குறியீட்டைப் பயன்படுத்தி edudz இல் உள்நுழைய உள்ளீர்கள்';

  @override
  String get gradesTitle => 'தரங்கள்';

  @override
  String get messagesSearchTitle => 'செய்திகளைத் தேடுங்கள்';

  @override
  String get messagesSearchHint => 'தேடல் சொல்லை உள்ளிடவும்…';

  @override
  String get messagesSearchInstructions => 'மேலே ஒரு தேடல் சொல்லை உள்ளிடவும்';

  @override
  String get messagesNoResults => 'முடிவுகள் எதுவும் கிடைக்கவில்லை';
}
